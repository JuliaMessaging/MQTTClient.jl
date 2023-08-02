print("\n"^3)

## TCP Protocol Smoke Test and Stress Test
uds_test_client, uds_test_conn = MakeConnection(MQTTClient.IOConnection("/tmp/mqtt.sock"))
try
    s = connect(uds_test_conn.protocol)
    close(s)

    @testset "UDS Smoke tests" begin
        println("="^80)
        println("Running smoke tests against /tmp/mqtt.sock")
        println("-"^80)

        smoke_test(uds_test_client, uds_test_conn)
    end

    @testset "UDS stress test" begin
        println("="^80)
        println("Running stress tests against /tmp/mqtt.sock")
        println("-"^80)

        stress_test(uds_test_client, uds_test_conn)
    end
catch e
    if (e isa DNSError) || (e isa IOError)
        println("$(uds_test_conn.protocol.path) not online -- skipping smoke test")
        @error e
    else
        rethrow(e)
    end
end

println("-"^80)
