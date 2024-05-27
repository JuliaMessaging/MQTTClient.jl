abstract type AbstractNodeCallback end

function DefaultCB(topic, payload)
    @debug "Recieved data on $topic without callback specified" payload
    nothing
end

struct EmptyCallback <: AbstractNodeCallback end
struct FunctionCallback <: AbstractNodeCallback
    eval::Function
end

struct TrieNode{F<:AbstractNodeCallback}
    children::Dict{String,TrieNode}
    cb::F

    TrieNode() = new{EmptyCallback}(Dict{String,TrieNode}(), EmptyCallback())
    TrieNode(child::Dict{String,TrieNode}) = new{EmptyCallback}(child, EmptyCallback())

    TrieNode(cb::Function) =
        new{FunctionCallback}(Dict{String,TrieNode}(), FunctionCallback(cb))
    TrieNode(child::Dict{String,TrieNode}, cb::Function) =
        new{FunctionCallback}(child, FunctionCallback(cb))

    TrieNode(::Nothing, cb::Function) = TrieNode(cb)
    TrieNode(childnode::TrieNode, cb::Function) = TrieNode(childnode.children, cb)

    TrieNode(cb::EmptyCallback) = TrieNode()
    TrieNode(cb::FunctionCallback) = TrieNode(cb.eval)
end

(node::TrieNode{FunctionCallback})(topic, payload) =
    Base.invokelatest(node.cb.eval, topic, payload)
(node::TrieNode{EmptyCallback})(topic, payload) = DefaultCB(topic, payload)

function Base.get(root::TrieNode, topic::String, default::Function)
    parts = split(topic, '/')
    return something(trie_lookup(root, get(parts, 1, nothing), parts[2:end]), default)
end

trie_lookup(node::TrieNode{FunctionCallback}, part::Nothing, topic_parts::Any) = node
trie_lookup(node::TrieNode{EmptyCallback}, part::Nothing, topic_parts::Any) = nothing
trie_lookup(node::Nothing, part::Any, topic_parts::Any) = nothing

function trie_lookup(node::TrieNode, part::AbstractString, topic_parts::Vector)
    topic = trie_lookup(
        get(node.children, part, nothing),
        get(topic_parts, 1, nothing),
        topic_parts[2:end],
    )
    wildcard = trie_lookup(
        get(node.children, "+", nothing),
        get(topic_parts, 1, nothing),
        topic_parts[2:end],
    )
    multi = get(node.children, "#", nothing)

    something(topic, wildcard, multi, Some(nothing))
end

function Base.insert!(root::TrieNode, key::String, fn::Function)
    depth = count(==('/'), key) + 1
    key_parts = eachsplit(key, '/', keepempty = true)
    node = root
    for (idx, part) in enumerate(key_parts)
        if idx === depth
            #@info "reached base node"
            node.children[part] = TrieNode(get(node.children, part, nothing), fn)
        elseif haskey(node.children, part)
            #@info "already exists"
            node = node.children[part]
        else
            #@info "inserting new node"
            node.children[part] = TrieNode()
            node = node.children[part]
        end
    end
end

function remove!(root::TrieNode, topic::String)
    parts = split(topic, '/')
    remove_node!(root, get(parts, 1, nothing), parts[2:end])
    nothing
end

function remove_node!(node::TrieNode, part, parts::Vector)
    child_node = get(node.children, part, nothing)

    if part == "#"
        for k in keys(node.children)
            delete!(node.children, k)
        end
        return true
    elseif part == "+"
        return all([
            (
                (
                    remove_node!(
                        get(node.children, k, nothing),
                        get(parts, 1, nothing),
                        parts[2:end],
                    ) && isempty(node.children[k].children)
                ) ? (delete!(node.children, k); true) : false
            ) for k in keys(node.children)
        ])
    elseif isnothing(child_node)
        return false
    elseif isempty(child_node.children) && isempty(parts)
        # leaf to remove, delete part from node
        delete!(node.children, part)
        return true
    elseif isempty(parts)
        # branching leaf, only remove cb from child_node
        node.children[part] = TrieNode(child_node.children)
        return false
    else
        # branch, go to next
        if remove_node!(
            get(node.children, part, nothing),
            get(parts, 1, nothing),
            parts[2:end],
        ) && isempty(child_node.children)
            delete!(node.children, part)
            return true
        end
        return false
    end
end
remove_node!(node::Nothing, part, parts::Vector) = false


prune!(node::TrieNode) =
    while !isempty(node.children) &&
          any([prune!(node, key, childnode) for (key, childnode) in node.children])
    end
prune!(node::TrieNode, key, childnode::TrieNode{MQTTClient.FunctionCallback}) =
    !isempty(childnode.children) ?
    any([prune!(childnode, k, n) for (k, n) in childnode.children]) : false

function prune!(node::TrieNode, key, childnode::TrieNode{MQTTClient.EmptyCallback})
    if isempty(childnode.children)
        delete!(node.children, key)
        return true
    end
    return any([prune!(childnode, k, n) for (k, n) in childnode.children])
end

explode(node::TrieNode{EmptyCallback}; path = []) =
    isempty(node.children) ? (path, nothing) :
    [explode(node.children[k], path = [path..., k]) for k in keys(node.children)]
explode(node::TrieNode{FunctionCallback}; path = []) =
    isempty(node.children) ? (path, node.cb) :
    (
        path,
        node.cb,
        [explode(node.children[k], path = [path..., k]) for k in keys(node.children)],
    )

show_exploded(vec::Vector) = join(show_exploded.(vec), "\n")
show_exploded((vec, cb)::Tuple{Vector{String},FunctionCallback}) =
    "$(join(vec, "/")): $(cb.eval)"
show_exploded((vec, cb, child)::Tuple{Vector{String},FunctionCallback,Vector}) =
    "$(join(vec, "/")): $(cb.eval)\n$(show_exploded(child))"


Base.show(io::IO, ::MIME"text/plain", node::TrieNode) =
    isempty(node.children) ? print(io, node) : print(io, show_exploded(explode(node)))
Base.show(node::TrieNode) =
    isempty(node.children) ? print(node) : print(show_exploded(explode(node)))

function show_tree(node::TrieNode, prefix::String = "", is_last::Bool = true)
    tree_string = ""

    # Get the children keys
    children_keys = collect(keys(node.children))

    for (i, key) in enumerate(children_keys)
        is_last_child = i == length(children_keys)
        # Determine the appropriate prefix based on whether this is the last child
        current_prefix = is_last_child ? "└── " : "├── "
        next_prefix = is_last_child ? "    " : "│   "

        # Print the key with the appropriate prefix
        tree_string *= (prefix * current_prefix * key)

        tree_string *=
            isa(node.children[key].cb, FunctionCallback) ?
            "{$(node.children[key].cb.eval)}\n" : "\n"

        # Recursively print the child nodes
        tree_string *= show_tree(node.children[key], prefix * next_prefix, is_last_child)
    end
    tree_string
end
