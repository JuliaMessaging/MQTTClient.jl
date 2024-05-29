using MQTTClient

broker = "test.mosquitto.org"
topic = "jl/example"
payload = "Hello World!"

# Define the callback for receiving messages.
function on_msg(topic, payload)
    return println("Received message topic: [", topic, "] payload: [", String(payload), "]")
end

# Instantiate a client.
client, connection = MakeConnection(broker, 1883)

connect(client, connection)
println("connected to $client at $(connection.protocol)")

# Subscribe to the topic.
subscribe(client, topic, on_msg; qos=QOS_2)
println("subscribed to $topic")

sleep(0.5)

publish(client, topic, payload; qos=QOS_2)
println("published $payload to $topic")

# Unsubscribe from the topic
unsubscribe(client, topic)
println("unsubscribed from $topic")

# Disconnect from the broker. Not strictly needed as the broker will also
# disconnect us if the socket is closed. But this is considered good form
# and needed if you want to resume this session later.
disconnect(client)
