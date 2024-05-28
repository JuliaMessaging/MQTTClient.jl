## Connect
[MQTT v3.1.1 Doc](http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/os/mqtt-v3.1.1-os.html#_Toc398718028)

Connects the `Client` instance to the specified broker. There is a synchronous and an asynchronous version available. Both versions take the same arguments.

#### Arguments
**Required arguments:**
* **client**::Client: The client to connect to the broker.
* **connection**::Connection: The information for how the client connects to the broker.

use `MakeConnection` to get the client and the connection objects. 

#### Call example

```julia
connect(client, connection)
```

#### Synchronous connect
This method waits until the client is connected to the broker.


#### Asynchronous connect
This method doesn't wait and returns a `Future` object. You may wait on this object with the fetch method. This future completes once the client is fully connected.

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
publish(client, "hello" "world")
publish(client, "foo/bar", "hello world")
```

This is a valid use of the optional arguments.
```julia
publish(client, "foo/bar", "hello world", qos=QOS_1, retain=true)
```

#### Synchronous publish
This method waits until the publish message has been processed completely and successfully. So in case of QOS 2 it waits until the PUBCOMP has been received.


#### Asynchronous publish
This method doesn't wait and returns a `Future` object. You may choose to wait on this object. This future completes once the publish message has been processed completely and successfully. So in case of QOS 2 it waits until the PUBCOMP has been received.


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
This example subscribes to the topic "test" with QOS_2.
```julia
cb(topic, payload) = println("[$topic] $(String(payload))")
subscribe(client, "test", cb, qos=QOS_2))
```

While a lambda function can be used, it can help to define the callback function.
```julia
cb(topic, payload) = println("[$topic] $(String(payload))")
subscribe(client, "foo/bar", cb, qos=QOS_2)
subscribe(client, "foo/baz", ((args...) -> nothing), qos=QOS_2)
```

```bash
julia> client.on_msg
foo/bar: cb
foo/baz: #15
```

#### Synchronous subscribe
This method waits until the subscribe message has been successfully sent and acknowledged.

```julia
subscribe(c, "test", on_msg, qos=QOS_2))
```

#### Asynchronous subscribe
This method doesn't wait and returns a `Future` object. You may choose to wait on this object. This future completes once the subscribe message has been successfully sent and acknowledged.


## Unsubscribe
[MQTT v3.1.1 Doc](http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/os/mqtt-v3.1.1-os.html#_Toc398718072)

This method unsubscribes the Client from the specified topics. There is a synchronous and an asynchronous version available. Both versions take the same arguments.

#### Arguments
**Required arguments:**
* **client**::Client: The connected client to unsubscribe from the topics.
* **topics**::String...: The `Tuple` of topics to unsubscribe from.

#### Example call
```julia
unsubscribe(client, "test")
```

#### Synchronous unsubscribe
This method waits until the unsubscribe method has been sent and acknowledged.


#### Asynchronous unsubscribe
This method doesn't wait and returns a `Future` object. You may wait on this object with the fetch method. This future completes once the unsubscribe message has been sent and acknowledged.

## Disconnect
[MQTT v3.1.1 Doc](http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/os/mqtt-v3.1.1-os.html#_Toc398718090)

Disconnects the `Client` instance gracefully, shuts down the background tasks and stores session state. There is only a synchronous version available.

#### Arguments
**Required arguments:**
* **client**::Client: The client to disconnect.

#### Example call
```julia
disconnect(client)
```