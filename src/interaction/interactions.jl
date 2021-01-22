################################################################################
### Interactions
################################################################################


# Basic idea:
# - top level scene gets events from the backend via `process!(::Scene, ::AbstractEvent)`
# - events are forwarded to `process!(::Interactions, ::AbstractEvent, ::Scene)`
# - and then `process!(interaction, ::AbstractEvent, ::Scene)`
#   - Interactions are sorted by priority (high first)
#   - events can be consumed by returning true
# - if an event has not been processed/consumed, it will be forwarded to child scenes

const MAX_PRIORITY = typemax(Int8)
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

function deregister!(col::Interactions, key::Symbol)
    _priority, idx = col.keymap[key]
    deleteat!(col.interactions, idx)
    
    i = findfirst(i -> i == idx, col.prioritymap[_priority])
    deleteat!(col.prioritymap[_priority], i)
    need_update = if isempty(col.prioritymap[_priority])
        delete!(col.prioritymap, _priority)
        true
    else
        col.prioritymap[_priority][i:end] .-= 1
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
        return maybe_remove_priority!(target.parent, _priority)
    end
end



# Could probably be optimized, but I don't think it's worth it.
function Base.replace!(
        f::Function, target::Union{SceneLike, AbstractPlot}, key, 
        _priority = DEFAULT_PRIORITY
    )
    replace!(target, key, f, _priority)
end
function Base.replace!(
        target::Union{SceneLike, AbstractPlot}, key, @nospecialize(int), 
        _priority = DEFAULT_PRIORITY
    )
    if haskey(target.interactions.keymap, key)
        deregister!(target.interactions, key)
    end
    register!(target.interactions, key, int, _priority)
    add_priority!(target, _priority)
    nothing
end



hasinteraction(target, key) = haskey(target.interactions.keymap, key)
hasinteraction(col::Interactions, key) = haskey(col.keymap, key)
function hasinteraction(target::Scene, key, recursive)
    result = haskey(target.interactions.keymap, key)
    if recusive
        result && return true
        for plot in target.plots
            hasinteraction(plot, key, true) && return true
        end
        for child in target.children
            hasinteraction(plot, key, true) && return true
        end
    else
        return result
    end
end
function hasinteraction(target::AbstractPlot, key, recursive)
    result = haskey(target.interactions.keymap, key)
    if recusive
        result && return true
        for plot in target.plots
            hasinteraction(plot, key, true) && return true
        end
    else
        return result
    end
end

function Base.getindex(col::Interactions, key::Symbol)
    _, idx = col.keymap[key]
    col.interactions[idx]
end
    


# event dispatch
# It should go:
# Backend -> process!(root_scene, event)
#         -> process!(child_or_plot, event, priority) ... (recursively)
#         -> process!(interactions, event, priority)
#         -> process!(interaction, event, parent_plot_or_scene)
function process!(root::Scene, @nospecialize(event))
    # Nope, this should be the currently displayed scene instead
    # @assert isroot(root) "The event entrypoint should only be called using the root scene!"

    # Update state first so that the state is always the current state
    update_state!(root.input_state, event)

    # process by priority first, reverse render order second
    for _priority in reverse(root.interactions.active)
        for plot in reverse(root.plots)
            process!(plot, event, _priority) && return nothing
        end
        for child in reverse(root.children)
            process!(child, event, _priority) && return nothing
        end        
        # Should this happen before plots?
        process!(root.interactions, event, root, _priority) && return nothing
    end

    return nothing
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


# Update input states
update_state!(@nospecialize(args...)) = nothing
update_state!(state, event::WindowResizeEvent) = state.window_area = event.area
update_state!(state, event::WindowDPIEvent) = state.window_dpi = event.dpi
update_state!(state, event::WindowOpenEvent) = state.window_open = event.is_open
update_state!(state, event::WindowFocusEvent) = state.window_focused = event.is_focused
update_state!(state, event::WindowHoverEvent) = state.window_hovered = event.is_hovered

function update_state!(state, event::MouseButtonEvent)
    if event.action == Mouse.press
        push!(state.mouse_buttons, event.button)
        event.button == Mouse.left   && push!(state.mouse_state, Mouse.left_press)
        event.button == Mouse.middle && push!(state.mouse_state, Mouse.middle_press)
        event.button == Mouse.right  && push!(state.mouse_state, Mouse.right_press)
    else # release
        delete!(state.mouse_buttons, event.button)
        if event.button == Mouse.left   
            delete!(state.mouse_state, Mouse.left_press)
            delete!(state.mouse_state, Mouse.left_repeat)
            push!(state.mouse_state, Mouse.left_release)
        elseif event.button == Mouse.middle 
            delete!(state.mouse_state, Mouse.middle_press)
            delete!(state.mouse_state, Mouse.middle_repeat)
            push!(state.mouse_state, Mouse.middle_release)
        elseif event.button == Mouse.right  
            delete!(state.mouse_state, Mouse.right_press)
            delete!(state.mouse_state, Mouse.right_repeat)
            push!(state.mouse_state, Mouse.right_release)
        end
    end
    nothing
end
function update_state!(state, event::MouseMovedEvent)
    state.mouse_movement = event.position - state.mouse_position
    state.mouse_position = event.position
    if Mouse.left_press in state.mouse_state
        delete!(state.mouse_state, Mouse.left_press)
        push!(state.mouse_state, Mouse.left_repeat)
    elseif Mouse.middle_press in state.mouse_state
        delete!(state.mouse_state, Mouse.middle_press)
        push!(state.mouse_state, Mouse.middle_repeat)
    elseif Mouse.right_press in state.mouse_state
        delete!(state.mouse_state, Mouse.right_press)
        push!(state.mouse_state, Mouse.right_repeat)
    end
    nothing
end

function update_state!(state, event::KeyEvent)
    if event.action == Keyboard.release
        delete!(state.keyboard_buttons, event.key)
    elseif event.action == Keyboard.press
        push!(state.keyboard_buttons, event.key)
    else # repeat
        # This means a key <press> event wasn't caught. If that actually happens
        # we should probably push!() here too
        @assert(
            event.key in state.keyboard_buttons,
            "Key $(event.key) should be in state 'pressed' but isn't."
        )
    end
    nothing
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