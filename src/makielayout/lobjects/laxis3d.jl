function LAxis3D(parent::Scene; bbox = nothing, kwargs...)

    default_attrs = default_attributes(LAxis3D, parent).attributes
    theme_attrs = subtheme(parent, :LAxis3D)
    attrs = merge!(merge!(Attributes(kwargs), theme_attrs), default_attrs)

    decorations = Dict{Symbol, Any}()

    layoutobservables = LayoutObservables{LAxis3D}(attrs.width, attrs.height, attrs.tellwidth, attrs.tellheight, attrs.halign, attrs.valign, attrs.alignmode;
        suggestedbbox = bbox)

    scenearea = lift(round_to_IRect2D, layoutobservables.computedbbox)

    scene = Scene(parent, scenearea, raw = true)
    campixel!(scene)

    attrs.limits = Node(FRect3D((0, 0, 0), (1, 1, 1)))

    attrs.frameflips = Node((false, false, false))

    # camera position
    attrs.camerapos = Node(Vec3f0(-10, -10, -10))
    attrs.cameralookat = Node(Vec3f0(0, 0, 0))
    attrs.camera_upvector = Node(Vec3f0(0, 1, 0))
    xyz_scaling = Node(Vec3f0(1, 1, 1))

    attrs.fovy = Node(45.0f0)
    attrs.aspect = Node(1.0f0)
    attrs.znear = Node(-10f0)
    attrs.zfar = Node(10_000f0)

    viewmatrix = lift(AbstractPlotting.lookat, attrs.camerapos, attrs.cameralookat, attrs.camera_upvector)

    perspecmat = lift(AbstractPlotting.perspectiveprojection, attrs.fovy, attrs.aspect, attrs.znear, attrs.zfar)

    on(viewmatrix) do vm
        camera(scene).view[] = vm
        camera(scene).projectionview[] = perspecmat[] * vm
    end

    on(perspecmat) do pm
        camera(scene).projection[] = pm
        camera(scene).projectionview[] = pm * viewmatrix[]
    end

    viewmatrix[] = viewmatrix[]
    perspecmat[] = perspecmat[]

    # camera lookat
    # camera upvector
    # xyz scaling factors
    # field of view / orthographic?

    linesegments!(scene, Point3f0[(0, 0, 0), (1, 0, 0), (0, 0, 0), (0, 1, 0), (0, 0, 0), (0, 0, 1)], color = [:red, :green, :blue])
    # for dim in 1:3
    #     add_frame!(scene, attrs.limits, attrs.frameflips, dim)
    # end

    LAxis3D(parent, scene, layoutobservables, attrs)
end


function add_frame!(scene, limits, flips, dim)

    framepoints = lift(limits, flips) do lims, flips

        dim_extrema = (minimum(limits)[dim], maximum(limits)[dim])
        dim_limit = dim_extrema[flips[dim]+1]

        

    end

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
LAxis3D has the following attributes:

$(let
    _, docs, defaults = default_attributes(LAxis3D, nothing)
    docvarstring(docs, defaults)
end)
"""
LAxis3D


function AbstractPlotting.plot!(
    la::LAxis3D, P::AbstractPlotting.PlotFunc,
    attributes::AbstractPlotting.Attributes, args...;
    kw_attributes...)

    plot = AbstractPlotting.plot!(la.scene, P, attributes, args...; kw_attributes...)[end]

    # autolimits!(la)
    plot
end