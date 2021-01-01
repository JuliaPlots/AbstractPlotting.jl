#=
Figures are supposed to fill the gap that Scenes in combination with Layoutables leave.
A scene is supposed to be a generic canvas on which plot objects can be placed and drawn.
Layoutables always require one specific type of scene, with a PixelCamera, in order to draw
their visual components there.
Figures also have layouts, which scenes do not have.
This is because every figure needs a layout, while not every scene does.
Figures keep track of the Layoutables that are created inside them, which scenes don't.

The idea is there are three types of plotting commands.
They can return either:
    - a FigureAxisPlot (figure, axis and plot)
    - an AxisPlot (axis and plot)
    - or an AbstractPlot (only plot)

This is needed so that users can without much boilerplate create the necessary structures and access them accordingly.

A normal plotting command creates a FigureAxisPlot, which can be splatted into figure, axis and plot. It displays like a figure, so that simple plots show up immediately.

A non-mutating plotting command that references a FigurePosition or a FigureSubposition creates an axis at that position and returns an AxisPlot, which can be splatted into axis and plot.

All mutating plotting commands return AbstractPlots.
They can either reference a FigurePosition or a FigureSubposition, in which case it is looked up
if an axis is placed at that position (if not it errors) or it can reference an axis directly to plot into.
=#

get_scene(fig::Figure) = fig.scene

const _current_figure = Ref{Union{Nothing, Figure}}(nothing)
current_figure() = _current_figure[]
current_figure!(fig) = (_current_figure[] = fig)

current_axis() = current_axis(current_figure())
current_axis(fig::Figure) = fig.current_axis[]
function current_axis!(fig::Figure, ax)
    if ax.parent !== fig
        error("This axis' parent is not the given figure")
    end
    fig.current_axis[] = ax
    ax
end
function current_axis!(ax)
    fig = ax.parent
    if !(fig isa Figure)
        error("Axis parent is not a figure but a $(typeof(ax.parent)). Only axes in figures can have current_axis! called on them.")
    end

    current_axis!(fig, ax)
    # if the current axis is in a different figure, we switch to that as well
    # so that current_axis and current_figure are not out of sync
    current_figure!(fig)
    ax
end

function Figure(; kwargs...)
    scene, layout = layoutscene(; kwargs...)
    Figure(
        scene,
        layout,
        [],
        Attributes(),
        Ref{Any}(nothing)
    )
end

export Figure, current_axis, current_figure, current_axis!, current_figure!

# the FigurePosition is used to plot into a specific part of a figure and create
# an axis there, like `scatter(fig[1, 2], ...)`
struct FigurePosition
    fig::Figure
    gp::GridLayoutBase.GridPosition
end

function Base.getindex(fig::Figure, rows, cols, side = GridLayoutBase.Inner())
    FigurePosition(fig, fig.layout[rows, cols, side])
end

function Base.setindex!(fig::Figure, obj, rows, cols, side = GridLayoutBase.Inner())
    fig.layout[rows, cols, side] = obj
    register_in_figure!(fig, obj)
    obj
end

Base.lastindex(f::Figure, i) = lastindex(f.layout, i)
Base.lastindex(f::FigurePosition, i) = lastindex(f.fig, i)

# for now just redirect figure display/show to the internal scene
Base.show(io::IO, fig::Figure) = show(io, fig.scene)
Base.display(fig::Figure) = display(fig.scene)
Base.show(io::IO, ::MIME"text/plain", fig::Figure) = print(io, "Figure()")
# Base.show(io::IO, ::MIME"image/svg+xml", fig::Figure) = show(io, MIME"image/svg+xml"(), fig.scene)
Base.show(io::IO, ::MIME"image/png", fig::Figure) = show(io, MIME"image/png"(), fig.scene)

# a FigureSubposition is just a deeper nested position in a figure's layout, and it doesn't
# necessarily have to refer to an existing layout either, because those can be created
# when it becomes necessary
struct FigureSubposition{T}
    parent::T
    rows
    cols
    side::GridLayoutBase.Side
end

# fp[1, 2] creates a FigureSubposition, a nested version of FigurePosition
# currently, because at the time of creation there is not necessarily a gridlayout
# at all nested locations, the end+1 syntax doesn't work, because it's not known how many
# rows/cols the nested grid has if it doesn't exist yet
function Base.getindex(parent::Union{FigurePosition,FigureSubposition},
        rows, cols, side = GridLayoutBase.Inner())
    FigureSubposition(parent, rows, cols, side)
end

function Base.setindex!(parent::Union{FigurePosition,FigureSubposition}, obj,
    rows, cols, side = GridLayoutBase.Inner())

    layout = find_or_make_layout!(parent)
    figure = get_figure(parent)
    layout[rows, cols, side] = obj
    register_in_figure!(figure, obj)
    obj
end

function Base.setindex!(parent::FigurePosition, obj)
    parent.gp[] = obj
    figure = get_figure(parent)
    register_in_figure!(figure, obj)
    obj
end

function Base.setindex!(parent::FigureSubposition, obj)
    layout = find_or_make_layout!(parent.parent)
    figure = get_figure(parent)
    layout[parent.rows, parent.cols, parent.side] = obj
    register_in_figure!(figure, obj)
    obj
end

function register_in_figure!(fig::Figure, gridlayout::GridLayoutBase.GridLayout)
    # do nothing, gridlayouts don't need to be specifically added to the content list
end

# to power a simple syntax for plotting into nested grids like
# `scatter(fig[1, 1][2, 3], ...)` we need to either find the only gridlayout that
# sits at that position, or we create all the ones that are missing along the way
# as a convenience, so that users don't have to manually create gridlayouts all that often
function find_or_make_layout!(fp::FigurePosition)
    c = contents(fp.gp, exact = true)
    layouts = filter(x -> x isa GridLayoutBase.GridLayout, c)
    if isempty(layouts)
        return fp.gp[] = GridLayoutBase.GridLayout()
    elseif length(layouts) == 1
        return only(layouts)
    else
        error("Found more than zero or one GridLayouts at $(fp.gp)")
    end
end

function find_or_make_layout!(layout::GridLayoutBase.GridLayout, fsp::FigureSubposition)
    gp = layout[fsp.rows, fsp.cols, fsp.side]
    c = contents(gp, exact = true)
    layouts = filter(x -> x isa GridLayoutBase.GridLayout, c)
    if isempty(layouts)
        return gp[] = GridLayoutBase.GridLayout()
    elseif length(layouts) == 1
        return only(layouts)
    else
        error("Found more than zero or one GridLayouts at $(gp)")
    end
end

function find_or_make_layout!(fsp::FigureSubposition)
    layout = find_or_make_layout!(fsp.parent)
    find_or_make_layout!(layout, fsp)
end


get_figure(fsp::FigureSubposition) = get_figure(fsp.parent)
get_figure(fp::FigurePosition) = fp.fig
