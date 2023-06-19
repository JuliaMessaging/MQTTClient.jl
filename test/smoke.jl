import MQTTClient.User

const MQTT_BROKER = "test.mosquitto.org"
const MQTT_PORT = 1883

println("ENV Vars: ")
for (k,v) in ENV
    println("$k => $v")
end

try
    s = connect(MQTT_BROKER, MQTT_PORT)
    close(s)

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
        connect(client, MQTT_BROKER, MQTT_PORT)
        sleep(0.5)
        disconnect(client)
        sleep(0.5)
        connect(client, MQTT_BROKER, MQTT_PORT)
        sleep(0.5)

        @time subscribe(client, (topic, QOS_2))

        println("Testing publish qos 0")
        publish(client, topic, payload, qos=QOS_0)
        sleep(0.1)
        publish(client, topic, payload, qos=QOS_0)
        wait(condition)

        println("Testing publish qos 1")
        publish(client, topic, payload, qos=QOS_1)
        sleep(0.1)
        publish(client, topic, payload, qos=QOS_1)
        wait(condition)

        println("Testing publish qos 2")
        publish(client, topic, payload, qos=QOS_2)
        sleep(0.1)
        publish(client, topic, payload, qos=QOS_2)
        wait(condition)

        publish(client, topic, payload)
        sleep(0.1)
        publish(client, topic, payload)

        # TODO: Fix this, there is some kind of problem either with mqtt or test that makes will not work.
        # println("Testing connect will")
        # disconnect(client)
        # connect(client, MQTT_BROKER, MQTT_PORT, will=Message(false, MQTT.QOS_2, false, topic, payload))
        # wait(condition)

        @test isopen(client.socket)
        disconnect(client)
    end
catch e
    println("$MQTT_BROKER:$MQTT_PORT not online -- skipping smoke test")
    @error e
end
