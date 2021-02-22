@recipe(StemPlot) do scene
    Attributes(
        stemcolor = :black,
        stemcolormap = :viridis,
        stemcolorrange = automatic,
        stemwidth = 1,
        trunkwidth = 1,
        trunkcolor = :black,
        trunkcolormap = :viridis,
        trunkcolorrange = automatic,
        offset = 0,
        marker = :circle,
        markersize = 10,
        color = :gray65,
        colormap = :viridis,
        colorrange = automatic,
        strokecolor = :black,
        strokewidth = 1,
        visible = true,
    )
end


conversion_trait(::Type{<:StemPlot}) = PointBased()


trunkpoint(stempoint::P, offset::Number) where P <: Point2 = P(stempoint[1], offset)
trunkpoint(stempoint::P, offset::Point2) where P <: Point2 = P(offset...)
trunkpoint(stempoint::P, offset::Number) where P <: Point3 = P(stempoint[1], offset, offset)
trunkpoint(stempoint::P, offset::Point2) where P <: Point3 = P(stempoint[1], offset[1], offset[2])
trunkpoint(stempoint::P, offset::Point3) where P <: Point3 = P(offset...)


function plot!(sp::StemPlot{<:Tuple{<:AbstractVector{<:Point}}})
    points = sp[1]

    stemtuples = lift(points, sp.offset) do ps, to
        tuple.(ps, trunkpoint.(ps, to))
    end

    trunkpoints = @lift(last.($stemtuples))

    lines!(sp, trunkpoints,
        linewidth = sp.trunkwidth,
        color = sp.trunkcolor,
        colormap = sp.trunkcolormap,
        colorrange = sp.trunkcolorrange,
        visible = sp.visible)
    linesegments!(sp, stemtuples,
        linewidth = sp.stemwidth,
        color = sp.stemcolor,
        colormap = sp.stemcolormap,
        colorrange = sp.stemcolorrange,
        visible = sp.visible)
    scatter!(sp, sp[1],
        color = sp.color,
        colormap = sp.colormap,
        colorrange = sp.colorrange,
        markersize = sp.markersize,
        marker = sp.marker,
        strokecolor = sp.strokecolor,
        strokewidth = sp.strokewidth,
        visible = sp.visible)
    sp
end
