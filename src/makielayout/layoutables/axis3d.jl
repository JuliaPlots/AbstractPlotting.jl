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

    on(matrices) do (view, proj, eyepos)
        pv = proj * view
        scene.camera.projection[] = proj
        scene.camera.view[] = view
        scene.camera.eyeposition[] = eyepos
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

    mi1 = @lift(!(pi/2 <= $azimuth % 2pi < 3pi/2))
    mi2 = @lift(0 <= $azimuth % 2pi < pi)
    mi3 = @lift($elevation > 0)
    add_gridlines_and_frames!(scene, 1, limits, ticknode_1, mi1, mi2, mi3)
    add_gridlines_and_frames!(scene, 2, limits, ticknode_2, mi2, mi1, mi3)
    add_gridlines_and_frames!(scene, 3, limits, ticknode_3, mi3, mi1, mi2)
    # wireframe!(scene, limits)

    add_tick_labels!(topscene, scene, 1, limits, ticknode_1, mi1, mi2, mi3)
    add_tick_labels!(topscene, scene, 2, limits, ticknode_2, mi2, mi1, mi3)
    add_tick_labels!(topscene, scene, 3, limits, ticknode_3, mi3, mi1, mi2)


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

can_be_current_axis(ax3::Axis3) = true

function calculate_matrices(limits, px_area, elev, azim, perspectiveness)
    ws = widths(limits)

    t = AbstractPlotting.translationmatrix(-Float64.(limits.origin))
    s = AbstractPlotting.scalematrix(2 ./ Float64.(ws))
    t2 = AbstractPlotting.translationmatrix(Vec3(-1.0, -1.0, -1.0))
    scale_to_unit_cube_matrix = t2 * s * t

    ang_max = 70
    ang_min = 1

    @assert 0 <= perspectiveness <= 1

    angle = ang_min + (ang_max - ang_min) * perspectiveness

    # vFOV = 2 * Math.asin(sphereRadius / distance);
    # distance = sphere_radius / Math.sin(vFov / 2)

    # radius = sqrt(3) / tand(angle / 2)
    radius = sqrt(3) / sind(angle / 2)

    x = radius * cos(elev) * cos(azim)
    y = radius * cos(elev) * sin(azim)
    z = radius * sin(elev)

    eyepos = Vec3{Float64}(x, y, z)

    lookat = AbstractPlotting.lookat(
        eyepos,
        Vec3{Float64}(0, 0, 0),
        Vec3{Float64}(0, 0, 1))

    view = lookat * scale_to_unit_cube_matrix
    projection = AbstractPlotting.perspectiveprojection(Float64, angle, 1f0, radius - sqrt(3), radius + 2 * sqrt(3))

    view, projection, Vec3f0(inv(scale_to_unit_cube_matrix) * Vec4f0(eyepos..., 1))
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
    xlims = getlimits(ax, 1)
    ylims = getlimits(ax, 2)
    zlims = getlimits(ax, 3)

    ori = Vec3f0(xlims[1], ylims[1], zlims[1])
    widths = Vec3f0(xlims[2] - xlims[1], ylims[2] - ylims[1], zlims[2] - zlims[1])

    enlarge_factor = 0.1

    nori = ori .- (0.5 * enlarge_factor) * widths
    nwidths = widths .* (1 + enlarge_factor)

    lims = FRect3D(nori, nwidths)

    ax.limits[] = lims
    nothing
end

function getlimits(ax::Axis3, dim)

    plots_with_autolimits = if dim == 1
        filter(p -> !haskey(p.attributes, :xautolimits) || p.attributes.xautolimits[], ax.scene.plots)
    elseif dim == 2
        filter(p -> !haskey(p.attributes, :yautolimits) || p.attributes.yautolimits[], ax.scene.plots)
    elseif dim == 3
        filter(p -> !haskey(p.attributes, :zautolimits) || p.attributes.zautolimits[], ax.scene.plots)
    else
        error("Dimension $dim not allowed. Only 1, 2 or 3.")
    end

    visible_plots = filter(
        p -> !haskey(p.attributes, :visible) || p.attributes.visible[],
        plots_with_autolimits)

    bboxes = AbstractPlotting.data_limits.(visible_plots)
    finite_bboxes = filter(AbstractPlotting.isfinite_rect, bboxes)

    isempty(finite_bboxes) && return nothing

    templim = (finite_bboxes[1].origin[dim], finite_bboxes[1].origin[dim] + finite_bboxes[1].widths[dim])

    for bb in finite_bboxes[2:end]
        templim = limitunion(templim, (bb.origin[dim], bb.origin[dim] + bb.widths[dim]))
    end

    templim
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

