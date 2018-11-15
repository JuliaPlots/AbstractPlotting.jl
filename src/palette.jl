struct Palette{S, T<:AbstractVector{S}} <: AbstractVector{S}
   values::T
   i::Ref{UInt8}
   cycle::Bool
   Palette(values::T; cycle = false) where {T<:AbstractVector} =
       new{eltype(T), T}(values, Ref{UInt8}(1), cycle)
end

Palette(name::Union{String, Symbol}, n = 8; kwargs...) = Palette(to_colormap(name, n); kwargs...)

for s in [:(Key), :(Key{:color})]
    @eval function convert_attribute(p::Palette, key::($s))
        attr = convert_attribute(p.values[p.i[]], key)
        p.cycle && (p.i[] = p.i[] == length(p.values) ? one(UInt8) : p.i[] + one(UInt8))
        attr
    end
end

Base.size(p::Palette) = Base.size(p.values)

Base.getindex(p::Palette, i) = p.values[i+p.i[]-1]
