# MQTTClient

Documentation for [MQTTClient](https://github.com/JuliaMessaging/MQTTClient.jl).


Installation
------------
```julia
Pkg.add("MQTTClient")
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

## Getting started
To use this library you need to follow at least these steps:
1. Create an `Connection` struct for a given broker and protocol.
2. Create an instance of the `Client` struct.
3. Call the connect method with your `Client` and `Connection` instance.
4. Exchange data with the broker through publish, subscribe and unsubscribe. When subscribing, pass your `on_msg` function for that topic.
5. Disconnect from the broker. (Not strictly necessary, if you don't want to resume the session but considered good form and less likely to crash).

#### Basic example
Refer to the corresponding method documentation to find more options.

```julia
using MQTTClient
broker = "test.mosquitto.org"

#Define the callback for receiving messages.
function on_msg(topic, payload)
    @info("Received message topic: [", topic, "] payload: [", String(payload), "]")
end

#Instantiate a client and connection.
client, connection = MakeConnection(broker, 1883)
connect(client, connection)
#Set retain to true so we can receive a message from the broker once we subscribe
#to this topic.
publish(client, "jlExample", "Hello World!", retain=true)
#Subscribe to the topic we sent a retained message to.
subscribe(client, "jlExample", on_msg, qos=QOS_1)
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

### Read and write loops

`write_loop` takes packets off `write_packets`, serialises each one and writes it to the socket while holding `socket_lock`, so it never interleaves with the keep-alive task's `PINGREQ`. Every write updates `last_sent`. It stops after writing a `DISCONNECT`, or when the client is closed.

`read_loop` reads one packet at a time from the socket: the fixed header byte (packet type in the high four bits, flags in the low four), the remaining length, then the body. It looks up the handler for the packet type in `HANDLERS` and calls it with the body as a `PipeBuffer`. Every packet it reads updates `last_received`. Handlers complete the matching `Future` in `in_flight` (CONNACK, SUBACK, UNSUBACK, PUBACK, PUBCOMP), reply to the broker through `write_packets` (PUBACK and PUBREC for incoming QoS 1 and 2 messages, PUBREL, PUBCOMP), or call the subscription callback (PUBLISH). The loop runs until the client is closed.

`keep_alive_loop` checks once per second whether `keep_alive` seconds have passed since the last packet was sent or since the last one was received and, if so, sends a `PINGREQ`. If no `PINGRESP` arrives within `ping_timeout`, it disconnects.

### Topic trie

Subscription callbacks are stored in `on_msg`, a trie keyed by topic level: `subscribe(client, "sensors/+/temp", cb)` stores `cb` under the path `sensors` -> `+` -> `temp`. When a message arrives, its topic is split on `/` and looked up one level at a time. At each level an exact match is tried first, then the single-level wildcard `+`, then the multi-level wildcard `#`, which matches everything below that level. The first callback found is called with the topic and payload; if none matches, the message is logged at debug level and dropped. `unsubscribe` removes the callback from the trie.
