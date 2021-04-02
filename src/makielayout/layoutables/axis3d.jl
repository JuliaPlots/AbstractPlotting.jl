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

    @extract attrs (elevation, azimuth, perspectiveness, data_aspect, viewmode,
        xlabel, ylabel, zlabel,
    )

    decorations = Dict{Symbol, Any}()


    protrusions = lift(to_protrusions, attrs.protrusions)
    layoutobservables = LayoutObservables{Axis3}(attrs.width, attrs.height, attrs.tellwidth, attrs.tellheight, attrs.halign, attrs.valign, attrs.alignmode;
        suggestedbbox = bbox, protrusions = protrusions)

    notify(protrusions)

    limits = Node(FRect3D(Vec3f0(0f0, 0f0, 0f0), Vec3f0(100f0, 100f0, 100f0)))

    scenearea = lift(round_to_IRect2D, layoutobservables.computedbbox)

    scene = Scene(topscene, scenearea, raw = true, clear = false, backgroundcolor = attrs.backgroundcolor)

    matrices = lift(calculate_matrices, limits, scene.px_area, elevation, azimuth, perspectiveness, data_aspect, viewmode)

    on(matrices) do (view, proj, eyepos)
        pv = proj * view
        scene.camera.projection[] = proj
        scene.camera.view[] = view
        scene.camera.eyeposition[] = eyepos
        scene.camera.projectionview[] = pv
    end

    ticknode_1 = lift(limits, attrs.xticks, attrs.xtickformat) do lims, ticks, format
        tl = get_ticks(ticks, format, minimum(lims)[1], maximum(lims)[1])
    end

    ticknode_2 = lift(limits, attrs.yticks, attrs.ytickformat) do lims, ticks, format
        tl = get_ticks(ticks, format, minimum(lims)[2], maximum(lims)[2])
    end

    ticknode_3 = lift(limits, attrs.zticks, attrs.ztickformat) do lims, ticks, format
        tl = get_ticks(ticks, format, minimum(lims)[3], maximum(lims)[3])
    end

    mi1 = @lift(!(pi/2 <= $azimuth % 2pi < 3pi/2))
    mi2 = @lift(0 <= $azimuth % 2pi < pi)
    mi3 = @lift($elevation > 0)
    add_gridlines_and_frames!(scene, 1, limits, ticknode_1, mi1, mi2, mi3, attrs)
    add_gridlines_and_frames!(scene, 2, limits, ticknode_2, mi2, mi1, mi3, attrs)
    add_gridlines_and_frames!(scene, 3, limits, ticknode_3, mi3, mi1, mi2, attrs)

    add_ticks_and_ticklabels!(topscene, scene, 1, limits, ticknode_1, mi1, mi2, mi3, attrs)
    add_ticks_and_ticklabels!(topscene, scene, 2, limits, ticknode_2, mi2, mi1, mi3, attrs)
    add_ticks_and_ticklabels!(topscene, scene, 3, limits, ticknode_3, mi3, mi1, mi2, attrs)


    titlepos = lift(scene.px_area, attrs.titlegap, attrs.titlealign) do a, titlegap, align

        x = if align == :center
            a.origin[1] + a.widths[1] / 2
        elseif align == :left
            a.origin[1]
        elseif align == :right
            a.origin[1] + a.widths[1]
        else
            error("Title align $align not supported.")
        end

        yoffset = top(a) + titlegap

        Point2(x, yoffset)
    end

    titlealignnode = lift(attrs.titlealign) do align
        (align, :bottom)
    end

    titlet = text!(
        topscene, attrs.title,
        position = titlepos,
        visible = attrs.titlevisible,
        textsize = attrs.titlesize,
        align = titlealignnode,
        font = attrs.titlefont,
        color = attrs.titlecolor,
        space = :data,
        show_axis=false)
    decorations[:title] = titlet



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

function calculate_matrices(limits, px_area, elev, azim, perspectiveness, data_aspect,
    viewmode)
    ws = widths(limits)


    t = AbstractPlotting.translationmatrix(-Float64.(limits.origin))
    s = if data_aspect == :equal
        scales = 2 ./ Float64.(ws)
    elseif data_aspect == :data
        scales = 2 ./ max.(maximum(ws), Float64.(ws))
    elseif data_aspect isa VecTypes{3}
        scales = 2 ./ Float64.(ws) .* Float64.(data_aspect) ./ maximum(data_aspect)
    else
        error("Invalid data_aspect $data_aspect")
    end |> AbstractPlotting.scalematrix

    t2 = AbstractPlotting.translationmatrix(-0.5 .* ws .* scales)
    scale_matrix = t2 * s * t

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

    lookat_matrix = AbstractPlotting.lookat(
        eyepos,
        Vec3{Float64}(0, 0, 0),
        Vec3{Float64}(0, 0, 1))

    w = width(px_area)
    h = height(px_area)

    view_matrix = lookat_matrix * scale_matrix
    
    projection_matrix = projectionmatrix(view_matrix, limits, eyepos, radius, azim, elev, angle, w, h, scales, viewmode)

    # for eyeposition dependent algorithms, we need to present the position as if
    # there was no scaling applied
    eyeposition = Vec3f0(inv(scale_matrix) * Vec4f0(eyepos..., 1))
    
    view_matrix, projection_matrix, eyeposition
