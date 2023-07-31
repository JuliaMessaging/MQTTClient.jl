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
Client(ping_timeout::UInt64 = 10)
```

Use the wrapping function. this is equivalent to using the Client constructor; but with more specific syntax.
```julia
MQTTConnection()
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
connect(c, "test.mosquitto.org", keep_alive=60, client_id="TestClient", user=User("name", "pw"), will=Message(QOS_2, "TestClient/will", "payload", more_payload_data))
```

#### Synchronous connect
This method waits until the client is connected to the broker. TODO add return documentation

```julia
function connect(client::Client, host::AbstractString, port::Integer=1883;
keep_alive::Int64=0,
client_id::String=randstring(8),
user::User=User("", ""),
will::Message=Message(false, 0x00, false, "", Array{UInt8}()),
clean_session::Bool=true)
```

#### Asynchronous connect
This method doesn't wait and returns a `Future` object. You may wait on this object with the fetch method. This future completes once the client is fully connected. TODO add future data documentation

```julia
function connect_async(client::Client, host::AbstractString, port::Integer=1883;
keep_alive::Int64=0,
client_id::String=randstring(8),
user::User=User("", ""),
will::Message=Message(false, 0x00, false, "", Array{UInt8}()),
clean_session::Bool=true)
```