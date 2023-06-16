function on_msg(t,p)
    (t,p)
end

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
    p = MQTTClient.Packet(MQTTClient.CONNECT, rand(UInt8, 32))
    @test p.cmd == MQTTClient.CONNECT
end

@testset "mqtt distributed channel" begin
    ch = MQTTClient.mqtt_channel()
    a = MQTTClient.Packet(MQTTClient.PINGREQ, rand(UInt8, 16))
    put!(ch, a)
    b = take!(ch)
    @test a == b
end


@testset verbose = true "MQTT Client functionality" begin
    @testset "Client" begin
        c = MQTTClient.Client(on_msg)
        @test c.on_msg === on_msg
        @test c.keep_alive == 0x0000
        @test c.last_id == 0x0000
        @test isempty(c.in_flight)
        @test c.write_packets isa RemoteChannel
        @test c.socket isa TCPSocket
        @test c.socket_lock isa ReentrantLock
        @test c.ping_timeout == 60
        @test c.ping_outstanding[] == 0
        # Test custom ping_timeout value
        ping_timeout = UInt64(30)
        c2 = MQTTClient.Client(on_msg, ping_timeout)
        @test c2.ping_timeout == ping_timeout
        # Test that last_sent and last_received are initialized to NaN
        @test c2.last_sent.value == 0
        @test c2.last_received.value == 0
    end

    @testset "MQTT Message" begin
        msg = MQTTClient.Message(true, QOS_0, true, "test/mqtt_jl", "testing the MQTTClient.jl package")
        @test msg isa MQTTClient.Message

        msg = MQTTClient.Message(false, 0x01, false, "test", "payload")
        @test msg.dup == false
        @test msg.qos == 0x01
        @test msg.retain == false
        @test msg.topic == "test"
        @test msg.payload == [UInt8('p'), UInt8('a'), UInt8('y'), UInt8('l'), UInt8('o'), UInt8('a'), UInt8('d')]

        msg = MQTTClient.Message(MQTTClient.QOS_2, "test", "payload")
        @test msg.dup == false
        @test msg.qos == 0x02
        @test msg.retain == false
        @test msg.topic == "test"
        @test msg.payload == [UInt8('p'), UInt8('a'), UInt8('y'), UInt8('l'), UInt8('o'), UInt8('a'), UInt8('d')]
    end


    @testset "MQTT subscribe async" begin
        c = MQTTClient.Client((p,t) -> println(p,t))
        fut = MQTTClient.subscribe_async(c, ("test-topic/#", MQTTClient.QOS_2))
        @test fut isa Distributed.Future
    end

    @testset "MQTT publish async" begin
        c = MQTTClient.Client((p,t) -> println(p,t))
        fut = MQTTClient.publish_async(c, "test-topic/mqtt_jl", "test message")
        @test fut isa Distributed.Future
    end

    @testset "unsubscribe_async" begin
        # Create a mock client object
        client = Client((client, topic, message) -> nothing)

        # Set the packet ID
        id = 1
        client.last_id = id

        # Call the unsubscribe_async function with a single topic
        future = unsubscribe_async(client, "topic1")

        # Check that the in_flight dictionary was updated correctly
        @test client.in_flight[0x0002] == future

        # Check that the write_packet function was called with the correct arguments
        p = take!(client.write_packets)
        @test p == MQTTClient.Packet(MQTTClient.UNSUBSCRIBE  | 0x02, (0x0002, "topic1"))

        # Call the unsubscribe_async function with multiple topics
        future = unsubscribe_async(client, "topic1", "topic2", "topic3")

        # Check that the in_flight dictionary was updated correctly
        @test client.in_flight[0x0003] == future

        # Check that the write_packet function was called with the correct arguments
        p = take!(client.write_packets)
        @test p == MQTTClient.Packet(MQTTClient.UNSUBSCRIBE  | 0x02, (0x0003, "topic1", "topic2", "topic3"))
    end
end