end

function projectionmatrix(viewmatrix, limits, eyepos, radius, azim, elev, angle, width, height, scales, viewmode)
    near = radius - sqrt(3)
    far = radius + 2 * sqrt(3)

    aspect_ratio = width / height

    projection_matrix = if viewmode in (:fit, :fitzoom, :stretch)
        if height > width
            angle = angle / aspect_ratio
        end

        pm = AbstractPlotting.perspectiveprojection(Float64, angle, aspect_ratio, near, far)

        if viewmode in (:fitzoom, :stretch)
            points = decompose(Point3f0, limits)
            # @show points
            projpoints = Ref(pm * viewmatrix) .* to_ndim.(Point4f0, points, 1)

            maxx = maximum(x -> abs(x[1] / x[4]), projpoints)
            maxy = maximum(x -> abs(x[2] / x[4]), projpoints)

            ratio_x = maxx
            ratio_y = maxy

            if viewmode == :fitzoom
                if ratio_y > ratio_x
                    pm = AbstractPlotting.scalematrix(Vec3(1/ratio_y, 1/ratio_y, 1)) * pm
                else
                    pm = AbstractPlotting.scalematrix(Vec3(1/ratio_x, 1/ratio_x, 1)) * pm
                end
            else
                pm = AbstractPlotting.scalematrix(Vec3(1/ratio_x, 1/ratio_y, 1)) * pm
            end
        end
        pm
    else
        error("Invalid viewmode $viewmode")
    end
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

to_protrusions(x::Number) = GridLayoutBase.RectSides{Float32}(x, x, x, x)
to_protrusions(x::Tuple{Any, Any, Any, Any}) = GridLayoutBase.RectSides{Float32}(x...)

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

function add_gridlines_and_frames!(scene, dim::Int, limits, ticknode, miv, min1, min2, attrs)

    dimsym(sym) = Symbol(string((:x, :y, :z)[dim]) * string(sym))
    attr(sym) = attrs[dimsym(sym)]

    dpoint = (v, v1, v2) -> dimpoint(dim, v, v1, v2)
    d1 = dim1(dim)
    d2 = dim2(dim)

    tickvalues = @lift($ticknode[1])

    endpoints = lift(limits, tickvalues, min1, min2) do lims, ticks, min1, min2
        f1 = min1 ? minimum(lims)[d1] : maximum(lims)[d1]
        f2 = min2 ? minimum(lims)[d2] : maximum(lims)[d2]
        # from tickvalues and f1 and min2:max2
        mi = minimum(lims)
        ma = maximum(lims)
        map(filter(x -> !any(y -> x ≈ y[dim], extrema(lims)), ticks)) do t
            dpoint(t, f1, mi[d2]), dpoint(t, f1, ma[d2])
        end
    end
    linesegments!(scene, endpoints, color = attr(:gridcolor),
        xautolimits = false, yautolimits = false, zautolimits = false, transparency = true,
        visible = attr(:gridvisible))

    endpoints2 = lift(limits, tickvalues, min1, min2) do lims, ticks, min1, min2
        f1 = min1 ? minimum(lims)[d1] : maximum(lims)[d1]
        f2 = min2 ? minimum(lims)[d2] : maximum(lims)[d2]
        # from tickvalues and f1 and min2:max2
        mi = minimum(lims)
        ma = maximum(lims)
        map(filter(x -> !any(y -> x ≈ y[dim], extrema(lims)), ticks)) do t
            dpoint(t, mi[d1], f2), dpoint(t, ma[d1], f2)
        end
    end
    linesegments!(scene, endpoints2, color = attr(:gridcolor),
        xautolimits = false, yautolimits = false, zautolimits = false, transparency = true,
        visible = attr(:gridvisible))


    framepoints = lift(limits, min1, min2) do lims, mi1, mi2
        f(mi) = mi ? minimum : maximum
        p1 = dpoint(minimum(lims)[dim], f(mi1)(lims)[d1], f(mi2)(lims)[d2])
        p2 = dpoint(maximum(lims)[dim], f(mi1)(lims)[d1], f(mi2)(lims)[d2])
        p3 = dpoint(minimum(lims)[dim], f(!mi1)(lims)[d1], f(mi2)(lims)[d2])
        p4 = dpoint(maximum(lims)[dim], f(!mi1)(lims)[d1], f(mi2)(lims)[d2])
        p5 = dpoint(minimum(lims)[dim], f(mi1)(lims)[d1], f(!mi2)(lims)[d2])
        p6 = dpoint(maximum(lims)[dim], f(mi1)(lims)[d1], f(!mi2)(lims)[d2])
        # p7 = dpoint(minimum(lims)[dim], f(!mi1)(lims)[d1], f(!mi2)(lims)[d2])
        # p8 = dpoint(maximum(lims)[dim], f(!mi1)(lims)[d1], f(!mi2)(lims)[d2])
        [p1, p2, p3, p4, p5, p6]
        # [p1, p2, p3, p4, p5, p6, p7, p8]
    end

    linesegments!(scene, framepoints, color = attr(:spinecolor), linewidth = attr(:spinewidth),
        xautolimits = false, yautolimits = false, zautolimits = false, transparency = true,
        visible = attr(:spinesvisible))

    nothing
