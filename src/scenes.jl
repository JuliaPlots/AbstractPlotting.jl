
"""
    Scene TODO document this

## Constructors
$(SIGNATURES)

## Fields
$(FIELDS)
"""
mutable struct Scene <: AbstractScene
    "The parent of the Scene; if it is a top-level Scene, `parent == nothing`."
    parent

    "[`Events`](@ref) associated with the Scene."
    events::Events

    "Storage for interactions that may react to events"
    interactions::Interactions

    "The current pixel area of the Scene."
    px_area::Node{IRect2D}

    "Whether the scene should be cleared."
    clear::Bool

    "The `Camera` associated with the Scene."
    camera::Camera

    "The controls for the camera of the Scene."
    camera_controls::RefValue

    """
    The limits of the data plotted in this scene.
    Can't be set by user and is only used to store calculated data bounds.
    """
    data_limits::Node{Union{Nothing,FRect3D}}

    "The [`Transformation`](@ref) of the Scene."
    transformation::Transformation

    "The plots contained in the Scene."
    plots::Vector{AbstractPlot}
    # TODO why 2?
    theme::Attributes

    attributes::Attributes

    "Children of the Scene inherit its transformation."
    children::Vector{Scene}

    """
    The Screens which the Scene is displayed to.
    """
    current_screens::Vector{AbstractScreen}

    """
    Signal to indicate whether layouting should happen. If updated to true,
    the Scene will be layouted according to its attributes (`raw`, `center`, or `scale_plot`).
    """
    updated::Node{Bool}
end

_plural_s(x) = length(x) != 1 ? "s" : ""

function Base.show(io::IO, scene::Scene)
    println(io, "Scene ($(size(scene, 1))px, $(size(scene, 2))px):")
    print(io, "  $(length(scene.plots)) Plot$(_plural_s(scene.plots))")

    if length(scene.plots) > 0
        print(io, ":")
        for (i, plot) in enumerate(scene.plots)
            print(io, "\n")
            print(io, "    $(i == length(scene.plots) ? '└' : '├') ", plot)
        end
    end

    print(io, "\n  $(length(scene.children)) Child Scene$(_plural_s(scene.children))")

    if length(scene.children) > 0
        print(io, ":")
        for (i, subscene) in enumerate(scene.children)
            print(io, "\n")
            print(io,"    $(i == length(scene.children) ? '└' : '├') Scene ($(size(subscene, 1))px, $(size(subscene, 2))px)")
        end
    end
end

function Scene(
        events::Events,
        px_area::Node{IRect2D},
        clear::Bool,
        camera::Camera,
        camera_controls::RefValue,
        scene_limits,
        transformation::Transformation,
        plots::Vector{AbstractPlot},
        theme::Attributes, # the default values a scene owns
        attributes::Attributes, # the actual attribute values of a scene
        children::Vector{Scene},
        current_screens::Vector{AbstractScreen},
        parent=nothing,
    )

    # indicates whether we can start updating the plot
    # will be set when displayed
    updated = Node(false)

    scene = Scene(
        parent, events, Interactions(), px_area, clear, camera, camera_controls,
        Node{Union{Nothing,FRect3D}}(scene_limits),
        transformation, plots, theme, attributes,
        children, current_screens, updated
    )

    onany(updated, px_area) do update, px_area
        if update && !(scene.camera_controls[] isa PixelCamera)
            if !scene.raw[]
                scene.update_limits[] && update_limits!(scene)
                scene.scale_plot[] && scale_scene!(scene)
                scene.center[] && center!(scene)
            end
        end
        nothing
    end
    if scene[:camera][] !== automatic && camera_controls[] == EmptyCamera()
        # camera shouldn't really be part of the attributes, especially since
        # it just adds the camera one time and after that isn't usable
        cam = pop!(scene.attributes, :camera)[]
        apply_camera!(scene, cam)
    end
    scene
end