function add_gridlines_and_frames!(scene, dim::Int, limits, ticknode, miv, min1, min2)
    dpoint = (v, v1, v2) -> dimpoint(dim, v, v1, v2)
    d1 = dim1(dim)
    d2 = dim2(dim)
    endpoints = lift(limits, ticknode, min1, min2) do lims, ticks, min1, min2
        f1 = min1 ? minimum(lims)[d1] : maximum(lims)[d1]
        f2 = min2 ? minimum(lims)[d2] : maximum(lims)[d2]
        # from tickvalues and f1 and min2:max2
        mi = minimum(lims)
        ma = maximum(lims)
        map(filter(x -> !any(y -> x ≈ y[dim], extrema(lims)), ticks)) do t
            dpoint(t, f1, mi[d2]), dpoint(t, f1, ma[d2])
        end
    end
    linesegments!(scene, endpoints, color = :gray80,
        xautolimits = false, yautolimits = false, zautolimits = false)

    endpoints2 = lift(limits, ticknode, min1, min2) do lims, ticks, min1, min2
        f1 = min1 ? minimum(lims)[d1] : maximum(lims)[d1]
        f2 = min2 ? minimum(lims)[d2] : maximum(lims)[d2]
        # from tickvalues and f1 and min2:max2
        mi = minimum(lims)
        ma = maximum(lims)
        map(filter(x -> !any(y -> x ≈ y[dim], extrema(lims)), ticks)) do t
            dpoint(t, mi[d1], f2), dpoint(t, ma[d1], f2)
        end
    end
    linesegments!(scene, endpoints2, color = :gray80,
        xautolimits = false, yautolimits = false, zautolimits = false)


    framepoints = lift(limits, miv) do lims, miv
        m = (miv ? minimum : maximum)(lims)[dim]
        p1 = dpoint(m, minimum(lims)[d1], minimum(lims)[d2])
        p2 = dpoint(m, maximum(lims)[d1], minimum(lims)[d2])
        p3 = dpoint(m, maximum(lims)[d1], maximum(lims)[d2])
        p4 = dpoint(m, minimum(lims)[d1], maximum(lims)[d2])
        [p1, p2, p3, p4, p1]
    end
    lines!(scene, framepoints, color = :black, linewidth = 1,
        xautolimits = false, yautolimits = false, zautolimits = false)

    nothing
end

function add_tick_labels!(pscene, scene, dim::Int, limits, ticknode, miv, min1, min2)
    dpoint = (v, v1, v2) -> dimpoint(dim, v, v1, v2)
    d1 = dim1(dim)
    d2 = dim2(dim)

    labels_positions = lift(scene.px_area, scene.camera.projectionview, limits, ticknode, miv, min1, min2) do pxa, pv, lims, ticks, miv, min1, min2

        f1 = !min1 ? minimum(lims)[d1] : maximum(lims)[d1]
        f2 = min2 ? minimum(lims)[d2] : maximum(lims)[d2]

        o = pxa.origin

        points = [
            Point2f0(o + AbstractPlotting.project(scene, dpoint(t, f1, f2)))
            for t in ticks
        ]

        ticklabels = get_ticklabels(AbstractPlotting.automatic, ticks)

        v = collect(zip(ticklabels, points))
        v::Vector{Tuple{String, Point2f0}}
    end
    al = lift(miv, min1, min2) do mv, m1, m2
        if dim == 1
            (mv ⊻ m1 ? :right : :left, m2 ? :top : :bottom)
        elseif dim == 2
            (mv ⊻ m1 ? :left : :right, m2 ? :top : :bottom)
        elseif dim == 3
            (m1 ⊻ m2 ? :left : :right, :center)
        end
    end
    a = annotations!(pscene, labels_positions, align = al, show_axis = false)
    translate!(a, 0, 0, 1000)
    nothing
end