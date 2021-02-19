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
        visible = theme(scene, :visible),
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
        strokewidth = p.strokewidth, strokecolor = p.strokecolor, visible = p.visible
    )
end

"""
    groupedbarplot(x, groups; kwargs...)

Plots a grouped barplot; `groups` defines heights by group, i.e. each group corresponds to a normal barplot's `y`.  `x`, `groups` and all `group ∈ groups` should be 1 dimensional.

## Attributes
$(ATTRIBUTES)
"""
@recipe(GroupedBarPlot, x, groups) do scene
    default_theme(scene, BarPlot)
end

AbstractPlotting.conversion_trait(::Type{GroupedBarPlot}) = NoConversion()

function AbstractPlotting.plot!(p::GroupedBarPlot)
    widths = lift(p.width, p[1], p[2]) do width, x, groups
        n_x, n_groups = length(x), length(groups)
        extra_space = sum(diff(x)) / n_x # half of this on either end
        group_span = (x[end] - x[begin] + extra_space) / n_x
        if width === AbstractPlotting.automatic
            bars_span = group_span * 0.8
            bar_span = bars_span / n_groups
            [bar_span for group in groups]
        elseif width isa Number
            @assert width > 0
            @assert width * n_groups <= group_span
            [width for group in groups]
        elseif width isa AbstractVector
            @assert length(width) == length(groups)
            @assert sum(width) <= group_span
            width
        else
            error("Unsupported type for GroupedBarPlot attribute `width`")
        end
    end

    group_xs = lift(p[1], p[2], widths) do x, groups, widths
        bars_span = sum(widths)
        # first bar starts at: x - (bars_span/2) + (widths[begin]/2)
        group_xs = map(enumerate(groups)) do (i_group, group)
            # first bar start + preceding bar widths + half current bar
            midpoint_offset = -bars_span / 2 + sum(widths[1:i_group-1]) + widths[i_group]/2
            x .+ midpoint_offset
        end
        return group_xs
    end

    colors = lift(p.color, p[2], p.parent.backgroundcolor) do color, groups, bgcolor
        n_groups = length(groups)
        if color isa AbstractArray && length(color) == n_groups
            color
        else
            distinguishable_colors(n_groups, parse(Colorant, bgcolor), dropseed=true)
        end
    end

    p = lift(group_xs, p[2], colors, widths) do group_xs, group_ys, colors, widths
        for (group_x, group_y, color, width) ∈ zip(group_xs, group_ys, colors, widths)
            barplot!(p, group_x, group_y; p.attributes..., color=color, width=width)
        end
        p
    end

    p
end

AbstractPlotting.Legend(fig_or_scene, grouped_bar::GroupedBarPlot, args...; kwargs...) = Legend(fig_or_scene, grouped_bar.plots, args...; kwargs...)
