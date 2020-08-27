"""
    poly(vertices, indices; kwargs...)
    poly(points; kwargs...)
    poly(shape; kwargs...)
    poly(mesh; kwargs...)

Plots a polygon based on the arguments given.
When vertices and indices are given, it functions similarly to `mesh`.
When points are given, it draws one polygon that connects all the points in order.
When a shape is given (essentially anything decomposable by `GeometryBasics`), it will plot `decompose(shape)`.

    poly(coordinates, connectivity; kwargs...)

Plots polygons, which are defined by
`coordinates` (the coordinates of the vertices) and
`connectivity` (the edges between the vertices).

## Attributes
$(ATTRIBUTES)
"""
@recipe(Poly) do scene
    Attributes(;
        color = theme(scene, :color),
        visible = theme(scene, :visible),
        strokecolor = RGBAf0(0,0,0,0),
        colormap = theme(scene, :colormap),
        colorrange = automatic,
        strokewidth = 1.0,
        shading = false,
        # we turn this false for now, since otherwise shapes look transparent
        # since we use meshes, which are drawn into a different framebuffer because of fxaa
        # if we use fxaa=false, they're drawn into the same
        # TODO, I still think this is a bug, since they should still use the same depth buffer!
        fxaa = false,
        linestyle = nothing,
        overdraw = false,
        transparency = false,
    )
end

const PolyElements = Union{Polygon, MultiPolygon, Circle, Rect, AbstractMesh, VecTypes, AbstractVector{<:VecTypes}}

convert_arguments(::Type{<: Poly}, v::AbstractVector{<: PolyElements}) = (v,)
convert_arguments(::Type{<: Poly}, v::Union{Polygon, MultiPolygon}) = (v,)

convert_arguments(::Type{<: Poly}, args...) = ([convert_arguments(Scatter, args...)[1]],)
convert_arguments(::Type{<: Poly}, vertices::AbstractArray, indices::AbstractArray) = convert_arguments(Mesh, vertices, indices)

function plot!(plot::Poly{<: Tuple{Union{AbstractMesh, GeometryPrimitive}}})
    mesh!(
        plot, plot[1],
        color = plot[:color], colormap = plot[:colormap], colorrange = plot[:colorrange],
        shading = plot[:shading], visible = plot[:visible], overdraw = plot[:overdraw]
    )
    wireframe!(
        plot, plot[1],
        color = plot[:strokecolor], linestyle = plot[:linestyle],
        linewidth = plot[:strokewidth], visible = plot[:visible], overdraw = plot[:overdraw]
    )
end

# Poly conversion
poly_convert(geometries) = triangle_mesh.(geometries)
poly_convert(meshes::AbstractVector{<:AbstractMesh}) = meshes
poly_convert(polys::AbstractVector{<:Polygon}) = triangle_mesh.(polys)
function poly_convert(multipolygons::AbstractVector{<:MultiPolygon})
    return [merge(triangle_mesh.(multipoly.polygons)) for multipoly in multipolygons]
end

poly_convert(polygon::Polygon) = triangle_mesh(polygon)

function poly_convert(polygon::AbstractVector{<: VecTypes})
    return poly_convert([convert_arguments(Scatter, polygon)[1]])
end

function poly_convert(polygons::AbstractVector{<: AbstractVector{<: VecTypes}})
    return map(polygons) do poly
        s = GeometryBasics.split_intersections(poly)
        merge(triangle_mesh.(Polygon.(s)))
    end
end

to_line_segments(polygon) = convert_arguments(PointBased(), polygon)[1]

function to_line_segments(meshes::AbstractVector)
    line = Point2f0[]
    for (i, mesh) in enumerate(meshes)
        points = to_line_segments(mesh)
        append!(line, points)
        # push!(line, points[1])
        # dont need to separate the last line segment
        if i != length(meshes)
            push!(line, Point2f0(NaN))
        end
    end
    return line
end

function to_line_segments(polygon::AbstractVector{<: VecTypes})
    result = Point2f0.(polygon)
    push!(result, polygon[1])
    return result
end

function plot!(plot::Poly{<: Tuple{<: Union{Polygon, AbstractVector{<: PolyElements}}}})
    geometries = plot[1]
    meshes = lift(poly_convert, geometries)
    mesh!(plot, meshes;
        visible = plot.visible,
        shading = plot.shading,
        color = plot.color,
        colormap = plot.colormap,
        colorrange = plot.colorrange,
        overdraw = plot.overdraw,
        fxaa = plot.fxaa,
        transparency = plot.transparency
    )
    outline = lift(to_line_segments, geometries)
    lines!(
        plot, outline, visible = plot.visible,
        color = plot.strokecolor, linestyle = plot.linestyle,
        linewidth = plot.strokewidth,
        overdraw = plot.overdraw, transparency = plot.transparency
    )
end

