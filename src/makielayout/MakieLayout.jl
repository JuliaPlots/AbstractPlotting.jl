module MakieLayout

using ..AbstractPlotting
using ..AbstractPlotting: Rect2D
import ..AbstractPlotting: IRect2D
using ..AbstractPlotting.Keyboard
using ..AbstractPlotting.Mouse
using ..AbstractPlotting: ispressed, is_mouseinside, get_scene, FigureLike
using ..AbstractPlotting: _sanitize_observer_function
using ..AbstractPlotting: OpenInterval, Interval
using ..AbstractPlotting: Automatic, automatic
using Observables: onany
import Observables
import Formatting
using Match
import Animations
import PlotUtils
using GridLayoutBase
import Showoff
using Colors

const FPS = Node(30)
const COLOR_ACCENT = Ref(RGBf0(((79, 122, 214) ./ 255)...))
const COLOR_ACCENT_DIMMED = Ref(RGBf0(((174, 192, 230) ./ 255)...))

# Make GridLayoutBase default row and colgaps themeable when using MakieLayout
# This mutates module-level state so it could mess up other libraries using
# GridLayoutBase at the same time as MakieLayout, which is unlikely, though
function __init__()
    GridLayoutBase.DEFAULT_COLGAP_GETTER[] = function()
        ct = AbstractPlotting.current_default_theme()
        if haskey(ct, :colgap)
            ct[:colgap][]
        else
            GridLayoutBase.DEFAULT_COLGAP[]
        end
    end
    GridLayoutBase.DEFAULT_ROWGAP_GETTER[] = function()
        ct = AbstractPlotting.current_default_theme()
        if haskey(ct, :rowgap)
            ct[:rowgap][]
        else
            GridLayoutBase.DEFAULT_ROWGAP[]
        end
    end
end

include("layoutables.jl")
include("geometrybasics_extension.jl")
include("mousestatemachine.jl")
include("types.jl")
include("helpers.jl")
include("ticklocators/linear.jl")
include("ticklocators/wilkinson.jl")
include("defaultattributes.jl")
include("lineaxis.jl")
include("interactions.jl")
include("layoutables/axis.jl")
include("layoutables/axis3d.jl")
include("layoutables/colorbar.jl")
include("layoutables/label.jl")
include("layoutables/slider.jl")
include("layoutables/intervalslider.jl")
include("layoutables/button.jl")
include("layoutables/box.jl")
include("layoutables/toggle.jl")
include("layoutables/legend.jl")
include("layoutables/scene.jl")
include("layoutables/menu.jl")
include("layoutables/textbox.jl")

export Axis
export Axis3
export Slider
export IntervalSlider
export Button
export Colorbar
export Label
export Box
export Toggle
export Legend, axislegend
export LegendEntry, MarkerElement, PolyElement, LineElement, LegendElement
export LScene
export Menu
export Textbox
export linkxaxes!, linkyaxes!, linkaxes!
export AxisAspect, DataAspect
export autolimits!, limits!, reset_limits!
export LinearTicks, WilkinsonTicks, MultiplesTicks, IntervalsBetween, LogTicks
export hidexdecorations!, hideydecorations!, hidedecorations!, hidespines!
export tight_xticklabel_spacing!, tight_yticklabel_spacing!, tight_ticklabel_spacing!, tightlimits!
export layoutscene
export set_close_to!
export labelslider!, labelslidergrid!
export addmouseevents!
export interactions, register_interaction!, deregister_interaction!, activate_interaction!, deactivate_interaction!
export MouseEventTypes, MouseEvent, ScrollEvent, KeysEvent
export hlines!, vlines!, abline!
export Cycle


# from GridLayoutBase
export GridLayout, GridPosition
export GridLayoutSpec
export BBox
export LayoutObservables
export Inside, Outside, Mixed
export Fixed, Auto, Relative, Aspect
export width, height, top, bottom, left, right
export with_updates_suspended
export trim!
# these might conflict with other packages and are not used that often
# insertcols! does already conflict with DataFrames
# export appendcols!, appendrows!, prependcols!, prependrows!, deletecol!, deleterow!, insertrows!, insertcols!
export gridnest!
export AxisAspect, DataAspect
export colsize!, rowsize!, colgap!, rowgap!
export Left, Right, Top, Bottom, TopLeft, BottomLeft, TopRight, BottomRight

# hbox and vbox shadow AbstractPlotting functions
const hgrid! = GridLayoutBase.hbox!
const vgrid! = GridLayoutBase.vbox!

export grid!, hgrid!, vgrid!

export swap!
export ncols, nrows
export contents, content

if Base.VERSION >= v"1.4.2"
    include("precompile.jl")
    _precompile_()
end

end # module