function Scene(;clear=true, transform_func=identity, scene_attributes...)
    events = Events()
    theme = current_default_theme(; scene_attributes...)
    attributes = deepcopy(theme)
    px_area = lift(attributes.resolution) do res
        IRect(0, 0, res)
    end
    # on(events.window_area) do w_area
    #     if !any(x -> x ≈ 0.0, widths(w_area)) && px_area[] != w_area
    #         px_area[] = w_area
    #     end
    # end
    scene = Scene(
        events,
        px_area,
        clear,
        Camera(px_area),
        RefValue{Any}(EmptyCamera()),
        nothing,
        Transformation(transform_func),
        AbstractPlot[],
        theme,
        attributes,
        Scene[],
        AbstractScreen[]
    )
    register!(scene, :resize, DEFAULT_BACKEND_PRIORITY) do event::WindowResizeEvent, scene
        if !any(x -> x ≈ 0.0, widths(event.area)) && px_area[] != event.area
            px_area[] = event.area
        end
        false
    end
    # Set the transformation parent
    scene.transformation.parent[] = scene
    current_global_scene[] = scene
    scene
end

function Scene(
        scene::Scene;
        events=scene.events,
        px_area=scene.px_area,
        clear=false,
        cam=scene.camera,
        camera_controls=scene.camera_controls,
        transformation=Transformation(scene),
        theme=copy(theme(scene)),
        current_screens=scene.current_screens,
        kw_args...
    )
    child = Scene(
        events,
        px_area,
        clear,
        cam,
        camera_controls,
        nothing,
        transformation,
        AbstractPlot[],
        merge(current_default_theme(), theme),
        merge!(Attributes(; kw_args...), scene.attributes),
        Scene[],
        current_screens,
        scene
    )
    push!(scene.children, child)
    child
end

function Scene(parent::Scene, area; clear=false, transform_func=identity, attributes...)
    events = parent.events
    px_area = lift(pixelarea(parent), convert(Node, area)) do p, a
        # make coordinates relative to parent
        IRect2D(minimum(p) .+ minimum(a), widths(a))
    end
    child = Scene(
        events,
        px_area,
        clear,
        Camera(px_area),
        RefValue{Any}(EmptyCamera()),
        nothing,
        Transformation(transform_func),
        AbstractPlot[],
        current_default_theme(; attributes...),
        merge!(Attributes(; attributes...), parent.attributes),
        Scene[],
        parent.current_screens,
        parent
    )
    push!(parent.children, child)
    return child
end

# Base overloads for Scene

Base.haskey(scene::Scene, key::Symbol) = haskey(scene.attributes, key)
Base.propertynames(scene::Scene) = fieldnames(Scene) ∪ propertynames(scene.attributes)

function Base.getindex(scene::Scene, key::Symbol)
    return haskey(scene.attributes, key) ? scene.attributes[key] : scene.theme[key]
end

function Base.setindex!(scene::Scene, value, key::Symbol)
    scene.attributes[key] = value
end

Base.parent(scene::Scene) = scene.parent
isroot(scene::Scene) = parent(scene) === nothing
function root(scene::Scene)
    while !isroot(scene)
        scene = parent(scene)
    end
    scene
end
parent_or_self(scene::Scene) = isroot(scene) ? scene : parent(scene)


Base.size(x::Scene) = pixelarea(x) |> to_value |> widths |> Tuple
Base.size(x::Scene, i) = size(x)[i]
function Base.resize!(scene::Scene, xy::Tuple{Number,Number})
    resize!(scene, IRect(0, 0, xy))
end
Base.resize!(scene::Scene, x::Number, y::Number) = resize!(scene, (x, y))
function Base.resize!(scene::Scene, rect::Rect2D)
    pixelarea(scene)[] = rect
end

"""
    getscreen(scene::Scene)
Gets the current screen a scene is associated with.
Returns nothing if not yet displayed on a screen.
"""
function getscreen(scene::Scene)
    if isempty(scene.current_screens)
        isroot(scene) && return nothing # stop search
        return getscreen(parent(scene)) # screen could be in parent
    end
    # TODO, when would we actually want to get a specific screen?
    return last(scene.current_screens)
end

getscreen(scene::SceneLike) = getscreen(rootparent(scene))

