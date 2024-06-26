cb(args...) = nothing

@testset "TCP Client" begin
    server = MQTTClient.MockMQTTBroker(ip"127.0.0.1", 1889)
    client, conn = MakeConnection(ip"127.0.0.1", 1889)

    connect(client, conn)
    @test MQTTClient.isconnected(client)

    res = subscribe(client, "foo/bar", cb)
    @test res == [0x01, 0x00]
    res = publish(client, "bar/foo", "baz"; qos=QOS_2)
    @test isnothing(res)
    res = unsubscribe(client, "foo/bar")
    @test isnothing(res)

    res = disconnect(client)
    @test res == (0x00, 0x00, 0x00)

    # test reconnect
    connect(client, conn)
    @test MQTTClient.isconnected(client)
    res = disconnect(client)
    @test res == (0x00, 0x00, 0x00)

    @test MQTTClient.isclosed(client)
    @test isopen(server)

    close(server)  # stop the mock server

    @test !isopen(server)
end

if !Sys.iswindows() # since windows is not UNIX it doesn't support UDS 
    @testset "UDS Client" begin
        ## UDS Basic Run
        server = MQTTClient.MockMQTTBroker("/tmp/testmqtt.sock")
        client, conn = MakeConnection("/tmp/testmqtt.sock")

        connect(client, conn)
        @test MQTTClient.isconnected(client)

        res = subscribe(client, "foo/bar", cb)
        @test res == [0x01, 0x00]
        res = publish(client, "bar/foo", "baz")
        @test res == 0
        res = unsubscribe(client, "foo/bar")
        @test isnothing(res)

        res = disconnect(client)
        @test res == (0x00, 0x00, 0x00)

        # test reconnect
        connect(client, conn)
        @test MQTTClient.isconnected(client)
        res = disconnect(client)
        @test res == (0x00, 0x00, 0x00)

        @test MQTTClient.isclosed(client)
        @test isopen(server)

        close(server) # stop the mock server

        @test !isopen(server)
    end
end