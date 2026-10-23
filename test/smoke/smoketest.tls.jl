print("\n"^3)

## TLS Smoke Test and Stress Test
# Needs a broker with a TLS listener on localhost[8884] whose certificate is for "localhost" and is
# signed by the CA certificate in the MQTT_TLS_CA environment variable
using OpenSSL

tls_ca = get(ENV, "MQTT_TLS_CA", "")
if isempty(tls_ca)
    println("MQTT_TLS_CA not set -- skipping TLS smoke test")
else
    tls_test_conn = Connection(MQTTClient.TLS("localhost", 8884; ca_file=tls_ca))

    @testset "TLS Smoke tests" begin
        println("="^80)
        println("Running smoke tests against localhost[8884] over TLS")
        println("-"^80)

        smoke_test(Client(), tls_test_conn)
    end

    @testset "TLS stress test" begin
        println("="^80)
        println("Running stress tests against localhost[8884] over TLS")
        println("-"^80)

        stress_test(Client(), tls_test_conn)
    end

    @testset "TLS certificate verification" begin
        # The system roots do not include the test CA
        @test_throws Exception connect(Client(), Connection(MQTTClient.TLS("localhost", 8884)))
        # The certificate is for "localhost", not "127.0.0.1"
        @test_throws Exception connect(Client(), Connection(MQTTClient.TLS("127.0.0.1", 8884; ca_file=tls_ca)))
        @test connect(Client(), Connection(MQTTClient.TLS("127.0.0.1", 8884; verify=false))) == 0x00
    end
end

println("-"^80)
