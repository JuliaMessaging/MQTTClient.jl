struct TCP <: AbstractIOConnection
    ip::IPAddr
    port::Int64
    TCP(ip::IPAddr = Sockets.localhost, port::Int64 = 1883) = new(ip, port)
end

struct UDS <: AbstractIOConnection
    path::AbstractString
    UDS(path::AbstractString = pwd()) = new(path)
end

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
    connect(protocol::UDS)::PipeEndpoint

Establishes a connection to a Unix domain socket at the given path specified in the `UDS` struct.
"""
connect(protocol::UDS) = connect(protocol.path)
"""
    connect(protocol::TCP)::TCPSocket

Establishes a TCP connection to the given IP address and port specified in the `TCP` struct.
"""
connect(protocol::TCP) = connect(protocol.ip, protocol.port)

"""
    connect(protocol::MockIOConnection)::IOBuffer

Mocks a connection to an MQTT Broker with a local IOBuffer. Should only be used for testing.
"""
connect(protocol::MockIOConnection) = IOBuffer()


"""
    Connection{T <: AbstractIOConnection}

The `Connection` struct in Julia encapsulates the configuration and connection details required for an MQTT client to connect to an MQTT broker. 
This struct supports two types of connection protocols: TCP and Unix Domain Sockets (UDS), both of which are subtypes of `AbstractIOConnection`. 
The struct includes fields for protocol type, keep-alive interval, client ID, user credentials, a will message (a message that is sent by the broker if the client disconnects unexpectedly), 
and a flag indicating whether the session is clean (i.e., no persistent session state). 
The `Connection` constructor allows for flexible instantiation with default or specified values for each field, 
enabling easy setup of connection parameters tailored to the specific requirements of the MQTT client and broker interaction.

## Fields
- `protocol::T`: The underlying IO connection.
- `keep_alive::Int64`: The keep-alive time in seconds.
- `client_id::String`: The client identifier.
- `user::User`: The user credentials.
- `will::Message`: The last will and testament message.
- `clean_session::Bool`: Whether to start a clean session.

## Constructors
`Connection(protocol::T;
        keep_alive::Int64=32,
        client_id::String=randstring(8),
        user::User=User("", ""),
        will::Message=Message(false, 0x00, false, "", UInt8[]),
        clean_session::Bool=true) where T <: AbstractIOConnection` constructs a new `Connection` object with the specified protocol and optional keyword arguments.

`Connection(protocol::T,
        keep_alive::Int64,
        client_id::String,
        user::User,
        will::Message,
        clean_session::Bool) where T <: AbstractIOConnection` constructs a new `Connection` object with the specified arguments.

### Example using TCP protocol with default and custom values
```julia
tcp_connection = Connection(
    TCP(Sockets.localhost, 1883);       # Using TCP with localhost and port 1883
    keep_alive=60,                      # Custom keep-alive interval of 60 seconds
    client_id="my_mqtt_client",         # Custom client ID
    user=User("username", "password"),  # Custom user credentials
    will=Message(false, 0x01, false, "last/will/topic", UInt8[]),  # Custom will message
    clean_session=true                  # Default clean session flag
)
```

### Example using UDS protocol with all custom values
```julia
uds_connection_full = Connection(
    UDS("/var/run/mqtt.sock"),          # Using UDS with specified socket path
    45,                                 # Custom keep-alive interval of 45 seconds
    "another_client",                   # Custom client ID
    User("user", "pass"),               # Custom user credentials
    Message(true, 0x00, true, "will/topic", UInt8[1, 2, 3]),  # Custom will message
    false                               # Custom clean session flag
)
```
"""
struct Connection{T <: AbstractIOConnection} <: AbstractConfigElement
    protocol::T
    keep_alive::Int64
    client_id::String
    user::User
    will::Message
    clean_session::Bool

    Connection(protocol::T;
            keep_alive::Int64=32,
            client_id::String=randstring(8),
            user::User=User("", ""),
            will::Message=Message(false, 0x00, false, "", UInt8[]),
            clean_session::Bool=true) where T <: AbstractIOConnection = new{T}(protocol, keep_alive, client_id, user, will, clean_session)

    Connection(protocol::T,
            keep_alive::Int64,
            client_id::String,
            user::User,
            will::Message,
            clean_session::Bool) where T <: AbstractIOConnection = new{T}(protocol, keep_alive, client_id, user, will, clean_session)
end

Base.show(io::IO, connection::Connection) = print(io, "Connection(Protocol: $(connection.protocol), Client ID: $(connection.client_id)", (connection.user == User("","") ? "" : ", User Name: $(connection.user.name)"), ")")

"""
    Configuration

Container for the mqtt client and mqtt connection data. This is partially iterable, and can be spread to 2 variables with the `...` splat operator or `client, conn = conf` variable assignment.

## Example

```julia
# using the MakeConnection interface function
config = MakeConnection("/temp/mqtt.sock")

# using a defined IO
io = IOConnection("localhost",1883)
config = Configuration(io)

# spreading the variables
client, connection = Configuration(...)
```
"""
struct Configuration
    client::Client
    connection::Connection

    function Configuration(io::T,
            ping_timeout=UInt64(60),
            keep_alive::Int64=32,
            client_id::String=randstring(8),
            user::User=User("", ""),
            will::Message=Message(false, 0x00, false, "", UInt8[]),
            clean_session::Bool=true) where {T <: AbstractIOConnection}
        new(Client(ping_timeout), Connection(io, keep_alive, client_id, user, will, clean_session))
    end
    function Configuration(client::Client, connection::Connection)
        new(client, connection)
    end
end

Base.iterate(conf::Configuration, state=1) = state == 1 ? (conf.client, 2) : (conf.connection, nothing)
Base.length(::Configuration) = 2
Base.IteratorSize(::Type{Configuration}) = Base.HasLength()
Base.IteratorEltype(::Type{Configuration}) = AbstractConfigElement