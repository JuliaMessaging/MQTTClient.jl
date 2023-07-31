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

```julia
function publish(client::Client, topic::String, payload...;
    dup::Bool=false,
    qos::UInt8=0x00,
    retain::Bool=false)
```

#### Asynchronous publish
This method doesn't wait and returns a `Future` object. You may choose to wait on this object. This future completes once the publish message has been processed completely and successfully. So in case of QOS 2 it waits until the PUBCOMP has been received. TODO change future data documentation

```julia
function publish_async(client::Client, topic::String, payload...;
    dup::Bool=false,
    qos::UInt8=0x00,
    retain::Bool=false)
```

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

```julia
function subscribe_async(c, "test", on_msg, qos=QOS_2))
```

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

```julia
function unsubscribe(client::Client, topics::String...)
```

#### Asynchronous unsubscribe
This method doesn't wait and returns a `Future` object. You may wait on this object with the fetch method. This future completes once the unsubscribe message has been sent and acknowledged. TODO add future data documentation

```julia
function unsubscribe_async(client::Client, topics::String...)
```

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

#### Synchronous disconnect
```julia
function disconnect(client::Client))
```