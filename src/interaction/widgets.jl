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

function Base.convert(::Type{S}, w::Widget) where {S <: Scene}
    convert(S, Widgets.render(w))
end

Widgets.manipulatelayout(::MakieBackend) = hbox
