abstract type AbstractCamera end

# placeholder if no camera is present
struct EmptyCamera <: AbstractCamera end
cleanup!(scene, ::EmptyCamera) = nothing
cleanup!(scene, c::AbstractCamera) = @warn "Missing `cleanup!(scene, ::$(typeof(c)))`"

@enum RaymarchAlgorithm begin
    IsoValue # 0
    Absorption # 1
    MaximumIntensityProjection # 2
    AbsorptionRGBA # 3
    AdditiveRGBA # 4
    IndexedAbsorptionRGBA # 5
end

include("interaction/iodevices.jl")

# TODO maybe remove? deprecate?
"""
This struct provides accessible `Observable`s to monitor the events
associated with a Scene.

## Fields
$(TYPEDFIELDS)
"""
struct Events
    # exists as ...
    """
    The area of the window in pixels, as a `Rect2D`.
    """
    window_area::Node{IRect2D} # WindowResizeEvent, Node
    """
    The DPI resolution of the window, as a `Float64`.
    """
    window_dpi::Node{Float64} # WindowDPIEvent
    """
    The state of the window (open => true, closed => false).
    """
    window_open::Node{Bool} # WindowOpenEvent

    """
    The pressed mouse buttons.
    Updates when a mouse button is pressed.

    See also [`ispressed`](@ref).
    """
    mousebuttons::Node{Set{Mouse.Button}} # MouseClickedEvent
    """
    The position of the mouse as a `NTuple{2, Float64}`.
    Updates whenever the mouse moves.
    """
    mouseposition::Node{NTuple{2, Float64}} # MouseMovedEvent
    """
The state of the mouse drag, represented by an enumerator of `DragEnum`.
    """
    mousedrag::Node{Mouse.DragEnum} # -
    """
    The direction of scroll
    """
    scroll::Node{NTuple{2, Float64}} # MouseScrolledEvent

    """
    See also [`ispressed`](@ref).
    """
    keyboardbuttons::Node{Set{Keyboard.Button}} # KeyEvent

    unicode_input::Node{Vector{Char}} # UnicodeInputEvent
    dropped_files::Node{Vector{String}} # DroppedFilesEvent
    """
    Whether the Scene window is in focus or not.
    """
    hasfocus::Node{Bool} # WindowFocusEvent
    entered_window::Node{Bool} # WindowEnteredEvent
end

function Events()
    return Events(
        Node(IRect(0, 0, 0, 0)), # area
        Node(100.0), # dpi
        Node(false), #open

        Node(Set{Mouse.Button}()), # mosue buttons
        Node((0.0, 0.0)), # psotion
        Node(Mouse.notpressed), # drag
        Node((0.0, 0.0)), # scroll

        Node(Set{Keyboard.Button}()), # keys

        Node(Char[]), # unicode input
        Node(String[]), # dropped_files
        Node(false), # has focus
        Node(false), # entered window
    )
end


mutable struct InputState
    window_area::IRect2D # exists in scene
    window_dpi::Float64
    window_open::Bool
    window_focused::Bool
    window_hovered::Bool # (entered_window)

    mouse_buttons::Set{Mouse.Button}
    mouse_position::Vec2f0
    mouse_movement::Vec2f0 # current_position - old_position
    # left/middle/right press/repeat/release
    # should this really be here? Should keyboard have soemthing similar?
    mouse_state::Set{Mouse.DragState}
    # mouse_scroll::Vec2f0 # not persistent - not useful as state?

    keyboard_buttons::Set{Keyboard.Button}
    # unicode_input::Vector{Char} # not persistent - not useful as state
    # dropped_files::Vector{String} # persistent, but not cummulative, makes more sense to process as event
end
function InputState()
    InputState(
        IRect(0,0,0,0), 100.0, false, false, false,
        Set{Mouse.Button}(), Vec2f0(0), Vec2f0(0), Set{Mouse.DragState}(),
        Set{Keyboard.Button}()
    )
end

# Dispatchable events
abstract type AbstractEvent end
abstract type AbstractKeyboardEvent <: AbstractEvent end
abstract type AbstractMouseEvent <: AbstractEvent end
abstract type AbstractWindowEvent <: AbstractEvent end


# all the key presses (== keyboardbuttons)
struct KeyEvent <: AbstractKeyboardEvent
    key::Keyboard.Button
    action::Keyboard.Action
    # mod::ButtonModifier
end

# unicode_input
struct UnicodeInputEvent <: AbstractKeyboardEvent
    char::Char
end

# all the mouse button presses (== mousebuttons)
struct MouseButtonEvent <: AbstractMouseEvent
    button::Mouse.Button
    action::Mouse.Action
    # mod::ButtonModifier
end