"""
    `update!(p::Scene)`

Updates a `Scene` and all its children.
Update will perform the following operations for every scene:
```julia
if !scene.raw[]
    scene.update_limits[] && update_limits!(scene)
    scene.scale_plot[] && scale_scene!(scene)
    scene.center[] && center!(scene)
end
```
"""
function update!(p::Scene)
    p.updated[] = true
    foreach(update!, p.children)
end

# Just indexing into a scene gets you plot 1, plot 2 etc
Base.iterate(scene::Scene, idx=1) = idx <= length(scene) ? (scene[idx], idx + 1) : nothing
Base.length(scene::Scene) = length(scene.plots)
Base.lastindex(scene::Scene) = length(scene.plots)
getindex(scene::Scene, idx::Integer) = scene.plots[idx]
GeometryBasics.widths(scene::Scene) = widths(to_value(pixelarea(scene)))
struct Axis end

zero_origin(area) = IRect(0, 0, widths(area))

function child(scene::Scene; attributes...)
    Scene(scene, lift(zero_origin, pixelarea(scene)); attributes...)
end

"""
Creates a subscene with a pixel camera
"""
function cam2d(scene::Scene)
    return child(scene, clear=false, camera=cam2d!)
end

function campixel(scene::Scene)
    return child(scene, clear=false, camera=campixel!)
end

function getindex(scene::Scene, ::Type{Axis})
    for plot in scene
        isaxis(plot) && return plot
    end
    nothing
end


"""
Each argument can be named for a certain plot type `P`. Falls back to `arg1`, `arg2`, etc.
"""
function argument_names(plot::P) where P <: AbstractPlot
    argument_names(P, length(plot.converted))
end

function argument_names(::Type{<: AbstractPlot}, num_args::Integer)
    # this is called in the indexing function, so let's be a bit efficient
    ntuple(i -> Symbol("arg$i"), num_args)
end

function Base.empty!(scene::Scene)
    empty!(scene.plots)
    disconnect!(scene.camera)
    scene.data_limits[] = nothing
    scene.camera_controls[] = EmptyCamera()
    empty!(scene.theme)
    merge!(scene.theme, _current_default_theme)
    empty!(scene.children)
    empty!(scene.current_screens)
end

limits(scene::Scene) = scene.data_limits

limits(scene::SceneLike) = limits(parent(scene))

function scene_limits(scene::Scene)
    if scene.limits[] === automatic
        return scene.data_limits[]
    else
        return FRect3D(scene.limits[])
    end
end

# Since we can use Combined like a scene in some circumstances, we define this alias
theme(x::SceneLike, args...) = theme(x.parent, args...)
theme(x::Scene) = x.theme
theme(x::Scene, key) = deepcopy(x.theme[key])
theme(x::AbstractPlot, key) = deepcopy(x.attributes[key])
theme(::Nothing, key::Symbol) = deepcopy(current_default_theme()[key])

Base.push!(scene::Combined, subscene) = nothing # Combined plots add themselves uppon creation

function Base.push!(scene::Scene, plot::AbstractPlot)
    push!(scene.plots, plot)
    plot isa Combined || (plot.parent[] = scene)
    if !scene.raw[]
        # update scenes data limit for each new plot!
        scene.data_limits[] = if scene.data_limits[] === nothing
            data_limits(plot)
        else
            union(scene.data_limits[], data_limits(plot))
        end
    end
    for screen in scene.current_screens
        insert!(screen, scene, plot)
    end
end

function Base.delete!(screen::AbstractScreen, ::Scene, ::AbstractPlot)
    @warn "Deleting plots not implemented for backend: $(typeof(screen))"
end

function Base.delete!(scene::Scene, plot::AbstractPlot)
    len = length(scene.plots)
    filter!(x -> x !== plot, scene.plots)
    if length(scene.plots) == len
        error("$(typeof(plot)) not in scene!")
    end
    for screen in scene.current_screens
        delete!(screen, scene, plot)
    end
end

function Base.push!(scene::Scene, child::Scene)
    push!(scene.children, child)
    disconnect!(child.camera)
    nodes = map([:view, :projection, :projectionview, :resolution, :eyeposition]) do field
        lift(getfield(scene.camera, field)) do val
            push!(getfield(child.camera, field), val)
        end
    end
    cameracontrols!(child, nodes)
    return scene
