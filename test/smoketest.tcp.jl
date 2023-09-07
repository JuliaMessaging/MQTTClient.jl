print("\n"^3)

## TCP Protocol Smoke Test and Stress Test
protocol = IOConnection(localhost, 1883)
try
    s = connect(protocol)
    close(s)
    @testset "TCP Smoke tests" begin
        println("="^80)
        println("Running smoke tests against localhost[1883]")
        println("-"^80)

        tcp_test_client, tcp_test_conn = MakeConnection(localhost, 1883)
        smoke_test(tcp_test_client, tcp_test_conn)
    end

    @testset "TCP stress test" begin
        println("="^80)
        println("Running stress tests against localhost[1883]")
        println("-"^80)

        tcp_test_client, tcp_test_conn = MakeConnection(localhost, 1883)
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
