import MQTT: topic_wildcard_len_check, filter_wildcard_len_check, MQTTException

@testset "topic_wildcard_len_check" begin
    @test_throws MQTTException topic_wildcard_len_check("+")
    @test topic_wildcard_len_check("foo") == nothing
    @test_throws MQTTException topic_wildcard_len_check("#")
    @test_throws MQTTException topic_wildcard_len_check("")
end;

@testset "filter_wildcard_len_check" begin
    @test_throws MQTTException filter_wildcard_len_check("")
    @test_throws MQTTException filter_wildcard_len_check("#/")
    @test_throws MQTTException filter_wildcard_len_check("f+oo/bar/more")
    @test_throws MQTTException filter_wildcard_len_check("f#oo/bar/more")
    @test filter_wildcard_len_check("foo/bar/more") == nothing
    @test filter_wildcard_len_check("foo/bar/more/#") == nothing
    @test filter_wildcard_len_check("foo/+/bar/more") == nothing
end;

@testset "packet struct" begin
    p = MQTT.Packet(MQTT.CONNECT, rand(UInt8, 32))
    @test p.cmd == MQTT.CONNECT
end

@testset "mqtt distributed channel" begin
    ch = MQTT.mqtt_channel()
    a = MQTT.Packet(MQTT.PINGREQ, rand(UInt8, 16))
    put!(ch, a)
    b = take!(ch)
    @test a == b
end


@testset verbose = true "MQTT Client functionality" begin
    @testset "MQTT Client" begin
        c = MQTT.Client((p,t) -> println(p,t))
        @test c isa MQTT.Client   
    end

    @testset "MQTT Message" begin
        m = MQTT.Message(true, 0x00, true, "test/mqtt_jl", "testing the MQTT.jl package")
        @test m isa MQTT.Message
    end

end

@testset "MQTT subscribe async" begin
    c = MQTT.Client((p,t) -> println(p,t))
    fut = MQTT.subscribe_async(c, ("test-topic/#", MQTT.QOS_2))
    @test fut isa Distributed.Future
end

@testset "MQTT subscribe async" begin
    c = MQTT.Client((p,t) -> println(p,t))
    fut = MQTT.publish_async(c, "test-topic/mqtt_jl", "test message")
    @test fut isa Distributed.Future
end

# @testset "MQTT connect" begin
#     c = MQTT.Client((p,t) -> println(p,t))
#     session_present_bit = MQTT.connect(
#         c,
#         "test.mosquitto.org",
#         1883,
#         client_id = "test-mqtt-jll",
#         keep_alive = 600,
#         clean_session = true,
#         will = MQTT.Message(true, 0x00, true, "test/mqtt_jl", "testing the MQTT.jl package"),
#     )
#     @test session_present_bit === 0x00
# end