end

events(scene::Scene) = scene.events
events(scene::SceneLike) = events(scene.parent)

camera(scene::Scene) = scene.camera
camera(scene::SceneLike) = camera(scene.parent)

cameracontrols(scene::Scene) = scene.camera_controls[]
cameracontrols(scene::SceneLike) = cameracontrols(scene.parent)

cameracontrols!(scene::Scene, cam) = (scene.camera_controls[] = cam)
cameracontrols!(scene::SceneLike, cam) = cameracontrols!(parent(scene), cam)

pixelarea(scene::Scene) = scene.px_area
pixelarea(scene::SceneLike) = pixelarea(scene.parent)

plots(scene::SceneLike) = scene.plots

const _forced_update_scheduled = Ref(false)

"""
Returns whether a scene needs to be updated
"""
function must_update()
    val = _forced_update_scheduled[]
    _forced_update_scheduled[] = false
    val
end

"""
Forces the scene to be re-rendered
"""
function force_update!()
    _forced_update_scheduled[] = true
end


const current_global_scene = Ref{Any}()

"""
Returns the current active scene (the last scene that got created)
"""
function current_scene()
    if isassigned(current_global_scene)
        current_global_scene[]
    else
        Scene()
    end
end

"""
Fetches all plots sharing the same camera
"""
plots_from_camera(scene::Scene) = plots_from_camera(scene, scene.camera)
function plots_from_camera(scene::Scene, camera::Camera, list=AbstractPlot[])
    append!(list, scene.plots)
    for child in scene.children
        child.camera == camera && !child.raw[] && plots_from_camera(child, camera, list)
    end
    list
end

"""
Flattens all the combined plots and returns a Vector of Atomic plots
"""
function flatten_combined(plots::Vector, flat=AbstractPlot[])
    for elem in plots
        if (elem isa Combined)
            flatten_combined(elem.plots, flat)
        else
            push!(flat, elem)
        end
    end
    flat
end


function insertplots!(screen::AbstractDisplay, scene::Scene)
    for elem in scene.plots
        insert!(screen, scene, elem)
    end
    foreach(s -> insertplots!(screen, s), scene.children)
end
update_cam!(scene::Scene, bb::AbstractCamera, rect) = nothing

function scale_scene!(scene::Scene)
    if is2d(scene) !== nothing && is2d(scene)
        area = pixelarea(scene)[]
        lims = scene_limits(scene)
        # not really sure how to scale 3D scenes in a reasonable way
        mini, maxi = minimum(lims), maximum(lims)
        l = ((mini[1], maxi[1]), (mini[2], maxi[2]))
        xyzfit = fit_ratio(area, l)
        s = to_ndim(Vec3f0, xyzfit, 1f0)
        scale!(scene, s)
    end
    return scene
end

function center!(scene::Scene, padding=0.01)
    bb = boundingbox(scene)
    bb = transformationmatrix(scene)[] * bb
    w = widths(bb)
    padd = w .* padding
    bb = FRect3D(minimum(bb) .- padd, w .+ 2padd)
    update_cam!(scene, bb)
    scene
end
parent_scene(x::Combined) = parent_scene(parent(x))
parent_scene(x::Scene) = x

Base.isopen(x::SceneLike) = events(x).window_open[]


function is2d(scene::SceneLike)
    lims = scene_limits(scene)
    lims === nothing && return nothing
    return is2d(lims)
end
is2d(lims::Rect2D) = return true
is2d(lims::Rect3D) = widths(lims)[3] == 0.0

"""
    update_limits!(scene::Scene, limits::Union{Automatic, Rect} = scene.limits[], padding = scene.padding[])

This function updates the limits of the `Scene` passed to it based on its data.
If an actual limit is set by the theme or its attributes (scene.limits !== automatic),
it will not update the limits. Call update_limits!(scene, automatic) for that.
"""
update_limits!(scene::Scene) = update_limits!(scene, scene.limits[])

function update_limits!(scene::Scene, limits, padding)
    update_limits!(scene, limits, to_ndim(Vec3f0, padding, 0.0))
