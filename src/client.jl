"""
    Client

A mutable struct representing an MQTT client.

An MQTT client is any device (from a microcontroller up to a fully-fledged server) that runs an MQTT library and connects to an MQTT broker over a network. Information is organized in a hierarchy of topics.

# Fields
- `on_msg::Dict{String,Function}`: A dictionary mapping topic names to callback functions.
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
mutable struct Client{T}
    cond_state::Threads.Condition
    @atomic state::Symbol                  # :ready, :connected, :done, :error
    excp::Union{Exception, Nothing}      # exception to be thrown when state == :error

    on_msg::Dict{String,Function}
    keep_alive::UInt16

    data_lock::ReentrantLock
    last_id::UInt16
    in_flight::Dict{UInt16, Future}

    write_packets::RemoteChannel{Channel{Packet}}
    socket::Union{T, Nothing}
    socket_lock::ReentrantLock

    ping_timeout::UInt64

    @atomic ping_outstanding::UInt8
    @atomic last_sent::Float64
    @atomic last_received::Float64

    write_task::Union{Nothing,Task}
    read_task::Union{Nothing,Task}
    keep_alive_task::Union{Nothing,Task}

    Client{T}(ping_timeout::UInt64=UInt64(60)) where { T <: AbstractProtocol } = new{T}(
            Threads.Condition(ReentrantLock()),
            :ready,
            nothing,
            Dict{String,Function}(),
            0x0020,
            ReentrantLock(),
            0x0000,
            Dict{UInt16, Future}(),
            RemoteChannel(() -> Channel{Packet}(typemax(Int64))),
            nothing,
            ReentrantLock(),
            ping_timeout,
            0,
            0.0,
            0.0,
            nothing,
            nothing,
            nothing)
end



"""
    write_loop(client)

This function writes data to the socket.

# Arguments
- `client`: A client object.

# Returns
Nothing.

"""
function write_loop(client)
    try
        while !isdone(client)
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
            @atomic client.last_sent = time()
        end
    catch e
        @info e
        # channel closed
        if isa(e, InvalidStateException)
            close(client.socket)
        else
            rethrow(e)
        end
    end
    nothing
end

"""
    read_loop(client)

Reads data from a client socket and processes it.

# Arguments
- `client`: A client object.

# Example
```julia
read_loop(client)
```
"""
function read_loop(client)
    try
        while !isdone(client)
            cmd_flags = read(client.socket, UInt8)
            len = read_len(client.socket)
            data = read(client.socket, len)
            buffer = PipeBuffer(data)
            cmd = cmd_flags & 0xF0
            flags = cmd_flags & 0x0F

            if haskey(HANDLERS, cmd)
                @atomic client.last_received = time()
                HANDLERS[cmd](client, buffer, cmd, flags)
            else
                # TODO unexpected cmd protocol error
            end
        end
    catch e
        # socket closed
        if !isa(e, EOFError)
            rethrow(e)
        end
    end
    nothing
end

"""
    keep_alive_loop(client::Client)

This function runs a loop that sends a PINGREQ message to the MQTT broker to keep the connection alive. The loop checks the connection at regular intervals determined by the `client.keep_alive` value. If no message has been sent or received within the keep-alive interval, a PINGREQ message is sent. If no PINGRESP message is received within the `client.ping_timeout` interval, the client is disconnected.
"""
function keep_alive_loop(client::Client)
    ping_sent = time()

    if client.keep_alive > 10
        check_interval = 5
    else
        check_interval = client.keep_alive / 2
    end
    timer = Timer(0, interval=check_interval)

    while !isdone(client)
        if time() - lastsent(client) >= client.keep_alive || time() - lastreceived(client) >= client.keep_alive
            if !ispingoutstanding(client)
                @atomic client.ping_outstanding = 0x1
                try
                    lock(client.socket_lock)
                    write(client.socket, PINGREQ)
                    write(client.socket, 0x00)
                    unlock(client.socket_lock)
                    @atomic client.last_sent = time()
                catch e
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

        if ispingoutstanding(client) && time() - ping_sent >= client.ping_timeout
            try # No pingresp received
                disconnect(client)
                break
            catch e
                # channel closed
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
    nothing
end

function packet_id(client::Client)
    lock(client.data_lock)
    try
        if client.last_id == typemax(UInt16)
            client.last_id = 0
        end
        client.last_id += 1
        return client.last_id
    finally
        unlock(client.data_lock)
    end
end

# write packet to mqtt broker
function write_packet(client::Client, cmd::UInt8, data...)
    put!(client.write_packets, Packet(cmd, data))
end

function fetch(c::Client)
    kat = isnothing(c.keep_alive_task) || istaskfailed(c.keep_alive_task) ? nothing : fetch(c.keep_alive_task)
    rt = isnothing(c.read_task) || istaskfailed(c.read_task) ? nothing : wait(c.read_task)
    wt = isnothing(c.write_task) || istaskfailed(c.write_task) ? nothing : wait(c.write_task)
    (kat,rt,wt)
end

lock(c::Client) = lock.([c.cond_state, c.data_lock, c.socket_lock])
unlock(c::Client) = unlock.([c.cond_state, c.data_lock, c.socket_lock])

isready(c::Client) = ((@atomic :monotonic c.state) === :ready)
isconnected(c::Client) = ((@atomic :monotonic c.state) === :connected)
isdone(c::Client) = ((@atomic :monotonic c.state) === :done)
isfailed(c::Client) = ((@atomic :monotonic c.state) === :error)

ispingoutstanding(c::Client) = ((@atomic :monotonic c.ping_outstanding) === 0x01)
lastsent(c::Client) = (@atomic :monotonic c.last_sent)
lastreceived(c::Client) = (@atomic :monotonic c.last_received)

Base.show(io::IO, client::Client{D}) where D = print(io, "MQTTClient(State: $(client.state), Data Transportation Method: $D, Topic Subscriptions: $(collect(keys(client.on_msg))))")
