print("\n"^3)

## UDS Protocol Smoke Test and Stress Test
protocol = IOConnection("/tmp/mqtt.sock")
try
    s = connect(protocol)
    close(s)

    @testset "UDS Smoke tests" begin
        println("="^80)
        println("Running smoke tests against /tmp/mqtt.sock")
        println("-"^80)
        uds_test_client, uds_test_conn = MakeConnection("/tmp/mqtt.sock")
        smoke_test(uds_test_client, uds_test_conn)
    end

    @testset "UDS stress test" begin
        println("="^80)
        println("Running stress tests against /tmp/mqtt.sock")
        println("-"^80)

        uds_test_client, uds_test_conn = MakeConnection("/tmp/mqtt.sock")
        stress_test(uds_test_client, uds_test_conn)
    end
catch e
    if (e isa DNSError) || (e isa IOError)
        println("$(protocol.path) not online -- skipping smoke/stress test")
        @error e
    else
        rethrow(e)
    end
end

println("-"^80)