@testset verbose=true "handlers" begin
    @testset "handle_connack" begin
        c = MQTTClient.Client(on_msg)
        c.in_flight[0x0000] = Future()

        # Test successful connection
        io = IOBuffer(UInt8[0x00, 0x00])
        future = MQTTClient.handle_connack(c, io, 0x00, 0x00)
        @test fetch(future) == 0x00

        # Test unsuccessful connection
        io = IOBuffer(UInt8[0x01, 0x01])
        c.in_flight[0x0000] = Future()
        future = MQTTClient.handle_connack(c, io, 0x00, 0x00)
        @test fetch(future) isa MQTTException

        # Test unsuccessful connection
        io = IOBuffer(UInt8[0x01, 0x01])
        @test_throws ErrorException MQTTClient.handle_connack(c, io, 0x00, 0x00)
    end

    @testset "handle_publish" begin
        c = MQTTClient.Client(on_msg)
        # Test QoS 0
        io = IOBuffer(UInt8[0x00, 0x04, 0x74, 0x65, 0x73, 0x74, 0x70, 0x61, 0x79])
        MQTTClient.handle_publish(c, io, 0x00, 0x00)
        @test c.on_msg("test", "pay") == ("test", "pay")

        # Test QoS 1
        io = IOBuffer(UInt8[0x00, 0x04, 0x74, 0x65, 0x73, 0x74, 0x00, 0x01, 0x70, 0x61])
        MQTTClient.handle_publish(c, io, 0x00, 0x02)
        @test c.on_msg("test", "pa") == ("test", "pa")

        # Test QoS 2
        io = IOBuffer(UInt8[0x00, 0x04, 0x74, 0x65, 0x73, 0x74, 0x00, 0x01])
        MQTTClient.handle_publish(c, io, 0x00, 0x04)
        @test c.on_msg("test", "") == ("test", "")
    end

    @testset "handle_ack" begin
        c = MQTTClient.Client(on_msg)
        c.in_flight[0x0001] = Future()

        # Test successful ack
        io = IOBuffer(UInt8[0x00, 0x01])
        MQTTClient.handle_ack(c, io, 0x00, 0x00)
        @test !haskey(c.in_flight, 0x0001)
    end

    @testset "handle_pubrec" begin
        c = MQTTClient.Client(on_msg)
        s = IOBuffer()

        # Set the cmd and flags values
        cmd = 0x50
        flags = 0x02

        # Write the packet ID to the IO object
        write(s, UInt16(3))
        seekstart(s)

        # Call the handle_pubrec function
        MQTTClient.handle_pubrec(c, s, cmd, flags)
        p = take!(c.write_packets)
        #!TODO: Figure out why the id changes
        @test p == MQTTClient.Packet(MQTTClient.PUBREL  | 0x02, (0x0300,))
    end

    @testset "handle_pubrel" begin
        c = MQTTClient.Client(on_msg)
        s = IOBuffer()

        # Set the cmd and flags values
        cmd = 0x62
        flags = 0x02

        # Write the packet ID to the IO object
        write(s, UInt16(1))
        seekstart(s)

        # Call the handle_pubrel function
        MQTTClient.handle_pubrel(c, s, cmd, flags)
        p = take!(c.write_packets)
        @test p == MQTTClient.Packet(MQTTClient.PUBCOMP, (0x0100,))
    end

    @testset "handle_suback" begin
        c = MQTTClient.Client(on_msg)
        s = IOBuffer()

        # Set the cmd and flags values
        cmd = 0x90
        flags = 0x00

        # Write the packet ID and return code to the IO object
        write(s, UInt16(1))
        write(s, UInt8(0x00))
        seekstart(s)

        c.in_flight[0x0100] = Future()

        # Call the handle_suback function
        MQTTClient.handle_suback(c, s, cmd, flags)

        # Check that the in_flight dictionary was updated correctly
        future = c.in_flight[0x0100]
        @test fetch(future) == UInt8[0x01, 0x00, 0x00]
    end

    @testset "handle_pingresp" begin
        c = MQTTClient.Client(on_msg)
        s = IOBuffer()

        # Set the cmd and flags values
        cmd = 0xD0
        flags = 0x00

        # Set the ping_outstanding value to 0x1
        c.ping_outstanding[] = 0x1

        # Call the handle_pingresp function
        MQTTClient.handle_pingresp(c, s, cmd, flags)

        # Check that the ping_outstanding value was updated correctly
        @test c.ping_outstanding[] == 0x0

        # Set the ping_outstanding value to 0x0 and call the handle_pingresp function again
        c.ping_outstanding[] = 0x0
        MQTTClient.handle_pingresp(c, s, cmd, flags)
        p = take!(c.write_packets)
        @test p == MQTTClient.Packet(MQTTClient.DISCONNECT, ())
    end

end
