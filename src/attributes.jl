"""
Main structure for holding attributes, for theming plots etc!
"""
struct Attributes
    # name, for better error messages!
    name::String
    # We dont have one node per value anymore, but instead one node
    # that gets triggered on any setindex!, or whenever an input attribute node changes
    # This makes it easier to layer Observable{Attributes}()
    on_change::Node{Pair{Symbol, Any}}
    # The supported fields, so we can throw an error, whenever fields are not supported
    supported_fields::Set{Symbol}
    # The attributes given at construction time, taking the highest priority
    from_user::Dict{Symbol, Any}
    # attributes filled in by e.g. a theme, or other processes in the pipeline
    from_theme::Dict{Symbol, Any}
    # The "global" default values for this specific attribute instance
    # Will be immutabe (maybe not a Dict then?) and shared between all similar objects
    default_values::Dict{Symbol, Any}

    function Attributes(name::String, default_values::Dict{Symbol, Any}, from_user::Dict{Symbol, Any})
        on_change = Node{Pair{Symbol, Any}}()
        supported_fields = Set(keys(default_values))
        return new(name, on_change, supported_fields, from_user,
                   Dict{Symbol, Any}(), default_values)
    end
end

function Base.propertynames(attributes::Attributes)
    return getfield(attributes, :supported_fields)
end

function Base.getproperty(attributes::Attributes, field::Symbol)
    name = getfield(attributes, :name)
    if field in propertynames(attributes)
        # The priority is:
        # User given
        from_user = getfield(attributes, :from_user)
        haskey(from_user, field) && return from_user[field]
        # Theme given
        from_theme = getfield(attributes, :from_theme)
        haskey(from_theme, field) && return from_theme[field]
        # Construction defaults
        default_values = getfield(attributes, :default_values)
        haskey(default_values, field) && return default_values[field]
        error("Incorrectly constructed Attributes ($(name))! No value found for $(field)")
    else
        error("Field $(field) not in attributes $(name)!")
    end
end

function Base.setproperty!(attributes::Attributes, field::Symbol, value)
    name = getfield(attributes, :name)
    if field in propertynames(attributes)
        # we always set the users data, since setting this is done by the user!
        from_user = getfield(attributes, :from_user)
        from_user[field] = value
        on_change = getfield(attributes, :on_change)
        # trigger change!
        on_change[] = (field, value)
    else
        error("Field $(field) not in attributes $(name)!")
    end
end


Base.broadcastable(x::Attributes) = Ref(x)

# The rules that we use to convert values to a Node in Attributes
value_convert(x::Observables.AbstractObservable) = Observables.observe(x)
value_convert(@nospecialize(x)) = x

# We transform a tuple of observables into a Observable(tuple(values...))
function value_convert(x::NTuple{N, # name, for better error messages!Union{Any, Observables.AbstractObservable}}) where N
    result = Observable(to_value.(x))
    onany((args...)-> args, x...)
    return result
end

value_convert(x::NamedTuple) = Attributes(x)

node_pairs(pair::Union{Pair, Tuple{Any, Any}}) = (pair[1] => convert(Node{Any}, value_convert(pair[2])))
node_pairs(pairs) = (node_pairs(pair) for pair in pairs)

Attributes(; kw_args...) = Attributes(Dict{Symbol, Node}(node_pairs(kw_args)))
Attributes(pairs::Pair...) = Attributes(Dict{Symbol, Node}(node_pairs(pairs)))
Attributes(pairs::AbstractVector) = Attributes(Dict{Symbol, Node}(node_pairs.(pairs)))
Attributes(pairs::Iterators.Pairs) = Attributes(collect(pairs))
Attributes(nt::NamedTuple) = Attributes(; nt...)
attributes(x::Attributes) = getfield(x, :attributes)

Base.keys(x::Attributes) = keys(x.attributes)
Base.values(x::Attributes) = values(x.attributes)

function Base.iterate(x::Attributes, state...)
    s = iterate(keys(x), state...)
    s === nothing && return nothing
    return (s[1] => x[s[1]], s[2])
end

function Base.copy(attributes::Attributes)
    result = Attributes()
    for (k, v) in attributes
        # We need to create a new Signal to have a real copy
        result[k] = copy(v)
    end
    return result
end

Base.filter(f, x::Attributes) = Attributes(filter(f, attributes(x)))
Base.empty!(x::Attributes) = (empty!(attributes(x)); x)
Base.length(x::Attributes) = length(attributes(x))

function Base.merge!(target::Attributes, args::Attributes...)
    for elem in args
        merge_attributes!(target, elem)
    end
    return target
end

Base.merge(target::Attributes, args::Attributes...) = merge!(copy(target), args...)

@generated hasfield(x::T, ::Val{key}) where {T, key} = :($(key in fieldnames(T)))

function Base.getproperty(x::T, key::Symbol) where T <: Union{Attributes, Transformable}
    if hasfield(x, Val(key))
        getfield(x, key)
    else
        getindex(x, key)
    end
end

function Base.setproperty!(x::T, key::Symbol, value) where T <: Union{Attributes, Transformable}
    if hasfield(x, Val(key))
        setfield!(x, key, value)
    else
        setindex!(x, value, key)
    end
end

function getindex(x::Attributes, key::Symbol)
    x = attributes(x)[key]
    # We unpack Attributes, even though, for consistency, we store them as nodes
    # this makes it easier to create nested attributes
    return x[] isa Attributes ? x[] : x
end

function setindex!(x::Attributes, value, key::Symbol)
    if haskey(x, key)
        x.attributes[key][] = value
    else
        x.attributes[key] = convert(Node{Any}, value)
    end
end

function setindex!(x::Attributes, value::Node, key::Symbol)
    if haskey(x, key)
        # error("You're trying to update an attribute node with a new node. This is not supported right now.
        # You can do this manually like this:
        # lift(val-> attributes[$key] = val, node::$(typeof(value)))
        # ")
        return x.attributes[key] = convert(Node{Any}, value)
    else
        #TODO make this error. Attributes should be sort of immutable
        return x.attributes[key] = convert(Node{Any}, value)
    end
    return x
end

function Base.show(io::IO,::MIME"text/plain", attr::Attributes)
    d = Dict()
    for p in pairs(attr.attributes)
        d[p.first] = to_value(p.second)
    end
    show(IOContext(io, :limit => false), MIME"text/plain"(), d)

end

Base.show(io::IO, attr::Attributes) = show(io, MIME"text/plain"(), attr)

"""
    get_attribute(dict::Attributes, key::Key)
Gets the attribute at `key`, converts it and extracts the value
"""
function get_attribute(dict::Attributes, key::Key)
    return convert_attribute(to_value(dict[key]), Key{key}())
end

"""
    get_attribute(dict::Attributes, key::Key)
Gets the attribute at `key` as a converted signal
"""
function get_lifted_attribute(dict::Attributes, key::Key)
    return lift(x-> convert_attribute(x, Key{key}()), dict[key])
end
