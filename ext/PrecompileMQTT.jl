# COV_EXCL_START
module PrecompileMQTT # Should be same name as the file (just like a normal package)

using PrecompileTools

using Distributed: Future
using Sockets

using MQTTClient

precompile(Tuple{typeof(Core.kwcall), NamedTuple{(:qos,), Tuple{MQTTClient.QOS}}, typeof(MQTTClient.subscribe), MQTTClient.Client, String, Function})
precompile(Tuple{typeof(Core.kwcall), NamedTuple{(:qos,), Tuple{MQTTClient.QOS}}, typeof(MQTTClient.publish), MQTTClient.Client, String, String})

precompile(Tuple{typeof(Base.convert), Type{MQTTClient.Packet}, MQTTClient.Packet})
precompile(Tuple{typeof(Base.write), Base.PipeEndpoint, Array{UInt8, 1}})
precompile(Tuple{typeof(Base.read), Base.PipeEndpoint, Type{UInt8}})
precompile(Tuple{typeof(Base.indexed_iterate), Tuple{Nothing, Int64}, Int64})
precompile(Tuple{typeof(Base.read), Base.PipeEndpoint, Int64})
precompile(Tuple{typeof(Base.haskey), Base.Dict{UInt8, Function}, UInt8})
precompile(Tuple{typeof(Base.getindex), Base.Dict{UInt8, Function}, UInt8})
precompile(Tuple{typeof(Base.indexed_iterate), Tuple{Nothing, Int64}, Int64, Int64})
precompile(Tuple{typeof(Base.read), Sockets.TCPSocket, Int64})
precompile(Tuple{typeof(Base.write), Base.PipeEndpoint, UInt8})
precompile(Tuple{typeof(Base.fetch), Base.Channel{Any}})
precompile(Tuple{typeof(Base.iterate), UInt16})
precompile(Tuple{typeof(Base.something), MQTTClient.TrieNode{MQTTClient.FunctionCallback}, Nothing, Vararg{Any}})

precompile(Tuple{typeof(Sockets.connect), MQTTClient.Client, MQTTClient.MQTTConnection{MQTTClient.TCP}})
precompile(Tuple{typeof(Sockets.connect), Sockets.IPv6, Int64})
precompile(Tuple{typeof(Sockets.connect), MQTTClient.Client, MQTTClient.MQTTConnection{MQTTClient.UDS}})
precompile(Tuple{typeof(Sockets.connect), String})

precompile(Tuple{typeof(MQTTClient.write_len), Sockets.TCPSocket, Int64})
precompile(Tuple{typeof(MQTTClient.read_len), Sockets.TCPSocket})
precompile(Tuple{typeof(MQTTClient.write_packet), MQTTClient.Client, UInt8, String, Vararg{Any}})
precompile(Tuple{typeof(MQTTClient.mqtt_write), Base.GenericIOBuffer{Array{UInt8, 1}}, UInt8})
precompile(Tuple{typeof(MQTTClient.write_len), Base.PipeEndpoint, Int64})
precompile(Tuple{typeof(MQTTClient.read_len), Base.PipeEndpoint})
precompile(Tuple{typeof(MQTTClient.mqtt_write), Base.GenericIOBuffer{Array{UInt8, 1}}, MQTTClient.QOS})

precompile(Tuple{Type{MQTTClient.Packet}, UInt8, Tuple{}})
precompile(Tuple{Type{NamedTuple{(:qos,), T} where T<:Tuple}, Tuple{MQTTClient.QOS}})


# Precompiling the package like this provides a slower initial load of the package but faster code execution.
# based on tests this precompile step reduces compilation at runtime by ~25% and decreases first execution time by ~10%.
@setup_workload begin
    # Putting some things in `@setup_workload` instead of `@compile_workload` can reduce the size of the
    # precompile file and potentially make loading faster.

    cb(t,p) = nothing
    topic = "foo"
    payload = "bar"

    @compile_workload begin
        udsclient, udsconnection = MakeConnection("/tmp/mqtt.sock")
        tcpclient, tcpconnection = MakeConnection("test.mosquitto.org", 1883)

        ## Handlers:
        # handle_connack
        c = MQTTClient.Client()
        c.in_flight[0x0000] = Future()
        io = IOBuffer(UInt8[0x00, 0x00])
        future = MQTTClient.handle_connack(c, io, 0x00, 0x00)
        fetch(future)

        # handle_publish
        c = MQTTClient.Client()
        insert!(c.on_msg, "test", cb)

        message = MQTTClient.Message(false, UInt8(MQTTClient.QOS_0), false, topic, payload)
        optional = message.qos == 0x00 ? () : (0)
        cmd = MQTTClient.PUBLISH | ((message.dup & 0x1) << 3) | (message.qos << 1) | message.retain
        packet = MQTTClient.Packet(cmd, [message.topic, optional..., message.payload])
        buffer = PipeBuffer()
        for i in packet.data
            MQTTClient.mqtt_write(buffer, i)
        end
        MQTTClient.handle_publish(c, buffer, 0x00, 0x00)

        # handle_ack
        c = MQTTClient.Client()
        c.in_flight[0x0001] = Future()
        io = IOBuffer(UInt8[0x00, 0x01])
        MQTTClient.handle_ack(c, io, 0x00, 0x00)

        # handle_pubrec
        c = MQTTClient.Client()
        s = IOBuffer()
        cmd = 0x50
        flags = 0x02
        write(s, UInt16(3))
        seekstart(s)
        MQTTClient.handle_pubrec(c, s, cmd, flags)
        take!(c.write_packets)

        # handle_pubrel
        c = MQTTClient.Client()
        s = IOBuffer()
        cmd = 0x62
        flags = 0x02
        write(s, UInt16(1))
        seekstart(s)
        MQTTClient.handle_pubrel(c, s, cmd, flags)
        p = take!(c.write_packets)


        # handle_suback
        c = MQTTClient.Client()
        s = IOBuffer()
        cmd = 0x90
        flags = 0x00
        write(s, UInt16(1))
        write(s, UInt8(0x00))
        seekstart(s)
        c.in_flight[0x0100] = Future()
        MQTTClient.handle_suback(c, s, cmd, flags)
        future = c.in_flight[0x0100]
        fetch(future)

        # handle_pingresp
        c = MQTTClient.Client()
        s = IOBuffer()
        cmd = 0xD0
        flags = 0x00
        @atomicswap c.ping_outstanding = 0x1
        @atomicswap c.state = 0x01
        MQTTClient.handle_pingresp(c, s, cmd, flags)

        ## Interfaces:
        # subscribe
        c = MQTTClient.Client()
        future = MQTTClient.subscribe_async(c, topic, cb, qos=MQTTClient.QOS_2)

        # unsubscribe
        c =  MQTTClient.Client()
        insert!(c.on_msg, topic, cb)
        @atomicswap c.last_id = 0x0
        future = unsubscribe_async(c, topic)

    end
end

end # module
# COV_EXCL_STOP
