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

@testset "MQTT Client" begin
    c = MQTT.Client((p,t) -> println(p,t))
    @test c isa MQTT.Client
end