function plot!(plot::Mesh{<: Tuple{<: AbstractVector{P}}}) where P <: Union{AbstractMesh, Polygon}
    meshes = plot[1]
    color_node = plot.color
    attributes = Attributes(visible = plot.visible, shading = plot.shading, fxaa=plot.fxaa)

    attributes[:colormap] = get(plot, :colormap, nothing)
    attributes[:colorrange] = get(plot, :colorrange, nothing)

    bigmesh = if color_node[] isa AbstractVector && length(color_node[]) == length(meshes[])
        # One color per mesh
        real_colors = Observable(RGBAf0[])
        attributes[:color] = real_colors
        lift(meshes, color_node, attributes.colormap, attributes.colorrange) do meshes, colors, cmap, crange
            # Color are reals, so we need to transform it to colors first
            single_colors = if colors isa AbstractVector{<:Number}
                interpolated_getindex.((to_colormap(cmap),), colors, (crange,))
            else
                to_color.(colors)
            end
            empty!(real_colors[])

            # Map one single color per mesh to each vertex
            for (mesh, color) in zip(meshes, single_colors)
                append!(real_colors[], Iterators.repeated(RGBAf0(color), length(coordinates(mesh))))
            end
            real_colors[] = real_colors[]
            if P <: AbstractPolygon
                meshes = triangle_mesh.(meshes)
            end
            return merge(meshes)
        end
    else
        attributes[:color] = color_node
        lift(meshes) do meshes
            return merge(GeometryBasics.mesh.(meshes))
        end
    end
    mesh!(plot, attributes, bigmesh)
end


"""
    arrows(points, directions; kwargs...)
    arrows(x, y, u, v)
    arrows(x::AbstractVector, y::AbstractVector, u::AbstractMatrix, v::AbstractMatrix)
    arrows(x, y, z, u, v, w)

Plots arrows at the specified points with the specified components.
`u` and `v` are interpreted as vector components (`u` being the x
and `v` being the y), and the vectors are plotted with the tails at
`x`, `y`.

If `x, y, u, v` are `<: AbstractVector`, then each 'row' is plotted
as a single vector.

If `u, v` are `<: AbstractMatrix`, then `x` and `y` are interpreted as
specifications for a grid, and `u, v` are plotted as arrows along the
grid.

`arrows` can also work in three dimensions.

## Attributes
$(ATTRIBUTES)
"""
@recipe(Arrows, points, directions) do scene
    theme = Attributes(
        arrowhead = automatic,
        arrowtail = nothing,
        linecolor = :black,
        linewidth = 1,
        arrowsize = 0.3,
        linestyle = nothing,
        scale = Vec3f0(1),
        normalize = false,
        lengthscale = 1.0f0
    )
    # connect arrow + linecolor by default
    get!(theme, :arrowcolor, theme[:linecolor])
    theme
end

# For the matlab/matplotlib users
const quiver = arrows
const quiver! = arrows!
export quiver, quiver!

arrow_head(N, marker) = marker
arrow_head(N, marker::Automatic) = N == 2 ? '▲' : Pyramid(Point3f0(0, 0, -0.5), 1f0, 1f0)

scatterfun(N) = N == 2 ? scatter! : meshscatter!


