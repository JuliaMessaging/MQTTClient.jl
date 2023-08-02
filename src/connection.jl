"""
    AbstractIOConnection

    Base Connection Protocol type
"""
abstract type AbstractIOConnection end

struct TCP <: AbstractIOConnection
    ip::IPAddr
    port::Int64
    TCP(ip::IPAddr = Sockets.localhost, port::Int64 = 1883) = new(ip, port)
end
IOConnection(ip::IPAddr, port::Int64) = TCP(ip, port)
IOConnection(ip::String, port::Int64) = TCP(getaddrinfo(ip), port)
connect(protocol::TCP) = connect(protocol.ip, protocol.port)

struct UDS <: AbstractIOConnection
    path::AbstractString
    UDS(path::AbstractString = pdw()) = new(path)
end
IOConnection(path::AbstractString) = UDS(path)
connect(protocol::UDS) = connect(protocol.path)


"""
    TCPConnection(host::AbstractString, port::Integer)

    A struct that represents a transport control protocol socket connection.

# Examples
```julia
julia> conn = TCPConnection("localhost", 1883)
TCPConnection(MQTTClient.TCP, "localhost", 1883)
```
"""
struct MQTTConnection{T <: AbstractIOConnection}
    protocol::T
    keep_alive::Int64
    client_id::String
    user::User
    will::Message
    clean_session::Bool

    MQTTConnection(protocol::T;
            keep_alive::Int64=32,
            client_id::String=randstring(8),
            user::User=User("", ""),
            will::Message=Message(false, 0x00, false, "", UInt8[]),
            clean_session::Bool=true) where T <: AbstractIOConnection = new{T}(protocol, keep_alive, client_id, user, will, clean_session)

    MQTTConnection(protocol::T,
            keep_alive::Int64,
            client_id::String,
            user::User,
            will::Message,
            clean_session::Bool) where T <: AbstractIOConnection = new{T}(protocol, keep_alive, client_id, user, will, clean_session)
end
