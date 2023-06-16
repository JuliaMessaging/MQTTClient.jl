push!(LOAD_PATH,"../src/")

using MQTTClient
using Documenter

DocMeta.setdocmeta!(MQTTClient, :DocTestSetup, :(using MQTTClient); recursive=true)

makedocs(;
    modules=[MQTTClient],
    authors="Nick Shindler <nick@shindler.tech>",
    repo="https://github.com/NickMcSweeney/MQTTClient.jl/blob/{commit}{path}#{line}",
    sitename="MQTTClient.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://NickMcSweeney.github.io/MQTTClient.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/NickMcSweeney/MQTTClient.jl",
    devbranch="main",
)
