function AbstractPlotting.plot!(
        lscene::LScene, P::AbstractPlotting.PlotFunc,
        attributes::AbstractPlotting.Attributes, args...;
        kw_attributes...)

    plot = AbstractPlotting.plot!(lscene.scene, P, attributes, args...; kw_attributes...)[end]

    plot
end

protrusionnode(ls::LScene) = ls.layoutobservables.protrusions
reportedsizenode(ls::LScene) = ls.layoutobservables.reportedsize

function LScene(parent::Scene; bbox = nothing, scenekw = NamedTuple(), kwargs...)

    default_attrs = default_attributes(LScene, parent).attributes
    theme_attrs = subtheme(parent, :LScene)
    attrs = merge!(merge!(Attributes(kwargs), theme_attrs), default_attrs)

    layoutobservables = LayoutObservables(LScene, attrs.width, attrs.height, attrs.tellwidth, attrs.tellheight,
        attrs.halign, attrs.valign, attrs.alignmode; suggestedbbox = bbox)

    scene = Scene(parent, lift(IRect2D_rounded, layoutobservables.computedbbox); scenekw...)

    LScene(scene, attrs, layoutobservables)
end
