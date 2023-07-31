"""
    MQTTConnection(host::IPAddr; ping_timeout=UInt64(60), port=1883, keep_alive::Int64=0, client_id::String=randstring(8), user::User=User("", ""), will::Message=Message(false, 0x00, false, "", UInt8[]), clean_session::Bool=true)

Create a new `Client` object with the specified `host` and optional keyword arguments.

# Arguments
- `host::IPAddr`: The IP address of the MQTT broker.

# Keyword Arguments
- `ping_timeout::UInt64=60`: The number of seconds to wait for a ping response before disconnecting. Default is 60.
- `port::Int=1883`: The port number to connect to. Default is 1883.
- `keep_alive::Int64=0`: The number of seconds between sending keep-alive messages. Default is 0.
- `client_id::String=randstring(8)`: The client ID to use when connecting. Default is a random 8-character string.
- `user::User=User("", "")`: The username and password to use when connecting. Default is an empty username and password.
- `will::Message=Message(false, 0x00, false, "", UInt8[])`: The last will and testament message to send if the client disconnects unexpectedly. Default is an empty message.
- `clean_session::Bool=true`: Whether to start a clean session when connecting. Default is true.

# Examples
```julia
host = Sockets.getaddrinfo("test.mosquitto.org")
client = MQTTConnection(host)

host = Sockets.ip"192.168.1.10"
client = MQTTConnection(host, port=8883, user=User("foo", "bar"))

host = Sockets.localhost
client = MQTTConnection(host, port=5000, keep_alive=10)
```
"""
function MQTTConnection(host::IPAddr;
        ping_timeout=UInt64(60),
        port=1883,
        keep_alive::Int64=0,
        client_id::String=randstring(8),
        user::User=User("", ""),
        will::Message=Message(false, 0x00, false, "", UInt8[]),
        clean_session::Bool=true)
    client = Client(ping_timeout)
    resolve(connect_async(client, "$host", port, keep_alive=keep_alive, client_id=client_id, user=user, will=will, clean_session=clean_session))
    return client
end

"""
    connect_async(client::Client, host::AbstractString, port::Integer=1883;
       keep_alive::UInt16=0x0000,
       client_id::String=randstring(8),
       user::User=User("", ""),
       will::Message=Message(false, 0x00, false, "", Array{UInt8}()),
       clean_session::Bool=true)

Connects the `Client` instance to the specified broker. 
Returns a `Future` object that contains a session_present bit from the broker on success and an exception on failure.

# Arguments
- `keep_alive::Int64=0`: Time in seconds to wait before sending a ping to the broker if no other packets are being sent or received.
- `client_id::String=randstring(8)`: The id of the client.
- `user::User=User("", "")`: The MQTT authentication.
- `will::Message=Message(false, 0x00, false, "", Array{UInt8}())`: The MQTT will to send to all other clients when this client disconnects.  
- `clean_session::Bool=true`: Flag to resume a session with the broker if present.
"""
function connect_async(client::Client, host::AbstractString, port::Integer=1883;
                       keep_alive::Int64=10,
                       client_id::String=randstring(8),
                       user::User=User("", ""),
                       will::Message=Message(false, 0x00, false, "", UInt8[]),
                       clean_session::Bool=true)

    client.write_packets = @mqtt_channel
    try
        client.keep_alive = convert(UInt16, keep_alive)
    catch
        error("Could not convert keep_alive to UInt16")
    end
    client.socket = connect(host, port)
    @debug "connect to host"
    @dispatch write_loop(client)
    @dispatch read_loop(client)
    @debug "set backround procs"

    if client.keep_alive > 0x0000
        @dispatch keep_alive_loop(client)
    end

    @debug "set keep alive"

    #TODO reset client on clean_session = true

    protocol_name = "MQTT"
    protocol_level = 0x04
    connect_flags = 0x02 # clean session

    @debug "set protocol"

    local optional_user = ()
    local optional_will = ()

    if length(user.name) > 0 && length(user.password) > 0
        connect_flags |= 0xC0
        optional_user = (user.name, user.password)
    elseif length(user.name) > 0
        connect_flags |= 0x80
        optional_user = (user.name)
    end

    if length(will.topic) > 0
        optional_will = (will.topic, convert(UInt16, length(will.payload)), will.payload)
        connect_flags |= 0x04 | ((will.qos & 0x03) << 3) | ((will.retain & 0x01) << 5)
    end

    @debug "set optional fields"

    future = Future()
    client.in_flight[0x0000] = future

    write_packet(client, CONNECT,
                 protocol_name,
                 protocol_level,
                 connect_flags,
                 client.keep_alive,
                 client_id,
                 optional_user...,
                 optional_will...)

    @debug "write packets"

    return future
end

"""
    connect(client::Client, host::AbstractString, port::Integer=1883;
        keep_alive::UInt16=0x0000,
        client_id::String=randstring(8),
        user::User=User("", ""),
        will::Message=Message(false, 0x00, false, "", Array{UInt8}()),
        clean_session::Bool=true)

Connects the `Client` instance to the specified broker. 
Waits until the connect is done. Returns the session_present bit from the broker on success and an exception on failure.

# Arguments
- `keep_alive::Int64=0`: Time in seconds to wait before sending a ping to the broker if no other packets are being sent or received.
- `client_id::String=randstring(8)`: The id of the client.
- `user::User=User("", "")`: The MQTT authentication.
- `will::Message=Message(false, 0x00, false, "", Array{UInt8}())`: The MQTT will to send to all other clients when this client disconnects.  
- `clean_session::Bool=true`: Flag to resume a session with the broker if present.
"""
connect(client::Client, host::AbstractString, port::Integer=1883;
        keep_alive::Int64=0,
        client_id::String=randstring(8),
        user::User=User("", ""),
        will::Message=Message(false, 0x00, false, "", UInt8[]),
        clean_session::Bool=true) = resolve(connect_async(client, host, port, keep_alive=keep_alive, client_id=client_id, user=user, will=will, clean_session=clean_session))


"""
    disconnect(client::Client)

Disconnects the client from the broker and stops the tasks.
"""
function disconnect(client::Client)
    write_packet(client, DISCONNECT)
    close(client.write_packets)

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
