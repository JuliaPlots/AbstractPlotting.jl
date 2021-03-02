"""
    layoutable(Axis3, fig_or_scene; bbox = nothing, kwargs...)

Creates an `Axis3` object in the parent `fig_or_scene` which consists of a child scene
with orthographic projection for 2D plots and axis decorations that live in the
parent.
"""
function layoutable(::Type{<:Axis3}, fig_or_scene::Union{Figure, Scene}; bbox = nothing, kwargs...)

    topscene = get_topscene(fig_or_scene)

    default_attrs = default_attributes(Axis3, topscene).attributes
    theme_attrs = subtheme(topscene, :Axis3)
    attrs = merge!(merge!(Attributes(kwargs), theme_attrs), default_attrs)

    @extract attrs (elevation, azimuth, perspectiveness
    )

    decorations = Dict{Symbol, Any}()

    protrusions = Node(GridLayoutBase.RectSides{Float32}(0,0,0,0))
    layoutobservables = LayoutObservables{Axis3}(attrs.width, attrs.height, attrs.tellwidth, attrs.tellheight, attrs.halign, attrs.valign, attrs.alignmode;
        suggestedbbox = bbox, protrusions = protrusions)

    limits = Node(FRect3D(Vec3f0(0f0, 0f0, 0f0), Vec3f0(100f0, 100f0, 100f0)))

    scenearea = lift(round_to_IRect2D, layoutobservables.computedbbox)

    scene = Scene(topscene, scenearea, raw = true)

    matrices = lift(calculate_matrices, limits, scene.px_area, elevation, azimuth, perspectiveness)

    on(matrices) do (view, proj)
        pv = proj * view
        scene.camera.projection.val = proj
        scene.camera.view.val = view
        scene.camera.projectionview[] = pv
    end

    ticknode_1 = lift(limits) do lims
        get_tickvalues(LinearTicks(4), minimum(lims)[1], maximum(lims)[1])
    end

    ticknode_2 = lift(limits) do lims
        get_tickvalues(LinearTicks(4), minimum(lims)[2], maximum(lims)[2])
    end

    ticknode_3 = lift(limits) do lims
        get_tickvalues(LinearTicks(4), minimum(lims)[3], maximum(lims)[3])
    end

    mi1 = false
    mi2 = false
    mi3 = true
    add_gridlines!(scene, 1, limits, ticknode_1, mi2, mi3)
    add_gridlines!(scene, 2, limits, ticknode_2, mi1, mi3)
    add_gridlines!(scene, 3, limits, ticknode_3, mi1, mi2)
    # wireframe!(scene, limits)


    mouseeventhandle = addmouseevents!(scene)
    scrollevents = Node(ScrollEvent(0, 0))
    keysevents = Node(KeysEvent(Set()))

    on(scene.events.scroll) do s
        if is_mouseinside(scene)
            scrollevents[] = ScrollEvent(s[1], s[2])
        end
    end

    on(scene.events.keyboardbuttons) do buttons
        keysevents[] = KeysEvent(buttons)
    end

    interactions = Dict{Symbol, Tuple{Bool, Any}}()


    ax = Axis3(fig_or_scene, layoutobservables, attrs, decorations, scene, limits,
        mouseeventhandle, scrollevents, keysevents, interactions)


    function process_event(event)
        for (active, interaction) in values(ax.interactions)
            active && process_interaction(interaction, event, ax)
        end
    end

    on(process_event, mouseeventhandle.obs)
    on(process_event, scrollevents)
    on(process_event, keysevents)

    register_interaction!(ax,
        :dragrotate,
        DragRotate())


    # trigger projection via limits
    limits[] = limits[]

    ax
end

function calculate_matrices(limits, px_area, elev, azim, perspectiveness)
    ws = widths(limits)

    t = AbstractPlotting.translationmatrix(-limits.origin)
    s = AbstractPlotting.scalematrix(2 ./ ws)
    t2 = AbstractPlotting.translationmatrix(Vec3f0(-1, -1, -1))
    scale_to_unit_cube_matrix = t2 * s * t

    ang_max = 70
    ang_min = 1

    @assert 0 <= perspectiveness <= 1

    angle = ang_min + (ang_max - ang_min) * perspectiveness
    radius = sqrt(3) / tand(angle / 2)

    x = radius * cos(elev) * cos(azim)
    y = radius * cos(elev) * sin(azim)
    z = radius * sin(elev)

    lookat = AbstractPlotting.lookat(
        Vec3f0(x, y, z),
        Vec3f0(0, 0, 0),
        Vec3f0(0, 0, 1))

    view = lookat * scale_to_unit_cube_matrix
    projection = AbstractPlotting.perspectiveprojection(Float32, angle, 1f0, 1f0, 10000f0)
    view, projection
end


function AbstractPlotting.plot!(
    ax::Axis3, P::AbstractPlotting.PlotFunc,
    attributes::AbstractPlotting.Attributes, args...;
    kw_attributes...)

plot = AbstractPlotting.plot!(ax.scene, P, attributes, args...; kw_attributes...)

autolimits!(ax)
plot
end

function AbstractPlotting.plot!(P::AbstractPlotting.PlotFunc, ax::Axis3, args...; kw_attributes...)
attributes = AbstractPlotting.Attributes(kw_attributes)
AbstractPlotting.plot!(ax, P, attributes, args...)
end

function autolimits!(ax::Axis3)
    nothing
end

# mutable struct LineAxis3D

# end

function dimpoint(dim, v, v1, v2)
    if dim == 1
        Point(v, v1, v2)
    elseif dim == 2
        Point(v1, v, v2)
    elseif dim == 3
        Point(v1, v2, v)
    end
end

function dim1(dim)
    if dim == 1
        2
    elseif dim == 2
        1
    elseif dim == 3
        1
    end
end

function dim2(dim)
    if dim == 1
        3
    elseif dim == 2
        3
    elseif dim == 3
        2
    end
end

function add_gridlines!(scene, dim::Int, limits, ticknode, min1, min2)
    dpoint = (v, v1, v2) -> dimpoint(dim, v, v1, v2)
    d1 = dim1(dim)
    d2 = dim2(dim)
    endpoints = lift(limits, ticknode, min1, min2) do lims, ticks, min1, min2
        f1 = min1 ? minimum(lims)[d1] : maximum(lims)[d1]
        f2 = min2 ? minimum(lims)[d2] : maximum(lims)[d2]
        # from tickvalues and f1 and min2:max2
        mi = minimum(lims)
        ma = maximum(lims)
        map(ticks) do t
            dpoint(t, f1, mi[d2]), dpoint(t, f1, ma[d2])
        end
    end
    linesegments!(scene, endpoints, color = :gray80)

    endpoints2 = lift(limits, ticknode, min1, min2) do lims, ticks, min1, min2
        f1 = min1 ? minimum(lims)[d1] : maximum(lims)[d1]
        f2 = min2 ? minimum(lims)[d2] : maximum(lims)[d2]
        # from tickvalues and f1 and min2:max2
        mi = minimum(lims)
        ma = maximum(lims)
        map(ticks) do t
            dpoint(t, mi[d1], f2), dpoint(t, ma[d1], f2)
        end
    end
    linesegments!(scene, endpoints2, color = :gray80)
end