end

function update_limits!(scene::Scene, ::Automatic, padding::Vec3f0=scene.padding[])
    # for when scene is empty
    dlimits = data_limits(scene)
    dlimits === nothing && return # nothing to limit if there isn't anything
    tlims = (minimum(dlimits), maximum(dlimits))
    let avec = tlims[1], bvec = tlims[2]
        if !all(x -> all(isfinite, x), (avec, bvec))
            @warn "limits of scene contain non finite values: $(avec) .. $(bvec)"
            mini = map(x -> ifelse(isfinite(x), x, zero(x)), avec)
            maxi = Vec3f0(ntuple(3) do i
                x = bvec[i]
                ifelse(isfinite(x), x, avec[i] + oneunit(avec[i]))
            end)
            tlims = (mini, maxi)
        end
    end
    local new_widths
    let avec = tlims[1], bvec = tlims[2]
        new_widths = Vec3f0(ntuple(3) do i
            a = avec[i]; b = bvec[i]
            w = b - a
            # check for widths == 0.0... 3rd dimension is allowed to be 0 though.
            # TODO maybe we should allow any one dimension to be 0, and then use the other 2 as 2D
            with0 = (i != 3) && (w ≈ 0.0)
            with0 && @warn "Founds 0 width in scene limits: $(avec) .. $(bvec)"
            ifelse(with0, 1f0, w)
        end)
    end
    update_limits!(scene, FRect3D(tlims[1], new_widths), padding)
end

"""
    update_limits!(scene::Scene, new_limits::Rect, padding = Vec3f0(0))

This function updates the limits of the given `Scene` according to the given Rect.

A `Rect` is a generalization of a rectangle to n dimensions.  It contains two vectors.
The first vector defines the origin; the second defines the displacement of the vertices from the origin.
This second vector can be thought of in two dimensions as a vector of width (x-axis) and height (y-axis),
and in three dimensions as a vector of the width (x-axis), breadth (y-axis), and height (z-axis).

Such a `Rect` can be constructed using the `FRect` or `FRect3D` functions that are exported by
`AbstractPlotting.jl`.  See their documentation for more information.
"""
function update_limits!(scene::Scene, new_limits::Rect, padding::Vec3f0=scene.padding[])
    lims = FRect3D(new_limits)
    lim_w = widths(lims)
    # use the smallest widths for scaling, to have a consistently wide padding for all sides
    minw = if lim_w[3] ≈ 0.0
        m = min(lim_w[1], lim_w[2])
        Vec3f0(m, m, 0.0)
    else
        Vec3f0(minimum(lim_w))
    end
    padd_abs = minw .* to_ndim(Vec3f0, padding, 0.0)
    scene.data_limits[] = FRect3D(minimum(lims) .- padd_abs, lim_w .+  2padd_abs)
    scene
end


################################################################################
### Interactions
################################################################################


# Basic idea:
# - top level scene gets events from the backend via `process!(::Scene, ::AbstractEvent)`
# - events are forwarded to `process!(::Interactions, ::AbstractEvent, ::Scene)`
# - and then `process!(interaction, ::AbstractEvent, ::Scene)`
#   - Interactions are sorted by priority (high first)
#   - events can be consumed by returning true
# - if an event has not been processed consumed, it will be forwarded to child scenes

const DEFAULT_BACKEND_PRIORITY = Int8(50)
const DEFAULT_PRIORITY = Int8(0)


