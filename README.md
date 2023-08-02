# MQTTClient.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://JuliaMQTT.github.io/MQTTClient.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://JuliaMQTT.github.io/MQTTClient.jl/dev/)
[![Build Status](https://github.com/JuliaMQTT/MQTTClient.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/JuliaMQTT/MQTTClient.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/JuliaMQTT/MQTTClient.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/JuliaMQTT/MQTTClient.jl)
[![Coverage](https://coveralls.io/repos/github/JuliaMQTT/MQTTClient.jl/badge.svg?branch=main)](https://coveralls.io/github/JuliaMQTT/MQTTClient.jl?branch=main)
[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)

MQTT Client Library for Julia

This library provides a powerful and easy-to-use interface for connecting to an MQTT broker, publishing messages, and subscribing to topics to receive published messages. It supports fully multi-threaded operation with Dagger.jl and file persistence for reliable message delivery.

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
- [ ] fix connect method
    * make it not hardcoded
- [ ] disconnect_async/disconnect
    * think about what we need to do and how
    * the reconnect should still work
- [ ] implement clean session = false
- [ ] remove dagger
    * create a DaggerMQTT.jl or something like this pkg.
- [ ] add global on_msg handler option back
- [ ] shamelessly copy documenter structure of Rocket
    * move docs out of readme