# MQTTClient.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://JuliaMessaging.github.io/MQTTClient.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://JuliaMessaging.github.io/MQTTClient.jl/dev/)
[![Build Status](https://github.com/JuliaMessaging/MQTTClient.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/JuliaMessaging/MQTTClient.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/JuliaMessaging/MQTTClient.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/JuliaMessaging/MQTTClient.jl)
[![Coverage](https://coveralls.io/repos/github/JuliaMessaging/MQTTClient.jl/badge.svg?branch=main)](https://coveralls.io/github/JuliaMessaging/MQTTClient.jl?branch=main)
[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)

MQTT Client Library for Julia

This library provides a MQTT Client and functions for interfacing with a standard MQTT broker. This includes publishing messages, and subscribing to topics to receive published messages. 

This package supports using Transmission Control Protocol (TCP) as well as Unix Domain Sockets (UDS) as the protocol to connect to the MQTT broker over. An example configuration for a `Mosquitto` broker can be found in the test folder. 

## Sponsorship
![sponsor logo](https://www.volkerwessels.com/dynamics/modules/SFIL0200/view.php?fil_Id=366300&thumb_nr=26)

This package is developed and sponsored by [MapXact](https://mapxact.com/) and its development is driven by its use in production systems at MapXact. However, as an open-source project, we welcome all contributions, feedback, and feature requests.

## Contributing

If you would like to contribute to the project, please submit a PR. All contributions are welcomed and appreciated.

This work is based on the MQTT.jl packages created by [femtomic](https://github.com/femtomc/MQTT.jl) and [rweilbacher](https://github.com/rweilbacher/MQTT.jl), and a lot of credit is due to their work along with the other contributors to those repositories.

### TODO

- [ ] Review examples
- [ ] protocol error handling
- [ ] reconnect
- [ ] persistence (in memory, files)
- [ ] look at enums and how to use them
- [ ] qos2 
    * separate handle_pubrecrel into two different methods and fix them
- [ ] review connect method
    * make it not hardcoded
- [ ] disconnect_async/disconnect
    * think about what we need to do and how
    * the reconnect should still work
- [ ] implement clean session = false
- [ ] add global on_msg handler option back