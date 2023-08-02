function smoke_test(client, conn)
    condition = Condition()
    topic = "foo"
    payload = Random.randstring(20)
    client_test_res = Channel{Bool}(100)

    function on_msg(t, p)
        msg = p |> String
        println("Received message topic: [", t, "] payload: [", msg, "]")
        put!(client_test_res, MQTTClient.topic_eq("$topic#", t))
        put!(client_test_res, msg == payload)
        sleep(0.01)
        notify(condition)
    end

    client = Client()
    println(client)

    println("Testing reconnect")
    connect(client, conn)
    sleep(0.5)
    disconnect(client)
    sleep(0.5)
    connect(client, conn)
    sleep(0.5)

    @time subscribe(client, topic, on_msg, qos=QOS_2)
    @time subscribe(client, "$topic/qos0", on_msg, qos=QOS_2)
    @time subscribe(client, "$topic/qos1", on_msg, qos=QOS_2)
    @time subscribe(client, "$topic/qos2", on_msg, qos=QOS_2)

    println("Testing publish qos 0")
    publish(client, "$topic/qos0", payload, qos=QOS_0)
    sleep(0.02)
    publish(client, "$topic/qos0", payload, qos=QOS_0)
    sleep(0.02)
    publish_async(client, topic, payload)
    wait(condition)

    println("Testing publish qos 1")
    publish(client, "$topic/qos1", payload, qos=QOS_1)
    sleep(0.02)
    publish(client, "$topic/qos1", payload, qos=QOS_1)
    sleep(0.02)
    publish_async(client, topic, payload)
    wait(condition)

    println("Testing publish qos 2")
    publish(client, "$topic/qos2", payload, qos=QOS_2)
    sleep(0.02)
    publish(client, "$topic/qos2", payload, qos=QOS_2)
    sleep(0.02)
    publish_async(client, topic, payload)
    wait(condition)

    # publish(client, topic, payload)
    # sleep(0.1)
    # publish(client, topic, payload)

    # TODO: Fix this, there is some kind of problem either with mqtt or test that makes will not work.
    # println("Testing connect will")
    # disconnect(client)
    # connect(client, MQTT_BROKER, MQTT_PORT, will=Message(false, MQTT.QOS_2, false, topic, payload))
    # wait(condition)

    @test isopen(client.socket)
    disconnect(client)

    while !isempty(client_test_res)
        sleep(0.02)
        res =  take!(client_test_res)
        @test res
    end
end

function stress_test(client, conn)
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

    connect(client, conn)
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
