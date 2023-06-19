using Test

using MQTTClient
using Distributed, Random

import MQTTClient: topic_wildcard_len_check, filter_wildcard_len_check, MQTTException
import Sockets: TCPSocket, connect

@testset verbose=true "client tests" begin
include("unittest.client.jl")
end
@testset verbose=true "utils tests" begin
include("unittest.utils.jl")
end

## Needs to have internet connection to run
if !haskey(ENV, "GITHUB_ACTION")
    include("smoke.jl")
end
## !TODO: Fix packet tests for full unit testing
# include("mocksocket.jl")
# include("packet.jl")
