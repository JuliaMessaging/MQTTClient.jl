"""
    MakeConnection(host::Union{IPAddr, String}, port::Int64;
                   ping_timeout=UInt64(60),
                   keep_alive::Int64=32,
                   client_id::String=randstring(8),
                   user::User=User("", ""),
                   will::Message=Message(false, 0x00, false, "", UInt8[]),
                   clean_session::Bool=true)::Tuple

    MakeConnection(path::String;
                   ping_timeout=UInt64(60),
                   keep_alive::Int64=32,
                   client_id::String=randstring(8),
                   user::User=User("", ""),
                   will::Message=Message(false, 0x00, false, "", UInt8[]),
                   clean_session::Bool=true)::Tuple

Creates an MQTT client connection to an MQTT broker, handling the construction 
of both the `Client` and `Connection` objects inside the `Configuration` struct. This function provides 
flexible ways to specify the connection details either through a TCP connection 
with host and port, a Unix Domain Socket path.

# Arguments
- `host::Union{IPAddr, String}`: The IP address or hostname of the MQTT broker.
- `port::Int64`: The port number to connect to.
- `path::String`: The file system path for Unix Domain Socket connection.
- `io::T`: An object of subtype `AbstractIOConnection`.
- `ping_timeout::UInt64`: The ping timeout in seconds (default: 60).
- `keep_alive::Int64`: The keep-alive time in seconds (default: 32).
- `client_id::String`: The client identifier (default: a random string of length 8).
- `user::User`: The user credentials for the MQTT broker (default: anonymous user).
- `will::Message`: The last will message to be sent in case of unexpected disconnection (default: an empty will message).
- `clean_session::Bool`: Indicates whether to start a clean session (default: true).

# Returns
- A `Configuration` struct where `client::Client` is the MQTT client instance 
  and `connection::Connection` is the connection information used to connect to the broker.

This function simplifies the process of setting up an MQTT client connection. 
Depending on the type of connection, you can specify the broker's IP address 
and port or a Unix Domain Socket path, it infers the Protocol and then constructs the necessary 
provided or default parameters. Refer to the documentation for [`Client`](@ref) and 
[`Connection`](@ref) object.

## Examples

```julia
# Example with IP address and port
client, connection = MakeConnection("127.0.0.1", 1883, client_id="mqtt_client_1")

# Example with Unix Domain Socket path
client, connection = MakeConnection("/var/run/mqtt.sock", user=User("user", "pass"))
```
"""
function MakeConnection(host::Union{IPAddr, String}, port::Int64;
        ping_timeout=UInt64(60),
        keep_alive::Int64=32,
        client_id::String=randstring(8),
        user::User=User("", ""),
        will::Message=Message(false, 0x00, false, "", UInt8[]),
        clean_session::Bool=true)::Configuration 
    Configuration(IOConnection(host,port),ping_timeout,keep_alive,client_id,user,will,clean_session)
end
function MakeConnection(path::String;
        ping_timeout=UInt64(60),
        keep_alive::Int64=32,
        client_id::String=randstring(8),
        user::User=User("", ""),
        will::Message=Message(false, 0x00, false, "", UInt8[]),
        clean_session::Bool=true)::Configuration
    Configuration(IOConnection(path),ping_timeout,keep_alive,client_id,user,will,clean_session)
end


