using Test

using MQTTClient
using Distributed, Random

import MQTTClient: topic_wildcard_len_check, filter_wildcard_len_check, MQTTException
import Sockets: TCPSocket, PipeServer, connect, localhost, getaddrinfo, IOError, DNSError

@testset verbose=true "client tests" begin
    include("unittest.client.jl")
end
@testset verbose=true "utils tests" begin
    include("unittest.utils.jl")
end


# if !haskey(ENV, "GITHUB_ACTION")
    # smoke and stress test test functions.
    include("smoketest.jl")

    ## Needs to have internet connection to run
    include("smoketest.tcp.jl")

    ## Needs to have a broker listening on /tmp/mqtt/mqtt.sock
    # The broker needs to be configured for anonymous access and to
    # accept clients which have a max_keepalive = 0
    include("smoketest.uds.jl")
# end

## !TODO: Fix packet tests for full unit testing
# include("mocksocket.jl")
# include("packet.jl")
