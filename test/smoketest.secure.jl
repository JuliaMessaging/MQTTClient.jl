print("\n"^3)

## TCP Protocol Smoke Test and Stress Test
protocol = IOConnection(localhost, 8883)
try
    s = connect(protocol)
    close(s)

    @testset "User/Pass Secured TCP Smoke tests" begin
        println("="^80)
        println("Running smoke tests against localhost[8883] user:test, pass:test")
        println("-"^80)
        tcp_test_client, tcp_test_conn = MakeConnection(localhost, 8883, user = MQTTClient.User("test","test"))
        smoke_test(tcp_test_client, tcp_test_conn)
    end

    @testset "User/Pass Secured TCP stress test" begin
        println("="^80)
        println("Running stress tests against localhost[8883] user:test, pass:test")
        println("-"^80)
        tcp_test_client, tcp_test_conn = MakeConnection(localhost, 8883, user = MQTTClient.User("test","test"))
        stress_test(tcp_test_client, tcp_test_conn)
    end
catch e
    if (e isa DNSError) || (e isa IOError)
        println("$(protocol.ip):$(protocol.port) not online -- skipping smoke/stress test")
        @error e
    else
        rethrow(e)
    end
end

println("-"^80)

