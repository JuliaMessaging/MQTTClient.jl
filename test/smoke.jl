import MQTT.User

@testset "Smoke tests" begin
    println("Running smoke tests")

    condition = Condition()
    topic = "foo"
    payload = Random.randstring(20)

    function on_msg(t, p)
        msg = p |> String
        println("Received message topic: [", t, "] payload: [", msg, "]")
        @test t == topic
        @test msg == payload

        notify(condition)
    end

    client = Client(on_msg)
    println(client)

    println("Testing reconnect")
    connect(client, "test.mosquitto.org", 1883)
    disconnect(client)
    connect(client, "test.mosquitto.org", 1883)

    @time subscribe(client, (topic, QOS_0))

    println("Testing publish qos 0")
    publish(client, topic, payload, qos=QOS_0)
    wait(condition)

    println("Testing publish qos 1")
    publish(client, topic, payload, qos=QOS_1)
    wait(condition)

    println("Testing publish qos 2")
    publish(client, topic, payload, qos=QOS_2)
    wait(condition)

    publish(client, topic, payload)

    # TODO: Fix this, there is some kind of problem either with mqtt or test that makes will not work.
    # println("Testing connect will")
    # disconnect(client)
    # connect(client, "test.mosquitto.org", 1883, will=Message(false, MQTT.QOS_2, false, topic, payload))
    # wait(condition)

    @test isopen(client.socket)
    disconnect(client)
end
