"""
    topic_eq(baseT::String, compareT::String)

A function that compares two MQTT topics and returns a boolean value based on their equality. If the `baseT` topic contains a wildcard character `#`, the macro checks if the `compareT` topic contains the string before the wildcard character. Otherwise, it checks if the two topics are equal.

# Examples
```julia
julia> topic_eq("sport/#", "sport/tennis")
true

julia> topic_eq("sport/tennis", "sport/football")
false
```
"""
function topic_eq(baseT, compareT)
   if contains(baseT, "#")
       T = split(baseT, "#")[1]
       return contains(compareT, T)
   else
       return baseT == compareT
   end
end

mqtt_read(s::IO, ::Type{UInt16}) = ntoh(read(s, UInt16))

function mqtt_read(s::IO, ::Type{String})
    len = mqtt_read(s, UInt16)
    return String(read(s, len))
end

function mqtt_write(stream::IO, x::Any)
    write(stream, x)
end

function mqtt_write(stream::IO, x::UInt16)
    write(stream, hton(x))
end

function mqtt_write(stream::IO, x::String)
    mqtt_write(stream, convert(UInt16, length(x)))
    write(stream, x)
end

function write_len(s::IO, len::Int64)
    while true
        b = convert(UInt8, mod(len, 128))
        len = div(len, 128)
        if len > 0
            b = b | 0x80
        end
        write(s, b)
        if(len == 0)
            break
        end
    end
end

function read_len(s::IO)
    multiplier = 1
    value = 0
    while true
        b = read(s, UInt8)
        value += (b & 127) * multiplier
        multiplier *= 128
        if multiplier > 128 * 128 * 128
            throw(ErrorException("malformed remaining length"))
        end
        if (b & 128) == 0
            break
        end
    end
    return value
end

"""
    resolve(future)

Fetch the result of a `Future` object and return it. If the result is an exception, throw the exception, otherwise return the result.

# Arguments
- `future`: The `Future` object to fetch the result from.

# Returns
- The result of the `Future`, or throws an exception if the result is an exception.
"""
function resolve(future)
    r = fetch(future)
    return (typeof(r) <: Exception) ? throw(r) : r
end

 # Helper method to check if it is possible to subscribe to a topic
 function filter_wildcard_len_check(sub)
     #Regex: matches any valid topic, + and # are not in allowed in strings, + is only allowed as a single symbol between two /, # is only allowed at the end
     if !(occursin(r"(^[^#+]+|[+])(/([^#+]+|[+]))*(/#)?$", sub)) || length(sub) > 65535
         throw(MQTTException("Invalid topic"))
     end
 end

 # Helper method to check if it is possible to publish a topic
 function topic_wildcard_len_check(topic)
     # Search for + or # in a topic. Return MQTT_ERR_INVAL if found.
     # Also returns MQTT_ERR_INVAL if the topic string is too long.
     # Returns MQTT_ERR_SUCCESS if everything is fine.
     if !(occursin(r"^[^#+]+$", topic)) || length(topic) > 65535
         throw(MQTTException("Invalid topic"))
     end
 end

Base.wait(::Nothing) = sleep(0.001)

function taskstatus(t::Task)
    if istaskdone(t)
        :done
    elseif istaskfailed(t)
        :failed
    elseif istaskstarted(t)
        :running
    else
        :ready
    end
end

"""
    MockMQTTBroker(args...)
    MockMQTTBroker(path::String)
    MockMQTTBroker(ip::Sockets.IPAddr, port::Int)

creates a mock mqtt broker over UDS or TCP that handles CONNECT, SUBSCRIBE, UNSUBSCRIBE, PUBLISH, PING, and DISCONNECT messages.

## Example

```julia
using Sockets # need sockets to us ip""

server = MQTTClient.MockMQTTBroker(ip"127.0.0.1", 1883)
# Sockets.TCPServer(RawFD(20) active)
client, conn = MakeConnection(ip"127.0.0.1", 1883)
# MQTTClient.Configuration(MQTTClient[state: ready, read_loop: ready, write_loop: ready, keep_alive: ready]
# , Connection(Protocol: MQTTClient.TCP(ip"127.0.0.1", 1883), Client ID: OL5hUGmT))

connect(client, conn)
# 0x00

subscribe(client, "foo/bar", (args...) -> nothing)
# 2-element Vector{UInt8}:
#  0x01
#  0x00
publish(client, "bar/foo", qos=QOS_2)
unsubscribe(client, "foo/bar")

disconnect(client)
# (0x00, 0x00, 0x00)
close(server)
```

"""
function MockMQTTBroker(args...)
    server = listen(args...)

    function mock_response(cmd::UInt8, flags::UInt8, buffer::IO)
        if cmd == 0x10 # CONNECT
        #     println("Received CONNECT packet")
            return [Packet(0x20, 0x0000)] # CONNACK
        elseif cmd == 0x80 # SUBSCRIBE
            # println("Received SUBSCRIBE packet")
            id = mqtt_read(buffer, UInt16)
            return [Packet(0x90, UInt8[id >> 8, id & 0xFF, 0x01, 0x00])] # SUBACK
        elseif cmd == 0x30 # PUBLISH
            # println("Received PUBLISH packet")
            dup = (flags & 0x08) >> 3
            qos = (flags & 0x06) >> 1
            retain = (flags & 0x01)
            topic = mqtt_read(buffer, String)
            if qos !== 0x00 # not QOS0
                id = mqtt_read(buffer, UInt16)
                return [Packet(0x40, id)] # PUBACK
            end
        elseif cmd == 0xA0 # UNSUBSCRIBE
            # println("Received UNSUBSCRIBE packet")
            id = mqtt_read(buffer, UInt16)
            return [Packet(0xB0, id)] # UNSUBACK
        elseif cmd == 0xC0 # PINGREQ
            # println("Recieved PING REQ packet")
            return [Packet(0xD0, 0x00)]
        end
        []
    end

    @async while isopen(server)
        conn = accept(server)
        while isopen(conn)
            # read data
            cmd_flags = read(conn, UInt8)
            len = read_len(conn)
            data = read(conn, len)
            buffer = PipeBuffer(data)
            cmd = cmd_flags & 0xF0
            flags = cmd_flags & 0x0F

            # pause and transition.
            sleep(0.001)

            if cmd == 0xE0 # DISCONNECT
                # println("Received DISCONNECT packet")
                # DISCONNECT does not require acknowledgment
                close(conn)
                break
            end

            # respond
            packets = mock_response(cmd, flags, buffer)
            for packet in packets
                buffer = PipeBuffer()
                for i in packet.data
                    mqtt_write(buffer, i)
                end
                data = take!(buffer)
                write(conn, packet.cmd)
                write_len(conn, length(data))
                write(conn, data)
                sleep(0.001)
            end
        end
    end
    server
end