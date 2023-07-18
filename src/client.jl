## Consts
## ------
# command consts
const CONNECT = 0x10
const CONNACK = 0x20
const PUBLISH = 0x30
const PUBACK = 0x40
const PUBREC = 0x50
const PUBREL = 0x60
const PUBCOMP = 0x70
const SUBSCRIBE = 0x80
const SUBACK = 0x90
const UNSUBSCRIBE = 0xA0
const UNSUBACK = 0xB0
const PINGREQ = 0xC0
const PINGRESP = 0xD0
const DISCONNECT = 0xE0

# connect return code consts
const CONNECTION_ACCEPTED = 0x00
const CONNECTION_REFUSED_UNACCEPTABLE_PROTOCOL_VERSION = 0x01
const CONNECTION_REFUSED_IDENTIFIER_REJECTED = 0x02
const CONNECTION_REFUSED_SERVER_UNAVAILABLE = 0x03
const CONNECTION_REFUSED_BAD_USER_NAME_OR_PASSWORD = 0x04
const CONNECTION_REFUSED_NOT_AUTHORIZED = 0x05

# error consts
const CONNACK_ERRORS = Dict{UInt8, String}(
                                           0x01 => "connection refused unacceptable protocol version",
                                           0x02 => "connection refused identifier rejected",
                                           0x03 => "connection refused server unavailable",
                                           0x04 => "connection refused bad user name or password",
                                           0x05 => "connection refused not authorized",
                                          )

## Enums
## -----
# QOS values
@enum(QOS::UInt8,
      QOS_0 = 0x00,
      QOS_1 = 0x01,
      QOS_2 = 0x02)

# connection values
@enum(CONN::UInt8,
      TCP = 0x00, # transmission control protocol
      UDS = 0x01) # unix domain socket


## Structs
## -------

"""
    struct MQTTException <: Exception
        msg::AbstractString
    end

    A custom exception type for MQTT errors.

    # Examples
    ```julia-repl
    julia> throw(MQTTException(\"Connection refused: Not authorized\"))
    MQTTException(\"Connection refused: Not authorized\")
    ```
"""
struct MQTTException <: Exception
    msg::AbstractString
end

"""
    Packet

A composite type representing a packet.

# Fields

- `cmd::UInt8`: an 8-bit unsigned integer representing the command.
- `data::Any`: any value representing the data.

"""
struct Packet
    cmd::UInt8
    data::Any
end

"""
    Message

A composite type representing a message.

# Fields

- `dup::Bool`: a boolean indicating whether the message is a duplicate.
- `qos::UInt8`: an 8-bit unsigned integer representing the quality of service.
- `retain::Bool`: a boolean indicating whether the message should be retained.
- `topic::String`: a string representing the topic.
- `payload::Array{UInt8}`: an array of 8-bit unsigned integers representing the payload.

# Constructors

- `Message(qos::QOS, topic::String, payload...)`: constructs a new message with default values for `dup` and `retain`.
- `Message(dup::Bool, qos::QOS, retain::Bool, topic::String, payload...)`: constructs a new message with all fields specified.
- `Message(dup::Bool, qos::UInt8, retain::Bool, topic::String, payload...)`: constructs a new message with all fields specified.

"""
struct Message
    dup::Bool
    qos::UInt8
    retain::Bool
    topic::String
    payload::Array{UInt8}

    function Message(qos::QOS, topic::String, payload...)
        return Message(false, UInt8(qos), false, topic, payload...)
    end

    function Message(dup::Bool, qos::QOS, retain::Bool, topic::String, payload...)
        return Message(dup, UInt8(qos), retain, topic, payload...)
    end

    function Message(dup::Bool, qos::UInt8, retain::Bool, topic::String, payload...)
        # Convert payload to UInt8 Array with PipeBuffer
        buffer = PipeBuffer()
        for i in payload
            write(buffer, i)
        end
        encoded_payload = take!(buffer)
        return new(dup, qos, retain, topic, encoded_payload)
    end
end

"""
    User(name::String, password::String)

A struct that represents a user with a name and password.

# Examples
```julia
julia> user = User("John", "password")
User("John", "password")
```
"""
struct User
    name::String
    password::String
end

"""
    AbstractConnection

    Base Connection type
"""
abstract type AbstractConnection end

"""
    TCPConnection(host::AbstractString, port::Integer)

    A struct that represents a transport control protocol socket connection.

# Examples
```julia
julia> conn = TCPConnection("localhost", 1883)
TCPConnection(MQTTClient.TCP, "localhost", 1883)
```
"""
mutable struct TCPConnection <: AbstractConnection

    type::CONN
    host::String
    port::Int

    TCPConnection() = new(
        TCP,
        "localhost",
        8883
       )
    
    TCPConnection(host::AbstractString, port::Int) = new(
        TCP,
        host,
        port
       )
end

"""
    UDSConnection(host::AbstractString, port::Integer)

    A struct that represents a unix domain socket connection.

# Examples
```julia
julia> conn = UDSConnection("/tmp/mqtt/mqtt.sock")
UDSConnection(MQTTClient.UDS, "/tmp/mqtt/mqtt.sock")
```
"""
mutable struct UDSConnection <: AbstractConnection
    type::CONN
    path::String

    UDSConnection() = new(
        UDS,
        pwd()
       )
    
    UDSConnection(path::AbstractString) = new(
        UDS,
        path
       )

end

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

    Client() = new(
            Dict{String,Function}(),
            0x0000,
            0x0000,
            Dict{UInt16, Future}(),
            (@mqtt_channel),
            TCPSocket(),
            ReentrantLock(),
            60,
            Atomic{UInt8}(0),
            Atomic{Float64}(),
            Atomic{Float64}())

    Client(ping_timeout::UInt64) = new(
            Dict{String,Function}(),
            0x0000,
            0x0000,
            Dict{UInt16, Future}(),
            (@mqtt_channel),
            TCPSocket(),
            ReentrantLock(),
            ping_timeout,
            Atomic{UInt8}(0),
            Atomic{Float64}(),
            Atomic{Float64}())
    
    Client(path::AbstractString, ping_timeout::UInt64 = UInt64(60)) = new(
            Dict{String,Function}(),
            0x0000,
            0x0000,
            Dict{UInt16, Future}(),
            (@mqtt_channel),
            PipeServer(),
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
