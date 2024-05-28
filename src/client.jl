"""
    Client

The MQTT client in Julia facilitates communication between a device and an MQTT broker over a network. 
It manages connections, message handling, and maintains the state of communication. 
The client operates through three main loops: the read loop listens for incoming messages from the broker and processes them using designated handlers; 
the write loop sends packets to the broker from a queue, ensuring thread safety with a socket lock; 
and the keep-alive loop periodically sends ping requests to the broker to maintain the connection and detect disconnections. 
This client uses atomic operations to ensure thread safety for shared variables and supports asynchronous task management for efficient, non-blocking operations.

# Fields
- `state::UInt8`: client state.
- `on_msg::TrieNode`: A trie mapping topics to callback functions.
- `keep_alive::UInt16`: The keep-alive time in seconds.
- `last_id::UInt16`: The last packet identifier used.
- `in_flight::Dict{UInt16, Future}`: A dictionary mapping packet identifiers to futures.
- `write_packets::AbstractChannel`: A channel for writing packets.
- `socket`: The socket used for communication with the broker.
- `socket_lock`: A lock for synchronizing access to the socket.
- `ping_timeout::UInt64`: The ping timeout in seconds.
- `ping_outstanding::Atomic{UInt8}`: An atomic counter for the number of outstanding ping requests.
- `last_sent::Atomic{Float64}`: An atomic float representing the timestamp of the last sent packet.
- `last_received::Atomic{Float64}`: An atomic float representing the timestamp of the last received packet.

# Constructor
`Client(ping_timeout::UInt64=UInt64(60))` constructs a new `Client` object with the specified ping timeout (default: 60 seconds).
"""
mutable struct Client
    @atomic state::UInt8

    on_msg::TrieNode
    keep_alive::UInt16

    # TODO mutex?
    @atomic last_id::UInt16
    in_flight::Dict{UInt16,Future}

    write_packets::Channel{Packet}
    socket::IO
    socket_lock::ReentrantLock

    ping_timeout::UInt64

    # TODO remove atomic?
    @atomic ping_outstanding::UInt8
    @atomic last_sent::Float64
    @atomic last_received::Float64

    write_task::Task
    read_task::Task
    keep_alive_task::Task

    Client(ping_timeout::UInt64 = UInt64(60)) = new(
        0x00,
        TrieNode(),
        0x0000,
        0x0000,
        Dict{UInt16,Future}(),
        Channel{Packet}(typemax(Int64)),
        IOBuffer(),
        ReentrantLock(),
        ping_timeout,
        0x00,
        0.0,
        0.0,
        Task(nothing),
        Task(nothing),
        Task(nothing),
    )
end


function write_loop(client::Client)::UInt8
    try
        while !isclosed(client)
            if isready(client.write_packets)
                packet = take!(client.write_packets)
                buffer = PipeBuffer()
                for i in packet.data
                    mqtt_write(buffer, i)
                end
                data = take!(buffer)
                lock(client.socket_lock)
                write(client.socket, packet.cmd)
                write_len(client.socket, length(data))
                write(client.socket, data)
                unlock(client.socket_lock)
                @atomicswap client.last_sent = time()

                if packet.cmd === DISCONNECT
                    @debug "stopping write loop (DISCONNECT sent)"
                    break
                end
            else
                sleep(0.0001)
            end
        end
        @debug "ending write loop!"
        return 0x00
    catch e
        @debug "Write Loop threw an $(typeof(e))"
        if !isa(e, InvalidStateException)
            @atomicswap client.state = 0x03
            ### Uncomment this for debugging the (async) write loop.
            # @error "WRITE LOOP ERROR"
            # for (exc, bt) in current_exceptions()
            #    showerror(stdout, exc, bt)
            #    println(stdout)
            # end
            rethrow()
        end
        # channel closed
        close(client.socket)
        return 0x01
    end
end


