function LSlider(parent::Scene; bbox = nothing, kwargs...)

    default_attrs = default_attributes(LSlider, parent).attributes
    theme_attrs = subtheme(parent, :LSlider)
    attrs = merge!(merge!(Attributes(kwargs), theme_attrs), default_attrs)

    decorations = Dict{Symbol, Any}()

    @extract attrs (
        halign, valign, linewidth, buttonradius, horizontal,
        startvalue, value, color_active, color_active_dimmed, color_inactive,
        buttonstrokewidth, buttoncolor_inactive
    )

    sliderrange = attrs.range

    protrusions = Node(GridLayoutBase.RectSides{Float32}(0, 0, 0, 0))
    layoutobservables = LayoutObservables{LSlider}(attrs.width, attrs.height, attrs.tellwidth, attrs.tellheight,
        halign, valign, attrs.alignmode; suggestedbbox = bbox, protrusions = protrusions)

    onany(buttonradius, horizontal, buttonstrokewidth) do br, hori, bstrw
        layoutobservables.autosize[] = if hori
            (nothing, 2 * (br + bstrw))
        else
            (2 * (br + bstrw), nothing)
        end
    end

    subarea = lift(layoutobservables.computedbbox) do bbox
        round_to_IRect2D(bbox)
    end

    # the slider gets its own subscene so a click doesn't have to hit the line
    # perfectly but can be registered in the whole area that the slider scene has
    subscene = Scene(parent, subarea, camera=campixel!)

    sliderbox = lift(bb -> Rect{2, Float32}(zeros(eltype(bb.origin), 2), bb.widths), layoutobservables.computedbbox)

    endpoints = lift(sliderbox, horizontal) do bb, horizontal

        if horizontal
            y = bottom(bb) + height(bb) / 2
            [Point2f0(left(bb), y),
            Point2f0(right(bb), y)]
        else
            x = left(bb) + width(bb) / 2
            [Point2f0(x, bottom(bb)),
            Point2f0(x, top(bb))]
        end
    end

    # this is the index of the selected value in the slider's range
    # selected_index = Node(1)
    # add the selected index to the attributes so it can be manipulated later
    attrs.selected_index = 1
    selected_index = attrs.selected_index

    # the fraction on the slider corresponding to the selected_index
    # this is only used after dragging
    sliderfraction = lift(selected_index, sliderrange) do i, r
        (i - 1) / (length(r) - 1)
    end

    dragging = Node(false)

    # what the slider actually displays currently (also during dragging when
    # the slider position is in an "invalid" position given the slider's range)
    displayed_sliderfraction = Node(0.0)

    on(sliderfraction) do frac
        # only update displayed fraction through sliderfraction if not dragging
        # dragging overrides the value so there is clear mouse interaction
        if !dragging[]
            displayed_sliderfraction[] = frac
        end
    end

    on(selected_index) do i
        value[] = sliderrange[][i]
    end

    # initialize slider value with closest from range
    selected_index[] = closest_index(sliderrange[], startvalue[])

    buttonpoint = lift(sliderbox, horizontal, displayed_sliderfraction, buttonradius,
            buttonstrokewidth) do bb, horizontal, sf, brad, bstw

        pad = brad + bstw

        if horizontal
            [Point2f0(left(bb) + pad + (width(bb) - 2pad) * sf, bottom(bb) + height(bb) / 2)]
        else
            [Point2f0(left(bb) + 0.5f0 * width(bb), bottom(bb) + pad + (height(bb) - 2pad) * sf)]
        end
    end

    linepoints = lift(endpoints, buttonpoint) do eps, bp
        [eps[1], bp[1], bp[1], eps[2]]
    end

    linecolors = lift(color_active_dimmed, color_inactive) do ca, ci
        [ca, ci]
    end

    linesegs = linesegments!(subscene, linepoints, color = linecolors, linewidth = linewidth, raw = true)[end]
    decorations[:linesegments] = linesegs

    linestate = addmouseevents!(subscene, linesegs)

    bsize = @lift($buttonradius * 2f0)

    bcolor = Node{Any}(buttoncolor_inactive[])


    button = scatter!(subscene, buttonpoint, markersize = bsize, color = bcolor, marker = '⚫',
        strokewidth = buttonstrokewidth, strokecolor = color_active_dimmed, raw = true)[end]
    decorations[:button] = button


    mouseevents = addmouseevents!(subscene)

    onmouseleftup(mouseevents) do event
        bcolor[] = buttoncolor_inactive[]
    end

    onmouseleftdrag(mouseevents) do event

        pad = buttonradius[] + buttonstrokewidth[]

        dragging[] = true
        dif = event.px - event.prev_px
        fraction = if horizontal[]
            dif[1] / (width(sliderbox[]) - 2pad)
        else
            dif[2] / (height(sliderbox[]) - 2pad)
        end
        if fraction != 0.0f0
            newfraction = min(max(displayed_sliderfraction[] + fraction, 0f0), 1f0)
            displayed_sliderfraction[] = newfraction

            newindex = closest_fractionindex(sliderrange[], newfraction)
            if selected_index[] != newindex
                selected_index[] = newindex
            end
        end
    end

    onmouseleftdragstop(mouseevents) do event
        dragging[] = false
        # adjust slider to closest legal value
        sliderfraction[] = sliderfraction[]
    end

    onmouseleftdown(mouseevents) do event

        bcolor[] = color_active[]

        pad = buttonradius[] + buttonstrokewidth[]

        pos = event.px
        dim = horizontal[] ? 1 : 2
        frac = (pos[dim] - endpoints[][1][dim] - pad) / (endpoints[][2][dim] - endpoints[][1][dim] - 2pad)
        selected_index[] = closest_fractionindex(sliderrange[], frac)
    end

    onmouseleftdoubleclick(mouseevents) do event
        selected_index[] = closest_index(sliderrange[], startvalue[])
    end

    onmouseenter(mouseevents) do event
        # bcolor[] = color_active[]
        linecolors[] = [color_active[], color_inactive[]]
        button.strokecolor = color_active[]
    end

    onmouseout(mouseevents) do event
        bcolor[] = buttoncolor_inactive[]
        linecolors[] = [color_active_dimmed[], color_inactive[]]
        button.strokecolor = color_active_dimmed[]
    end

    onany(buttonradius, horizontal) do br, horizontal
        protrusions[] = if horizontal
            GridLayoutBase.RectSides{Float32}(br, br, 0, 0)
        else
            GridLayoutBase.RectSides{Float32}(0, 0, br, br)
        end
    end

    # trigger protrusions using one observable
    buttonradius[] = buttonradius[]

    # trigger bbox
    layoutobservables.suggestedbbox[] = layoutobservables.suggestedbbox[]

    LSlider(parent, subscene, layoutobservables, attrs, decorations)
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
