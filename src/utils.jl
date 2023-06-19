# macro dispatch(arg)
#     return Threads.nthreads() > 1 ? :(Dagger.spawn($arg)) : :(schedule(Task(() -> $arg)))
# end

macro dispatch(ex)
    if Threads.nthreads() == 1
        return :(@async $(esc(ex)))
    elseif Threads.nthreads() > 1
        return :(Dagger.@spawn $(esc(ex)))
    else
        return :(throw(Exception("Threads are not valid")))
    end
end

macro mqtt_channel(len::Number=128)
    return Threads.nthreads() > 1 ? :(RemoteChannel(()->Channel{Packet}($len))) : :(Channel{Packet}($len))
end

mqtt_read(s::IO, ::Type{UInt16}) = ntoh(read(s, UInt16))

function mqtt_read(s::IO, ::Type{String})
    len = mqtt_read(s, UInt16)
    return String(read(s, len))
end

function mqtt_write(stream::IO, x::Any)
    write(stream, x)
end

function mqtt_write(stream::IO, x::UInt16)
    write(stream, hton(x))
end

function mqtt_write(stream::IO, x::String)
    mqtt_write(stream, convert(UInt16, length(x)))
    write(stream, x)
end

function write_len(s::IO, len::Int64)
    while true
        b = convert(UInt8, mod(len, 128))
        len = div(len, 128)
        if len > 0
            b = b | 0x80
        end
        write(s, b)
        if(len == 0)
            break
        end
    end
end

function read_len(s::IO)
    multiplier = 1
    value = 0
    while true
        b = read(s, UInt8)
        value += (b & 127) * multiplier
        multiplier *= 128
        if multiplier > 128 * 128 * 128
            throw(ErrorException("malformed remaining length"))
        end
        if (b & 128) == 0
            break
        end
    end
    return value
end

# the docs make it sound like fetch would alrdy work in this way
# check julia sources
function resolve(future)
    r = fetch(future)
    if typeof(r) <: Exception
        throw(r)
    end
    return r
end
