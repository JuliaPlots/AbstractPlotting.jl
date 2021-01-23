module MouseEventTypes
    @enum MouseEventType begin
        enter
        over
        out
        leftdown
        rightdown
        middledown
        leftup
        rightup
        middleup
        leftdragstart
        rightdragstart
        middledragstart
        leftdrag
        rightdrag
        middledrag
        leftdragstop
        rightdragstop
        middledragstop
        leftclick
        rightclick
        middleclick
        leftdoubleclick
        rightdoubleclick
        middledoubleclick
        downoutside
        upoutside
    end
    export MouseEventType
end

using .MouseEventTypes

"""
    MouseStateEvent

Describes a mouse state change.

Fields:
- `type`: MouseEventType
- `data`: Mouse position in data coordinates
- `px`: Mouse position in px relative to scene origin
- `prev_data`: Previous mouse position in data coordinates
- `prev_px`: Previous mouse position in px relative to scene origin
"""
struct MouseStateEvent <: AbstractMouseEvent
    type::MouseEventType

    data::Point2f0
    px::Point2f0

    prev_data::Point2f0
    prev_px::Point2f0
end

mutable struct MouseStateMachine
    # state
    prev_t::Float64     # time of last click (for doubleclick)
    prev_data::Point2f0 # mouseposition in data coordinates
    prev_px::Point2f0   # mouseposition in pixel coordinates

    dragging::Bool
    tracked_button::Mouse.Button # for draging and (double-)clicking
    last_click::Mouse.Button     # for doubleclick
    was_over::Bool               # ... relevant plots/scene

    # Settings
    doubleclick_timeout::Float64
    plots::Vector{AbstractPlot} # restrict to events on those - if empty ignore
    consume_source_events::Bool
end

function MouseStateMachine(
        prev_data = Point2f0(0), prev_px = Point2f0(0), plots = AbstractPlot[]; 
        doubleclick_timeout = 0.2, consume_source_events = true
    )
    MouseStateMachine(
        time(), Point2f0(0), Point2f0(0),
        false, Mouse.none, Mouse.none, false,
        doubleclick_timeout, AbstractPlot[p for p in plots], consume_source_events
    )
end

"""
    MouseStateMachine(scene[, elements...; kwargs...])

Creates and attaches a `MouseStateMachine` that produces `MouseStateEvents` in 
the given `scene`. These events will propagate to any attached plot, but not to 
other scenes.

`MouseStateEvent`s are usually produced when the mouse hovers over the given 
`elements` (which are plots) or, if those are empty, the given `scene`. 
Exceptions include dragging and hover events.

To react to a `MouseStateEvent` you may implement an interaction for it. E.g.
`register!(scene, name) do e::MouseStateEvent, parent; ... end`.

Keyword Arguments:
- `priority = DEFAULT_UI_PRIORITY`: Priority of the `MouseStateMachine`. 
Interactions with higher priority may stop `MouseStateEvent`s from being 
produced and those with lower priority may be skipped.
- `doubleclick_timeout = 0.2`: Maximum time between two clicks for them to 
register as a doubleclick.
- `consume_source_events = true`: Controls whether consuming a `MouseStateEvent`
also consumes the `MouseMovedEvent` or `MouseButtonEvent` it originates from.
"""
function MouseStateMachine(
        scene::Scene, plots::AbstractPlot...; 
        priority = DEFAULT_UI_PRIORITY, kwargs...
    )
    msm = MouseStateMachine(
        mouseposition(scene), mouseposition_px(scene), plots; kwargs...
    )
    replace!(scene, :mousestatemachine, msm, )
end

function spawn!(
        scene, state, type, 
        data = state.prev_data, px = state.prev_px, 
        prev_data = state.prev_data, prev_px = state.prev_px
    )

    event = MouseStateEvent(type, data, px, prev_data, prev_px)
    
    # similar to root process, but doesn't update the global state and doesn't
    # dispatch to subscenes.
    processed = false
    for _priority in reverse(scene.interactions.active)
        for plot in reverse(scene.plots)
            processed = processed || process!(plot, event, _priority)
            processed && @goto finish
        end    
        # Should this happen before plots?
        processed = processed || process!(scene.interactions, event, scene, _priority)
        processed && @goto finish
    end

    @label finish
    return state.consume_source_events && processed
end

