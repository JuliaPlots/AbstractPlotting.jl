function layoutable(::Type{RangeSlider}, fig_or_scene; bbox = nothing, kwargs...)

    topscene = get_topscene(fig_or_scene)

    default_attrs = default_attributes(RangeSlider, topscene).attributes
    theme_attrs = subtheme(topscene, :RangeSlider)
    attrs = merge!(merge!(Attributes(kwargs), theme_attrs), default_attrs)

    decorations = Dict{Symbol, Any}()

    @extract attrs (
        halign, valign, horizontal, linewidth,
        startvalues, values, color_active, color_active_dimmed, color_inactive
    )

    sliderrange = attrs.range

    protrusions = Node(GridLayoutBase.RectSides{Float32}(0, 0, 0, 0))
    layoutobservables = LayoutObservables{RangeSlider}(attrs.width, attrs.height, attrs.tellwidth, attrs.tellheight,
        halign, valign, attrs.alignmode; suggestedbbox = bbox, protrusions = protrusions)

    onany(linewidth, horizontal) do lw, horizontal
        if horizontal
            layoutobservables.autosize[] = (nothing, Float32(lw))
        else
            layoutobservables.autosize[] = (Float32(lw), nothing)
        end
    end

    sliderbox = lift(identity, layoutobservables.computedbbox)

    endpoints = lift(sliderbox, horizontal) do bb, horizontal

        h = height(bb)
        w = width(bb)

        if horizontal
            y = bottom(bb) + h / 2
            [Point2f0(left(bb) + h/2, y),
             Point2f0(right(bb) - h/2, y)]
        else
            x = left(bb) + w / 2
            [Point2f0(x, bottom(bb) + w/2),
             Point2f0(x, top(bb) - w/2)]
        end
    end

    # this is the index of the selected value in the slider's range
    # selected_index = Node(1)
    # add the selected index to the attributes so it can be manipulated later
    attrs.selected_indices = (1, 1)
    selected_indices = attrs.selected_indices

    # the fraction on the slider corresponding to the selected_indices
    # this is only used after dragging
    sliderfractions = lift(selected_indices, sliderrange) do is, r
        map(is) do i
            (i - 1) / (length(r) - 1)
        end
    end

    dragging = Node(false)

    # what the slider actually displays currently (also during dragging when
    # the slider position is in an "invalid" position given the slider's range)
    displayed_sliderfractions = Node((0.0, 0.0))

    on(sliderfractions) do fracs
        # only update displayed fraction through sliderfraction if not dragging
        # dragging overrides the value so there is clear mouse interaction
        if !dragging[]
            displayed_sliderfractions[] = fracs
        end
    end

    on(selected_indices) do is
        values[] = getindex.(Ref(sliderrange[]), is)
    end

    # initialize slider value with closest from range
    selected_indices[] = closest_index.(Ref(sliderrange[]), startvalues[])

    middlepoints = lift(endpoints, displayed_sliderfractions) do ep, sfs
        [Point2f0(ep[1] .+ sf .* (ep[2] .- ep[1])) for sf in sfs]
    end

    linepoints = lift(endpoints, middlepoints) do eps, middles
        [eps[1], middles[1], middles[1], middles[2], middles[2], eps[2]]
    end

    linecolors = lift(color_active_dimmed, color_inactive) do ca, ci
        [ci, ca, ci]
    end

    endbuttoncolors = lift(color_active_dimmed, color_inactive) do ca, ci
        [ci, ci]
    end

    endbuttons = scatter!(topscene, endpoints, color = endbuttoncolors, markersize = linewidth, strokewidth = 0, raw = true)
    decorations[:endbuttons] = endbuttons

    linesegs = linesegments!(topscene, linepoints, color = linecolors, linewidth = linewidth, raw = true)
    decorations[:linesegments] = linesegs

    button_magnification = Node(1.0)
    buttonsize = @lift($linewidth * $button_magnification)
    buttons = scatter!(topscene, middlepoints, color = color_active, strokewidth = 0, markersize = buttonsize, raw = true)
    decorations[:buttons] = buttons

    mouseevents = addmouseevents!(topscene, linesegs, buttons)

    onmouseleftdrag(mouseevents) do event

        dragging[] = true
        dif = event.px
        fraction = if horizontal[]
            (event.px[1] - endpoints[][1][1]) / (endpoints[][2][1] - endpoints[][1][1])
        else
            (event.px[2] - endpoints[][1][2]) / (endpoints[][2][2] - endpoints[][1][2])
        end
        fraction = clamp(fraction, 0, 1)

        i_closer = argmin(abs.(fraction .- displayed_sliderfractions[]))

        displayed_sliderfractions[] = minmax(if i_closer == 1
            (fraction, displayed_sliderfractions[][2])
        else
            (displayed_sliderfractions[][1], fraction)
        end...)

        newindices = closest_fractionindex.(Ref(sliderrange[]), displayed_sliderfractions[])
        if selected_indices[] != newindices
            selected_indices[] = newindices
        end
    end

    onmouseleftdragstop(mouseevents) do event
        dragging[] = false
        # adjust slider to closest legal value
        sliderfractions[] = sliderfractions[]
    end

    onmouseleftdown(mouseevents) do event

        pos = event.px
        dim = horizontal[] ? 1 : 2
        frac = (pos[dim] - endpoints[][1][dim]) / (endpoints[][2][dim] - endpoints[][1][dim])
        newindex = closest_fractionindex(sliderrange[], frac)
        if abs(newindex - selected_indices[][1]) < abs(newindex - selected_indices[][2])
            selected_indices[] = (newindex, selected_indices[][2])
        else
            selected_indices[] = (selected_indices[][1], newindex)
        end
        # linecolors[] = [color_active[], color_inactive[]]
    end

    onmouseleftdoubleclick(mouseevents) do event
        selected_indices[] = closest_index(sliderrange[], startvalues[])
    end

    onmouseenter(mouseevents) do event
        button_magnification[] = 1.25
    end

    onmouseout(mouseevents) do event
        button_magnification[] = 1.0
    end

    # trigger autosize through linewidth for first layout
    linewidth[] = linewidth[]

    RangeSlider(fig_or_scene, layoutobservables, attrs, decorations)
end

function valueindex(sliderrange, value)
    for (i, val) in enumerate(sliderrange)
        if val == value
            return i
        end
    end
    nothing
end

function closest_fractionindex(sliderrange, fraction)
    n = length(sliderrange)
    onestepfrac = 1 / (n - 1)
    i = round(Int, fraction / onestepfrac) + 1
    min(max(i, 1), n)
end

function closest_index(sliderrange, value)
    for (i, val) in enumerate(sliderrange)
        if val == value
            return i
        end
    end
    # if the value wasn't found this way try inexact
    closest_index_inexact(sliderrange, value)
end

function closest_index_inexact(sliderrange, value)
    distance = Inf
    selected_i = 0
    for (i, val) in enumerate(sliderrange)
        newdist = abs(val - value)
        if newdist < distance
            distance = newdist
            selected_i = i
        end
    end
    selected_i
end

"""
Set the `slider` to the value in the slider's range that is closest to `value`.
"""
function set_close_to!(slider, value)
    closest = closest_index(slider.range[], value)
    slider.selected_index = closest
end
