## Client struct
The client struct is used to store state for an MQTT connection. All callbacks, apart from `on_message`, can't be set through the constructor and have to be set manually after instantiating the `Client` struct.

**Fields in the Client that are relevant for the library user:**
* **ping_timeout**::UInt64: Time, in seconds, the Client waits for the PINGRESP after sending a PINGREQ before he disconnects ; *default = 60 seconds*
* **on_message**::Function: This function gets called upon receiving a publish message from the broker.
* **on_disconnect**::Function:
* **on_connect**::Function:
* **on_subscribe**::Function:
* **on_unsubscribe**::Function:

##### Constructors

```julia
Client()
```

Specify a custom ping_timeout
```julia
Client(ping_timeout::UInt64 = 700)
```

Use the wrapping function to get the client and the connection metadata struct. this is equivalent to using the Client constructor; but with more specific syntax.
passing a single unix path or a ip and a port here will determine which protocol is used to communication.
```julia
client, connection = MakeConnection()
```

additional information can be specified for when the connection is made.
```julia
client, connection = MakeConnection("/tmp/mqtt.sock", keep_alive=60, client_id="TestClient", user=User("name", "pw"), will=Message(QOS_2, "TestClient/will", "payload", more_payload_data))

## Message struct
The `Message` struct is the data structure for generic MQTT messages. This is mostly used internally but is exposed to the user in some cases for easier to read arguments (Passing a "will" to the connect method uses the `Message` struct for example).

#### Constructors
This is a reduced constructor meant for messages that can't be duplicate or retained (like the "will"). **This message constructor should be in most cases!** The dup and retained flag are false by default.

```julia
function Message(qos::QOS, topic::String, payload...)
```

This is the full `Message` constructor. It has all possible fields.

```julia
function Message(dup::Bool, qos::QOS, retain::Bool, topic::String, payload...)
```

This constructor is mostly for internal use. It uses the `UInt8` equivalent of the `QOS` enum for easier processing.

```julia
function Message(dup::Bool, qos::UInt8, retain::Bool, topic::String, payload...)
```