#######
## Shared conversions for attributes!
# attribute at with "name" will be converted by convert_attribute(x, key"name")
# The backend will call this, to "normalize" attributes to common types.
# The plan for the future is to move away from:
# scatter(colormap = :viridis, colorrange = (0, 1))
# To e.g.:
# scatter(color = sampler(:viridis, (0, 1)))
# There should always only be one attribute name per feature!
# We can then, on top of that, still go back to adding super short
# attributes as part of a lazy API (e.g. scatter(c=(:viridis, 0, 1)), or whatever)
#
########

"""
    to_color(color)

Converts a `color` symbol (e.g. `:blue`) to a color RGBA.
"""
to_color(color) = convert_attribute(color, key"color"())

"""
    to_colormap(cm[, N = 20])

Converts a colormap `cm` symbol (e.g. `:Spectral`) to a colormap RGB array, where `N` specifies the number of color points.
"""
to_colormap(color) = convert_attribute(color, key"colormap"())
to_rotation(color) = convert_attribute(color, key"rotation"())
to_font(color) = convert_attribute(color, key"font"())
to_align(color) = convert_attribute(color, key"align"())
to_textsize(color) = convert_attribute(color, key"textsize"())

convert_attribute(x, key::Key, ::Key) = convert_attribute(x, key)
convert_attribute(s::SceneLike, x, key::Key, ::Key) = convert_attribute(s, x, key)
convert_attribute(s::SceneLike, x, key::Key) = convert_attribute(x, key)
convert_attribute(x, key::Key) = x

struct Palette{N}
   colors::SArray{Tuple{N},RGBA{Float32},1,N}
   i::Ref{UInt8}
   Palette(colors) = new{length(colors)}(SVector{length(colors)}(to_color.(colors)), zero(UInt8))
end

Palette(name::Union{String, Symbol}, n=8) = Palette(to_colormap(name, n))

function convert_attribute(p::Palette{N}, ::key"color") where {N}
    p.i[] = p.i[] == N ? one(UInt8) : p.i[] + one(UInt8)
    p.colors[p.i[]]
end

convert_attribute(c::Colorant, ::key"color") = convert(RGBA{Float32}, c)
convert_attribute(c::Symbol, k::key"color") = convert_attribute(string(c), k)
function convert_attribute(c::String, ::key"color")
    c in all_gradient_names && return to_colormap(c)
    return parse(RGBA{Float32}, c)
end

# Do we really need all colors to be RGBAf0?!
convert_attribute(c::AbstractArray{<: Colorant}, k::key"color") = el32convert(c)
convert_attribute(c::AbstractArray{<: Union{Tuple{Any, Number}, Symbol}}, k::key"color") = to_color.(c)

convert_attribute(c::AbstractArray, ::key"color", ::key"heatmap") = el32convert(c)

convert_attribute(c::Tuple, k::key"color") = convert_attribute.(c, k)
function convert_attribute(c::Tuple{T, F}, k::key"color") where {T, F <: Number}
    RGBAf0(Colors.color(to_color(c[1])), c[2])
end
convert_attribute(c::Billboard, ::key"rotations") = Quaternionf0(0, 0, 0, 1)
convert_attribute(r::AbstractArray, ::key"rotations") = to_rotation.(r)
convert_attribute(r::StaticVector, ::key"rotations") = to_rotation(r)

convert_attribute(c, ::key"markersize", ::key"scatter") = to_2d_scale(c)
convert_attribute(c, k1::key"markersize", k2::key"meshscatter") = to_3d_scale(c)

to_2d_scale(x::Number) = Vec2f0(x)
to_2d_scale(x::VecTypes) = to_ndim(Vec2f0, x, 1)
to_2d_scale(x::Tuple{<:Number, <:Number}) = to_ndim(Vec2f0, x, 1)
to_2d_scale(x::AbstractVector) = to_2d_scale.(x)

to_3d_scale(x::Number) = Vec3f0(x)
to_3d_scale(x::VecTypes) = to_ndim(Vec3f0, x, 1)
to_3d_scale(x::AbstractVector) = to_3d_scale.(x)

convert_attribute(c::Number, ::key"glowwidth") = Float32(c)
convert_attribute(c, ::key"glowcolor") = to_color(c)
convert_attribute(c, ::key"strokecolor") = to_color(c)
convert_attribute(c::Number, ::key"strokewidth") = Float32(c)

