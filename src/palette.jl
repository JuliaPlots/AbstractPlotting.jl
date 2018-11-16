abstract type AbstractPalette{S} <: AbstractVector{S} end

struct Palette{S, T<:AbstractVector{S}} <: AbstractPalette{S}
   values::T
   i::Ref{UInt8}
   cycle::Bool
   Palette(values::T; cycle = true) where {T<:AbstractVector} =
       new{eltype(T), T}(values, Ref{UInt8}(1), cycle)
end

Palette(name::Union{String, Symbol}, n = 8; kwargs...) = Palette(to_colormap(name, n); kwargs...)

# add all methods that will be necessary to remove ambiguities
for s in [:(Key), :(Key{:color}), :(Key{:linestyle})]
    @eval convert_attribute(p::AbstractPalette, key::($s)) = convert_palette(p, key)
end

convert_attribute(p::AbstractPalette, m::Key{:marker}, s::Key{:scatter}) = convert_palette(p, m, s)

function convert_palette(p::AbstractPalette, args...)
    attr = convert_attribute(p[], args...)
    is_cycle(p) && forward!(p)
    attr
end

function forward!(p::Palette, n = 1)
    (p.i[] = (p.i[]+n-1)%length(p)+1)
    p
end

function freeze(p::Palette)
    f = Palette(p.values, cycle = false)
    f.i[] = p.i[]
    f
end

reset(p::Palette) = Palette(p.values, cycle = p.cycle)

is_cycle(p::Palette) = p.cycle

Base.size(p::Palette) = Base.size(p.values)

Base.getindex(p::Palette, i) = p.values[(i+p.i[]-2) % length(p)+1]

Base.getindex(p::Palette) = p.values[p.i[]]
