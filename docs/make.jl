push!(LOAD_PATH, "../src/")

using MQTTClient
using Documenter

DocMeta.setdocmeta!(MQTTClient, :DocTestSetup, :(using MQTTClient); recursive=true)

makedocs(;
    modules=[MQTTClient],
    authors="Nick Shindler <nick@shindler.tech>",
    repo="https://github.com/JuliaMessaging/MQTTClient.jl/blob/{commit}{path}#{line}",
    sitename="MQTTClient.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://JuliaMessaging.github.io/MQTTClient.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "Getting Started" => "getting-started.md",
        "MQTT Interface Functions" => "interfaces.md",
        "MQTT Client" => "client.md",
        "MQTT API" =>
            ["Client" => "api/client.md", "Interfacing Functions" => "api/interface.md"],
        "Utils" => "utils.md",
    ],
)

deploydocs(; repo="github.com/JuliaMessaging/MQTTClient.jl", devbranch="main")