function process!(state::MouseStateMachine, event::MouseButtonEvent, parent)
    # TODO
    # Do we need to update positions here? 
    # The saved positions should always be as up to date as they can be based
    # on MouseMovedEvent triggers. The only time they may not be is if a 
    # MouseButtonEvent happens before any MouseMovedEvent - highly unlikely?

    hovered = isempty(state.plots) ? is_mouseinside(parent) : mouseover(parent, state.plots)

    if event.action == Mouse.press

        # This should happen even if we're outside so we don't freeze?
        if state.tracked_button != Mouse.none
            # reset tracking and finish drag if something else is tracked
            state.tracked_button = Mouse.none
            if state.dragging
                state.dragging = false
                type = @match state.tracked_button begin
                    Mouse.left => MouseEventTypes.leftdragstop
                    Mouse.right => MouseEventTypes.rightdragstop
                    Mouse.middle => MouseEventTypes.middledragstop
                    x => error("No recognized mouse button $x")
                end
                spawn!(parent, state, type) && return true
            end
        elseif hovered
            # Only initiate drag and clicks when inside
            state.tracked_button = event.button
        end

        # dispatch down event
        if hovered
            type = @match event.button begin
                Mouse.left => MouseEventTypes.leftdown
                Mouse.right => MouseEventTypes.rightdown
                Mouse.middle => MouseEventTypes.middledown
                x => error("No recognized mouse button $x")
            end
            spawn!(parent, state, type) && return true
        else
            spawn!(parent, state, MouseEventTypes.downoutside) && return true
        end

    else # release

        tracked_button = state.tracked_button
        was_none = tracked_button == Mouse.none # TODO remove
        state.tracked_button = Mouse.none
        @assert was_none || (tracked_button != Mouse.none) "For verifying only" # TODO remove
    
        # double-/click/dragstop
        if event.button == tracked_button
            if state.dragging
                # Should happen inside and outside the area to finalize drag
                state.dragging = false
                type = @match event.button begin
                    Mouse.left => MouseEventTypes.leftdragstop
                    Mouse.right => MouseEventTypes.rightdragstop
                    Mouse.middle => MouseEventTypes.middledragstop
                    x => error("No recognized mouse button $x")
                end
                spawn!(parent, state, type) && return true

            else # do clicks
                # implicitly inside/hovered because we didn't move
                # (if we did we would be dragging)

                # double click
                if event.button == state.last_click && (time() - state.prev_t) < state.doubleclick_timeout
                    type = @match event.button begin
                        Mouse.left => MouseEventTypes.leftdoubleclick
                        Mouse.right => MouseEventTypes.rightdoubleclick
                        Mouse.middle => MouseEventTypes.middledoubleclick
                        x => error("No recognized mouse button $x")
                    end
                    # This means the next click cannot reach this branch
                    state.last_click = Mouse.none
                    spawn!(parent, state, type) && return true
                else # click not a double click - update state
                    state.last_click = event.button
                    state.prev_t = time()
                end

                # single click
                # this also happens if the doubleclick is ignored/not consumed
                type = @match event.button begin
                    Mouse.left => MouseEventTypes.leftclick
                    Mouse.right => MouseEventTypes.rightclick
                    Mouse.middle => MouseEventTypes.middleclick
                    x => error("No recognized mouse button $x")
                end
                spawn!(parent, state, type) && return true
            end
        end

        # do up
        if hovered
            type = @match event.button begin
                Mouse.left => MouseEventTypes.leftup
                Mouse.right => MouseEventTypes.rightup
                Mouse.middle => MouseEventTypes.middleup
                x => error("No recognized mouse button $x")
            end
            spawn!(parent, state, type) && return true
        else
            spawn!(parent, state, MouseEventTypes.upoutside) && return true
        end
    end

    return false
end

function process!(state::MouseStateMachine, event::MouseMovedEvent, parent)
    prev_data = state.prev_data
    prev_px = state.prev_px
    data = state.prev_data = mouseposition(parent)
    px = state.prev_px = mouseposition_px(parent)
    hovered = isempty(state.plots) ? is_mouseinside(parent) : mouseover(parent, state.plots)
    
    if state.tracked_button != Mouse.none
        if !state.dragging
            state.dragging = true
            type = @match state.tracked_button begin
                Mouse.left => MouseEventTypes.leftdragstart
                Mouse.right => MouseEventTypes.rightdragstart
                Mouse.middle => MouseEventTypes.middledragstart
                x => error("No recognized mouse button $x")
            end
            spawn!(parent, state, type, data, px, prev_data, prev_px) && return true
        end

        type = @match state.tracked_button begin
            Mouse.left => MouseEventTypes.leftdrag
            Mouse.right => MouseEventTypes.rightdrag
            Mouse.middle => MouseEventTypes.middledrag
            x => error("No recognized mouse button $x")
        end
        spawn!(parent, state, type, data, px, prev_data, prev_px) && return true
    end

    # enter/over/out
    if (state.was_over && hovered) 
        return spawn!(parent, state, MouseEventTypes.over, data, px, prev_data, prev_px)
    elseif (state.was_over && !hovered)
        state.was_over = false
        return spawn!(parent, state, MouseEventTypes.out, data, px, prev_data, prev_px)
    elseif (!state.was_over && hovered)
        state.was_over = true
        return spawn!(parent, state, MouseEventTypes.enter, data, px, prev_data, prev_px)
    else
        return false
    end
end


#=
How this is supposed to work:

# First create a scene (with plots) which is supposed to use MouseStateEvent
scene = Scene()
p1 = poly!(scene, ...)

# add the MouseStateMachine as an interaction
# the MouseStateMachine slots into the priority system as usual, meaning
# anything with hgiher prority may stop MouseStateEvents from spawning
# anything with lower priority may be stopped by consumed MouseStateEvents
# this affects MouseMovedEvent and MouseButtonEvent
msm = MouseStateMachine(scene, p1)
register!(scene, :mousestatemachine, msm, DEFAULT_UI_PRIORITY)

# MouseStateEvent's will now spawn on the `scene` level and propagate to plots
# they act just like usual events, but also consume the source MouseMovedEvent
# or MouseButtonEvent if they are consumed
register!(scene, :dragging_thing) do (event::MouseStateEvent, parent)
    # do stuff ...
end
=#

#=
Logic:

on button down:
  if tracked > untrack, finish drag event
  else 
      if hovered > start tracking
  if hovered > down event
  else > down outside event
on button up:
  if tracked:
      if dragging > finish drag event (drag should always get finished)
      else (implicitly hovered)
          if matches last click & fast enough > double click
          else > update state
          > single click
  if hovered > up event
  else > up outside event
on move:
  > update last position
  if tracked
      if not dragging > start dragging, drag start event (implicitly hovered)
      > drag event
  > enter/over/out event


Notes
- drag can only start inside, but continue outside
- drag finalizes when pressing another mousebuttons (anywhere)
- dragging disables click events
- no drag or click is accepted if second button is pressed
    - though a third click should start one - maybe change this?
=#