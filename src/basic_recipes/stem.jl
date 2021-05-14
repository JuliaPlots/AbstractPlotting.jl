"""
    stem(xs, ys, [zs]; kwargs...)

Plots markers at the given positions extending from `offset` along stem lines.

`offset` can be a number, in which case it sets y for 2D, and z for 3D stems.
It can be a Point2 for 2D plots, as well as a Point3 for 3D plots.
It can also be an iterable of any of these at the same length as xs, ys, zs.

The conversion trait of stem is `PointBased`.

## Attributes
$(ATTRIBUTES)
"""
@recipe(Stem) do scene
    Attributes(
        stemcolor = :black,
        stemcolormap = theme(scene, :colormap),
        stemcolorrange = automatic,
        stemwidth = 1,
        stemlinestyle = nothing,
        trunkwidth = 1,
        trunklinestyle = nothing,
        trunkcolor = :black,
        trunkcolormap = theme(scene, :colormap),
        trunkcolorrange = automatic,
        offset = 0,
        marker = :circle,
        markersize = 10,
        color = :gray65,
        colormap = theme(scene, :colormap),
        colorrange = automatic,
        strokecolor = :black,
        strokewidth = 1,
        visible = true,
        inspectable = theme(scene, :inspectable)
    )
end


conversion_trait(::Type{<:Stem}) = PointBased()


trunkpoint(stempoint::P, offset::Number) where P <: Point2 = P(stempoint[1], offset)
trunkpoint(stempoint::P, offset::Point2) where P <: Point2 = P(offset...)
trunkpoint(stempoint::P, offset::Number) where P <: Point3 = P(stempoint[1], stempoint[2], offset)
trunkpoint(stempoint::P, offset::Point3) where P <: Point3 = P(offset...)


function plot!(s::Stem{<:Tuple{<:AbstractVector{<:Point}}})
    points = s[1]

    stemtuples = lift(points, s.offset) do ps, to
        tuple.(ps, trunkpoint.(ps, to))
    end

    trunkpoints = @lift(last.($stemtuples))

    lines!(s, trunkpoints,
        linewidth = s.trunkwidth,
        color = s.trunkcolor,
        colormap = s.trunkcolormap,
        colorrange = s.trunkcolorrange,
        visible = s.visible,
        linestyle = s.trunklinestyle,
        inspectable = s.inspectable)
    linesegments!(s, stemtuples,
        linewidth = s.stemwidth,
        color = s.stemcolor,
        colormap = s.stemcolormap,
        colorrange = s.stemcolorrange,
        visible = s.visible,
        linestyle = s.stemlinestyle,
        inspectable = s.inspectable)
    scatter!(s, s[1],
        color = s.color,
        colormap = s.colormap,
        colorrange = s.colorrange,
        markersize = s.markersize,
        marker = s.marker,
        strokecolor = s.strokecolor,
        strokewidth = s.strokewidth,
        visible = s.visible,
        inspectable = s.inspectable)
    s
end