"""
    connect_async(client::Client, connection::Connection)

Establishes an asynchronous connection to the MQTT broker using the provided `Client` and `Connection` objects. This function initializes the client, establishes the connection, and starts the necessary loops for communication.

# Arguments
- `client::Client`: The MQTT client instance.
- `connection::Connection`: The connection information used to connect to the broker.

# Returns
- A `Future` object that can be used to await the completion of the connection process.

## Example

```julia
client, connection = MakeConnection("127.0.0.1", 1883, client_id="mqtt_client_1")
future = connect_async(client, connection)
wait(future)
```

# See Also
- [`connect`](@ref): The synchronous version of this function.
"""
function connect_async(client::Client, connection::Connection)
    if !isready(client)
            @atomicswap client.state = 0x00
            client.on_msg = TrieNode()
            @atomicswap client.last_id = 0x0000
            client.in_flight = Dict{UInt16, Future}()
            client.write_packets = Channel{Packet}(typemax(Int64))
            client.socket = IOBuffer()
            client.socket_lock = ReentrantLock()
            @atomicswap client.ping_outstanding = 0
            @atomicswap client.last_sent = 0.0
            @atomicswap client.last_received = 0.0
            client.write_task = Task(nothing)
            client.read_task = Task(nothing)
            client.keep_alive_task = Task(nothing)
    end

    try
        client.keep_alive = convert(UInt16, connection.keep_alive)
    catch
        error("Could not convert keep_alive to UInt16")
    end

    client.socket = connect(connection.protocol)

    client.write_task = @async write_loop(client)
    client.read_task = @async read_loop(client)

    if client.keep_alive > 0x0000
        client.keep_alive_task = @async keep_alive_loop(client)
    end

    #TODO reset client on clean_session = true

    protocol_name = "MQTT"
    protocol_level = 0x04 # v3.1.1
    connect_flags = 0x02 # clean session

    local optional_user = ()
    local optional_will = ()

    if length(connection.user.name) > 0 && length(connection.user.password) > 0
        connect_flags |= 0xC0
        optional_user = (connection.user.name, connection.user.password)
    elseif length(connection.user.name) > 0
        connect_flags |= 0x80
        optional_user = (connection.user.name)
    end

    if length(connection.will.topic) > 0
        optional_will = (connection.will.topic, convert(UInt16, length(connection.will.payload)), connection.will.payload)
        connect_flags |= 0x04 | ((connection.will.qos & 0x03) << 3) | ((connection.will.retain & 0x01) << 5)
    end

    future = Future()
    client.in_flight[0x0000] = future

    write_packet(client, CONNECT,
                 protocol_name,
                 protocol_level,
                 connect_flags,
                 client.keep_alive,
                 connection.client_id,
                 optional_user...,
                 optional_will...)

    return future
end


"""
    connect(client::Client, connection::Connection)

Establishes a synchronous connection to the MQTT broker using the provided [`Client`](@ref) and [`Connection`](@ref) objects. This function wraps [`connect_async`](@ref) and waits for the connection process to complete.

# Arguments
- `client::Client`: The MQTT client instance.
- `connection::Connection`: The connection information used to connect to the broker.

# Returns
- The result of the connection process after it completes.

The connect function is responsible for establishing a connection between an MQTT client and an MQTT broker. It initializes the client's state, sets up the necessary communication channels, and handles the connection handshake according to the MQTT protocol. When called, connect first ensures that the client's state and resources are properly initialized. This includes resetting the client's state, setting up the socket connection, and creating the channels and locks required for communication. The function then starts the asynchronous tasks needed to manage the read, write, and keep-alive loops, which are crucial for maintaining the connection and ensuring that messages are sent and received properly.

Additionally, the connect function handles the specifics of the MQTT protocol handshake. It constructs and sends the CONNECT packet, including details such as the client ID, user credentials, and optional will message. This handshake process ensures that the broker recognizes the client and sets up the session according to the specified parameters. The synchronous connect function blocks until the connection process is complete, providing a straightforward way to establish the connection without needing to manage asynchronous operations directly. This makes it suitable for applications that require a simple, blocking call to connect to the broker and start communicating immediately.

## Example

```julia
client, connection = MakeConnection("127.0.0.1", 1883, client_id="mqtt_client_1")
result = connect(client, connection)
```

# See Also
- [`connect_async`](@ref): The asynchronous version of this function.
- [`Client`](@ref)
- [`Connection`](@ref)
"""
connect(client::Client, connection::Connection) = fetch(connect_async(client, connection))


"""
    disconnect(client::Client)

Disconnects the client from the broker and stops the tasks.
"""
function disconnect(client::Client)
    if !isconnected(client)
        throw(MQTTException("Not Connected. Cannot Disconnect."))
    end

    write_packet(client, DISCONNECT)
    if isa(client.write_task, Task)
        wait(client.write_task)
    end

    @atomicreplace client.state 0x01 => 0x02

    eof(client.socket)

    if isa(client.read_task, Task)
        wait(client.read_task)
    end

    close(client.write_packets)

    close(client.socket)

    res = fetch(client)
    @debug "MQTT client disconnected with async task states: $res"
    res
end

