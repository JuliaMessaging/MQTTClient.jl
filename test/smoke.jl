import MQTTClient.User

const MQTT_BROKER = "test.mosquitto.org"
const MQTT_PORT = 1883

try
    s = connect(MQTT_BROKER, MQTT_PORT)
    close(s)

    @testset "Smoke tests" begin
        println("Running smoke tests")

        condition = Condition()
        topic = "foo"
        payload = Random.randstring(20)
        client_test_res = Channel{Bool}(32)

        function on_msg(t, p)
            msg = p |> String
            println("Received message topic: [", t, "] payload: [", msg, "]")
            put!(client_test_res, t == topic)
            put!(client_test_res, msg == payload)

            notify(condition)
        end

        client = Client()
        println(client)

        println("Testing reconnect")
        connect(client, MQTT_BROKER, MQTT_PORT)
        sleep(0.5)
        disconnect(client)
        sleep(0.5)
        connect(client, MQTT_BROKER, MQTT_PORT)
        sleep(0.5)

        @time subscribe(client, topic, on_msg, qos=QOS_2)

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

        while !isempty(client_test_res)
            @test take!(client_test_res)
        end
    end

    @testset "stress test" begin
        println("Running stress tests")

        condition = Condition()
        topic1 = "foo"
        topic2 = "bar"
        topic3 = Random.randstring(4)
        topic4 = Random.randstring(8)
        topic5 = Random.randstring(16)
        topic6 = Random.randstring(32)
        payload = Random.randstring(64)
        client_test_res = Channel{Tuple}(512)

        function on_msg(t, p)
            msg = p |> String
            # println("Received message topic: [", t, "] payload: [", msg, "]")
            put!(client_test_res, (t,msg))
        end

        client = Client()

        connect(client, MQTT_BROKER, MQTT_PORT)
        sleep(0.5)

        @time subscribe(client, topic1, on_msg, qos=QOS_2)
        @time subscribe(client, topic2, on_msg, qos=QOS_2)
        @time subscribe(client, topic3, on_msg, qos=QOS_2)
        @time subscribe(client, topic4, on_msg, qos=QOS_2)
        @time subscribe(client, topic5, on_msg, qos=QOS_2)
        @time subscribe(client, topic6, on_msg, qos=QOS_2)

        @time for i in 1:256
            if i%6 == 1
                publish_async(client, topic1, payload)
            elseif i%6 == 2
                publish_async(client, topic2, payload)
            elseif i%6 == 3
                publish_async(client, topic3, payload)
            elseif i%6 == 4
                publish_async(client, topic4, payload)
            elseif i%6 == 5
                publish_async(client, topic5, payload)
            else
                publish_async(client, topic6, payload)
            end
        end
        count = 0
        @time while count < 256
            wait(client_test_res)
            t,p = take!(client_test_res)
            @test p == payload
            count += 1
        end
    end
catch e
    println("$MQTT_BROKER:$MQTT_PORT not online -- skipping smoke test")
    @error e
end
