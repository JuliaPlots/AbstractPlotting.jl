export mouseover, mouse_selection, mouseposition, hovered_scene
export select_rectangle, select_line, select_point


"""
    mouseover(scene::SceneLike, plots::AbstractPlot...)

Returns true if the mouse currently hovers any of `plots`.
"""
function mouseover(scene::SceneLike, plots::AbstractPlot...)
    p, idx = mouse_selection(scene)
    return p in flatten_plots(plots)
end

"""
    onpick(f, scene::SceneLike, plots::AbstractPlot...)

Calls `f(idx)` whenever the mouse is over any of `plots`.
`idx` is an index, e.g. when over a scatter plot, it will be the index of the
hovered element
"""
function onpick(
        f, scene::SceneLike, plots::AbstractPlot...; range=1, 
        name=Symbol("onpick<$(hash(f))>"), priority=DEFAULT_PRIORITY
    )
    fplots = flatten_plots(plots)
    args = range == 1 ? (scene,) : (scene, range)

    # Check returntype of f, warn if not Bool 
    # Or maybe we should just never consume and ignore the output of f?
    input_type = Base.signature_type(mouse_selection, Tuple{Scene}).types[2]
    output_type = Base.signature_type(f, Tuple{input_type}).types[2]

    if output_type == Bool
        # replace with the default name acts like map_once!?
        replace!(scene, name, priority) do e::MouseMovedEvent, parent
            p, idx = mouse_selection(args...)
            return (p in fplots) && f(idx)
        end
    else
        @warn(
            "The onpick function should return false (true) to declare the " * 
            "attached MouseMovedEvent as not consumed (consumed)."
        )
        replace!(scene, name, priority) do e::MouseMovedEvent, parent
            p, idx = mouse_selection(args...)
            (p in fplots) && f(idx)
            return false
        end
    end
    # map_once(events(scene).mouseposition) do mp
    #     p, idx = mouse_selection(args...)
    #     (p in fplots) && f(idx)
    #     return
    # end
    name
end

"""
    mouse_selection(scene::Scene)

Returns the plot that is under the current mouse position.
"""
function mouse_selection(scene::SceneLike)
    pick(scene, events(scene).mouseposition[])
end
function mouse_selection(scene::SceneLike, range)
    pick(scene, events(scene).mouseposition[], range)
end

function flatten_plots(x::Atomic, plots = AbstractPlot[])
    if isempty(x.plots)
        push!(plots, x)
    else
        flatten_plots(x.plots, plots)
    end
    plots
end

function flatten_plots(x::Combined, plots = AbstractPlot[])
    for elem in x.plots
        flatten_plots(elem, plots)
    end
    plots
end

function flatten_plots(array, plots = AbstractPlot[])
    for elem in array
        flatten_plots(elem, plots)
    end
    plots
end


# Maybe this should be deprecated for
#   scene_relative(scene, scene.input_state.mouse_position)
# in an interaction?
# Would be nice to have just `mouse_in_scene(scene)` there, but that collides.
"""
    mouse_in_scene(scene::Scene)

Returns the mouseposition relative to `scene` in pixels.
"""
function mouse_in_scene(
        scene::SceneLike; 
        name = Symbol("mouse_in_scene<$(rand(UInt64))>"), 
        priority = DEFAULT_BACKEND_PRIORITY + Int8(1)
    )
    output = Node(Vec2f0(0))
    register!(scene, name, priority) do e::MouseMovedEvent, scene
        output[] = mouse_in_scene(e.position)
        return false
    end
    # lift(pixelarea(p), pixelarea(scene), events(scene).mouseposition) do pa, sa, mp
    #     Vec(mp) .- minimum(sa)
    # end
    output
end



"""
    pick(scene, x, y)

Return the plot under pixel position `(x, y)`.
"""
function pick(scene::SceneLike, x::Number, y::Number)
    return pick(scene, Vec{2, Float64}(x, y))
end


"""
    pick(scene::Scene, xy::VecLike[, range])

Return the plot under pixel position xy
"""
function pick(scene::SceneLike, xy)
    screen = getscreen(scene)
    screen === nothing && return (nothing, 0)
    pick(scene, screen, Vec{2, Float64}(xy))
