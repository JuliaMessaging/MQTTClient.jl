module MQTTClient

using Distributed: Future, RemoteChannel
using Sockets: TCPSocket, IPAddr, PipeServer, getaddrinfo
import Sockets: connect
using Random: randstring
import Base: ReentrantLock, lock, unlock, convert
using Base.Threads


include("utils.jl")
include("internals.jl")
include("client.jl")
include("connection.jl")
include("handlers.jl")
include("interface.jl")

include("precompile.jl")

export
    MakeConnection,
    Client,
    MQTTConnection,
    IOConnection,
    MQTTException,
    User,
    QOS_0,
    QOS_1,
    QOS_2,
    connect_async,
    connect,
    subscribe_async,
    subscribe,
    unsubscribe_async,
    unsubscribe,
    publish_async,
    publish,
    disconnect,
    MQTT_ERR_INVAL
end