convert_arguments(::Type{<: Arrows}, x, y, u, v) = (Point2f0.(x, y), Vec2f0.(u, v))
function convert_arguments(::Type{<: Arrows}, x::AbstractVector, y::AbstractVector, u::AbstractMatrix, v::AbstractMatrix)
    (vec(Point2f0.(x, y')), vec(Vec2f0.(u, v)))
end
convert_arguments(::Type{<: Arrows}, x, y, z, u, v, w) = (Point3f0.(x, y, z), Vec3f0.(u, v, w))

function plot!(arrowplot::Arrows{<: Tuple{AbstractVector{<: Point{N, T}}, V}}) where {N, T, V}
    @extract arrowplot (points, directions, lengthscale, arrowhead, arrowsize, arrowcolor)
    headstart = lift(points, directions, lengthscale) do points, directions, s
        map(points, directions) do p1, dir
            dir = arrowplot[:normalize][] ? StaticArrays.normalize(dir) : dir
            Point{N, Float32}(p1) => Point{N, Float32}(p1 .+ (dir .* Float32(s)))
        end
    end
    linesegments!(
        arrowplot, headstart,
        color = arrowplot[:linecolor], linewidth = arrowplot[:linewidth],
        linestyle = arrowplot[:linestyle],
    )
    scatterfun(N)(
        arrowplot,
        lift(x-> last.(x), headstart),
        marker = lift(x-> arrow_head(N, x), arrowhead), markersize = arrowsize,
        color = arrowcolor, rotations = directions,  strokewidth = 0.0,
    )
end

"""
    wireframe(x, y, z)
    wireframe(positions)
    wireframe(mesh)

Draws a wireframe, either interpreted as a surface or as a mesh.

## Attributes
$(ATTRIBUTES)
"""
@recipe(Wireframe) do scene
    default_theme(scene, LineSegments)
end

function argument_conversion(::Type{Wireframe}, x::AbstractVector, y::AbstractVector, z::AbstractMatrix)
    (ngrid(x, y)..., z)
end

xvector(x::AbstractVector, len) = x
xvector(x::ClosedInterval, len) = range(minimum(x), stop=maximum(x), length=len)
xvector(x::AbstractMatrix, len) = x

yvector(x, len) = xvector(x, len)'
yvector(x::AbstractMatrix, len) = x

function plot!(plot::Wireframe{<: Tuple{<: Any, <: Any, <: AbstractMatrix}})
    points_faces = lift(plot[1:3]...) do x, y, z
        T = eltype(z); M, N = size(z)
        points = vec(Point3f0.(xvector(x, M), yvector(y, N), z))
        # Connect the vetices with faces, as one would use for a 2D Rectangle
        # grid with M,N grid points
        faces = decompose(LineFace{GLIndex}, Tesselation(Rect2D(0, 0, 1, 1), (M, N)))
        connect(points, faces)
    end
    linesegments!(plot, Attributes(plot), points_faces)
end


function plot!(plot::Wireframe{Tuple{T}}) where T
    points = lift(plot[1]) do g
        # get the point representation of the geometry
        indices = decompose(LineFace{GLIndex}, g)
        points = decompose(Point3f0, g)
        return connect(points, indices)
    end
    linesegments!(plot, Attributes(plot), points)
end

function sphere_streamline(linebuffer, ∇ˢf, pt, h, n)
    push!(linebuffer, pt)
    df = normalize(∇ˢf(pt[1], pt[2], pt[3]))
    push!(linebuffer, normalize(pt .+ h*df))
    for k=2:n
        cur_pt = last(linebuffer)
        push!(linebuffer, cur_pt)
        df = normalize(∇ˢf(cur_pt...))
        push!(linebuffer, normalize(cur_pt .+ h*df))
    end
    return
end

"""
    StreamLines

TODO add function signatures
TODO add descripton

## Attributes
$(ATTRIBUTES)
"""
@recipe(StreamLines, points, directions) do scene
    Attributes(
        h = 0.01f0,
        n = 5,
        color = :black,
        linewidth = 1
    )
end

"""
    Series - ?

TODO add function signatures
TODO add description

## Attributes
$(ATTRIBUTES)
"""
@recipe(Series, series) do scene
    Attributes(
        seriescolors = :Set1,
        seriestype = :lines
    )
end

convert_arguments(::Type{<: Series}, A::AbstractMatrix{<: Number}) = (A,)

function plot!(sub::Series)
    A = sub[1]
    colors = map_once(sub[:seriescolors], A) do colors, A
        cmap = to_colormap(colors)
        if size(A, 2) > length(cmap)
            @info("Colormap doesn't have enough distinctive values. Please consider using another value for seriescolors")
            cmap = interpolated_getindex.((cmap,), range(0, stop=1, length=M))
        end
        cmap
    end
    map_once(A, sub[:seriestype]) do A, stype
        empty!(sub.plots)
        N, M = size(A)
        for i = 1:M
            c = lift(getindex, colors, i)
            attributes = Attributes(color = c)
            a_view = view(A, :, i)
            if stype in (:lines, :scatter_lines)
                lines!(sub, attributes, a_view)
            end
            # if stype in (:scatter, :scatter_lines)
            #     scatter!(subsub, attributes, a_view)
            # end
            # subsub
        end
    end
    labels = get(sub, :labels) do
        map(i-> "y $i", 1:size(A[], 2))
    end
    legend!(sub, copy(sub.plots), labels)
    sub
end



"""
    annotations(strings::Vector{String}, positions::Vector{Point})

Plots an array of texts at each position in `positions`.

## Attributes
$(ATTRIBUTES)
"""
@recipe(Annotations, text, position) do scene
    default_theme(scene, Text)
end

function convert_arguments(::Type{<: Annotations},
                           strings::AbstractVector{<: AbstractString},
                           text_positions::AbstractVector{<: Point{N}}) where N
    return (map(strings, text_positions) do str, pos
        (String(str), Point{N, Float32}(pos))
    end,)
end

function plot!(plot::Annotations)
    sargs = (
        plot.model, plot.font,
        plot[1],
        getindex.(plot, (:color, :textsize, :align, :rotation, :justification, :lineheight))...,
    )
    atlas = get_texture_atlas()
    combinedpos = [Point3f0(0)]
    colors = RGBAf0[RGBAf0(0,0,0,0)]
    textsize = Float32[0]
    fonts = [defaultfont()]
    rotations = Quaternionf0[Quaternionf0(0,0,0,0)]

    tplot = text!(plot, " ",
        align = Vec2f0(0), model = Mat4f0(I),
        position = combinedpos, color = colors, visible = plot.visible,
        textsize = textsize, font = fonts, rotation = rotations
    ).plots[end]

    onany(sargs...) do model, pfonts, text_pos, args...
        io = IOBuffer();
        empty!(combinedpos); empty!(colors); empty!(textsize); empty!(fonts); empty!(rotations)
        broadcast_foreach(1:length(text_pos), to_font(pfonts), text_pos, args...) do idx, f,
                (text, startpos), color, tsize, alignment, rotation, justification, lineheight
            c = to_color(color)
            rot = to_rotation(rotation)
            pos = layout_text(text, startpos, tsize, f, alignment, rot, model, justification, lineheight)
            print(io, text)
            n = length(pos)
            append!(combinedpos, pos)
            append!(textsize, repeated(tsize, n))
            append!(colors, repeated(c, n))
            append!(fonts, one_attribute_per_char(f, text))
            append!(rotations, repeated(rot, n))
        end
        str = String(take!(io))
        # update string the signals
        tplot[1] = str
        return
    end
    # update one time in the beginning, since otherwise the above won't run
    notify!(sargs[1])
    plot
end

"""
    arc(origin, radius, start_angle, stop_angle; kwargs...)

This function plots a circular arc, centered at `origin` with radius `radius`,
from `start_angle` to `stop_angle`.
`origin` must be a coordinate in 2 dimensions (i.e., a `Point2`); the rest of the arguments must be
`<: Number`.

Examples:

`arc(Point2f0(0), 1, 0.0, π)`
`arc(Point2f0(1, 2), 0.3. π, -π)`

## Attributes
$(ATTRIBUTES)
"""
@recipe(Arc, origin, radius, start_angle, stop_angle) do scene
    Attributes(;
        default_theme(scene, Lines)...,
        resolution = 361,
    )
end

function plot!(p::Arc)
    args = getindex.(p, (:origin, :radius, :start_angle, :stop_angle, :resolution))
    positions = lift(args...) do origin, radius, start_angle, stop_angle, resolution
        map(range(start_angle, stop=stop_angle, length=resolution)) do angle
            origin .+ Point2f0((cos(angle), sin(angle)) .* radius)
        end
    end
    lines!(p, Attributes(p), positions)
end



function AbstractPlotting.plot!(plot::Plot(AbstractVector{<: Complex}))
    plot[:axis, :labels] = ("Re(x)", "Im(x)")
    lines!(plot, lift(im-> Point2f0.(real.(im), imag.(im)), x[1]))
end

"""
    barplot(x, y; kwargs...)

Plots a barplot; `y` defines the height.  `x` and `y` should be 1 dimensional.

## Attributes
$(ATTRIBUTES)
"""
@recipe(BarPlot, x, y) do scene
    Attributes(;
        fillto = 0.0,
        color = theme(scene, :color),
        colormap = theme(scene, :colormap),
        colorrange = automatic,
        marker = Rect,
        strokewidth = 0,
        strokecolor = :white,
        width = automatic,
        direction = :y,
    )
end

conversion_trait(::Type{<: BarPlot}) = PointBased()

function bar_rectangle(xy, width, fillto)
    x, y = xy
    # y could be smaller than fillto...
    ymin = min(fillto, y)
    ymax = max(fillto, y)
    w = abs(width)
    return FRect(x - (w / 2f0), ymin, w, ymax - ymin)
end

flip(r::Rect2D) = Rect2D(reverse(origin(r)), reverse(widths(r)))

function AbstractPlotting.plot!(p::BarPlot)

    in_y_direction = lift(p.direction) do dir
        if dir == :y
            true
        elseif dir == :x
            false
        else
            error("Invalid direction $dir. Options are :x and :y.")
        end
    end

    bars = lift(p[1], p.fillto, p.width, in_y_direction) do xy, fillto, width, in_y_direction
        # compute half-width of bars
        if width === automatic
            # times 0.8 for default gap
            width = mean(diff(first.(xy))) * 0.8 # TODO ignore nan?
        end

        rects = bar_rectangle.(xy, width, fillto)
        return in_y_direction ? rects : flip.(rects)
    end

    poly!(
        p, bars, color = p.color, colormap = p.colormap, colorrange = p.colorrange,
        strokewidth = p.strokewidth, strokecolor = p.strokecolor
    )
end

"""
    scatterlines(xs, ys, [zs]; kwargs...)

Plots `lines` between sets of x and y coordinates provided,
as well as plotting those points using `scatter`.

## Attributes
$(ATTRIBUTES)
"""
@recipe(ScatterLines) do scene
    merge(default_theme(scene, Scatter), default_theme(scene, Lines))
end

function plot!(p::Combined{scatterlines, <:NTuple{N, Any}}) where N
    plot!(p, Lines, Attributes(p), p[1:N]...)
    plot!(p, Scatter, Attributes(p), p[1:N]...)
end


"""
    band(x, ylower, yupper; kwargs...)
    band(lower, upper; kwargs...)

Plots a band from `ylower` to `yupper` along `x`.

## Attributes
$(ATTRIBUTES)
"""
@recipe(Band, lowerpoints, upperpoints) do scene
    Attributes(;
        default_theme(scene, Mesh)...,
        colorrange = automatic,
        color = RGBAf0(0.0,0,0,0.2)
    )
end

convert_arguments(::Type{<: Band}, x, ylower, yupper) = (Point2f0.(x, ylower), Point2f0.(x, yupper))

function band_connect(n)
    ns = 1:n-1
    ns2 = n+1:2n-1
    [GLTriangleFace.(ns, ns .+ 1, ns2); GLTriangleFace.(ns .+ 1, ns2 .+ 1, ns2)]
end

function plot!(plot::Band)
    @extract plot (lowerpoints, upperpoints)
    @lift(@assert length($lowerpoints) == length($upperpoints) "length of lower band is not equal to length of upper band!")
    coordinates = @lift([$lowerpoints; $upperpoints])
    connectivity = lift(x -> band_connect(length(x)), plot[1])
    mesh!(plot, coordinates, connectivity;
        color = plot[:color], colormap = plot[:colormap],
        colorrange = plot[:colorrange],
        shading = false, visible = plot[:visible]
    )
end


function fill_view(x, y1, y2, where::Nothing)
  x, y1, y2
end
function fill_view(x, y1, y2, where::Function)
  fill_view(x, y1, y2, where.(x, y1, y2))
end
function fill_view(x, y1, y2, bools::AbstractVector{<: Union{Integer, Bool}})
  view(x, bools), view(y1, bools), view(y2, bools)
end

"""
    fill_between!(x, y1, y2; where = nothing, scene = current_scene(), kw_args...)

fill the section between 2 lines with the condition `where`
"""
function fill_between!(x, y1, y2; where = nothing, scene = current_scene(), kw_args...)
  xv, ylow, yhigh = fill_view(x, y1, y2, where)
  band!(scene, xv, ylow, yhigh; kw_args...)
end

export fill_between!

"""
    contour(x, y, z)

Creates a contour plot of the plane spanning x::Vector, y::Vector, z::Matrix

## Attributes
$(ATTRIBUTES)
"""
@recipe(Contour) do scene
    default = default_theme(scene)
    pop!(default, :color)
    Attributes(;
        default...,
        color = nothing,
        colormap = theme(scene, :colormap),
        colorrange = AbstractPlotting.automatic,
        levels = 5,
        linewidth = 1.0,
        alpha = 1.0,
        fillrange = false,
    )
end

"""
    contour3d(x, y, z)

Creates a 3D contour plot of the plane spanning x::Vector, y::Vector, z::Matrix,
with z-elevation for each level.

## Attributes
$(ATTRIBUTES)
"""
@recipe(Contour3d) do scene
    default_theme(scene, Contour)
end

function contourlines(::Type{<: Contour}, contours, cols)
    result = Point2f0[]
    colors = RGBA{Float32}[]
    for (color, c) in zip(cols, Contours.levels(contours))
        for elem in Contours.lines(c)
            append!(result, elem.vertices)
            push!(result, Point2f0(NaN32))
            append!(colors, fill(color, length(elem.vertices) + 1))
        end
    end
    result, colors
end

function contourlines(::Type{<: Contour3d}, contours, cols)
    result = Point3f0[]
    colors = RGBA{Float32}[]
    for (color, c) in zip(cols, Contours.levels(contours))
        for elem in Contours.lines(c)
            for p in elem.vertices
                push!(result, Point3f0(p[1], p[2], c.level))
            end
            push!(result, Point3f0(NaN32))
            append!(colors, fill(color, length(elem.vertices) + 1))
        end
    end
    result, colors
end

to_levels(x::AbstractVector{<: Number}, cnorm) = x

function to_levels(n::Integer, cnorm)
    zmin, zmax = cnorm
    dz = (zmax - zmin) / (n + 1)
    range(zmin + dz; step = dz, length = n)
end

conversion_trait(::Type{<: Contour3d}) = SurfaceLike()
conversion_trait(::Type{<: Contour}) = SurfaceLike()
conversion_trait(::Type{<: Contour{<: Tuple{X, Y, Z, Vol}}}) where {X, Y, Z, Vol} = VolumeLike()
conversion_trait(::Type{<: Contour{<: Tuple{<: AbstractArray{T, 3}}}}) where T = VolumeLike()

function plot!(plot::Contour{<: Tuple{X, Y, Z, Vol}}) where {X, Y, Z, Vol}
    x, y, z, volume = plot[1:4]
    @extract plot (colormap, levels, linewidth, alpha)
    valuerange = lift(nan_extrema, volume)
    cliprange = replace_automatic!(plot, :colorrange) do
        valuerange
    end
    cmap = lift(colormap, levels, linewidth, alpha, cliprange, valuerange) do _cmap, l, lw, alpha, cliprange, vrange
        levels = to_levels(l, vrange)
        nlevels = length(levels)
        N = nlevels * 50
        iso_eps = nlevels * ((vrange[2] - vrange[1]) / N) # TODO calculate this
        cmap = to_colormap(_cmap)
        v_interval = cliprange[1] .. cliprange[2]
        # resample colormap and make the empty area between iso surfaces transparent
        map(1:N) do i
            i01 = (i-1) / (N - 1)
            c = AbstractPlotting.interpolated_getindex(cmap, i01)
            isoval = vrange[1] + (i01 * (vrange[2] - vrange[1]))
            line = reduce(levels, init = false) do v0, level
                (isoval in v_interval) || return false
                v0 || (abs(level - isoval) <= iso_eps)
            end
            RGBAf0(Colors.color(c), line ? alpha : 0.0)
        end
    end
    volume!(
        plot, x, y, z, volume, colormap = cmap, colorrange = cliprange, algorithm = 7,
        transparency = plot.transparency, overdraw = plot.overdraw,
        ambient = plot.ambient, diffuse = plot.diffuse, lightposition = plot.lightposition,
        shininess = plot.shininess, specular = plot.specular
    )
end

function color_per_level(color, colormap, colorrange, alpha, levels)
    color_per_level(to_color(color), colormap, colorrange, alpha, levels)
end

function color_per_level(color::Colorant, colormap, colorrange, alpha, levels)
    fill(color, length(levels))
end

function color_per_level(colors::AbstractVector, colormap, colorrange, alpha, levels)
    color_per_level(to_colormap(colors), colormap, colorrange, alpha, levels)
end

function color_per_level(colors::AbstractVector{<: Colorant}, colormap, colorrange, alpha, levels)
    if length(levels) == length(colors)
        return colors
    else
        # TODO resample?!
        error("For a contour plot, `color` with an array of colors needs to
        have the same length as `levels`.
        Found $(length(colors)) colors, but $(length(levels)) levels")
    end
end

function color_per_level(::Nothing, colormap, colorrange, a, levels)
    cmap = to_colormap(colormap)
    map(levels) do level
        c = interpolated_getindex(cmap, level, colorrange)
        RGBAf0(color(c), alpha(c) * a)
    end
end


function plot!(plot::T) where T <: Union{Contour, Contour3d}
    x, y, z = plot[1:3]
    if to_value(plot[:fillrange])
        plot[:interpolate] = true
        # TODO normalize linewidth for heatmap
        plot[:linewidth] = map(x-> x ./ 10f0, plot[:linewidth])
        heatmap!(plot, Attributes(plot), x, y, z)
    else
        zrange = lift(nan_extrema, z)
        levels = lift(plot[:levels], zrange) do levels, zrange
            if levels isa AbstractVector{<: Number}
                return levels
            elseif levels isa Integer
                to_levels(levels, zrange)
            else
                error("Level needs to be Vector of iso values, or a single integer to for a number of automatic levels")
            end
        end
        replace_automatic!(plot, :colorrange) do
            lift(nan_extrema, levels)
        end
        args = @extract plot (color, colormap, colorrange, alpha)
        level_colors = lift(color_per_level, args..., levels)
        result = lift(x, y, z, levels, level_colors) do x, y, z, levels, level_colors
            t = eltype(z)
            # Compute contours
            xv, yv = to_vector(x, size(z,1), t), to_vector(y, size(z,2), t)
            contours = Contours.contours(xv, yv, z,  convert(Vector{eltype(z)}, levels))
            contourlines(T, contours, level_colors)
        end
        lines!(
            plot, lift(first, result);
            color = lift(last, result), linewidth = plot[:linewidth]
        )
    end
    plot
end

function data_limits(x::Contour{<: Tuple{X, Y, Z}}) where {X, Y, Z}
    return xyz_boundingbox(transform_func(x), to_value.((x[1], x[2]))...)
end

"""
    VolumeSlices

TODO add function signatures
TODO add descripton

## Attributes
$(ATTRIBUTES)
"""
@recipe(VolumeSlices, x, y, z, volume) do scene
    Attributes(
        colormap = theme(scene, :colormap),
        colorrange = nothing,
        alpha = 0.1,
        contour = Attributes(),
        heatmap = Attributes(),
    )
end

convert_arguments(::Type{<: VolumeSlices}, x, y, z, volume) = convert_arguments(Contour, x, y, z, volume)
function plot!(vs::VolumeSlices)
    @extract vs (x, y, z, volume)
    replace_automatic!(vs, :colorrange) do
        map(extrema, volume)
    end
    keys = (:colormap, :alpha, :colorrange)
    contour!(vs, vs[:contour], x, y, z, volume)
    planes = (:xy, :xz, :yz)
    hattributes = vs[:heatmap]
    sliders = map(zip(planes, (x, y, z))) do plane_r
        plane, r = plane_r
        idx = Node(1)
        vs[plane] = idx
        hmap = heatmap!(vs, hattributes, x, y, zeros(length(x[]), length(y[]))).plots[end]
        on(idx) do i
            transform!(hmap, (plane, r[][i]))
            indices = ntuple(Val(3)) do j
                planes[j] == plane ? i : (:)
            end
            hmap[3][] = view(volume[], indices...)
        end
        idx
    end
    plot!(scene, vs, rest)
end

"""
    showlibrary(lib::Symbol)::Scene

Shows all colour gradients in the given library.
Returns a Scene with these colour gradients arranged
as horizontal colourbars.
"""
function showlibrary(lib::Symbol)::Scene

    cgrads = sort(PlotUtils.cgradients(lib))

    PlotUtils.clibrary(lib)

    showgradients(cgrads)

end

"""
    showgradients(
        cgrads::AbstractVector{Symbol};
        h = 0.0, offset = 0.2, textsize = 0.7,
        resolution = (800, length(cgrads) * 84)
    )::Scene

Plots the given colour gradients arranged as horizontal colourbars.
If you change the offsets or the font size, you may need to change the resolution.
"""
function showgradients(
        cgrads::AbstractVector{Symbol};
        h = 0.0,
        offset = 0.4,
        textsize = 0.7,
        resolution = (800, length(cgrads) * 84),
        monospace = true
    )::Scene

    scene = Scene(resolution = resolution)

    map(collect(cgrads)) do cmap

         c = to_colormap(cmap)

         cbar = image!(
             scene,
             range(0, stop = 10, length = length(c)),
             range(0, stop = 1, length = length(c)),
             reshape(c, (length(c),1)),
             show_axis = false
         )[end]

         cmapstr = monospace ? UnicodeFun.to_latex("\\mono{$cmap}") : string(cmap, ":")

         text!(
             scene,
             cmapstr,
             position = Point2f0(-0.1, 0.5 + h),
             align = (:right, :center),
             show_axis = false,
             textsize = textsize
         )

         translate!(cbar, 0, h, 0)

         h -= (1 + offset)

    end

    scene

end


"""
    timeseries(x::Node{{Union{Number, Point2}}})

Plots a sampled signal.
Usage:
```julia
signal = Node(1.0)
scene = timeseries(signal)
display(scene)
# @async is optional, but helps to continue evaluating more code
@async while isopen(scene)
    # aquire data from e.g. a sensor:
    data = rand()
    # update the signal
    signal[] = data
    # sleep/ wait for new data/ whatever...
    # It's important to yield here though, otherwise nothing will be rendered
    sleep(1/30)
end

```
"""
@recipe(TimeSeries, signal) do scene
    Attributes(
        history = 100;
        default_theme(scene, Lines)...
    )
end

signal2point(signal::Number, start) = Point2f0(time() - start, signal)
signal2point(signal::Point2, start) = signal
signal2point(signal, start) = error(""" Signal needs to be of type Number or Point.
Found: $(typeof(signal))
""")


function AbstractPlotting.plot!(plot::TimeSeries)
    # normal plotting code, building on any previously defined recipes
    # or atomic plotting operations, and adding to the combined `plot`:
    points = Node(fill(Point2f0(NaN), plot.history[]))
    buffer = copy(points[])
    lines!(plot, points)
    start = time()
    on(plot.signal) do x
        points[][end] = signal2point(x, start)
        circshift!(buffer, points[], 1)
        buff_ref = buffer
        buffer = points[]
        points[] = buff_ref
        update!(parent(plot))
    end
    plot
end

"""
    streamplot(f::function, xinterval, yinterval; kwargs...)

f must either accept `f(::Point)` or `f(x::Number, y::Number)`.
f must return a Point2.

Example:
```julia
v(x::Point2{T}) where T = Point2f0(x[2], 4*x[1])
streamplot(v, -2..2, -2..2)
```
## Attributes
$(ATTRIBUTES)

## Implementation
See the function [`streamplot_impl`](@ref) for implementation details.
"""
@recipe(StreamPlot, f, limits) do scene
    merge(
        Attributes(
            stepsize = 0.01,
            gridsize = (32, 32, 32),
            maxsteps = 500,
            colormap = theme(scene, :colormap),
            arrow_size = 0.03,
            density = 1.0
        ),
        default_theme(scene, Lines) # so that we can theme the lines as needed.
    )
end

function convert_arguments(::Type{<: StreamPlot}, f::Function, xrange, yrange)
    xmin, xmax = extrema(xrange)
    ymin, ymax = extrema(yrange)
    return (f, Rect(xmin, ymin, xmax - xmin, ymax - ymin))
end
function convert_arguments(::Type{<: StreamPlot}, f::Function, xrange, yrange, zrange)
    xmin, xmax = extrema(xrange)
    ymin, ymax = extrema(yrange)
    zmin, zmax = extrema(zrange)
    mini = Vec3f0(xmin, ymin, zmin)
    maxi = Vec3f0(xmax, ymax, zmax)
    return (f, Rect(mini, maxi .- mini))
end

function convert_arguments(::Type{<: StreamPlot}, f::Function, limits::Rect)
    return (f, limits)
end

"""
    streamplot_impl(CallType, f, limits::Rect{N, T}, resolutionND, stepsize)

Code adapted from an example implementation by Moritz Schauer (@mschauer)
from https://github.com/JuliaPlots/Makie.jl/issues/355#issuecomment-504449775

Background: The algorithm puts an arrow somewhere and extends the
streamline in both directions from there. Then, it chooses a new
position (from the remaining ones), repeating the the exercise until the
streamline gets blocked, from which on a new starting point, the process
repeats.

So, ideally, the new starting points for streamlines are not too close to
current streamlines.

Links:

[Quasirandom sequences](http://extremelearning.com.au/unreasonable-effectiveness-of-quasirandom-sequences/)
"""
function streamplot_impl(CallType, f, limits::Rect{N, T}, resolutionND, stepsize, maxsteps=500, dens=1.0) where {N, T}
    resolution = to_ndim(Vec{N, Int}, resolutionND, last(resolutionND))
    mask = trues(resolution...) # unvisited squares
    arrow_pos = Point{N, Float32}[]
    arrow_dir = Vec{N, Float32}[]
    line_points = Point{N, Float32}[]
    colors = Float64[]
    line_colors = Float64[]
    dt = Point{N, Float32}(stepsize)
    mini, maxi = minimum(limits), maximum(limits)
    r = ntuple(N) do i
        LinRange(mini[i], maxi[i], resolution[i] + 1)
    end
    apply_f(x0, P) = if P <: Point
        f(x0)
    else
        f(x0...)
    end
    # see http://extremelearning.com.au/unreasonable-effectiveness-of-quasirandom-sequences/
    ϕ = (MathConstants.φ, 1.324717957244746, 1.2207440846057596)[N]
    acoeff = ϕ.^(-(1:N))
    n_points = 0 # count visited squares
    ind = 0 # index of low discrepancy sequence
    while n_points < prod(resolution)*min(one(dens), dens) # fill up to 100*dens% of mask
        # next index from low discrepancy sequence
        c = CartesianIndex(ntuple(N) do i
            j = ceil(Int, ((0.5 + acoeff[i]*ind) % 1)*resolution[i])
            clamp(j, 1, size(mask, i))
        end)
        ind += 1
        if mask[c]
            x0 = Point(ntuple(N) do i
                first(r[i]) + (c[i] - 0.5) * step(r[i])
            end)
            point = apply_f(x0, CallType)
            if !(point isa Point2 || point isa Point3)
                error("Function passed to streamplot must return Point2 or Point3")
            end
            pnorm = norm(point)
            push!(arrow_pos, x0)
            push!(arrow_dir, point ./ pnorm)
            push!(colors, pnorm)
            mask[c] = false
            n_points += 1
            for d in (-1, 1)
                n_linepoints = 1
                x = x0
                ccur = c
                push!(line_points, Point{N, Float32}(NaN), x)
                push!(line_colors, 0.0, pnorm)
                while x in limits && n_linepoints < maxsteps
                    point = apply_f(x, CallType)
                    pnorm = norm(point)
                    x = x .+ d .* dt .* point ./ pnorm
                    if !(x in limits)
                        break
                    end
                    # WHAT? Why does point behave different from tuple in this
                    # broadcast
                    idx = CartesianIndex(searchsortedlast.(r, Tuple(x)))
                    if idx != ccur
                        if !mask[idx]
                            break
                        end
                        mask[idx] = false
                        n_points += 1
                        ccur = idx
                    end
                    push!(line_points, x)
                    push!(line_colors, pnorm)
                    n_linepoints += 1
                end
            end
        end
    end
    return (
        arrow_pos,
        arrow_dir,
        line_points,
        colors,
        line_colors,
    )
end

function plot!(p::StreamPlot)
    data = lift(p.f, p.limits, p.gridsize, p.stepsize, p.maxsteps, p.density) do f, limits, resolution, stepsize, maxsteps, density
        P = if applicable(f, Point2f0(0)) || applicable(f, Point3f0(0))
            Point
        else
            Number
        end
        streamplot_impl(P, f, limits, resolution, stepsize, maxsteps, density)
    end
    lines!(
        p,
        lift(x->x[3], data), color = lift(last, data), colormap = p.colormap,
        linestyle = p.linestyle,
        linewidth = p.linewidth
    )
    N = ndims(p.limits[])
    scatterfun(N)(
        p,
        lift(first, data), markersize = p.arrow_size, marker = arrow_head(N, automatic),
        color = lift(x-> x[4], data), rotations = lift(x-> x[2], data),
        colormap = p.colormap,
    )
end

"""
    spy(x::Range, y::Range, z::AbstractSparseArray)

Visualizes big sparse matrices.
Usage:
```julia
N = 200_000
x = sprand(Float64, N, N, (3(10^6)) / (N*N));
spy(x)
# or if you want to specify the range of x and y:
spy(0..1, 0..1, x)
```
## Attributes
$(ATTRIBUTES)
"""
@recipe(Spy, x, y, z) do scene
    Attributes(
        marker = automatic,
        markersize = automatic,
        colormap = theme(scene, :colormap),
        colorrange = automatic,
        framecolor = :black,
        framesize = 1,
    )
end

function convert_arguments(::Type{<: Spy}, x::SparseArrays.AbstractSparseArray)
    (0..size(x, 1), 0..size(x, 2), x)
end
function convert_arguments(::Type{<: Spy}, x, y, z::SparseArrays.AbstractSparseArray)
    (x, y, z)
end

function calculated_attributes!(::Type{<: Spy}, plot)
end

function plot!(p::Spy)
    rect = lift(p.x, p.y) do x, y
        xe = extrema(x)
        ye = extrema(y)
        FRect2D((xe[1], ye[1]), (xe[2] - xe[1], ye[2] - ye[1]))
    end
    # TODO FastPixel isn't accepting marker size in data coordinates
    # but instead in pixel - so we need to fix that in GLMakie for consistency
    # and make this nicer when redoing unit support
    markersize = lift(p.markersize, rect, p.z) do msize, rect, z
        if msize === automatic
            widths(rect) ./ Vec2f0(size(z))
        else
            msize
        end
    end
    # TODO correctly align marker
    xycol = lift(rect, p.z, markersize) do rect, z, markersize
        x, y, color = SparseArrays.findnz(z)
        points = map(x, y) do x, y
            (((Point2f0(x, y) .- 1) ./ Point2f0(size(z) .- 1)) .*
            widths(rect) .+ minimum(rect))
        end
        points, convert(Vector{Float32}, color)
    end

    replace_automatic!(p, :colorrange) do
        lift(xycol) do (xy, col)
            extrema_nan(col)
        end
    end

    marker = lift(p.marker) do x
        return x === automatic ? FastPixel() : x
    end

    scatter!(
        p,
        lift(first, xycol), color = lift(last, xycol),
        marker = marker, markersize = markersize, colorrange = p.colorrange
    )

    lines!(p, rect, color = p.framecolor, linewidth = p.framesize)
end
