using Test

using MQTT
using Distributed, Random

@testset verbose=true "client tests" begin
include("unittest.client.jl")
end
@testset verbose=true "utils tests" begin
include("unittest.utils.jl")
end

## Needs to have internet connection to run
# include("smoke.jl")
## !TODO: Fix packet tests for full unit testing
# include("mocksocket.jl")
# include("packet.jl")
