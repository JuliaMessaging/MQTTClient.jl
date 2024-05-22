
"""
    handle_connack(client::Client, s::IO, cmd::UInt8, flags::UInt8)

Handle a `CONNACK` packet.

# Arguments
- `client::Client`: The client that received the packet.
- `s::IO`: The socket used for communication.
- `cmd::UInt8`: The command byte.
- `flags::UInt8`: The flags byte.

# Examples
```julia
julia> handle_connack(client, s, 0x20, 0x00)
```
"""
function handle_connack(client::Client, s::IO, cmd::UInt8, flags::UInt8)
    session_present = read(s, UInt8)
    return_code = read(s, UInt8)

    future = client.in_flight[0x0000]
    if return_code == CONNECTION_ACCEPTED
        @atomicreplace client.state 0x00 => 0x01
        put!(future, session_present)
    else
        #! TODO: This could be handled better maybe?
        error = CONNACK_ERRORS[return_code]
        @atomicswap client.state = 0x03
        put!(future, MQTTException(error))
    end
end

"""
    handle_publish(client::Client, s::IO, cmd::UInt8, flags::UInt8)

This function handles the publish command in MQTT protocol.

# Arguments
- `client`: A client object.
- `s`: An input stream.
- `cmd`: An unsigned 8-bit integer.
- `flags`: An unsigned 8-bit integer.

# Returns
Future.

"""
function handle_publish(client::Client, s::IO, cmd::UInt8, flags::UInt8)
    dup = (flags & 0x08) >> 3
    qos = (flags & 0x06) >> 1
    retain = (flags & 0x01)

    topic = mqtt_read(s, String)

    if qos == 0x01
        id = mqtt_read(s, UInt16)
        write_packet(client, PUBACK, id)
    end

    if qos == 0x02
        id = mqtt_read(s, UInt16)
        write_packet(client, PUBREC, id)
    end

    payload = take!(s)
    @info "handling publish" topic String(payload) client.on_msg haskey(client.on_msg, topic)
    if haskey(client.on_msg, topic)
        client.on_msg[topic](topic,payload)
    else
        try
            options = Vector{String}(collect(keys(client.on_msg)))
            matches = findall(t -> topic_eq(t, topic), options)
            for topic_match in options[matches]
                client.on_msg[topic_match](topic,payload)
            end
        catch e
            @error e
            @atomicswap client.state = 0x03
        end
    end
end

function handle_ack(client::Client, s::IO, cmd::UInt8, flags::UInt8)
    id = mqtt_read(s, UInt16)
    # TODO move this to its own function
    if haskey(client.in_flight, id)
        future = client.in_flight[id]
        put!(future, nothing)
        delete!(client.in_flight, id)
    else
        # TODO unexpected ack protocol error
        @atomicswap client.state = 0x03
    end
end

function handle_pubrec(client::Client, s::IO, cmd::UInt8, flags::UInt8)
    id = mqtt_read(s, UInt16)
    write_packet(client, PUBREL  | 0x02, id)
end

function handle_pubrel(client::Client, s::IO, cmd::UInt8, flags::UInt8)
    id = mqtt_read(s, UInt16)
    write_packet(client, PUBCOMP, id)
end

function handle_suback(client::Client, s::IO, cmd::UInt8, flags::UInt8)
    id = mqtt_read(s, UInt16)
    return_codes = take!(s)
    put!(client.in_flight[id], return_codes)
end

function handle_pingresp(client::Client, s::IO, cmd::UInt8, flags::UInt8)
    if @atomic(client.ping_outstanding) == 0x1
        @atomicswap client.ping_outstanding = 0x0
    else
        # We received a subresp packet we didn't ask for
        disconnect(client)
    end
end

const HANDLERS = Dict{UInt8, Function}(
                                       CONNACK => handle_connack,
                                       PUBLISH => handle_publish,
                                       PUBACK => handle_ack,
                                       PUBREC => handle_pubrec,
                                       PUBREL => handle_pubrel,
                                       PUBCOMP => handle_ack,
                                       SUBACK => handle_suback,
                                       UNSUBACK => handle_ack,
                                       PINGRESP => handle_pingresp
                                      )
