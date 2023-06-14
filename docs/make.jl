using MQTT
using Documenter

DocMeta.setdocmeta!(MQTT, :DocTestSetup, :(using MQTT); recursive=true)

makedocs(;
    modules=[MQTT],
    authors="Nick Shindler <nick@shindler.tech>",
    repo="https://github.com/NickMcSweeney/MQTT.jl/blob/{commit}{path}#{line}",
    sitename="MQTT.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://NickMcSweeney.github.io/MQTT.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/NickMcSweeney/MQTT.jl",
    devbranch="main",
)
