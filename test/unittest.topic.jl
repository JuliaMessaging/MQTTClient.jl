@testset "Test TrieNode creation and insertion" begin
    root = MQTTClient.TrieNode()
    insert!(
        root, "topic1/device1", (topic, payload) -> println("Callback for $topic: $payload")
    )
    insert!(
        root, "topic1/device2", (topic, payload) -> println("Callback for $topic: $payload")
    )
    insert!(
        root,
        "topic2/+/foo",
        (topic, payload) -> println("Wildcard data for $topic: $payload"),
    )
    insert!(
        root, "topic2/bar/foo", (topic, payload) -> println("Callback for $topic: $payload")
    )

    # Ensure that the TrieNode structure is created correctly
    @test root.children["topic1"].children["device1"].cb isa MQTTClient.FunctionCallback
    @test root.children["topic1"].children["device2"].cb isa MQTTClient.FunctionCallback
    @test root.children["topic2"].children["+"].children["foo"].cb isa
        MQTTClient.FunctionCallback
    @test root.children["topic2"].children["bar"].children["foo"].cb isa
        MQTTClient.FunctionCallback
end

@testset "Test TrieNode removal" begin
    root = MQTTClient.TrieNode()
    insert!(
        root, "topic1/device1", (topic, payload) -> println("Callback for $topic: $payload")
    )
    insert!(
        root, "topic1/device2", (topic, payload) -> println("Callback for $topic: $payload")
    )
    insert!(
        root,
        "topic2/+/foo",
        (topic, payload) -> println("Wildcard data for $topic: $payload"),
    )
    insert!(
        root, "topic2/bar/foo", (topic, payload) -> println("Callback for $topic: $payload")
    )

    # Remove a node from the Trie
    MQTTClient.remove!(root, "topic2/bar/foo")
    MQTTClient.remove!(root, "topic1/device1")

    # Ensure that the removed node is no longer in the Trie
    @test !haskey(root.children["topic2"].children, "bar")
    @test !haskey(root.children["topic1"].children, "device1")
    @test haskey(root.children["topic1"].children, "device2")
end