end

function add_ticks_and_ticklabels!(pscene, scene, dim::Int, limits, ticknode, miv, min1, min2, attrs)

    dimsym(sym) = Symbol(string((:x, :y, :z)[dim]) * string(sym))
    attr(sym) = attrs[dimsym(sym)]

    dpoint = (v, v1, v2) -> dimpoint(dim, v, v1, v2)
    d1 = dim1(dim)
    d2 = dim2(dim)

    tickvalues = @lift($ticknode[1])
    ticklabels = @lift($ticknode[2])

    tick_segments = lift(limits, tickvalues, miv, min1, min2) do lims, ticks, miv, min1, min2

        f1 = !min1 ? minimum(lims)[d1] : maximum(lims)[d1]
        f2 = min2 ? minimum(lims)[d2] : maximum(lims)[d2]

        f1_oppo = min1 ? minimum(lims)[d1] : maximum(lims)[d1]
        f2_oppo = !min2 ? minimum(lims)[d2] : maximum(lims)[d2]

        diff_f1 = f1 - f1_oppo
        diff_f2 = f2 - f2_oppo

        map(ticks) do t
            p1 = dpoint(t, f1, f2)
            p2 = if dim == 3
                dpoint(t, f1, f2 + 0.03 * diff_f2)
            else
                dpoint(t, f1 + 0.03 * diff_f1, f2)
            end
            (p1, p2)
        end
    end

    linesegments!(scene, tick_segments,
        xautolimits = false, yautolimits = false, zautolimits = false,
        color = attr(:tickcolor), linewidth = attr(:tickwidth), visible = attr(:ticksvisible))

    labels_positions = lift(scene.px_area, scene.camera.projectionview,
            tick_segments, ticklabels) do pxa, pv, ticksegs, ticklabs

        o = pxa.origin

        points = map(ticksegs) do (tstart, tend)
            tstartp = Point2f0(o + AbstractPlotting.project(scene, tstart))
            tendp = Point2f0(o + AbstractPlotting.project(scene, tend))

            offset = (dim == 3 ? 10 : 5) * AbstractPlotting.GeometryBasics.normalize(
                Point2f0(tendp - tstartp))
            tendp + offset
        end

        v = collect(zip(ticklabs, points))
        v::Vector{Tuple{String, Point2f0}}
    end

    align = lift(miv, min1, min2) do mv, m1, m2
        if dim == 1
            (mv ⊻ m1 ? :right : :left, m2 ? :top : :bottom)
        elseif dim == 2
            (mv ⊻ m1 ? :left : :right, m2 ? :top : :bottom)
        elseif dim == 3
            (m1 ⊻ m2 ? :left : :right, :center)
        end
    end

    a = annotations!(pscene, labels_positions, align = align, show_axis = false,
        color = attr(:ticklabelcolor), textsize = attr(:ticklabelsize),
        font = attr(:ticklabelfont), visible = attr(:ticklabelsvisible),
    )

    translate!(a, 0, 0, 1000)

    label_pos_rot_valign = lift(scene.px_area, scene.camera.projectionview,
            limits, miv, min1, min2, attr(:labeloffset),
            attr(:labelrotation)) do pxa, pv, lims, miv, min1, min2,
                loffset, lrotation

        o = pxa.origin

        f1 = !min1 ? minimum(lims)[d1] : maximum(lims)[d1]
        f2 = min2 ? minimum(lims)[d2] : maximum(lims)[d2]

        p1 = dpoint(minimum(lims)[dim], f1, f2)
        p2 = dpoint(maximum(lims)[dim], f1, f2)

        pp1 = Point2f0(o + AbstractPlotting.project(scene, p1))
        pp2 = Point2f0(o + AbstractPlotting.project(scene, p2))

        midpoint = (pp1 + pp2) / 2

        # f1_oppo = min1 ? minimum(lims)[d1] : maximum(lims)[d1]
        # f2_oppo = !min2 ? minimum(lims)[d2] : maximum(lims)[d2]

        diff = pp2 - pp1

        # rotsign = miv ? 1 : -1
        diffsign = if dim == 1 || dim == 3
            !(min1 ⊻ min2) ? 1 : -1
        else
            (min1 ⊻ min2) ? 1 : -1
        end

        a = pi/2

        offset_vec = (AbstractPlotting.Mat2f0(cos(a), sin(a), -sin(a), cos(a)) *
            AbstractPlotting.GeometryBasics.normalize(diffsign * diff))
        # rot = rotsign * pi/2
        plus_offset = midpoint + loffset * offset_vec
            
        offset_ang = atan(offset_vec[2], offset_vec[1])
        offset_ang_90deg = offset_ang + pi/2
        offset_ang_90deg_alwaysup = ((offset_ang + pi/2 + pi/2) % pi) - pi/2

        # # prefer rotated left 90deg to rotated right 90deg
        slight_flip = offset_ang_90deg_alwaysup < -deg2rad(88)
        if slight_flip
            offset_ang_90deg_alwaysup += pi
        end
        offset_ang_90deg_alwaysup

        labelrotation = if lrotation == AbstractPlotting.automatic
            offset_ang_90deg_alwaysup
        else
            lrotation
        end

        valign = offset_vec[2] > 0 || slight_flip ? :bottom : :top

        plus_offset, labelrotation, valign
    end

    labelalign = lift(label_pos_rot_valign, attr(:labelalign)) do (_, _, valign), lalign
        if lalign == AbstractPlotting.automatic
            (:center, valign)
        else
            lalign
        end
    end

    text!(pscene, attr(:label),
        color = attr(:labelcolor),
        textsize = attr(:labelsize),
        font = attr(:labelfont),
        position = @lift($label_pos_rot_valign[1]),
        rotation = @lift($label_pos_rot_valign[2]),
        align = labelalign,
        visible = attr(:labelvisible)
    )

    nothing