end
function pick(scene::SceneLike, xy, range)
    screen = getscreen(scene)
    screen === nothing && return (nothing, 0)
    pick(scene, screen, Vec{2, Float64}(xy), Float64(range))
end


"""
    screen_relative(scene, position)

Normalizes mouse position relative to the screen rectangle
"""
screen_relative
@deprecate screen_relative scene_relative

"""
    scene_relative(scene[, event_or_position])

Normalizes mouse position relative to the screen rectangle
"""
scene_relative(scene::SceneLike) = scene_relative(scene, scene.input_state.mouse_position)
scene_relative(scene::SceneLike, e::MouseMovedEvent) = scene_relative(scene, e.position)
function scene_relative(scene::Scene, mpos)
    return Point2f0(mpos) .- Point2f0(minimum(pixelarea(scene)[]))
end

"""
    mouseposition([scene = hovered_scene()])

Return the current position of the mouse in _data coordinates_ of the
given `scene`.

By default uses the `scene` that the mouse is currently hovering over.
"""
mouseposition(scene = hovered_scene()) = to_world(scene, mouseposition_px(scene))

"""
    mouseposition_px([scene = hovered_scene()])

Return the current position of the mouse in _pixel coordinates_ of the
given `scene`.
    
By default uses the `scene` that the mouse is currently hovering over.
"""
mouseposition_px(scene = hovered_scene()) = scene_relative(scene)

"""
    hovered_scene()

Return the `scene` that the mouse is currently hovering over.

Properly identifies the scene for a plot with multiple sub-plots.
"""
hovered_scene() = error("hovered_scene is not implemented yet.")



mutable struct SelectionRectangle
    # Settings
    mouse_button::Mouse.Button
    extra_key::Union{Keyboard.Button, Nothing}

    # triggers when the selection is finished
    rect_ret::Node{FRect2D}

    # backend
    visible::Node{Bool}
    rect::Node{FRect2D}
    plot::Combined
end

"""
    SelectionRectangle(scene[; mouse_button, extra_button, color, strokecolor, strokewidth, kwargs...])

Creates a `sr::SelectionRectangle` which can be registered as an interaction via 
`register!(parent, name, sr)`.

Once registered, this will allow one to interactively select a rectangle by 
clicking the left mouse button, dragging and then un-clicking. The selection will
be visible in the given `scene` with events being sourced from `parent` passed 
to `register!`. 

The selected area is available via two nodes:
- `sr.rect::Node{FRect2D}` which triggers whenever the selection resizes, and
- `sr.rect_ret::Node{FRect2D}` which triggers only when the selection is finalized.

To adjust the visualization one may directly acces the underlying poly plot via 
`sr.plot`.
"""
function SelectionRectangle(
        scene; 
        mouse_button = Mouse.left, extra_key = nothing,
        color = RGBAf0(0, 0, 0, 0), strokecolor = RGBAf0(0.1, 0.1, 0.8, 0.5),
        strokewidth = 3.0, kwargs...
    )
    rect     = Node(FRect(0, 0, 0, 0))
    rect_ret = Node(FRect(0, 0, 0, 0))
    visible  = Node(false)

    plot = poly!(
        scene, rect, 
        raw = true, visible = visible, color = color, 
        strokecolor = strokecolor, strokewidth = strokewidth, 
        kwargs...
    )

    SelectionRectangle(mouse_button, extra_key, rect_ret, visible, rect, plot)
end

function process!(sr::SelectionRectangle, e::MouseButtonEvent, p::Scene)
    if e.button == sr.mouse_button && ispressed(p, sr.extra_button) &&
        is_mouseinside(p)

        if e.action == Mouse.press   # Start selection
            mp = mouseposition(p)
            sr.rect[] = FRect(mp, 0.0, 0.0)
            sr.visible[] = true
        else # Mouse.release        # Stop selection
            sr.visible[] = false
            r = absrect(sr.rect[])
            w, h = widths(r)
            if w > 0.0 && h > 0.0 # Ensure that the rectangle has none 0 size.
                sr.rect_ret[] = r
            end
        end
        return true
    end

    return false
end