# mousepositions -> mousedrag?
struct MouseMovedEvent <: AbstractMouseEvent
    position::Vec2f0
end

struct MouseScrolledEvent <: AbstractMouseEvent
    delta::Vec2f0
end

# Window events
struct WindowResizeEvent <: AbstractWindowEvent
    area::IRect2D
end
struct WindowDPIEvent <: AbstractWindowEvent
    dpi::Float64
end
struct WindowOpenEvent <: AbstractWindowEvent
    is_open::Bool
end
struct DroppedFilesEvent <: AbstractWindowEvent
    files::Vector{String}
end
struct WindowFocusEvent <: AbstractWindowEvent
    is_focused::Bool
end
struct WindowHoverEvent <: AbstractWindowEvent
    is_hovered::Bool
end

# ticks once per render - might be useful for animations?
struct RenderTickEvent <: AbstractEvent end

struct Interactions
    # active here or in child scenes/plots
    active::Vector{Int8}
    prioritymap::Dict{Int8, Vector{Int}}
    keymap::Dict{Symbol, Tuple{Int8, Int}}
    interactions::Vector{Any}
end
Interactions() = Interactions(Vector{Int8}(), Dict{Int8, Vector{Int}}(), Dict{Symbol, Tuple{Int8, Int}}(), Any[])


mutable struct Camera
    pixel_space::Node{Mat4f0}
    view::Node{Mat4f0}
    projection::Node{Mat4f0}
    projectionview::Node{Mat4f0}
    resolution::Node{Vec2f0}
    eyeposition::Node{Vec3f0}
    steering_nodes::Vector{Any}
end

"""
Holds the transformations for Scenes.

## Fields
$(TYPEDFIELDS)
"""
struct Transformation <: Transformable
    parent::RefValue{Transformable}
    translation::Node{Vec3f0}
    scale::Node{Vec3f0}
    rotation::Node{Quaternionf0}
    model::Node{Mat4f0}
    flip::Node{NTuple{3, Bool}}
    align::Node{Vec2f0}
    # data conversion node, for e.g. log / log10 etc
    transform_func::Node{Any}
    function Transformation(translation, scale, rotation, model, flip, align, transform_func)
        return new(
            RefValue{Transformable}(),
            translation, scale, rotation, model, flip, align, transform_func
        )
    end
end

struct Combined{Typ, T} <: ScenePlot{Typ}
    parent::SceneLike
    transformation::Transformation
    attributes::Attributes
    input_args::Tuple
    converted::Tuple
    interactions::Interactions
    plots::Vector{AbstractPlot}
end

function Base.show(io::IO, plot::Combined)
    print(io, typeof(plot))
end

parent(x::AbstractPlot) = x.parent

function func2string(func::F) where F <: Function
    string(F.name.mt.name)
end

plotkey(::Type{<: AbstractPlot{Typ}}) where Typ = Symbol(lowercase(func2string(Typ)))
plotkey(::T) where T <: AbstractPlot = plotkey(T)

plotfunc(::Type{<: AbstractPlot{Func}}) where Func = Func
plotfunc(::T) where T <: AbstractPlot = plotfunc(T)
plotfunc(f::Function) = f

func2type(x::T) where T = func2type(T)
func2type(x::Type{<: AbstractPlot}) = x
func2type(f::Function) = Combined{f}


"""
Billboard attribute to always have a primitive face the camera.
Can be used for rotation.
"""
struct Billboard end

"""
Type to indicate that an attribute will get calculated automatically
"""
struct Automatic end

"""
Singleton instance to indicate that an attribute will get calculated automatically
"""
const automatic = Automatic()


"""
`PlotSpec{P<:AbstractPlot}(args...; kwargs...)`

Object encoding positional arguments (`args`), a `NamedTuple` of attributes (`kwargs`)
as well as plot type `P` of a basic plot.
"""
struct PlotSpec{P<:AbstractPlot}
    args::Tuple
    kwargs::NamedTuple
    PlotSpec{P}(args...; kwargs...) where {P<:AbstractPlot} = new{P}(args, values(kwargs))
end

PlotSpec(args...; kwargs...) = PlotSpec{Combined{Any}}(args...; kwargs...)

Base.getindex(p::PlotSpec, i::Int) = getindex(p.args, i)
Base.getindex(p::PlotSpec, i::Symbol) = getproperty(p.kwargs, i)

to_plotspec(::Type{P}, args; kwargs...) where {P} =
    PlotSpec{P}(args...; kwargs...)

to_plotspec(::Type{P}, p::PlotSpec{S}; kwargs...) where {P, S} =
    PlotSpec{plottype(P, S)}(p.args...; p.kwargs..., kwargs...)

plottype(::PlotSpec{P}) where {P} = P
