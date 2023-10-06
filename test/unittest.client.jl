function on_msg(t,p)
    (t,p)
end

@testset verbose = true "MQTT Client functionality" begin
    @testset "Client" begin
        c = MQTTClient.Client()
        @test c.on_msg isa Dict
        @test c.keep_alive == 0x0000
        @test c.last_id == 0x0000
        @test isempty(c.in_flight)
        @test c.write_packets isa AbstractChannel
        @test isnothing(c.socket)
        @test c.socket_lock isa ReentrantLock
        @test c.ping_timeout == UInt64(60)
        @test c.ping_outstanding[] == 0
        # Test custom ping_timeout value
        ping_timeout = UInt64(30)
        c2 = MQTTClient.Client(ping_timeout)
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

    @testset "write_loop" begin
        c = MQTTClient.Client()
        c.socket = TCPSocket()
        close(c.socket)
        message = MQTTClient.Message(false, UInt8(MQTTClient.QOS_2), false, "test/foo", "payload")
        optional = message.qos == 0x00 ? () : (2)
        cmd = MQTTClient.PUBLISH | ((message.dup & 0x1) << 3) | (message.qos << 1) | message.retain
        packet = MQTTClient.Packet(cmd, [message.topic, optional..., message.payload])
        put!(c.write_packets, packet)

        @test_throws IOError MQTTClient.write_loop(c)
    end

    @testset "packet_id" begin
        c = MQTTClient.Client()
        c.last_id = typemax(UInt16)
        @test MQTTClient.packet_id(c) == 1
    end

    @testset "client state" begin
        c = MQTTClient.Client()
        @atomicswap c.state = 0x00
        @test isready(c)
        @atomicswap c.state = 0x01
        @test MQTTClient.isconnected(c)
        @atomicswap c.state = 0x02
        @test MQTTClient.isclosed(c)
        @atomicswap c.state = 0x03
        @test MQTTClient.iserror(c)
    end
end

@testset verbose = true "MQTT Connection functionality" begin
    @testset "MQTT TCP Connection from ip" begin
        conn = MQTTClient.MQTTConnection(MQTTClient.IOConnection(localhost, 1883))
        @test conn.protocol isa MQTTClient.TCP
        @test conn.protocol.ip == localhost
        @test conn.keep_alive == 32
        @test length(conn.client_id) == 8
        @test conn.user == MQTTClient.User("", "")
        @test conn.will == MQTTClient.Message(false, 0x00, false, "", UInt8[])
        @test conn.clean_session == true
    end

    @testset "MQTT TCP Connection from string" begin
        conn = MQTTClient.MQTTConnection(MQTTClient.IOConnection("localhost", 1883))
        @test conn.protocol isa MQTTClient.TCP
        @test conn.protocol.ip == getaddrinfo("localhost")
        @test conn.keep_alive == 32
        @test length(conn.client_id) == 8
        @test conn.user == MQTTClient.User("", "")
        @test conn.will == MQTTClient.Message(false, 0x00, false, "", UInt8[])
        @test conn.clean_session == true
    end

    @testset "MQTT UDS Connection" begin
        path = "/tmp/mqtt.sock"
        conn = MQTTClient.MQTTConnection(MQTTClient.IOConnection(path))
        @test conn.protocol isa MQTTClient.UDS
        @test conn.protocol.path == path
        @test conn.keep_alive == 32
        @test length(conn.client_id) == 8
        @test conn.user == MQTTClient.User("", "")
        @test conn.will == MQTTClient.Message(false, 0x00, false, "", UInt8[])
        @test conn.clean_session == true
    end
end


