@testset "mqtt_read" begin
    io = IOBuffer()
    write(io, hton(UInt16(0x1234)))
    seekstart(io)
    @test MQTTClient.mqtt_read(io, UInt16) == 0x1234

    io = IOBuffer()
    write(io, hton(UInt16(4)))
    write(io, "test")
    seekstart(io)
    @test MQTTClient.mqtt_read(io, String) == "test"
end

@testset "mqtt_write" begin
    io = IOBuffer()
    MQTTClient.mqtt_write(io, UInt16(0x1234))
    seekstart(io)
    @test read(io, UInt16) == hton(UInt16(0x1234))

    io = IOBuffer()
    MQTTClient.mqtt_write(io, "test")
    seekstart(io)
    @test read(io, UInt16) == hton(UInt16(4))
    @test String(read(io)) == "test"
end

@testset "write_len and read_len" begin
    io = IOBuffer()
    MQTTClient.write_len(io, 0)
    seekstart(io)
    @test MQTTClient.read_len(io) == 0

    io = IOBuffer()
    MQTTClient.write_len(io, 127)
    seekstart(io)
    @test MQTTClient.read_len(io) == 127

    io = IOBuffer()
    MQTTClient.write_len(io, 128)
    seekstart(io)
    @test MQTTClient.read_len(io) == 128

    io = IOBuffer()
    MQTTClient.write_len(io, 16383)
    seekstart(io)
    @test MQTTClient.read_len(io) == 16383

    io = IOBuffer()
    MQTTClient.write_len(io, 16384)
    seekstart(io)
    @test MQTTClient.read_len(io) == 16384

    io = IOBuffer()
    MQTTClient.write_len(io, 2097151)
    seekstart(io)
    @test MQTTClient.read_len(io) == 2097151

    io = IOBuffer()
    MQTTClient.write_len(io, 2097152)
    seekstart(io)
    @test_throws ErrorException("malformed remaining length") MQTTClient.read_len(io)

    io = IOBuffer()
    MQTTClient.write_len(io, 268435455)
    seekstart(io)
    @test_throws ErrorException("malformed remaining length") MQTTClient.read_len(io)
end
