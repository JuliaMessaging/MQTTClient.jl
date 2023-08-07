## Connect
[MQTT v3.1.1 Doc](http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/os/mqtt-v3.1.1-os.html#_Toc398718028)

Connects the `Client` instance to the specified broker. There is a synchronous and an asynchronous version available. Both versions take the same arguments.

#### Arguments
**Required arguments:**
* **client**::Client: The client to connect to the broker.
* **host**::AbstractString: The hostname or ip address of the broker.

**Optional arguments:**
* **port**::Integer: The port to use ; *default = 1883*
* **keep_alive**::Int64: If the client hasn't sent or received a message within this time limit, it will ping the broker to verify the connection is still active. A value of 0 means no pings will be sent. ; *default = 0*
* **client_id**::String: The id of the client. This should be unique per broker. Some brokers allow an empty client_id for a stateless connection (this means clean_session needs to be true). ; *default = random 8 char string*
* **user**::User: The user, password pair for authentication with the broker. Password can be empty even if user isn't. The password should probably be encrypted. ; *default = empty pair*  
* **will**::Message: The will of this client. This message gets published on the specified topic once the client disconnects from the broker. The type of this argument is `Message`, consult with it's documentation above for more info. ; *default = empty will*
* **clean_session**::Bool: Specifies whether or not a connection should be resumed. This implies this `Client` instance was previously connected to this broker. ; *default = true*

#### Call example
The dup and retain flag of a will have to be false so it's safest to use the minimal `Message` constructor (Refer to `Message` documentation above).

```julia
connect(client, connection)
```

#### Synchronous connect
This method waits until the client is connected to the broker. TODO add return documentation


#### Asynchronous connect
This method doesn't wait and returns a `Future` object. You may wait on this object with the fetch method. This future completes once the client is fully connected. TODO add future data documentation

## Publish
[MQTT v3.1.1 Doc](http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/os/mqtt-v3.1.1-os.html#_Toc398718037)

Publishes a message to the broker connected to the `Client` instance provided as a parameter. There is a synchronous and an asynchronous version available. Both versions take the same arguments.

#### Arguments
**Required arguments:**
* **client**::Client: The client to send the message over.
* **topic**::String: The topic to publish on. Normal rules for publish topics apply so "/ are allowed but no wildcards.
* **payload**::Any...: Can be several parameters with potentially different types. Can also be empty.

**Optional arguments:**
* **dup**::Bool: Tells the broker that the message is a duplicate. This should not be used under normal circumstances as the library handles this. ; *default = false*
* **qos**::QOS: The MQTT quality of service to use for the message. This has to be a QOS constant (QOS_0, QOS_1, QOS_2). ; *default = QOS_0*
* **retain**::Bool: Whether or not the message should be retained by the broker. This means the broker sends it to all clients who subscribe to this topic ; *default = false*

#### Call example
These are valid `payload...` examples.
```julia
publish(c, "hello/world")
publish(c, "hello/world", "Test", 6, 4.2)
```

This is a valid use of the optional arguments.
```julia
publish(c, "hello/world", "Test", 6, 4.2, qos=QOS_1, retain=true)
```

#### Synchronous publish
This method waits until the publish message has been processed completely and successfully. So in case of QOS 2 it waits until the PUBCOMP has been received. TODO add return documentation


#### Asynchronous publish
This method doesn't wait and returns a `Future` object. You may choose to wait on this object. This future completes once the publish message has been processed completely and successfully. So in case of QOS 2 it waits until the PUBCOMP has been received. TODO change future data documentation


## Subscribe
[MQTT v3.1.1 Doc](http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/os/mqtt-v3.1.1-os.html#_Toc398718063)

Subscribes the `Client` instance, provided as a parameter, to the specified topics. There is a synchronous and an asynchronous version available. Both versions take the same arguments.

#### Arguments
**Required arguments:**
* **client**::Client: The connected client to subscribe on. TODO phrasing?
* **topic**::String: The name of the topic.
* **on_msg**::Function: the callback function for that topic.
* **qos**::QOS: the named argument to set the QOS, defaults to QOS_0.

#### Call example
This example subscribes to the topic "test" with QOS_2 and "test2" with QOS_0.
```julia
subscribe(c, "test", ((t,p)->do_a_thing(p)), qos=QOS_2))
```

#### Synchronous subscribe
This method waits until the subscribe message has been successfully sent and acknowledged. TODO add return documentation

```julia
subscribe(c, "test", on_msg, qos=QOS_2))
```

#### Asynchronous subscribe
This method doesn't wait and returns a `Future` object. You may choose to wait on this object. This future completes once the subscribe message has been successfully sent and acknowledged. TODO change future data documentation


## Unsubscribe
[MQTT v3.1.1 Doc](http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/os/mqtt-v3.1.1-os.html#_Toc398718072)

This method unsubscribes the `Client` instance from the specified topics. There is a synchronous and an asynchronous version available. Both versions take the same arguments.

#### Arguments
**Required arguments:**
* **client**::Client: The connected client to unsubscribe from the topics.
* **topics**::String...: The `Tuple` of topics to unsubscribe from.

#### Example call
```julia
unsubscribe(c, "test1", "test2", "test3")
```

#### Synchronous unsubscribe
This method waits until the unsubscribe method has been sent and acknowledged. TODO add return documentation


#### Asynchronous unsubscribe
This method doesn't wait and returns a `Future` object. You may wait on this object with the fetch method. This future completes once the unsubscribe message has been sent and acknowledged. TODO add future data documentation

## Disconnect
[MQTT v3.1.1 Doc](http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/os/mqtt-v3.1.1-os.html#_Toc398718090)

Disconnects the `Client` instance gracefully, shuts down the background tasks and stores session state. There is only a synchronous version available.

#### Arguments
**Required arguments:**
* **client**::Client: The client to disconnect.

#### Example call
```julia
disconnect(c)
```