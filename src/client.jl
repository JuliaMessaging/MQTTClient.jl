"""
    Client([ping_timeout::UInt64])

A mutable struct that represents an MQTT client.

# Arguments
- `ping_timeout::UInt64`: The number of seconds to wait for a ping response before disconnecting. Default is 60.
- `path::AbstractString`: The path to the unix domain socket created by the broker.

# Fields
- `on_msg::Dict{String,Function}`: A dictionary of functions that will be called when a message is received.
- `keep_alive::UInt16`: The number of seconds between pings.
- `last_id::UInt16`: The last message ID used.
- `in_flight::Dict{UInt16, Future}`: A dictionary of messages that are waiting for a response.
- `write_packets::AbstractChannel`: A channel for writing packets to the socket.
- `socket`: The socket used for communication.
- `socket_lock`: A lock for the socket.
- `ping_timeout::UInt64`: The number of seconds to wait for a ping response before disconnecting.
- `ping_outstanding::Atomic{UInt8}`: A flag indicating whether a ping has been sent but not yet received.
- `last_sent::Atomic{Float64}`: The time the last packet was sent.
- `last_received::Atomic{Float64}`: The time the last packet was received.

# Examples
```julia
julia> client = Client()
julia> client = Client("/tmp/mqtt/mqtt.sock")
```
"""
mutable struct Client

    on_msg::Dict{String,Function}
    keep_alive::UInt16

    # TODO mutex?
    last_id::UInt16
    in_flight::Dict{UInt16, Future}

    write_packets::AbstractChannel
    socket
    socket_lock # TODO add type

    ping_timeout::UInt64

    # TODO remove atomic?
    ping_outstanding::Atomic{UInt8}
    last_sent::Atomic{Float64}
    last_received::Atomic{Float64}

    Client(ping_timeout::UInt64=UInt64(60)) = new(
            Dict{String,Function}(),
            0x0000,
            0x0000,
            Dict{UInt16, Future}(),
            (@mqtt_channel),
            nothing,
            ReentrantLock(),
            ping_timeout,
            Atomic{UInt8}(0),
            Atomic{Float64}(),
            Atomic{Float64}())
end



"""
    write_loop(client)

This function writes data to the socket.

# Arguments
- `client`: A client object.

# Returns
Nothing.

"""
function write_loop(client)
    try
        while true
            packet = take!(client.write_packets)
            buffer = PipeBuffer()
            for i in packet.data
                mqtt_write(buffer, i)
            end
            data = take!(buffer)
            lock(client.socket_lock)
            write(client.socket, packet.cmd)
            write_len(client.socket, length(data))
            write(client.socket, data)
            unlock(client.socket_lock)
            atomic_xchg!(client.last_sent, time())
        end
    catch e
        # channel closed
        if isa(e, InvalidStateException)
            close(client.socket)
        else
            rethrow()
        end
    end
end

"""
    read_loop(client)

Reads data from a client socket and processes it.

# Arguments
- `client`: A client object.

# Example
```julia
read_loop(client)
```
"""
function read_loop(client)
    try
        while true
            cmd_flags = read(client.socket, UInt8)
            len = read_len(client.socket)
            data = read(client.socket, len)
            buffer = PipeBuffer(data)
            cmd = cmd_flags & 0xF0
            flags = cmd_flags & 0x0F

            if haskey(HANDLERS, cmd)
                atomic_xchg!(client.last_received, time())
                HANDLERS[cmd](client, buffer, cmd, flags)
            else
                # TODO unexpected cmd protocol error
            end
        end
    catch e
        # socket closed
        if !isa(e, EOFError)
            rethrow()
        end
    end
end

"""
    keep_alive_loop(client::Client)

This function runs a loop that sends a PINGREQ message to the MQTT broker to keep the connection alive. The loop checks the connection at regular intervals determined by the `client.keep_alive` value. If no message has been sent or received within the keep-alive interval, a PINGREQ message is sent. If no PINGRESP message is received within the `client.ping_timeout` interval, the client is disconnected.
"""
function keep_alive_loop(client::Client)
    ping_sent = time()

    if client.keep_alive > 10
        check_interval = 5
    else
        check_interval = client.keep_alive / 2
    end
    timer = Timer(0, check_interval)

    while true
        if time() - client.last_sent[] >= client.keep_alive || time() - client.last_received[] >= client.keep_alive
            if client.ping_outstanding[] == 0x0
                atomic_xchg!(client.ping_outstanding, 0x1)
                try
                    lock(client.socket_lock)
                    write(client.socket, PINGREQ)
                    write(client.socket, 0x00)
                    unlock(client.socket_lock)
                    atomic_xchg!(client.last_sent, time())
                catch e
                    if isa(e, InvalidStateException)
                        break
                        # TODO is this the socket closed exception? Handle accordingly
                    else
                        rethrow()
                    end
                end
                ping_sent = time()
            end
        end

        if client.ping_outstanding[] == 1 && time() - ping_sent >= client.ping_timeout
            try # No pingresp received
                disconnect(client)
                break
            catch e
                # channel closed
                if isa(e, InvalidStateException)
                    break
                else
                    rethrow()
                end
            end
            # TODO automatic reconnect
        end

        wait(timer)
    end
end

# TODO needs mutex
function packet_id(client)
    if client.last_id == typemax(UInt16)
        client.last_id = 0
    end
    client.last_id += 1
    return client.last_id
end

# write packet to mqtt broker
function write_packet(client::Client, cmd::UInt8, data...)
    put!(client.write_packets, Packet(cmd, data))
end
