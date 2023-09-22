"""
    MakeConnection(host::Union{IPAddr, String}, port::Int64;
        ping_timeout=UInt64(60),
        keep_alive::Int64=32,
        client_id::String=randstring(8),
        user::User=User("", ""),
        will::Message=Message(false, 0x00, false, "", UInt8[]),
        clean_session::Bool=true) -> Tuple{Client, MQTTConnection}

Establishes a connection to the given host and port. The host can be either an IP address or a hostname.

# Arguments
- `host`: The IP address or hostname to connect to.
- `port`: The port number to connect to.
- `ping_timeout`: The maximum time in seconds to wait for a ping response before considering the connection lost.
- `keep_alive`: The maximum time in seconds that the client should wait before sending a ping request to keep the connection alive.
- `client_id`: The client identifier string.
- `user`: The user credentials for authentication.
- `will`: The last will and testament message to be sent by the server on behalf of the client.
- `clean_session`: Whether to start a clean session or resume a previous one.

# Returns
A tuple containing a `Client` object and an `MQTTConnection` object.
"""
MakeConnection(host::Union{IPAddr, String}, port::Int64;
        ping_timeout=UInt64(60),
        keep_alive::Int64=32,
        client_id::String=randstring(8),
        user::User=User("", ""),
        will::Message=Message(false, 0x00, false, "", UInt8[]),
        clean_session::Bool=true)::Tuple = MakeConnection(IOConnection(host,port),ping_timeout,keep_alive,client_id,user,will,clean_session)


"""
    MakeConnection(path::String;
        ping_timeout=UInt64(60),
        keep_alive::Int64=32,
        client_id::String=randstring(8),
        user::User=User("", ""),
        will::Message=Message(false, 0x00, false, "", UInt8[]),
        clean_session::Bool=true)  -> Tuple{Client, MQTTConnection}

Establishes a connection to a Unix domain socket at the given path.

# Arguments
- `path`: The path of the Unix domain socket to connect to.
- `ping_timeout`: The maximum time in seconds to wait for a ping response before considering the connection lost.
- `keep_alive`: The maximum time in seconds that the client should wait before sending a ping request to keep the connection alive.
- `client_id`: The client identifier string.
- `user`: The user credentials for authentication.
- `will`: The last will and testament message to be sent by the server on behalf of the client.
- `clean_session`: Whether to start a clean session or resume a previous one.

# Returns
A tuple containing a `Client` object and an `MQTTConnection` object.
"""
MakeConnection(path::String;
        ping_timeout=UInt64(60),
        keep_alive::Int64=32,
        client_id::String=randstring(8),
        user::User=User("", ""),
        will::Message=Message(false, 0x00, false, "", UInt8[]),
        clean_session::Bool=true)::Tuple = MakeConnection(IOConnection(path),ping_timeout,keep_alive,client_id,user,will,clean_session)

"""
    MakeConnection(io::T,
        ping_timeout=UInt64(60),
        keep_alive::Int64=32,
        client_id::String=randstring(8),
        user::User=User("", ""),
        will::Message=Message(false, 0x00, false, "", UInt8[]),
        clean_session::Bool=true)  -> Tuple{Client, MQTTConnection}

Establishes an MQTT connection using the given IO connection.

# Arguments
- `io`: An IO connection object that implements the `AbstractIOConnection` interface.
- `ping_timeout`: The maximum time in seconds to wait for a ping response before considering the connection lost.
- `keep_alive`: The maximum time in seconds that the client should wait before sending a ping request to keep the connection alive.
- `client_id`: The client identifier string.
- `user`: The user credentials for authentication.
- `will`: The last will and testament message to be sent by the server on behalf of the client.
- `clean_session`: Whether to start a clean session or resume a previous one.

# Returns
A tuple containing a `Client` object and an `MQTTConnection` object.
"""
function MakeConnection(io::T,
    ping_timeout=UInt64(60),
    keep_alive::Int64=32,
    client_id::String=randstring(8),
    user::User=User("", ""),
    will::Message=Message(false, 0x00, false, "", UInt8[]),
    clean_session::Bool=true)::Tuple where T <: AbstractIOConnection
    return (Client(ping_timeout), MQTTConnection(io, keep_alive, client_id, user, will, clean_session))
