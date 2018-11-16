abstract type AbstractPalette{S} end

struct Palette{S, T<:AbstractVector{S}} <: AbstractPalette{S}
   values::T
   i::Ref{UInt8}
   offset::Int8
   cycle::Bool
   Palette(values::T, i::Ref{UInt8}, offset::Int8=Int8(0); cycle = true) where {T<:AbstractVector} =
       new{eltype(T), T}(values, i, offset, cycle)
end

Base.eltype(::AbstractPalette{S}) where {S} = S

Palette(values::T, offset::Int8=Int8(0); cycle = true) where {T<:AbstractVector} =
    Palette(values, Ref{UInt8}(1), offset; cycle = cycle)

Palette(name::Union{String, Symbol}, n = 8; kwargs...) = Palette(to_colormap(name, n); kwargs...)

# add all methods that will be necessary to remove ambiguities
for s in [:(Key), :(Key{:color}), :(Key{:linestyle})]
    @eval convert_attribute(p::AbstractPalette, key::($s)) = _convert_attribute(p, key)
end
convert_attribute(p::AbstractPalette, m::Key{:marker}, s::Key{:scatter}) = _convert_attribute(p, m, s)

function convert_attribute(p::AbstractPalette)
    attr = p[]
    is_cycle(p) && forward!(p)
    attr
end

# Necessary to avoid dispatch issues: will be removed when above method becomes sufficient
_convert_attribute(p::AbstractPalette, args...) = convert_attribute(convert_attribute(p), args...)

function forward!(p::Palette, n = 1)
    (p.i[] = (p.i[]+n-1)%length(p)+1)
    p
end

freeze(p::Palette, offset = -1) = Palette(p.values, p.i, Int8(p.offset + offset), cycle = false)

reset(p::Palette) = Palette(p.values, cycle = p.cycle)

is_cycle(p::Palette) = p.cycle

Base.size(p::Palette) = Base.size(p.values)
Base.length(p::Palette) = Base.length(p.values)

Base.getindex(p::Palette, i=1) = p.values[(i+p.i[]+p.offset-2) % length(p)+1]
