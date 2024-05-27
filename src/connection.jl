"""
    TCP <: AbstractIOConnection

A struct representing a TCP connection.

The Transmission Control Protocol (TCP) is one of the main protocols of the Internet protocol suite. It provides reliable, ordered, and error-checked delivery of a stream of bytes between applications running on hosts communicating via an IP network. TCP is connection-oriented, meaning that a connection between client and server is established before data can be sent.

# Fields
- `ip::IPAddr`: The IP address of the remote host.
- `port::Int64`: The port number on the remote host.

# Constructor
`TCP(ip::IPAddr = Sockets.localhost, port::Int64 = 1883)` constructs a new `TCP` object with the specified IP address and port number (default: localhost:1883).
"""
struct TCP <: AbstractIOConnection
    ip::IPAddr
    port::Int64
    TCP(ip::IPAddr = Sockets.localhost, port::Int64 = 1883) = new(ip, port)
end

"""
    UDS <: AbstractIOConnection

A struct representing a Unix domain socket (UDS) connection.

A Unix domain socket, or IPC (inter-process communication) socket, is a data communications endpoint for exchanging data between processes executing on the same host operating system.

# Fields
- `path::AbstractString`: The file system path of the socket.

# Constructor
`UDS(path::AbstractString = pdw())` constructs a new `UDS` object with the specified file system path.
"""
struct UDS <: AbstractIOConnection
    path::AbstractString
    UDS(path::AbstractString = pwd()) = new(path)
end

"""
    MockIOConnection
A struct to signify there is no connection to a MQTT Broker. should be used for testing.
"""
struct MockIOConnection <: AbstractIOConnection end

"""
    IOConnection(ip::IPAddr, port::Int64)

Constructs a new `TCP` object with the specified IP address and port number.

# Arguments
- `ip::IPAddr`: The IP address of the remote host.
- `port::Int64`: The port number on the remote host.

# Returns
- `TCP`: A new `TCP` object.

---

    IOConnection(ip::String, port::Int64)

Constructs a new `TCP` object with the specified IP address and port number.

# Arguments
- `ip::String`: The IP address of the remote host as a string.
- `port::Int64`: The port number on the remote host.

# Returns
- `TCP`: A new `TCP` object.

---

    IOConnection(path::AbstractString)

Constructs a new `UDS` object with the specified file system path.

# Arguments
- `path::AbstractString`: The file system path of the socket.

# Returns
- `UDS`: A new `UDS` object.
"""
IOConnection(ip::IPAddr, port::Int64) = TCP(ip, port)
IOConnection(ip::String, port::Int64) = TCP(getaddrinfo(ip), port)
IOConnection(path::AbstractString) = UDS(path)
IOConnection() = MockIOConnection()

"""
    connect(protocol::UDS) -> PipeEndpoint

Establishes a connection to a Unix domain socket at the given path specified in the `UDS` struct.
"""
connect(protocol::UDS) = connect(protocol.path)
"""
    connect(protocol::TCP) -> TCPSocket

Establishes a TCP connection to the given IP address and port specified in the `TCP` struct.
"""
connect(protocol::TCP) = connect(protocol.ip, protocol.port)

"""
    connect(protocol::MockIOConnection) -> IOBuffer

Mocks a connection to an MQTT Broker with a local IOBuffer. Should only be used for testing.
"""
connect(protocol::MockIOConnection) = IOBuffer()


"""
    MQTTConnection{T <: AbstractIOConnection}

A struct containing an MQTT connection's metadata.

# Fields
- `protocol::T`: The underlying IO connection.
- `keep_alive::Int64`: The keep-alive time in seconds.
- `client_id::String`: The client identifier.
- `user::User`: The user credentials.
- `will::Message`: The last will and testament message.
- `clean_session::Bool`: Whether to start a clean session.

# Constructors
`MQTTConnection(protocol::T;
        keep_alive::Int64=32,
        client_id::String=randstring(8),
        user::User=User("", ""),
        will::Message=Message(false, 0x00, false, "", UInt8[]),
        clean_session::Bool=true) where T <: AbstractIOConnection` constructs a new `MQTTConnection` object with the specified protocol and optional keyword arguments.

`MQTTConnection(protocol::T,
        keep_alive::Int64,
        client_id::String,
        user::User,
        will::Message,
        clean_session::Bool) where T <: AbstractIOConnection` constructs a new `MQTTConnection` object with the specified arguments.
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

Base.show(io::IO, connection::MQTTConnection) = print(io, "MQTTConnection(Protocol: $(connection.protocol), Client ID: $(connection.client_id)", (connection.user == User("","") ? "" : ", User Name: $(connection.user.name)"), ")")
