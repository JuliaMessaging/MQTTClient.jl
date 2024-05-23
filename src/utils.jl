"""
    mqtt_channel(len::Number=128)

A macro that declares a data channel based on the number of threads available.
If more than one thread is available, it returns a `RemoteChannel` with a `Channel{Packet}` of length `len`.
Otherwise, it returns a `Channel{Packet}` of length `len`.

# Arguments
- `len::Number=128`: The length of the channel. Defaults to 128.

# Examples
```julia
@mqtt_channel  # Returns a Channel{Packet} of length 128
@mqtt_channel 64  # Returns a Channel{Packet} of length 64
```
"""
# Disabled for now until a scheduler can be configured properly
# macro mqtt_channel(len::Number=128)
#     return Threads.nthreads() > 1 ? :(RemoteChannel(()->Channel{Packet}($len))) : :(Channel{Packet}($len))
# end

"""
    topic_eq(baseT::String, compareT::String)

A macro that compares two MQTT topics and returns a boolean value based on their equality. If the `baseT` topic contains a wildcard character `#`, the macro checks if the `compareT` topic contains the string before the wildcard character. Otherwise, it checks if the two topics are equal.

# Examples
```julia
julia> @topic_eq "sport/#" "sport/tennis"
true

julia> @topic_eq "sport/tennis" "sport/football"
false
```
"""
function topic_eq(baseT, compareT)
   if contains(baseT, "#")
       T = split(baseT, "#")[1]
       return contains(compareT, T)
   else
       return baseT == compareT
   end
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

"""
    resolve(future)

Fetch the result of a `Future` object and return it. If the result is an exception, throw the exception, otherwise return the result.

# Arguments
- `future`: The `Future` object to fetch the result from.

# Returns
- The result of the `Future`, or throws an exception if the result is an exception.
"""
function resolve(future)
    r = fetch(future)
    return (typeof(r) <: Exception) ? throw(r) : r
end

 # Helper method to check if it is possible to subscribe to a topic
 function filter_wildcard_len_check(sub)
     #Regex: matches any valid topic, + and # are not in allowed in strings, + is only allowed as a single symbol between two /, # is only allowed at the end
     if !(occursin(r"(^[^#+]+|[+])(/([^#+]+|[+]))*(/#)?$", sub)) || length(sub) > 65535
         throw(MQTTException("Invalid topic"))
     end
 end

 # Helper method to check if it is possible to publish a topic
 function topic_wildcard_len_check(topic)
     # Search for + or # in a topic. Return MQTT_ERR_INVAL if found.
     # Also returns MQTT_ERR_INVAL if the topic string is too long.
     # Returns MQTT_ERR_SUCCESS if everything is fine.
     if !(occursin(r"^[^#+]+$", topic)) || length(topic) > 65535
         throw(MQTTException("Invalid topic"))
     end
 end

Base.wait(::Nothing) = sleep(0.001)

function taskstatus(t::Task)
    if istaskdone(t)
        :done
    elseif istaskfailed(t)
        :failed
    elseif istaskstarted(t)
        :running
    else
        :ready
    end
end