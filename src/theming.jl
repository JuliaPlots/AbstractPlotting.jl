
const minimal_default = Attributes(
    font = "Dejavu Sans",
    backgroundcolor = RGBAf0(1,1,1,1),
    color = Palette(ColorBrewer.palette("Dark2", 8), cycle = true),
    colormap = :viridis,
    linestyle = Palette([nothing, :dash, :dot, :dashdot, :dashdotdot], cycle = false),
    marker = Palette([:circle, :xcross, :utriangle, :diamond,
                      :dtriangle, :star6, :pentagon, :rect], cycle = false),
    resolution = reasonable_resolution(),
    visible = true,
    clear = true,
    show_axis = true,
    show_legend = false,
    scale_plot = true,
    center = true,
    axis = Attributes(),
    legend = Attributes(),
    axis_type = automatic,
    camera = automatic,
    limits = automatic,
    padding = Vec3f0(0.1),
    raw = false
)

const _current_default_theme = Attributes(; minimal_default...) # make a copy. TODO overload copy?

function current_default_theme(; kw_args...)
    new_theme, rest = merge_attributes!(Attributes(kw_args), _current_default_theme)
    merge!(new_theme, rest)
end

for (func, func!) in zip([:freeze, :reset], [:freeze!, :reset!])
    @eval begin
        $func(x, args...) = x
        $func(x::Observable{T}, args...) where {T} = Observable{T}($func(x[], args...))

        function $func!(theme::Attributes, args...)
            kwargs = ((k => $func(v, args...)) for (k, v) in theme if isa(v[], AbstractPalette) && is_cycle(v[]))
            merge!(theme, Attributes(; kwargs...))
        end
        $func(theme::Attributes, args...) = $func!(copy(theme), args...)
    end
end

function set_theme!(new_theme::Attributes)
    empty!(_current_default_theme)
    new_theme, rest = merge_attributes!(new_theme, minimal_default)
    merge!(_current_default_theme, new_theme, rest)
    return
end
function set_theme!(;kw_args...)
    set_theme!(Attributes(; kw_args...))
end