function read_loop(client::Client)::UInt8
    try
        while !isclosed(client)
            if !eof(client.socket)
                cmd_flags = read(client.socket, UInt8)
                len = read_len(client.socket)
                data = read(client.socket, len)
                buffer = PipeBuffer(data)
                cmd = cmd_flags & 0xF0
                flags = cmd_flags & 0x0F

                if haskey(HANDLERS, cmd)
                    @atomicswap client.last_received = time()
                    HANDLERS[cmd](client, buffer, cmd, flags)
                else
                    # TODO unexpected cmd protocol error
                end
            else
                sleep(0.0001)
            end
        end

        @debug "ending write loop!"
        return 0x00
    catch e
        @debug "Read Loop threw a $(typeof(e)) Exception."
        if !isa(e, EOFError)
            @atomicswap client.state = 0x03
            ### Uncomment this for debugging the (async) read loop.
            # @error "READ LOOP ERROR"
            # for (exc, bt) in current_exceptions()
            #    showerror(stdout, exc, bt)
            #    println(stdout)
            # end
            rethrow()
        end
        # socket closed
        return 0x01
    end
end


function keep_alive_loop(client::Client)::UInt8
    ping_sent = time()

    if client.keep_alive > 10
        check_interval = 5
    else
        check_interval = client.keep_alive / 2
    end
    timer = Timer(0, interval = check_interval)

    while !isclosed(client)
        if time() - @atomic(client.last_sent) >= client.keep_alive ||
           time() - @atomic(client.last_received) >= client.keep_alive
            if @atomic(client.ping_outstanding) == 0x0
                @atomicswap client.ping_outstanding = 0x1
                try
                    lock(client.socket_lock)
                    write(client.socket, PINGREQ)
                    write(client.socket, 0x00)
                    unlock(client.socket_lock)
                    @atomicswap client.last_sent = time()
                catch e
                    @atomicswap client.state = 0x03
                    if isa(e, InvalidStateException)
                        break
                        # TODO is this the socket closed exception? Handle accordingly
                    else
                        rethrow()
                    end
                end
                ping_sent = time()
            end
        end

        if @atomic(client.ping_outstanding) == 1 &&
           time() - ping_sent >= client.ping_timeout
            try # No pingresp received
                disconnect(client)
                break
            catch e
                # channel closed
                @atomicswap client.state = 0x03
                if isa(e, InvalidStateException)
                    break
                else
                    rethrow()
                end
            end
            # TODO automatic reconnect
        end

        wait(timer)
    end
    return 0x00
end

function packet_id(client::Client)::UInt16
    if client.last_id == typemax(UInt16)
        @atomicreplace client.last_id typemax(UInt16) => 0x0000
    end
    @atomic client.last_id + 0x0001
    return client.last_id
end

# write packet to mqtt broker
function write_packet(client::Client, cmd::UInt8, data...)
    put!(client.write_packets, Packet(cmd, data))
end

isready(client::Client)::Bool = client.state == 0x00
isconnected(client::Client)::Bool = client.state == 0x01
isclosed(client::Client)::Bool = client.state >= 0x02
iserror(client::Client)::Bool = client.state == 0x03

show(io::IO, client::Client) = print(
    io,
    "MQTTClient[state: $(get(CLIENT_STATE, client.state, :unknown)), read_loop: $(taskstatus(client.read_task)), write_loop: $(taskstatus(client.write_task)), keep_alive: $(taskstatus(client.keep_alive_task))]\n$(show_tree(client.on_msg))",
)

fetch(client::Client)::Tuple{UInt8,UInt8,UInt8} = begin
    try
        wres = isnothing(client.write_task) ? 0x00 : fetch(client.write_task)
        rres = isnothing(client.read_task) ? 0x00 : fetch(client.read_task)
        kares = isnothing(client.keep_alive_task) ? 0x00 : fetch(client.keep_alive_task)

        return (wres, rres, kares)
    catch e
        @error e
        return (0x00, 0x00, 0x00)
    end
end
