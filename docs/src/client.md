## Client struct
The client struct is used to store state for an MQTT connection. All callbacks, apart from `on_message`, can't be set through the constructor and have to be set manually after instantiating the `Client` struct.

##### Constructors

```julia
Client()
```

Specify a custom ping_timeout of 600 seconds
```julia
Client(600)
```

Use the wrapping function to get the client and the connection metadata struct. This generates a client and a connection object that can be used for making connections. The connection object stores information about how to connect the client to the broker.

Passing a ip and a port will be infered as a TCP connection.
```julia
client, connection = MakeConnection("localhost", 1883)
```
Passing a single path string will be infered as a UDS connection.
```julia
client, connection = MakeConnection("/tmp/mqtt.sock")
```

Additional information can be specified when the client and connection objects are constructed.
```julia
client, connection = MakeConnection("/tmp/mqtt.sock", keep_alive=60, client_id="TestClient", user=User("name", "pw"), will=Message(QOS_2, "TestClient/will", "payload", more_payload_data))
```

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