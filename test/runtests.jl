module Test

include("../src/MQTT.jl")
using .MQTT
using Random
using Test

import Base: read, write, close
import MQTT: read_len, Message

include("smoke.jl")
# include("mocksocket.jl")
# include("packet.jl")
include("unittests.jl")

end # module