convert_attribute(x::Nothing, ::key"linestyle") = x

"""
    `AbstractVector{<:AbstractFloat}` for denoting sequences of fill/nofill. e.g.

[0.5, 0.8, 1.2] will result in 0.5 filled, 0.3 unfilled, 0.4 filled. 1.0 unit is one linewidth!
"""
convert_attribute(A::AbstractVector, ::key"linestyle") = A

"""
    A `Symbol` equal to `:dash`, `:dot`, `:dashdot`, `:dashdotdot`
"""
function convert_attribute(ls::Symbol, ::key"linestyle")
    return if ls == :dash
        [0.0, 1.0, 2.0, 3.0, 4.0]
    elseif ls == :dot
        tick, gap = 1/2, 1/4
        [0.0, tick, tick+gap, 2tick+gap, 2tick+2gap]
    elseif ls == :dashdot
        dtick, dgap = 1.0, 1.0
        ptick, pgap = 1/2, 1/4
        [0.0, dtick, dtick+dgap, dtick+dgap+ptick, dtick+dgap+ptick+pgap]
    elseif ls == :dashdotdot
        dtick, dgap = 1.0, 1.0
        ptick, pgap = 1/2, 1/4
        [0.0, dtick, dtick+dgap, dtick+dgap+ptick, dtick+dgap+ptick+pgap, dtick+dgap+ptick+pgap+ptick,  dtick+dgap+ptick+pgap+ptick+pgap]
    else
        error("Unkown line style: $ls. Available: :dash, :dot, :dashdot, :dashdotdot or a sequence of numbers enumerating the next transparent/opaque region")
    end
end

function convert_attribute(f::Symbol, ::key"frames")
    f == :box && return ((true, true), (true, true))
    f == :semi && return ((true, false), (true, false))
    f == :none && return ((false, false), (false, false))
    throw(MethodError("$(string(f)) is not a valid framestyle. Options are `:box`, `:semi` and `:none`"))
end
convert_attribute(f::Tuple{Tuple{Bool,Bool},Tuple{Bool,Bool}}, ::key"frames") = f

convert_attribute(c::Tuple{<: Number, <: Number}, ::key"position") = Point2f0(c[1], c[2])
convert_attribute(c::Tuple{<: Number, <: Number, <: Number}, ::key"position") = Point3f0(c)
convert_attribute(c::VecTypes{N}, ::key"position") where N = Point{N, Float32}(c)

"""
    Text align, e.g.:
"""
convert_attribute(x::Tuple{Symbol, Symbol}, ::key"align") = Vec2f0(alignment2num.(x))
convert_attribute(x::Vec2f0, ::key"align") = x
const _font_cache = Dict{String, NativeFont}()

"""
    font conversion

a string naming a font, e.g. helvetica
"""
function convert_attribute(x::Union{Symbol, String}, k::key"font")
    str = string(x)
    get!(_font_cache, str) do
        str == "default" && return to_font("Dejavu Sans")
        fontpath = joinpath(@__DIR__, "..", "assets", "fonts")
        font = FreeTypeAbstraction.findfont(str; additional_fonts=fontpath)
        if font === nothing
            @warn("Could not find font $str, using Dejavu Sans")
            if "dejavu sans" == lowercase(str)
                # since we fall back to dejavu sans, we need to check for recursion
                error("recursion, font path seems to not contain dejavu sans: $fontpath")
            end
            return to_font("dejavu sans")
        end
        return font
    end
end
convert_attribute(x::Vector{String}, k::key"font") = convert_attribute.(x, k)
convert_attribute(x::NativeFont, k::key"font") = x

"""
    rotation accepts:
    to_rotation(b, quaternion)
    to_rotation(b, tuple_float)
    to_rotation(b, vec4)
"""
convert_attribute(s::Quaternion, ::key"rotation") = s
function convert_attribute(s::VecTypes{N}, ::key"rotation") where N
    if N == 4
        Quaternionf0(s...)
    elseif N == 3
        rotation_between(Vec3f0(0, 0, 1), to_ndim(Vec3f0, s, 0.0))
    elseif N == 2

        rotation_between(Vec3f0(0, 1, 0), to_ndim(Vec3f0, s, 0.0))
    else
        error("$N dimensional vector $s can't be converted to a rotation")
    end
