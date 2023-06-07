import MQTT.User

@testset "Smoke tests" begin
    println("Running smoke tests")

    condition = Condition()
    topic = "foo"
    payload = Random.randstring(20)

    function on_msg(t, p)
        println("Received message topic: [", t, "] payload: [", String(p), "]")
        @test t == topic
        @test String(p) == payload

        notify(condition)
    end

    client = Client(on_msg)
    println(client)

    #println("Testing reconnect")
    #connect(client, "test.mosquitto.org")
    #disconnect(client)
    #connect(client, "test.mosquitto.org")

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

    println("Testing connect will")
    disconnect(client)
    connect(client, "test.mosquitto.org", will=Message(false, 0x00, false, topic, payload))

    disconnect(client)
end