function process!(sr::SelectionRectangle, e::MouseMovedEvent, p::Scene)
    if sr.visible[] && ispressed(p, sr.mouse_button) && 
        ispressed(p, sr.extra_key) && is_mouseinside(p)

        mx, my = mouseposition(p)
        rx, ry = minimum(sr.rect[])
        sr.rect[] = FRect(rx, ry, mx - rx, my - ry)
        return true
    end
    return false
end

function select_rectangle(scene; kwargs...)
    sr = SelectionRectangle(scene; kwargs...)
    register!(
        scene, Symbol("selection_rectangle<$(rand(UInt64))>"), sr, 
        DEFAULT_BACKEND_PRIORITY + Int8(1)
    )
    sr.rect_ret
end



# """
#     select_rectangle(scene; kwargs...) -> rect
# Interactively select a rectangle on a 2D `scene` by clicking the left mouse button,
# dragging and then un-clicking. The function returns an **observable** `rect` whose
# value corresponds to the selected rectangle on the scene. In addition the function
# _plots_ the selected rectangle on the scene as the user clicks and moves the mouse
# around. When the button is not clicked any more, the plotted rectangle disappears.

# The value of the returned observable is updated **only** when the user un-clicks
# (i.e. when the final value of the rectangle has been decided) and only if the
# rectangle has area > 0.

# The `kwargs...` are propagated into `lines!` which plots the selected rectangle.
# """
# function select_rectangle(scene; strokewidth = 3.0, kwargs...)
#     key = Mouse.left
#     waspressed = Node(false)
#     rect = Node(FRect(0, 0, 1, 1)) # plotted rectangle
#     rect_ret = Node(FRect(0, 0, 1, 1)) # returned rectangle

#     # Create an initially hidden rectangle
#     plotted_rect = poly!(
#         scene, rect, raw = true, visible = false, color = RGBAf0(0, 0, 0, 0), strokecolor = RGBAf0(0.1, 0.1, 0.8, 0.5), strokewidth = strokewidth, kwargs...,
#     )

#     on(events(scene).mousedrag) do drag
#         if ispressed(scene, key) && is_mouseinside(scene)
#             mp = mouseposition(scene)
#             if drag == Mouse.down
#                 waspressed[] = true
#                 plotted_rect[:visible] = true # start displaying
#                 rect[] = FRect(mp, 0.0, 0.0)
#             elseif drag == Mouse.pressed
#                 mini = minimum(rect[])
#                 rect[] = FRect(mini, mp - mini)
#             end
#         else
#             if drag == Mouse.up && waspressed[] # User has selected the rectangle
#                 waspressed[] = false
#                 r = absrect(rect[])
#                 w, h = widths(r)
#                 if w > 0.0 && h > 0.0 # Ensure that the rectangle has non0 size.
#                     rect_ret[] = r
#                 end
#             end
#             # always hide if not the right key is pressed
#             plotted_rect[:visible] = false # make the plotted rectangle invisible
#         end
#         return rect_ret
#     end
#     return rect_ret
# end


mutable struct SelectionLine
    # Settings
    mouse_button::Mouse.Button
    extra_key::Union{Keyboard.Button, Nothing}

    # triggers when the selection is finished
    line_ret::Node{Vector{Point2f0}}

    # backend
    visible::Node{Bool}
    line::Node{Vector{Point2f0}}
    plot::Combined
end

"""
    SelectionLine(scene[; mouse_button, extra_button, color, linewidth, kwargs...])

Creates a `sl::SelectionLine` which can be registered as an interaction via 
`register!(parent, name, sl)`.

Once registered, this will allow one to interactively select a line by 
clicking the left mouse button, dragging and then un-clicking. The selection will
be visible in the given `scene` with events being sourced from `parent` passed 
to `register!`. 

The selected line is available via two nodes:
- `sl.line::Node{Vector{Point2f0}}` which triggers whenever the selection changes, and
- `sl.line_ret::Node{Vector{Point2f0}}` which triggers only when the selection is finalized.

To adjust the visualization one may directly acces the underlying line plot via 
`sl.plot`.
"""
function SelectionLine( 
        scene; 
        mouse_button = Mouse.left, extra_key = nothing,
        color = RGBAf0(0.1, 0.1, 0.8, 0.5), linewidth = 3.0, kwargs...
    )
    line     = Node([Point2f0(0), Point2f0(0)])
    line_ret = Node([Point2f0(0), Point2f0(0)])
    visible  = Node(false)

    plot = lines!(
        scene, line; visible = visible, color = color, 
        linewidth = linewidth, kwargs...
    )

    SelectionLine(mouse_button, extra_key, line_ret, visible, line, plot)
