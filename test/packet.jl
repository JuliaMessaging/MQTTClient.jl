const TOPIC_STRING = "foo"
const MESSAGE_STRING = "bar"

function on_msg(topic, payload)
    msg = p |> String
    @info "Received message topic: [", topic, "] payload: [", msg, "]"
    @test topic == TOPIC_STRING
    @test msg == MESSAGE_STRING
end

function is_out_correct(filename_expected::AbstractString, actual::Channel{UInt8}, mid::UInt16)
    file_data = read_all_to_arr(filename_expected)
    actual_data = Vector{UInt8}()

    for i in file_data
      append!(actual_data, take!(actual))
    end

    mid_index = get_mid_index(file_data)
    if mid_index > 0
      buffer = PipeBuffer()
      write(buffer, mid)
      converted_mid = take!(buffer)
      file_data[mid_index] = converted_mid[2]
      file_data[mid_index+1] = converted_mid[1]
    end

    correct = true
    i = 1
    while i <= length(file_data)
      if file_data[i] != actual_data[i]
        correct = false
        break
      end
      i += 1
    end
    return correct
end

function is_out_correct(filename_expected::AbstractString, actual::Channel{UInt8})
    file = open(filename_expected, "r")
    correct = true
    while !eof(file)
        if read(file, UInt8) != take!(actual)
            correct = false
            break
        end
    end
    return correct
end

@testset verbose=true "Running packet tests" begin

client = Client(on_msg)
last_id::UInt16 = 0x0001

@testset "Testing connect" begin
    connect(client, "test.mosquitto.org", 1883)
    tfh::TestFileHandler = client.socket
    @test is_out_correct("data/output/connect.dat", tfh.out_channel)
    # CONNACK is automatically being sent in connect call
end

@testset "Testing subscribe" begin
    subscribe_async(client, (TOPIC_STRING, QOS_1), ("cba", QOS_0))
    put_from_file(tfh, "data/input/suback.dat", client.last_id)
    @test is_out_correct("data/output/subreq.dat", tfh.out_channel, client.last_id)
end

@testset "Testing unsubscribe" begin
    unsubscribe_async(client, TOPIC_STRING, "cba")
    put_from_file(tfh, "data/input/unsuback.dat", client.last_id)
    @test is_out_correct("data/output/unsubreq.dat", tfh.out_channel, client.last_id)
end

@testset "Testing receive publish QOS 0" begin
    put_from_file(tfh, "data/input/qos0pub.dat")
    @test is_out_correct("data/output/puback.dat", tfh.out_channel, last_id)
end

@testset "Testing receive publish QOS 1" begin
    put_from_file(tfh, "data/input/qos1pub.dat", last_id)
    @test is_out_correct("data/output/puback.dat", tfh.out_channel, last_id)
    #last_id += 1
end

@testset "Testing receive publish QOS 2" begin
    put_from_file(tfh, "data/input/qos2pub.dat", last_id)
    @test is_out_correct("data/output/pubrec.dat", tfh.out_channel, last_id)
    put_from_file(tfh, "data/input/pubrel.dat", last_id)
    @test is_out_correct("data/output/pubcomp.dat", tfh.out_channel, last_id)
    #last_id += 1
end

@testset "Testing send publish QOS 0" begin
    publish_async(client, "test1", "QOS_0", qos=QOS_0)
    @test is_out_correct("data/output/qos0pub.dat", tfh.out_channel)
end

@testset "Testing send publish QOS 1" begin
    publish_async(client, "test2", "QOS_1", qos=QOS_1)
    put_from_file(tfh, "data/input/puback.dat", client.last_id)
    @test is_out_correct("data/output/qos1pub.dat", tfh.out_channel, client.last_id)
end

@testset "Testing send publish QOS 2" begin
    publish_async(client, "test3", "test", qos=QOS_2)
    @test is_out_correct("data/output/qos2pub.dat", tfh.out_channel, client.last_id)
    put_from_file(tfh, "data/input/pubrec.dat", client.last_id)
    @test is_out_correct("data/output/pubrel.dat", tfh.out_channel, client.last_id)
    put_from_file(tfh, "data/input/pubcomp.dat", client.last_id)
end

@testset "Testing disconnect" begin
    disconnect(client)
    @test is_out_correct("data/output/disco.dat", tfh.out_channel)
end

    #This has to be in it's own connect flow to not interfere with other messages
@testset "Testing keep alive with response" begin
    client = Client(on_msg)

    client.ping_timeout = 1
    connect(client, "test.mosquitto.org", 1883, client_id="TestID", keep_alive=1)
    tfh = client.socket
    @test is_out_correct("data/output/connect_keep_alive1s.dat", tfh.out_channel) # Consume output
    @test is_out_correct("data/output/pingreq.dat", tfh.out_channel)
    put_from_file(tfh, "data/input/pingresp.dat")
end

@testset "Testing keep alive without response" begin
    sleep(1.1)
    @test is_out_correct("data/output/pingreq.dat", tfh.out_channel)
    @test is_out_correct("data/output/disco.dat", tfh.out_channel)

    info("Testing unwanted pingresp")
    client = Client(on_msg)
    connect(client, "test.mosquitto.org", 1883, client_id="TestID", keep_alive=15)
    tfh = client.socket
    put_from_file(tfh, "data/input/pingresp.dat")
    sleep(0.1)
    @test tfh.closed
end
end

end