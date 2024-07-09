# MQTTClient.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://JuliaMessaging.github.io/MQTTClient.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://JuliaMessaging.github.io/MQTTClient.jl/dev/)
[![Build Status](https://github.com/JuliaMessaging/MQTTClient.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/JuliaMessaging/MQTTClient.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/JuliaMessaging/MQTTClient.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/JuliaMessaging/MQTTClient.jl)
[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)

MQTT Client Library for Julia
 
#### Important! Version `0.3.0` or higher requires at least Julia `v1.8`

This library provides a MQTT Client and functions for interfacing with a standard MQTT broker. This includes publishing messages, and subscribing to topics to receive published messages. See the [documentation](https://JuliaMessaging.github.io/MQTTClient.jl) for more information.

This package supports using Transmission Control Protocol (TCP) as well as Unix Domain Sockets (UDS) as the protocol to connect to the MQTT broker over. An example configuration for a `Mosquitto` broker can be found in the test folder. 

## Example Use

An example of how this package can be used is in the [examples/basic.jl](examples/basic.jl) file.

## Contributing

This package is using [MQTT protocol v3.1.1](https://docs.oasis-open.org/mqtt/mqtt/v3.1.1/mqtt-v3.1.1.html).

If you would like to contribute to the project, please submit a PR. All contributions are welcomed and appreciated.

This work is based on the MQTT.jl packages created by [femtomic](https://github.com/femtomc/MQTT.jl) and [rweilbacher](https://github.com/rweilbacher/MQTT.jl), and a lot of credit is due to their work along with the other contributors to those repositories.

### TODO

- [ ] protocol error handling
- [ ] reconnect
- [ ] persistence (in memory, files)
- [ ] look at enums and how to use them
- [ ] qos2 
    * separate handle_pubrecrel into two different methods and fix them
- [ ] review connect method
    * make it not hardcoded
- [x] disconnect_async/disconnect
    * think about what we need to do and how
    * the reconnect should still work
- [ ] implement clean session = false
- [ ] investigate adding global on_msg handler option back
- [ ] investigate using MQTT v5.0
