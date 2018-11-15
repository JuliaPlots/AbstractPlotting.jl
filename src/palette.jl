struct Palette{S, T<:AbstractVector{S}} <: AbstractVector{S}
   values::T
   i::Ref{UInt8}
   cycle::Bool
   Palette(values::T; cycle = false) where {T<:AbstractVector} =
       new{eltype(T), T}(values, Ref{UInt8}(1), cycle)
end

Palette(name::Union{String, Symbol}, n = 8; kwargs...) = Palette(to_colormap(name, n); kwargs...)

# add all methods that will be necessary to remove ambiguities
for s in [:(Key), :(Key{:color}), :(Key{:linestyle})]
    @eval function convert_attribute(p::Palette, key::($s))
        attr = convert_attribute(p.values[p.i[]], key)
        increment!(p)
        attr
    end
end

function increment!(p::Palette, n = 1)
    p.cycle && (p.i[] = (p.i[]+n-1)%length(p)+1)
    p
end

Base.size(p::Palette) = Base.size(p.values)

Base.getindex(p::Palette, i) = p.values[(i+p.i[]-2) % length(p)+1]
