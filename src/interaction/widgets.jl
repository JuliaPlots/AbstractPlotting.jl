import Widgets
using Widgets: Widget

struct MakieBackend <: Widgets.AbstractBackend; end

function Widgets.slider(::MakieBackend, range; label = nothing)
    if label === nothing
        scn = slider(range, raw = true, camera = campixel!)
        val = scn[end][:value]
    else
        scn, val = textslider(range, label)
    end
    Widget{:slider}([:label => label], output = val, layout = _ -> scn)
end

render(x) = x
render(w::Widget) = Widgets.render(w)

Widgets.manipulatelayout(::MakieBackend) = hbox