end

function hidexdecorations!(ax::Axis3;
    label = true, ticklabels = true, ticks = true, grid = true)

    if label
        ax.xlabelvisible = false
    end
    if ticklabels
        ax.xticklabelsvisible = false
    end
    if ticks
        ax.xticksvisible = false
    end
    if grid
        ax.xgridvisible = false
    end
    # if minorgrid
    #     ax.xminorgridvisible = false
    # end
    # if minorticks
    #     ax.xminorticksvisible = false
    # end

    ax
end

function hideydecorations!(ax::Axis3;
    label = true, ticklabels = true, ticks = true, grid = true)

    if label
        ax.ylabelvisible = false
    end
    if ticklabels
        ax.yticklabelsvisible = false
    end
    if ticks
        ax.yticksvisible = false
    end
    if grid
        ax.ygridvisible = false
    end
    # if minorgrid
    #     ax.yminorgridvisible = false
    # end
    # if minorticks
    #     ax.yminorticksvisible = false
    # end

    ax
end

function hidezdecorations!(ax::Axis3;
    label = true, ticklabels = true, ticks = true, grid = true)

    if label
        ax.zlabelvisible = false
    end
    if ticklabels
        ax.zticklabelsvisible = false
    end
    if ticks
        ax.zticksvisible = false
    end
    if grid
        ax.zgridvisible = false
    end
    # if minorgrid
    #     ax.zminorgridvisible = false
    # end
    # if minorticks
    #     ax.zminorticksvisible = false
    # end

    ax
end

function hidedecorations!(ax::Axis3;
    label = true, ticklabels = true, ticks = true, grid = true)

    hidexdecorations!(ax; label = label, ticklabels = ticklabels,
        ticks = ticks, grid = grid)
    hideydecorations!(ax; label = label, ticklabels = ticklabels,
        ticks = ticks, grid = grid)
    hidezdecorations!(ax; label = label, ticklabels = ticklabels,
        ticks = ticks, grid = grid)

    ax
end

function hidespines!(ax::Axis3)
    ax.xspinesvisible = false
    ax.yspinesvisible = false
    ax.zspinesvisible = false
    ax
end