end

function convert_attribute(s::Tuple{VecTypes, AbstractFloat}, ::key"rotation")
    qrotation(to_ndim(Vec3f0, s[1], 0.0), s[2])
end
convert_attribute(angle::AbstractFloat, ::key"rotation") = qrotation(Vec3f0(0, 0, 1), Float32(angle))
convert_attribute(r::AbstractVector, k::key"rotation") = to_rotation.(r)
convert_attribute(r::AbstractVector{<: Quaternionf0}, k::key"rotation") = r



convert_attribute(x, k::key"colorrange") = x==nothing ? nothing : Vec2f0(x)

convert_attribute(x, k::key"textsize") = Float32(x)
convert_attribute(x::AbstractVector{T}, k::key"textsize") where T <: Number = el32convert(x)
convert_attribute(x::AbstractVector{T}, k::key"textsize") where T <: VecTypes = elconvert(Vec2f0, x)
convert_attribute(x, k::key"linewidth") = Float32(x)
convert_attribute(x::AbstractVector, k::key"linewidth") = el32convert(x)

# ColorBrewer colormaps that support only 8 colors require special handling on the backend, so we show them here.
const colorbrewer_8color_names = String.([
    :Accent,
    :Dark2,
    :Pastel2,
    :Set2
])

# throw an error i
const plotutils_names = PlotUtils.clibraries() .|> PlotUtils.cgradients |> x -> vcat(x...) .|> String

const all_gradient_names = Set(vcat(plotutils_names, colorbrewer_8color_names))

"""
    available_gradients()

Prints all available gradient names.
"""
function available_gradients()
    println("Gradient Symbol/Strings:")
    for name in sort(collect(all_gradient_names))
        println("    ", name)
    end
end

"""
Reverses the attribute T upon conversion
"""
struct Reverse{T}
    data::T
end

function convert_attribute(r::Reverse, ::key"colormap", n::Integer=20)
    reverse(to_colormap(r.data, n))
end

function convert_attribute(cs::ColorScheme, ::key"colormap", n::Integer=20)
    return to_colormap(cs.colors, n)
end

"""
    to_colormap(b, x)

An `AbstractVector{T}` with any object that [`to_color`](@ref) accepts.
"""
convert_attribute(cm::AbstractVector, ::key"colormap", n::Int=length(cm)) = to_colormap(to_color.(cm), n)

function convert_attribute(cm::AbstractVector{<: Colorant}, ::key"colormap", n::Int=length(cm))
    colormap = length(cm) == n ? cm : resample(cm, n)
    return el32convert(colormap)
end

"""
Tuple(A, B) or Pair{A, B} with any object that [`to_color`](@ref) accepts
"""
function convert_attribute(cs::Union{Tuple, Pair}, ::key"colormap", n::Int=2)
    return to_colormap([to_color.(cs)...], n)
end

to_colormap(x, n::Integer) = convert_attribute(x, key"colormap"(), n)

"""
A Symbol/String naming the gradient. For more on what names are available please see: `available_gradients()`.
For now, we support gradients from `PlotUtils` natively.
"""
function convert_attribute(cs::Union{String, Symbol}, ::key"colormap", n::Integer=20)
    cs_string = string(cs)
    if cs_string in all_gradient_names
        if cs_string in colorbrewer_8color_names # special handling for 8 color only
            return to_colormap(ColorBrewer.palette(cs_string, 8), n)
        else                                    # cs_string must be in plotutils_names
            return RGBf0.(PlotUtils.cvec(Symbol(cs), n))
        end
    else
        error("There is no color gradient named: $cs")
    end
end

function AbstractPlotting.convert_attribute(cg::PlotUtils.ColorGradient, ::key"colormap", n::Integer=length(cg.values))
    # PlotUtils does not always give [0, 1] range, so we adapt to what it has
    return getindex.(Ref(cg), LinRange(first(cg.values), last(cg.values), n)) # workaround until PlotUtils tags a release
    # TODO change this once PlotUtils supports collections of indices
end


