print("\n"^3)

## TCP Protocol Smoke Test and Stress Test
tcp_test_client, tcp_test_conn = MakeConnection(localhost, 8883, user = MQTTClient.User("test","test"))
try
    s = connect(tcp_test_conn.protocol)
    close(s)

    @testset "User/Pass Secured TCP Smoke tests" begin
        println("="^80)
        println("Running smoke tests against localhost[8883] user:test, pass:test")
        println("-"^80)

        smoke_test(tcp_test_client, tcp_test_conn)
    end

    @testset "User/Pass Secured TCP stress test" begin
        println("="^80)
        println("Running stress tests against localhost[8883] user:test, pass:test")
        println("-"^80)

        stress_test(tcp_test_client, tcp_test_conn)
    end
catch e
    if (e isa DNSError) || (e isa IOError)
        println("$(tcp_test_conn.protocol.ip):$(tcp_test_conn.protocol.port) not online -- skipping smoke test")
        @error e
    else
        rethrow(e)
    end
end

println("-"^80)
