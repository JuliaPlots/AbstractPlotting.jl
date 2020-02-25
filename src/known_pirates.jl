# I don't have time to move everything to their correct repositories right now
# So I just move any pirate I encounter here for easier clean up later!

################################################################################
# Needs moving to GeometryTypes.jl
# See: https://github.com/JuliaGeometry/GeometryTypes.jl/pull/166 for a start!

const Rect{N, T} = HyperRectangle{N, T}
const Rect2D{T} = HyperRectangle{2, T}
const FRect2D = Rect2D{Float32}

"A generic, three dimensional rectangle."
const Rect3D{T} = Rect{3, T}

"An float valued, three dimensional rectangle."
const FRect3D = Rect3D{Float32}

"An integer valued, three dimensional rectangle."
const IRect3D = Rect3D{Int}

"An integer valued, two dimensional rectangle."
const IRect2D = Rect2D{Int}


"""
    IRect(x, y, w, h)

Creates a two dimensional rectangle of integer dimensions, at origin (x, y)
and with width w and height h
"""
function IRect(x, y, w, h)
    HyperRectangle{2, Int}(Vec(round(Int, x), round(Int, y)), Vec(round(Int, w), round(Int, h)))
end

"""
    IRect(xy::VecTypes, w, h)

Creates a two dimensional rectangle of integer dimensions, with origin
at vector xy, and with width w and height h
"""
function IRect(xy::VecTypes, w, h)
    IRect(xy[1], xy[2], w, h)
end

"""
    IRect(x, y, wh::VecTypes)

Creates a two dimensional rectangle of integer dimensions, with origin
at (x, y), and with width and height as the respective components of vector wh
"""
function IRect(x, y, wh::VecTypes)
    IRect(x, y, wh[1], wh[2])
end

"""
    IRect(xy::VecTypes, wh::VecTypes)

Creates a two dimensional rectangle of integer dimensions, with origin
at vector xy, and with width and height as the respective components of vector wh
"""
function IRect(xy::VecTypes, wh::VecTypes)
    IRect(xy[1], xy[2], wh[1], wh[2])
end

"""
    IRect(xy::NamedTuple{(:x, :y)}, wh::NamedTuple{(:width, :height)})

This takes two named tuples and constructs an integer valued rectangle with them.
"""
function IRect(xy::NamedTuple{(:x, :y)}, wh::NamedTuple{(:width, :height)})
    IRect(xy.x, xy.y, wh.width, wh.height)
end

function positive_widths(rect::HyperRectangle{N, T}) where {N, T}
    mini, maxi = minimum(rect), maximum(rect)
    realmin = min.(mini, maxi)
    realmax = max.(mini, maxi)
    HyperRectangle{N, T}(realmin, realmax .- realmin)
end

"""
    FRect(x, y, w, h)

Creates a two dimensional rectangle, at origin (x, y)
and with width w and height h.  Formally defined as the
Cartesian product of the intervals (x, y) and (w, h).
"""
function FRect(x, y, w, h)
    HyperRectangle{2, Float32}(Vec2f0(x, y), Vec2f0(w, h))
end
function FRect(r::SimpleRectangle)
    FRect(r.x, r.y, r.w, r.h)
end
function FRect(r::Rect)
    FRect(minimum(r), widths(r))
end
function FRect(xy::VecTypes, w, h)
    FRect(xy[1], xy[2], w, h)
end
function FRect(x, y, wh::VecTypes)
    FRect(x, y, wh[1], wh[2])
end
function FRect(xy::VecTypes, wh::VecTypes)
    FRect(xy[1], xy[2], wh[1], wh[2])
end

function FRect3D(x::Tuple{Tuple{<: Number, <: Number}, Tuple{<: Number, <: Number}})
    FRect3D(Vec3f0(x[1]..., 0), Vec3f0(x[2]..., 0))
end
function FRect3D(x::Tuple{Tuple{<: Number, <: Number, <: Number}, Tuple{<: Number, <: Number, <: Number}})
    FRect3D(Vec3f0(x[1]...), Vec3f0(x[2]...))
end

function FRect3D(x::Rect2D)
    FRect3D(Vec3f0(minimum(x)..., 0), Vec3f0(widths(x)..., 0.0))
end
