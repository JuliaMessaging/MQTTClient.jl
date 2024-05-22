## Consts
## ------
# command consts
const CONNECT = 0x10
const CONNACK = 0x20
const PUBLISH = 0x30
const PUBACK = 0x40
const PUBREC = 0x50
const PUBREL = 0x60
const PUBCOMP = 0x70
const SUBSCRIBE = 0x80
const SUBACK = 0x90
const UNSUBSCRIBE = 0xA0
const UNSUBACK = 0xB0
const PINGREQ = 0xC0
const PINGRESP = 0xD0
const DISCONNECT = 0xE0

# connect return code consts
const CONNECTION_ACCEPTED = 0x00
const CONNECTION_REFUSED_UNACCEPTABLE_PROTOCOL_VERSION = 0x01
const CONNECTION_REFUSED_IDENTIFIER_REJECTED = 0x02
const CONNECTION_REFUSED_SERVER_UNAVAILABLE = 0x03
const CONNECTION_REFUSED_BAD_USER_NAME_OR_PASSWORD = 0x04
const CONNECTION_REFUSED_NOT_AUTHORIZED = 0x05

# error consts
const CONNACK_ERRORS = Dict{UInt8, String}(
                                           0x01 => "connection refused unacceptable protocol version",
                                           0x02 => "connection refused identifier rejected",
                                           0x03 => "connection refused server unavailable",
                                           0x04 => "connection refused bad user name or password",
                                           0x05 => "connection refused not authorized",
                                          )

const CLIENT_STATE = Dict{UInt8, Symbol}(
                                        0x00 => :ready,
                                        0x01 => :connected,
                                        0x02 => :closed,
                                        )
## Types

"""
    AbstractIOConnection

    Base Connection Protocol type
"""
abstract type AbstractIOConnection end

AbstractProtocol = Union{PipeEndpoint, TCPSocket}

## Enums
## -----
# QOS values
@enum(QOS::UInt8,
      QOS_0 = 0x00,
      QOS_1 = 0x01,
      QOS_2 = 0x02)

## Structs
## -------

"""
    struct MQTTException <: Exception
        msg::AbstractString
    end

    A custom exception type for MQTT errors.

    # Examples
    ```julia
    julia> throw(MQTTException(\"Connection refused: Not authorized\"))
    MQTTException(\"Connection refused: Not authorized\")
    ```
"""
struct MQTTException <: Exception
    msg::AbstractString
end

"""
    Packet

A composite type representing a packet.

# Fields

- `cmd::UInt8`: an 8-bit unsigned integer representing the command.
- `data::Any`: any value representing the data.

"""
struct Packet
    cmd::UInt8
    data::Any
end

Base.:(==)(p1::Packet, p2::Packet) = p1.cmd == p2.cmd && p1.data == p2.data


"""
    Message

A composite type representing a message.

# Fields

- `dup::Bool`: a boolean indicating whether the message is a duplicate.
- `qos::UInt8`: an 8-bit unsigned integer representing the quality of service.
- `retain::Bool`: a boolean indicating whether the message should be retained.
- `topic::String`: a string representing the topic.
- `payload::Array{UInt8}`: an array of 8-bit unsigned integers representing the payload.

# Constructors

- `Message(qos::QOS, topic::String, payload...)`: constructs a new message with default values for `dup` and `retain`.
- `Message(dup::Bool, qos::QOS, retain::Bool, topic::String, payload...)`: constructs a new message with all fields specified.
- `Message(dup::Bool, qos::UInt8, retain::Bool, topic::String, payload...)`: constructs a new message with all fields specified.

"""
struct Message
    dup::Bool
    qos::UInt8
    retain::Bool
    topic::String
    payload::Array{UInt8}

    function Message(qos::QOS, topic::String, payload...)
        return Message(false, UInt8(qos), false, topic, payload...)
    end

    function Message(dup::Bool, qos::QOS, retain::Bool, topic::String, payload...)
        return Message(dup, UInt8(qos), retain, topic, payload...)
    end

    function Message(dup::Bool, qos::UInt8, retain::Bool, topic::String, payload...)
        # Convert payload to UInt8 Array with PipeBuffer
        buffer = PipeBuffer()
        for i in payload
            write(buffer, i)
        end
        encoded_payload = take!(buffer)
        return new(dup, qos, retain, topic, encoded_payload)
    end
end

Base.:(==)(m1::Message, m2::Message) = m1.dup == m2.dup && m1.qos == m2.qos && m1.retain == m2.retain && m1.topic == m2.topic && m1.payload == m2.payload

"""
    User(name::String, password::String)

A struct that represents a user with a name and password.

# Examples
```julia
julia> user = User("John", "password")
User("John", "password")
```
"""
struct User
    name::String
    password::String
end

Base.:(==)(u1::User, u2::User) = u1.name == u2.name && u1.password == u2.password