"""
    subscribe_async(client::Client, topic::String, on_msg::Function; qos::UInt8=QOS_0)

Subscribe to a topic asynchronously.

# Arguments
- `client::Client`: The MQTT client.
- `topic::String`: The topic to subscribe to.
- `on_msg::Function`: The function to call when a message is received on the topic.
- `qos::UInt8`: The quality of service level to use for the subscription. Default is 0.

# Returns
- `Future`: A future that can be used to wait for the subscription to complete.

# Examples
```julia
future = subscribe_async(client, "my/topic", on_msg, qos=QOS_2)
```
"""
function subscribe_async(client, topic, on_msg; qos=QOS_0)
    filter_wildcard_len_check(topic)
    future = Future()
    id = packet_id(client)
    client.in_flight[id] = future
    write_packet(client, SUBSCRIBE | 0x02, id, topic, qos)
    insert!(client.on_msg, topic, on_msg)
    return future
end

"""
    subscribe(client::Client, topic::String, on_msg::Function; qos::UInt8=QOS_0)

Subscribe to a topic.

# Arguments
- `client::Client`: The MQTT client.
- `topic::String`: The topic to subscribe to.
- `on_msg::Function`: The function to call when a message is received on the topic.
- `qos::UInt8`: The quality of service level to use for the subscription. Default is 0.

# Examples
```julia
subscribe(client, "my/topic", on_msg)
```
"""
subscribe(client, topic, on_msg; qos=QOS_0) = resolve(subscribe_async(client, topic, on_msg, qos=qos))


"""
    unsubscribe_async(client::Client, topics::String...)

Unsubscribes the `Client` instance from the supplied topic names.
Deletes the callback from the client
Returns a `Future` object that contains `nothing` on success and an exception on failure. 
"""
function unsubscribe_async(client::Client, topic::String)
    future = Future()
    id = packet_id(client)
    client.in_flight[id] = future
    write_packet(client, UNSUBSCRIBE | 0x02, id, topic)
    remove!(client.on_msg, topic)
    return future
end
function unsubscribe_async(client::Client, topics::String...)
    future = Future()
    id = packet_id(client)
    client.in_flight[id] = future
    write_packet(client, UNSUBSCRIBE | 0x02, id, topics...)
    ((t) -> remove!(client.on_msg, t)).(topics)
    return future
end

"""
    unsubscribe(client::Client, topics::String...) 

Unsubscribes the `Client` instance from the supplied topic names.
Waits until the unsubscribe is fully acknowledged. Returns `nothing` on success and an exception on failure.
"""
unsubscribe(client::Client, topics::String...) = resolve(unsubscribe_async(client, topics...))

"""
   publish_async(client::Client, message::Message)

Publishes the message. Returns a `Future` object that contains `nothing` on success and an exception on failure. 
"""
function publish_async(client::Client, message::Message)
    future = Future()
    optional = ()
    topic_wildcard_len_check(message.topic)
    if message.qos == 0x00
        put!(future, 0)
    elseif message.qos == 0x01 || message.qos == 0x02
        future = Future()
        id = packet_id(client)
        client.in_flight[id] = future
        optional = (id)
    else
        throw(MQTTException("invalid qos"))
    end
    cmd = PUBLISH | ((message.dup & 0x1) << 3) | (message.qos << 1) | message.retain
    write_packet(client, cmd, message.topic, optional..., message.payload)
    return future
end

"""
    publish_async(client::Client, topic::String, payload...;
       dup::Bool=false,
       qos::QOS=QOS_0,
       retain::Bool=false)

Pulishes a message with the specified parameters. Returns a `Future` object that contains `nothing` on success and an exception on failure.  
"""
publish_async(client::Client, topic::String, payload...;
              dup::Bool=false,
              qos::QOS=QOS_0,
              retain::Bool=false) = publish_async(client, Message(dup, UInt8(qos), retain, topic, payload...))

"""
   publish(client::Client, topic::String, payload...;
      dup::Bool=false,
      qos::QOS=QOS_0,
      retain::Bool=false)

 Waits until the publish is completely acknowledged. Publishes a message with the specified parameters. Returns `nothign` on success and throws an exception on failure.
 """
 publish(client::Client, topic::String, payload...;
         dup::Bool=false,
         qos::QOS=QOS_0,
         retain::Bool=false) = resolve(publish_async(client, topic, payload..., dup=dup, qos=qos, retain=retain))
