function LAxis3D(parent::Scene; bbox = nothing, kwargs...)

    default_attrs = default_attributes(LAxis3D, parent).attributes
    theme_attrs = subtheme(parent, :LAxis3D)
    attrs = merge!(merge!(Attributes(kwargs), theme_attrs), default_attrs)

    decorations = Dict{Symbol, Any}()

    layoutobservables = LayoutObservables{LAxis3D}(attrs.width, attrs.height, attrs.tellwidth, attrs.tellheight, attrs.halign, attrs.valign, attrs.alignmode;
        suggestedbbox = bbox)

    scenearea = lift(round_to_IRect2D, layoutobservables.computedbbox)

    scene = Scene(parent, scenearea, raw = true, camera = cam3d!)

    linesegments!(scene, Point3f0[(0, 0, 0), (1, 0, 0), (0, 0, 0), (0, 1, 0), (0, 0, 0), (0, 0, 1)], raw = true)

    LAxis3D(parent, scene, layoutobservables, attrs)
end

function default_attributes(::Type{LAxis3D}, scene)
    attrs, docdict, defaultdict = @documented_attributes begin
        "The vertical alignment of the axis within its suggested bounding box."
        valign = :center
        "The horizontal alignment of the axis within its suggested bounding box."
        halign = :center
        "The width of the axis."
        width = nothing
        "The height of the axis."
        height = nothing
        "Controls if the parent layout can adjust to this element's width"
        tellwidth = true
        "Controls if the parent layout can adjust to this element's height"
        tellheight = true
        "The background color of the axis."
        backgroundcolor = :white
        "The align mode of the axis in its parent GridLayout."
        alignmode = Inside()
        "3D Limits"
        limits = FRect3D((0, 0, 0), (1, 1, 1))
    end

    (attributes = attrs, documentation = docdict, defaults = defaultdict)
end

@doc """
LAxis has the following attributes:

$(let
    _, docs, defaults = default_attributes(LAxis, nothing)
    docvarstring(docs, defaults)
end)
"""
LAxis


function AbstractPlotting.plot!(
    la::LAxis3D, P::AbstractPlotting.PlotFunc,
    attributes::AbstractPlotting.Attributes, args...;
    kw_attributes...)

    plot = AbstractPlotting.plot!(la.scene, P, attributes, args...; kw_attributes...)[end]

    # autolimits!(la)
    plot
end