end


function process!(sl::SelectionLine, e::MouseButtonEvent, p::Scene)
    if e.button == sl.mouse_button && ispressed(p, sl.extra_button) &&
        is_mouseinside(p)

        if e.action == Mouse.press   # Start selection
            mp = mouseposition(p)
            sl.line[][1] = Point2f0(mp)
            sl.line[][2] = Point2f0(mp)
            sl.line[] = sl.line[]
            sl.visible[] = true
        else # Mouse.release        # Stop selection
            sl.visible[] = false
            if sl.line[][1] != sl.line[][2]
                sl.line_ret[] = copy(sl.line[]) # TODO copy really needed?
            end
        end
        return true
    end

    return false
end

function process!(sl::SelectionLine, e::MouseMovedEvent, p::Scene)
    if sl.visible[] && ispressed(p, sl.mouse_button) && 
        ispressed(p, sl.extra_key) && is_mouseinside(p)

        mp = mouseposition(p)
        sl.line[][2] = Point2f0(mp)
        sl.line[] = sl.line[]
        return true
    end
    return false
end

function select_line(scene; kwargs...)
    sl = SelectionLine(scene; kwargs...)
    register!(
        scene, Symbol("selection_line<$(rand(UInt64))>"), sl, 
        DEFAULT_BACKEND_PRIORITY + Int8(1)
    )
    sl.line_ret
end



# """
#     select_line(scene; kwargs...) -> line
# Interactively select a line (typically an arrow) on a 2D `scene` by clicking the left mouse button,
# dragging and then un-clicking. Return an **observable** whose value corresponds
# to the selected line on the scene. In addition the function
# _plots_ the line on the scene as the user clicks and moves the mouse
# around. When the button is not clicked any more, the plotted line disappears.

# The value of the returned line is updated **only** when the user un-clicks
# and only if the selected line has non-zero length.

# The `kwargs...` are propagated into `lines!` which plots the selected line.
# """
# function select_line(scene; kwargs...)
#     key = Mouse.left
#     waspressed = Node(false)
#     line = Node([Point2f0(0,0), Point2f0(1,1)])
#     line_ret = Node([Point2f0(0,0), Point2f0(1,1)])
#     # Create an initially hidden  arrow
#     plotted_line = lines!(
#         scene, line; visible = false, color = RGBAf0(0.1, 0.1, 0.8, 0.5),
#         linewidth = 4, kwargs...,
#     )

#     on(events(scene).mousedrag) do drag
#         if ispressed(scene, key) && is_mouseinside(scene)
#             mp = mouseposition(scene)
#             if drag == Mouse.down
#                 waspressed[] = true
#                 plotted_line[:visible] = true  # start displaying
#                 line[][1] = mp
#                 line[][2] = mp
#                 line[] = line[]
#             elseif drag == Mouse.pressed
#                 line[][2] = mp
#                 line[] = line[] # actually update observable
#             end
#         else
#             if drag == Mouse.up && waspressed[] # User has selected the rectangle
#                 waspressed[] = false
#                 if line[][1] != line[][2]
#                     line_ret[] = copy(line[])
#                 end
#             end
#             # always hide if not the right key is pressed
#             plotted_line[:visible] = false
#         end
#         return line_ret
#     end
#     return line_ret
# end


mutable struct SelectionPoint
    # Settings
    mouse_button::Mouse.Button
    extra_key::Union{Keyboard.Button, Nothing}

    # triggers when the selection is finished
    point_ret::Node{Point2f0}

    # backend
    visible::Node{Bool}
    point::Node{Vector{Point2f0}}
    plot::Combined
end


