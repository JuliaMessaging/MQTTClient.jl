using Test

using MQTTClient
using Distributed, Random

import MQTTClient: topic_wildcard_len_check, filter_wildcard_len_check, MQTTException
import Sockets: TCPSocket, PipeServer, connect

@testset verbose=true "client tests" begin
include("unittest.client.jl")
include("unittest.uds_client.jl")
end
@testset verbose=true "utils tests" begin
include("unittest.utils.jl")
end

## Needs to have internet connection to run
if !haskey(ENV, "GITHUB_ACTION")
    include("smoke.jl")
end

## Needs to have a broker listening on /tmp/mqtt/mqtt.sock
# The broker needs to be configured for anonymous access and to 
# accept clients which have a max_keepalive = 0
if haskey(ENV, "UDS_TEST") && ENV["UDS_TEST"] == "true"
    include("uds_smoke.jl")
end
## !TODO: Fix packet tests for full unit testing
# include("mocksocket.jl")
# include("packet.jl")