@testset verbose = true "MQTT interface functionality" begin
    @testset "Make MQTT tcp connection" begin
        c, conn = MQTTClient.MakeConnection("localhost", 1883)
        @test c isa MQTTClient.Client
        @test conn isa MQTTClient.MQTTConnection
        c, conn = MQTTClient.MakeConnection(localhost, 1883)
        @test c isa MQTTClient.Client
        @test conn isa MQTTClient.MQTTConnection
    end

    @testset "Make MQTT uds connection" begin
        c, conn = MQTTClient.MakeConnection("/tmp/mqtt.sock")
        @test c isa MQTTClient.Client
        @test conn isa MQTTClient.MQTTConnection
    end
    
    @testset "Test Client show function" begin
        io = IOBuffer()
        client, conn = MQTTClient.MakeConnection("localhost", 1883)
        show(io, client)
        str = take!(io) |> String
        @test str == "MQTTClient(Topic Subscriptions: String[])"
    end
    @testset "Test Connection show function" begin
        io = IOBuffer()
        client, conn = MQTTClient.MakeConnection("localhost", 1883, client_id="foo")
        show(io, conn)
        str = take!(io) |> String
        @test contains(str, "MQTTConnection(Protocol: MQTTClient.TCP")
    end

    @testset "MQTT subscribe async" begin
        c = MQTTClient.Client()
        fut = MQTTClient.subscribe_async(c, "test-topic/#", ((p) -> p), qos=MQTTClient.QOS_2)
        @test fut isa Distributed.Future
    end

    @testset "MQTT publish async" begin
        c = MQTTClient.Client()
        fut = MQTTClient.publish_async(c, "test-topic/mqtt_jl", "test message")
        @test fut isa Distributed.Future
    end

    @testset "unsubscribe_async" begin
        # Create a mock client object
        client = MQTTClient.Client()

        client.on_msg["topic1"] = ((p) -> p)

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


        client.on_msg["topic1"] = ((p) -> p)
        client.on_msg["topic2"] = ((p) -> p)
        client.on_msg["topic3"] = ((p) -> p)
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
        c = MQTTClient.Client()
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

        @test MQTTClient.isclosed(c)
    end

    @testset "handle_publish" begin
        #! TODO: fix this test.
        c = MQTTClient.Client()
        ch = Channel{String}(5)
        c.on_msg["test"] = (t,p) -> put!(ch, strip(String(p),'\0'))
        c.on_msg["test/#"] = (t,p) -> put!(ch, strip(String(p),'\0'))

        message = MQTTClient.Message(false, UInt8(MQTTClient.QOS_0), false, "test", "payload")
        optional = message.qos == 0x00 ? () : (0)
        cmd = MQTTClient.PUBLISH | ((message.dup & 0x1) << 3) | (message.qos << 1) | message.retain
        packet = MQTTClient.Packet(cmd, [message.topic, optional..., message.payload])
        buffer = PipeBuffer()
        for i in packet.data
            MQTTClient.mqtt_write(buffer, i)
        end
        MQTTClient.handle_publish(c, buffer, 0x00, 0x00)
        payload = take!(ch)
        @test payload == "payload"

        message = MQTTClient.Message(false, UInt8(MQTTClient.QOS_1), false, "test", "payload")
        optional = message.qos == 0x00 ? () : (1)
        cmd = MQTTClient.PUBLISH | ((message.dup & 0x1) << 3) | (message.qos << 1) | message.retain
        packet = MQTTClient.Packet(cmd, [message.topic, optional..., message.payload])
        buffer = PipeBuffer()
        for i in packet.data
            MQTTClient.mqtt_write(buffer, i)
        end
        MQTTClient.handle_publish(c, buffer, 0x00, 0x02)
        payload = take!(ch)
        @test payload == "payload"

        message = MQTTClient.Message(false, UInt8(MQTTClient.QOS_2), false, "test", "payload")
        optional = message.qos == 0x00 ? () : (2)
        cmd = MQTTClient.PUBLISH | ((message.dup & 0x1) << 3) | (message.qos << 1) | message.retain
        packet = MQTTClient.Packet(cmd, [message.topic, optional..., message.payload])
        buffer = PipeBuffer()
        for i in packet.data
            MQTTClient.mqtt_write(buffer, i)
        end
        MQTTClient.handle_publish(c, buffer, 0x00, 0x04)
        payload = take!(ch)
        @test payload == "payload"

        message = MQTTClient.Message(false, UInt8(MQTTClient.QOS_2), false, "test/foo", "payload")
        optional = message.qos == 0x00 ? () : (2)
        cmd = MQTTClient.PUBLISH | ((message.dup & 0x1) << 3) | (message.qos << 1) | message.retain
        packet = MQTTClient.Packet(cmd, [message.topic, optional..., message.payload])
        buffer = PipeBuffer()
        for i in packet.data
            MQTTClient.mqtt_write(buffer, i)
        end
        MQTTClient.handle_publish(c, buffer, 0x00, 0x04)
        payload = take!(ch)
        @test payload == "payload"

        # on_msg["test/#"] = (t,p) -> put!(ch, p == "payload4")
        # io = IOBuffer(Vector{UInt8}("\0\x08test/foopayload4"))
        # @test MQTTClient.mqtt_read(io, String) == "test/foo"
        # MQTTClient.handle_publish(c, io, 0x00, 0x02)
    end

    @testset "handle_ack" begin
        c = MQTTClient.Client()
        c.in_flight[0x0001] = Future()

        # Test successful ack
        io = IOBuffer(UInt8[0x00, 0x01])
        MQTTClient.handle_ack(c, io, 0x00, 0x00)
        @test !haskey(c.in_flight, 0x0001)

        c.in_flight[0x0002] = Future()

        # Test unsuccessful ack
        io = IOBuffer(UInt8[0x00, 0x01])
        MQTTClient.handle_ack(c, io, 0x00, 0x00)
        @test c.state === 0x03
    end

    @testset "handle_pubrec" begin
        c = MQTTClient.Client()
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
        c = MQTTClient.Client()
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
        c = MQTTClient.Client()
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
        c = MQTTClient.Client()
        s = IOBuffer()

        # Set the cmd and flags values
        cmd = 0xD0
        flags = 0x00

        # Set the ping_outstanding value to 0x1
        c.ping_outstanding[] = 0x1

        @atomicswap c.state = 0x01

        # Call the handle_pingresp function
        MQTTClient.handle_pingresp(c, s, cmd, flags)

        # Check that the ping_outstanding value was updated correctly
        @test c.ping_outstanding[] == 0x0

        # NOTE: update this to use different msg type.
        # # Set the ping_outstanding value to 0x0 and call the handle_pingresp function again
        c.ping_outstanding[] = 0x0
        @test_throws MethodError MQTTClient.handle_pingresp(c, s, cmd, flags)

        # p = take!(c.write_packets)
        # @test p == MQTTClient.Packet(MQTTClient.DISCONNECT, ())
    end

end
