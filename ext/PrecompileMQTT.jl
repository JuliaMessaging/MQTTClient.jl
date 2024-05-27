# COV_EXCL_START
module PrecompileMQTT # Should be same name as the file (just like a normal package)

using MQTTClient
using PrecompileTools

# precompile(Tuple{typeof(Base.indexed_iterate), Tuple{Nothing, Int64}, Int64})
# precompile(Tuple{typeof(Base.indexed_iterate), Tuple{Nothing, Int64}, Int64, Int64})

# Precompiling the package like this provides a slower initial load of the package but faster code execution.
# based on tests this precompile step reduces compilation at runtime by ~25% and decreases first execution time by ~10%.
@setup_workload begin
    # Putting some things in `@setup_workload` instead of `@compile_workload` can reduce the size of the
    # precompile file and potentially make loading faster.

    # on_msg(t,p) = println("topic [$t]: $p")
    # topic = "foo"
    # msg = "bar"
    # payload = Vector{UInt8}("baz")

   #  function run_client(client, conn)
   #     topic = "foo"
   #     payload = Random.randstring(20)

   #     function on_msg(t, p)
   #         nothing
   #     end

   #     connect(client, conn)
   #     sleep(0.05)
   #     disconnect(client)
   #     sleep(0.05)
   #     connect(client, conn)
   #     sleep(0.05)

   #     subscribe(client, "$topic/qos0", on_msg, qos=QOS_0)
   #     subscribe(client, "$topic/qos1", on_msg, qos=QOS_1)
   #     subscribe(client, "$topic/qos2", on_msg, qos=QOS_2)

   #     publish(client, "$topic/qos0", payload, qos=QOS_0)
   #     publish(client, "$topic/qos1", payload, qos=QOS_1)
   #     publish(client, "$topic/qos2", payload, qos=QOS_2)

   #     disconnect(client)
   # end

    @compile_workload begin
        # all calls in this block will be precompiled, regardless of whether
        # they belong to your package or not (on Julia 1.8 and higher)

        # udsclient, udsconnection = MakeConnection("/tmp/mqtt.sock")
        # # connect_async(udsclient, udsconnection)
        # subscribe_async(udsclient, topic, on_msg, qos=QOS_2)
        # publish_async(udsclient, topic, msg)
        # publish_async(udsclient, topic, payload)
        # unsubscribe_async(udsclient, topic)
        # # disconnect(udsclient)

        # tcpclient, tcpconnection = MakeConnection("test.mosquitto.org", 1883)

        # # cannot run against live broker connections
        # # TODO: fix the mocksocket to allow testing/precompiling connections.
        # # run_client(tcpclient, tcpconnection)
        # # connect_async(tcpclient, tcpconnection)
        # subscribe_async(tcpclient, topic, on_msg, qos=QOS_2)
        # publish_async(tcpclient, topic, msg)
        # publish_async(tcpclient, topic, payload)
        # unsubscribe_async(tcpclient, topic)
        # # disconnect(tcpclient)
    end
end

end # module
# COV_EXCL_STOP
