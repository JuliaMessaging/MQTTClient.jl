using Test

using MQTTClient
using Distributed, Random

import MQTTClient: topic_wildcard_len_check, filter_wildcard_len_check, MQTTException, Packet
import Sockets: TCPSocket, PipeServer, connect, localhost, getaddrinfo, IOError, DNSError
import Base.PipeEndpoint

@testset verbose=true "client tests" begin
    include("unittest.client.jl")
end
@testset verbose=true "utils tests" begin
    include("unittest.utils.jl")
end

# These tests need a mqtt broker running.
# A mosquitto configuration file is provided that will allow these tests to be run.
println("Running tests for Julia: ", VERSION)
# smoke and stress test test functions.
VERSION < v"1.9.0" ? include("smoketest_v1_6.jl") : include("smoketest.jl")

## Needs to have a broker listening on localhost[1883]
# The broker needs to be configured for anonymous access
include("smoketest.tcp.jl")

## Needs to have a broker listening on localhost[8883]
# The broker needs to be configured for access with user:test passwd:test
include("smoketest.secure.jl")

## Needs to have a broker listening on /tmp/mqtt/mqtt.sock
# The broker needs to be configured for anonymous access
include("smoketest.uds.jl")

## !TODO: Fix mocksocket and packet tests for full unit testing
# include("mocksocket.jl")
# include("packet.jl")