"""
    register!(scene_or_plot, key::Symbol, interaction::Any[, priority=0])
    register!(scene_or_plot, key[, priority]) do event, scene ... end

Register an interaction (function or object) with the given key.

Interactions are used to process events which are created by the backend and
given to the top-level scene. The scene distributes events to interactions in 
order of priority (high first). If an interaction returns true, that event is
consumed, i.e. not passed to other interactions. If an event is not consumed it
will be forwarded to child scenes and may be processed there.

An interaction of type `::Function` should have the signature 
`f(::EventType, ::Scene)::Bool` where `EventType` is some type inherting from 
`AbstractEvent` and always return `true` or `false`.

More complex interaction can be implemented as custom types, e.g. 
`struct MyInteraction ... end`. To process an event a function
`process!(::MyInteraction, ::EventType, ::Scene)::Bool` should be implemented, 
where `EventType` is some type inheriting from `AbstractEvent`.

The available Events are:

```
AbstractEvent
    AbstractKeyboardEvent
        KeyEvent
        InputEvent
    AbstractMouseEvent
        MouseClickedEvent
        MouseMovedEvent
        MouseScrolledEvent
    AbstractWindowEvent
        WindowResizeEvent
        WindowDPIEvent
        WindowOpenEvent
        DroppedFilesEvent
        WindowFocusEvent
        WindowEnteredEvent
    RenderTickEvent
```
"""
function register!(f::Function, target::Union{SceneLike, AbstractPlot}, key, _priority = DEFAULT_PRIORITY)
    register!(target, key, f, _priority)
end
function register!(target::Union{SceneLike, AbstractPlot}, key, int, _priority = DEFAULT_PRIORITY)
    register!(target.interactions, key, int, _priority)
    add_priority!(target, _priority)
    nothing
end
function register!(col::Interactions, key, interaction, _priority = DEFAULT_PRIORITY)
    active = col.active
    prioritymap = col.prioritymap
    keymap = col.keymap
    interactions = col.interactions

    if haskey(keymap, key)
        # KeyError() maybe?
        error("Interaction with name $key already exists.")
    end

    # Insert priority-ordered interaction

    # find index into interactions and add it
    if haskey(prioritymap, _priority)
        idx = last(prioritymap[_priority])+1
        # Update larger indices
        for indices in values(prioritymap)
            if first(indices) >= idx
                indices .+= 1
            end
        end
        push!(prioritymap[_priority], idx)
        idx
    elseif isempty(prioritymap)
        push!(prioritymap, _priority => Int[1])
        idx = 1
    else
        priorities = sort(collect(keys(prioritymap)))
        idx = if _priority < first(priorities)
            1
        elseif last(priorities) < _priority
            lastindex(interactions) + 1
        else
            i = findfirst(p -> p > _priority, priorities)
            first(prioritymap[i])
        end
        # Update larger indices
        for indices in values(prioritymap)
            if first(indices) >= idx
                indices .+= 1
            end
        end
        push!(prioritymap, _priority => Int[idx])
    end

    for (k, v) in keymap
        if v[2] >= idx
            keymap[k] = (v[1], v[2]+1)
        end
    end
    push!(keymap, key => (_priority, idx))
    insert!(interactions, idx, interaction)

    nothing
end

# register priority in all parent plots and scenes
add_priority!(target::Nothing, _priority) = nothing
function add_priority!(target, _priority)
    if !(_priority in target.interactions.active)
        push!(target.interactions.active, _priority)
        sort!(target.interactions.active)
        return add_priority!(target.parent, _priority)
    end
    return nothing
end



"""
    deregister!(scene, key)

Removes the interaction associated with the given key.
"""
function deregister!(target::Union{SceneLike, AbstractPlot}, key)
    need_update, _priority = deregister!(target.interactions, key)
    if need_update
        maybe_remove_priority!(target, _priority)
    end
    nothing
end

# removing - follow Dict?
function deregister!(col::Interactions, key::Symbol)
    _priority, idx = col.keymap[key]
    deleteat!(col.interactions, idx)
    
    i = findfirst(i -> i == idx, col.prioritymap[_priority])
    deleteat!(col.prioritymap[_priority], i)
    need_update = if isempty(col.prioritymap[_priority])
        deleteat!(col.prioritymap, _priority)
        true
    else
        col.prioritymap[_priority][i:end] -= 1
        false
    end
    for (k, v) in col.prioritymap
        (k > _priority) && (v .-= 1)
    end

    delete!(col.keymap, key)
    for (k, v) in col.keymap
        (v[2] > idx) && (col.keymap[k] = (v[1], v[2]-1))
    end

    return need_update, _priority
end

function has_other_source(scene::Scene, _priority)
    for child in scene.children
        _priority in child.interactions.active && return true
    end
    for plot in scene.plots
        _priority in plot.interactions.active && return true
    end
    false