# TODO why does this have drag behavior?
"""
    SelectionPoint(scene[; mouse_button, extra_button, color, markerwidth, marker, kwargs...])

Creates a `sp::SelectionLine` which can be registered as an interaction via 
`register!(parent, name, sp)`.

Once registered, this will allow one to interactively select a point by 
clicking the left mouse button, dragging and then un-clicking. The selection will
be visible in the given `scene` with events being sourced from `parent` passed 
to `register!`. 

The selected point is available via two nodes:
- `sp.point::Node{Vector{Point2f0}}` which triggers whenever the selection changes, and
- `sp.point_ret::Node{Point2f0}` which triggers only when the selection is finalized.

To adjust the visualization one may directly acces the underlying scatter plot 
via `sp.plot`.
"""
function SelectionPoint( 
        scene; 
        mouse_button = Mouse.left, extra_key = nothing,
        color = RGBAf0(0.1, 0.1, 0.8, 0.5), markersize = 20px, 
        marker= Circle(Point2f0(0, 0), Float32(1)), kwargs...
    )
    point     = Node([Point2f0(0), Point2f0(0)])
    point_ret = Node([Point2f0(0), Point2f0(0)])
    visible  = Node(false)

    plot = scatter!(
        scene, point; visible = visible, marker = marker, markersize = markersize,
        color = color, kwargs...,
    )

    SelectionPoint(mouse_button, extra_key, point_ret, visible, point, plot)
end


function process!(sp::SelectionPoint, e::MouseButtonEvent, p::Scene)
    if e.button == sp.mouse_button && ispressed(p, sp.extra_button) &&
        is_mouseinside(p)

        if e.action == Mouse.press   # Start selection
            mp = mouseposition(p)
            sp.point[][1] = Point2f0(mp)
            sp.point[] = sp.point[]
            sp.visible[] = true
        else # Mouse.release        # Stop selection
            sp.visible[] = false
            sp.point_ret[] = sp.point[][1]
        end
        return true
    end

    return false
end

function process!(sp::SelectionPoint, e::MouseMovedEvent, p::Scene)
    if sp.visible[] && ispressed(p, sp.mouse_button) && 
        ispressed(p, sp.extra_key) && is_mouseinside(p)

        mp = mouseposition(p)
        sp.point[][2] = Point2f0(mp)
        sp.point[] = sp.point[]
        return true
    end
    return false
end

function select_point(scene; kwargs...)
    sp = SelectionPoint(scene; kwargs...)
    register!(
        scene, Symbol("selection_point<$(rand(UInt64))>"), sp, 
        DEFAULT_BACKEND_PRIORITY + Int8(1)
    )
    sp.point_ret
end




# """
#     select_point(scene; kwargs...) -> point
# Interactively select a point on a 2D `scene` by clicking the left mouse button,
# dragging and then un-clicking. Return an **observable** whose value corresponds
# to the selected point on the scene. In addition the function
# _plots_ the point on the scene as the user clicks and moves the mouse
# around. When the button is not clicked any more, the plotted point disappears.

# The value of the returned point is updated **only** when the user un-clicks.

# The `kwargs...` are propagated into `scatter!` which plots the selected point.
# """
# function select_point(scene; kwargs...)
#     key = Mouse.left
#     pmarker = Circle(Point2f0(0, 0), Float32(1))
#     waspressed = Node(false)
#     point = Node([Point2f0(0,0)])
#     point_ret = Node(Point2f0(0,0))
#     # Create an initially hidden  arrow
#     plotted_point = scatter!(
#         scene, point; visible = false, marker = pmarker, markersize = 20px,
#         color = RGBAf0(0.1, 0.1, 0.8, 0.5), kwargs...,
#     )

#     on(events(scene).mousedrag) do drag
#         if ispressed(scene, key) && is_mouseinside(scene)
#             mp = mouseposition(scene)
#             if drag == Mouse.down
#                 waspressed[] = true
#                 plotted_point[:visible] = true  # start displaying
#                 point[][1] = mp
#                 point[] = point[]
#             elseif drag == Mouse.pressed
#                 point[][1] = mp
#                 point[] = point[] # actually update observable
#             end
#         else
#             if drag == Mouse.up && waspressed[] # User has selected the rectangle
#                 waspressed[] = false
#                 point_ret[] = copy(point[][1])
#             end
#             # always hide if not the right key is pressed
#             plotted_point[:visible] = false
#         end
#         return point_ret
#     end
#     return point_ret
# end