end
# NOTE: comment out for now
# TODO: add Type to Client struct at some point.
# function MakeConnection(io::TCP,
#         ping_timeout=UInt64(60),
#         keep_alive::Int64=32,
#         client_id::String=randstring(8),
#         user::User=User("", ""),
#         will::Message=Message(false, 0x00, false, "", UInt8[]),
#         clean_session::Bool=true)::Tuple{Client, MQTTConnection}
#     return (Client{TCPSocket}(ping_timeout), MQTTConnection(io, keep_alive, client_id, user, will, clean_session))
# end
# function MakeConnection(io::UDS,
#         ping_timeout=UInt64(60),
#         keep_alive::Int64=32,
#         client_id::String=randstring(8),
#         user::User=User("", ""),
#         will::Message=Message(false, 0x00, false, "", UInt8[]),
#         clean_session::Bool=true)::Tuple{Client, MQTTConnection}
#     return (Client{PipeEndpoint}(ping_timeout), MQTTConnection(io, keep_alive, client_id, user, will, clean_session))
# end



"""
    connect_async(client::Client, connection::MQTTConnection)

Establishes an asynchronous connection to an MQTT broker using the specified `client` and `connection` objects.

The function sets up the write and read loops, as well as the keep-alive loop if the keep-alive time is greater than 0. It also sets the protocol name and level, and the connect flags.

If the user name and password are provided in the `connection` object, they are included in the connect flags. If a will topic is provided, it is also included in the connect flags.

The function returns a `Future` object that can be used to track the progress of the connection.
"""
function connect_async(client::Client, connection::MQTTConnection)
    if !isready(client)
            @atomicswap client.state = 0x00
            client.on_msg = Dict{String,Function}()
            client.last_id = 0x0000
            client.in_flight = Dict{UInt16, Future}()
            client.write_packets = Channel{Packet}(typemax(Int64))
            client.socket = nothing
            client.socket_lock = ReentrantLock()
            client.ping_outstanding = Atomic{UInt8}(0)
            client.last_sent = Atomic{Float64}()
            client.last_received = Atomic{Float64}()
    end

    try
        client.keep_alive = convert(UInt16, connection.keep_alive)
    catch
        error("Could not convert keep_alive to UInt16")
    end

    client.socket = connect(connection.protocol)

    @async write_loop(client)
    @async read_loop(client)

    if client.keep_alive > 0x0000
        @async keep_alive_loop(client)
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

    @async begin
        wait(client.in_flight[0x0000])
        @atomicreplace client.state 0x00 => 0x01
    end

    return future
end


"""
    connect(client::Client, connection::MQTTConnection)

Establishes a synchronous connection to an MQTT broker using the specified `client` and `connection` objects.

This function is a wrapper around the `connect_async` function, which establishes an asynchronous connection. The `connect` function blocks until the connection is established by calling the `resolve` function on the `Future` object returned by `connect_async`.
"""
connect(client::Client, connection::MQTTConnection) = resolve(connect_async(client, connection))


"""
    disconnect(client::Client)

Disconnects the client from the broker and stops the tasks.
"""
function disconnect(client::Client)
    if !isconnected(client)
        throw(MQTTException("Not Connected. Cannot Disconnect."))
    end
    write_packet(client, DISCONNECT)
    close(client.write_packets)

    @atomicreplace client.state 0x01 => 0x02

    # FIXME: figure out what this does.
    #wait(client.socket.closenotify)
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
    future = Future()
    id = packet_id(client)
    client.in_flight[id] = future
    write_packet(client, SUBSCRIBE | 0x02, id, topic, qos)
    client.on_msg[topic] = on_msg
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
function unsubscribe_async(client::Client, topics::String...)
    future = Future()
    id = packet_id(client)
    client.in_flight[id] = future
    topic_data = []
    write_packet(client, UNSUBSCRIBE | 0x02, id, topics...)
    ((t) -> delete!(client.on_msg, t)).(topics)
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
