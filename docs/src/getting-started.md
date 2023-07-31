# MQTTClient

Documentation for [MQTTClient](https://github.com/NickMcSweeney/MQTTClient.jl).


Installation
------------
```julia
Pkg.clone("https://github.com/NickMcSweeney/MQTTClient.jl.git")
```
Testing
-------
```julia
Pkg.test("MQTTClient")
```
Usage
-----
Import the library with the `using` keyword.

Samples are available in the `examples` directory.
```julia
using MQTTClient
```

Advanced Usage
--------------
True multi-threading is available via Dagger.jl and will be enabled if Julia is run with more than 1 thread enabled.

```bash
julia -t 2
```
The _read_loop_, _write_loop_ _keep_alive_loop_, and _on_msg_ callback are all called as scheduled processes via `Dagger.@spawn` rather than `@async`. 
This is work in progress, so it is not 100% stable. 
Also based on testing, for simple/low load networks it is slower to run it threaded than to run async (probably because there is more overhead managing threads).

## Getting started
To use this library you need to follow at least these steps:
1. Define an `on_msg` callback function for a given topic.
2. Create an instance of the `Client` struct.
3. Call the connect method with your `Client` instance.
4. Exchange data with the broker through publish, subscribe and unsubscribe. When subscribing, pass your `on_msg` function for that topic.
5. Disconnect from the broker. (Not strictly necessary, if you don't want to resume the session but considered good form and less likely to crash).

#### Basic example
Refer to the corresponding method documentation to find more options.

```julia
using MQTTClient
broker = "test.mosquitto.org"

#Define the callback for receiving messages.
function on_msg(topic, payload)
    info("Received message topic: [", topic, "] payload: [", String(payload), "]")
end

#Instantiate a client.
client = Client()
connect(client, broker, 1883)
#Set retain to true so we can receive a message from the broker once we subscribe
#to this topic.
publish(client, "jlExample", "Hello World!", retain=true)
#Subscribe to the topic we sent a retained message to.
subscribe(client, "jlExample", on_msg, qos=QOS_1))
#Unsubscribe from the topic
unsubscribe(client, "jlExample")
#Disconnect from the broker. Not strictly needed as the broker will also
#disconnect us if the socket is closed. But this is considered good form
#and needed if you want to resume this session later.
disconnect(client)
```


Internal workings
-----------------
It isn't necessary to read this section if you just want to use this library but it might give additional insight into how everything works.

The `Client` instance has a `Channel`, called `write_packets`, to keep track of outbound messages that still need to be sent. Julia channels are basically just blocking queues so they have exactly the behavior we want.

For storing messages that are awaiting acknowledgment, `Client` has a `Dict`, mapping message ids to `Future` instances. These futures get completed once the message has been completely acknowledged. There might then be information in the `Future` relevant to the specific message.

Once the connect method is called on a `Client`, relevant fields are initialized and the julia `connect` method is called to get a connected socket. Then two background tasks are started that perpetually check for messages to send and receive. If `keep_alive` is non-zero another tasks get started that handles sending the keep alive and verifying the pingresp arrived in time.

TODO explain read and write loop a bit