function convert_arguments(P::PlotFunc, d::KernelDensity.UnivariateKDE)
    ptype = plottype(P, Lines) # choose the more concrete one
    to_plotspec(ptype, convert_arguments(ptype, d.x, d.density))
end

function convert_arguments(::Type{<:Poly}, d::KernelDensity.UnivariateKDE)
    points = Vector{Point2f0}(undef, length(d.x) + 2)
    points[1] = Point2f0(d.x[1], 0)
    points[2:end-1] .= Point2f0.(d.x, d.density)
    points[end] = Point2f0(d.x[end], 0)
    (points,)
end

function convert_arguments(P::PlotFunc, d::KernelDensity.BivariateKDE)
    ptype = plottype(P, Heatmap)
    to_plotspec(ptype, convert_arguments(ptype, d.x, d.y, d.density))
end

"""
    density(values; npoints = 200, offset = 0.0, direction = :x)

Plot a kernel density estimate of `values`.
`npoints` controls the resolution of the estimate, the baseline can be
shifted with `offset` and the `direction` set to :x or :y.
`bandwidth` and `boundary` are determined automatically by default.

`color` is usually set to a single color, but can also be set to `:value`, to color
with a gradient along `values`, or to `:density`, which colors with an orthogonal
gradient. For `:density`, only two-color colormaps can be rendered correctly.

## Attributes
$(ATTRIBUTES)
"""
@recipe(Density) do scene
    Theme(
        color = :gray85,
        colormap = :viridis,
        colorrange = AbstractPlotting.automatic,
        strokecolor = :black,
        strokewidth = 1,
        strokearound = false,
        npoints = 200,
        offset = 0.0,
        direction = :x,
        boundary = automatic,
        bandwidth = automatic,
    )
end

function plot!(plot::Density{<:Tuple{<:AbstractVector}})
    x = plot[1]

    lowerupper = lift(x, plot.direction, plot.boundary, plot.offset,
        plot.npoints, plot.bandwidth) do x, dir, bound, offs, n, bw

        k = KernelDensity.kde(x;
            npoints = n,
            (bound === automatic ? NamedTuple() : (boundary = bound,))...,
            (bw === automatic ? NamedTuple() : (bandwidth = bw,))...,
        )

        if dir === :x
            lower = Point2f0.(k.x, offs)
            upper = Point2f0.(k.x, offs .+ k.density)
        elseif dir === :y
            lower = Point2f0.(offs, k.x)
            upper = Point2f0.(offs .+ k.density, k.x)
        else
            error("Invalid direction $dir, only :x or :y allowed")
        end
        (lower, upper)
    end

    linepoints = lift(lowerupper, plot.strokearound) do lu, sa
        if sa
            ps = copy(lu[2])
            push!(ps, lu[1][end])
            push!(ps, lu[1][1])
            push!(ps, lu[1][2])
            ps
        else
            lu[2]
        end
    end

    lower = Node(Point2f0[])
    upper = Node(Point2f0[])

    on(lowerupper) do (l, u)
        lower.val = l
        upper[] = u
    end
    notify(lowerupper)

    colorobs = lift(plot.color, lowerupper, typ = Any) do c, lu
        if c == :value
            [l[1] for l in lu[1]]
        elseif c == :density
            o = Float32(plot.offset[])
            vcat([l[2] - o for l in lu[1]], [l[2] - o for l in lu[2]])
        else
            c
        end
    end

    band!(plot, lower, upper, color = colorobs, colormap = plot.colormap,
        colorrange = plot.colorrange)
    l = lines!(plot, linepoints, color = plot.strokecolor,
        linewidth = plot.strokewidth)
    plot
end