end
function has_other_source(scene::AbstractPlot, _priority)
    for plot in scene.plots
        _priority in plot.interactions.active && return true
    end
    false
end

maybe_remove_priority!(::Nothing, _priority) = nothing
function maybe_remove_priority!(target, _priority)
    if any(p == _priority for p in keys(target.interactions.prioritymap))
        # interaction with _priority exists here
        return nothing
    elseif has_other_source(target, _priority)
        # interaction with _priority exists in a child
        return nothing
    else
        # doesn't exist, can be removed here, maybe also in parent
        idx = findfirst(==(_priority), target.interactions.active)
        deleteat!(target.interactions.active, idx)
        return maybe_remove_priority(target.parent, _priority)
    end
end



# event dispatch
function process!(scene::Scene, @nospecialize(event))
    # process by priority first, reverse rende rorder second
    for _priority in reverse(scene.interactions.active)
        for plot in reverse(scene.plots)
            process!(plot, event, _priority) && return true
        end
        for child in reverse(scene.children)
            process!(child, event, _priority) && return true
        end        
        # Should this happen before plots?
        process!(scene.interactions, event, scene, _priority) && return true
    end
    return false
end

function process!(scene::Scene, @nospecialize(event), _priority)
    (_priority in scene.interactions.active) || return false
    for plot in reverse(scene.plots)
        process!(plot, event, _priority) && return true
    end
    for child in reverse(scene.children)
        process!(child, event, _priority) && return true
    end        
    return process!(scene.interactions, event, scene, _priority)
end

function process!(plot::AbstractPlot, @nospecialize(event), _priority)
    (_priority in plot.interactions.active) || return false
    for child in reverse(plot.plots)
        process!(child, event, _priority) && return true
    end
    return process!(plot.interactions, event, plot, _priority)
end

# dispatch events to interactions
function process!(col::Interactions, @nospecialize(event), parent::Union{SceneLike, AbstractPlot}, _priority)
    haskey(col.prioritymap, _priority) || return false 
    for idx in col.prioritymap[_priority]
        x = process!(col.interactions[idx], event, parent) 
        x && return true
    end
    return false
end

# Default - do nothing
process!(@nospecialize args...) = false

# For functions
function process!(f::Function, @nospecialize(event), parent::Union{SceneLike, AbstractPlot})
    if applicable(f, event, parent)
        # To make this error if the returntype is not a Bool
        return ifelse(f(event, parent), true, false)
    end
    return false
end








# """
#     priority(scene, key)

# Get the priority of an interaction associated with a given key.
# """
# priority(scene::Scene, key) = priority(scene.interactions, key)
# """
#     priority!(scene, key, priority)

# Sets the priority of an interaction associated with a given key.
# """
# priority!(scene::Scene, key, _priority) = priority!(scene.interactions, key, _priority)

# """
#     priorities(scene)

# Returns a `Dict(priority => keys)`` of all priority values and their associated keys.
# """
# priorities(scene::Scene) = priorities(scene.interactions)


# # get/set priority
# priority(col::Interactions, key::Symbol) = col.priorities[col.keymap[key]]
# function priorities(col::Interactions)
#     output = Dict{Int64, Vector{Symbol}}()
#     for (k, v) in col.keymap
#         _priority = col.priorities[v]
#         if haskey(output, _priority)
#             output[_priority] = Symbol[k]
#         else
#             push!(output[_priority], k)
#         end
#     end
#     output
# end
# function priority!(col::Interactions, key::Symbol, _priority)
#     old = col.keymap[key]
#     new = priority_to_index(priorities, _priority)
    
#     # Same position, nothing to do
#     col.priorities[old] == new-1 && return nothing

#     # Otherwise remove and insert elsewhere
#     interaction = col.interactions[old]
#     deleteat!(col.interactions, old)
#     deleteat!(col.priorities, old)
#     insert!(col.interactions, new-1, interaction)
#     insert!(col.priorities, new-1, _priority)

#     col.keymap[key] = new-1
#     for (k, v) in col.keymap
#         (old < v < new-1) && (col.keymap[k] -= 1)
#     end

#     nothing
# end