"""
    to_volume_algorithm(b, x)

Enum values: `IsoValue` `Absorption` `MaximumIntensityProjection` `AbsorptionRGBA` `IndexedAbsorptionRGBA`
"""
function convert_attribute(value, ::key"algorithm")
    if isa(value, RaymarchAlgorithm)
        return Int32(value)
    elseif isa(value, Int32) && value in 0:5
        return value
    elseif value == 7
        return value # makie internal contour implementation
    else
        error("$value is not a valid volume algorithm. Please have a look at the documentation of `to_volume_algorithm`")
    end
end

"""
Symbol/String: iso, absorption, mip, absorptionrgba, indexedabsorption
"""
function convert_attribute(value::Union{Symbol, String}, k::key"algorithm")
    vals = Dict(
        :iso => IsoValue,
        :absorption => Absorption,
        :mip => MaximumIntensityProjection,
        :absorptionrgba => AbsorptionRGBA,
        :indexedabsorption => IndexedAbsorptionRGBA,
    )
    algorithm = get(vals, Symbol(value)) do
        error("$value not a valid volume algorithm. Needs to be in $(keys(vals))")
    end
    return convert_attribute(algorithm, k)
end

const _marker_map = Dict(
    :rect => '■',
    :star5 => '★',
    :diamond => '◆',
    :hexagon => '⬢',
    :cross => '✚',
    :xcross => '❌',
    :utriangle => '▲',
    :dtriangle => '▼',
    :ltriangle => '◀',
    :rtriangle => '▶',
    :pentagon => '⬟',
    :octagon => '⯄',
    :star4 => '✦',
    :star6 => '🟋',
    :star8 => '✷',
    :vline => '┃',
    :hline => '━',
    :+ => '+',
    :x => 'x',
    :circle => '●'
)


"""
    available_marker_symbols()

Displays all available marker symbols.
"""
function available_marker_symbols()
    println("Marker Symbols:")
    for (k, v) in _marker_map
        println("    ", k, " => ", v)
    end
end



"""
    to_spritemarker(b, x::Circle)

`GeometryTypes.Circle(Point2(...), radius)`
"""
to_spritemarker(x::Circle) = x

"""
    to_spritemarker(b, ::Type{Circle})

`Type{GeometryTypes.Circle}`
"""
to_spritemarker(::Type{<: Circle}) = Circle(Point2f0(0), 1f0)
"""
    to_spritemarker(b, ::Type{Rectangle})

`Type{GeometryTypes.Rectangle}`
"""
to_spritemarker(::Type{<: Rectangle}) = HyperRectangle(Vec2f0(0), Vec2f0(1))
to_spritemarker(::Type{<: Rect}) = HyperRectangle(Vec2f0(0), Vec2f0(1))
to_spritemarker(x::HyperRectangle) = x
"""
    to_spritemarker(b, marker::Char)

Any `Char`, including unicode
"""
to_spritemarker(marker::Char) = marker

"""
Matrix of AbstractFloat will be interpreted as a distancefield (negative numbers outside shape, positive inside)
"""
to_spritemarker(marker::Matrix{<: AbstractFloat}) = el32convert(marker)

"""
Any AbstractMatrix{<: Colorant} or other image type
"""
to_spritemarker(marker::AbstractMatrix{<: Colorant}) = marker

"""
A `Symbol` - Available options can be printed with `available_marker_symbols()`
"""
function to_spritemarker(marker::Symbol)
    if haskey(_marker_map, marker)
        return to_spritemarker(_marker_map[marker])
    else
        @warn("Unsupported marker: $marker, using ● instead")
        return '●'
    end
end


to_spritemarker(marker::String) = marker
to_spritemarker(marker::AbstractVector{Char}) = String(marker)

"""
Vector of anything that is accepted as a single marker will give each point it's own marker.
Note that it needs to be a uniform vector with the same element type!
"""
function to_spritemarker(marker::AbstractVector)
    marker = to_spritemarker.(marker)
    if isa(marker, AbstractVector{Char})
        String(marker)
    else
        marker
    end
end

convert_attribute(value, ::key"marker", ::key"scatter") = to_spritemarker(value)
convert_attribute(value, ::key"isovalue", ::key"volume") = Float32(value)
convert_attribute(value, ::key"isorange", ::key"volume") = Float32(value)
