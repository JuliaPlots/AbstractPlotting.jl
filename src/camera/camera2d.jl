struct Camera2D <: AbstractCamera
    area::Node{FRect2D}
    zoomspeed::Node{Float32}
    zoombutton::Node{ButtonTypes}
    panbutton::Node{Union{ButtonTypes, Vector{ButtonTypes}}}
    padding::Node{Float32}
    last_area::Node{Vec{2, Int}}
    update_limits::Node{Bool}
end

"""
    cam2d!(scene::SceneLike, kwargs...)

Creates a 2D camera for the given Scene.
"""
function cam2d!(scene::SceneLike; kw_args...)
    cam_attributes = merged_get!(:cam2d, scene, Attributes(kw_args)) do
        Theme(
            area = node(:area, FRect(0, 0, 1, 1)),
            zoomspeed = 0.10f0,
            zoombutton = nothing,
            panbutton = Mouse.right,
            selectionbutton = (Keyboard.space, Mouse.left),
            padding = 0.001,
            last_area = Vec(size(scene)),
            update_limits = false,
        )
    end
    cam = from_dict(Camera2D, cam_attributes)
    # remove previously connected camera
    disconnect!(camera(scene))
    add_zoom!(scene, cam)
    add_pan!(scene, cam)
    correct_ratio!(scene, cam)
    selection_rect!(scene, cam, cam_attributes[:selectionbutton])
    cameracontrols!(scene, cam)
    cam
end

wscale(screenrect, viewrect) = widths(viewrect) ./ widths(screenrect)


"""
    `update_cam!(scene::SceneLike, area)`

Updates the camera for the given `scene` to cover the given `area` in 2d.
"""
update_cam!(scene::SceneLike, area) = update_cam!(scene, cameracontrols(scene), area)
"""
    `update_cam!(scene::SceneLike)`

Updates the camera for the given `scene` to cover the limits of the `Scene`.
Useful when using the `Node` pipeline.
"""
update_cam!(scene::SceneLike) = update_cam!(scene, cameracontrols(scene), limits(scene)[])


function update_cam!(scene::Scene, cam::Camera2D, area3d::Rect)
    area = FRect2D(area3d)
    area = positive_widths(area)
    # ignore rects with width almost 0
    any(x-> x ≈ 0.0, widths(area)) && return

    pa = pixelarea(scene)[]
    px_wh = normalize(widths(pa))
    wh = normalize(widths(area))
    ratio = px_wh ./ wh
    if ratio ≈ Vec(1.0, 1.0)
        cam.area[] = area
    else
        # we only want to make the area bigger, to at least show what was selected
        # so we make the minimum 1.0, and grow in the other dimension
        s = ratio ./ minimum(ratio)
        newwh = s .* widths(area)
        cam.area[] = FRect(minimum(area), newwh)
    end
    update_cam!(scene, cam)
end

function update_cam!(scene::SceneLike, cam::Camera2D)
    x, y = minimum(cam.area[])
    w, h = widths(cam.area[]) ./ 2f0
    # These nodes should be final, no one should do map(cam.projection),
    # so we don't push! and just update the value in place
    view = translationmatrix(Vec3f0(-x - w, -y - h, 0))
    projection = orthographicprojection(-w, w, -h, h, -10_000f0, 10_000f0)
    camera(scene).view[] = view
    camera(scene).projection[] = projection
    camera(scene).projectionview[] = projection * view
    cam.last_area[] = Vec(size(scene))
    if cam.update_limits[]
        #
        w2 = Vec2f0(w, h) .* 0.2
        update_limits!(scene, Rect(origin(cam.area[]) .+ w2, widths(cam.area[]) .- 2w2))
    end
    return
end

function correct_ratio!(scene, cam)
    on(camera(scene), pixelarea(scene)) do area
        neww = widths(area)
        change = neww .- cam.last_area[]
        if !(change ≈ Vec(0.0, 0.0))
            s = 1.0 .+ (change ./ cam.last_area[])
            camrect = FRect(minimum(cam.area[]), widths(cam.area[]) .* s)
            cam.area[] = camrect
            update_cam!(scene, cam)
        end
        return
    end
end

function add_pan!(scene::SceneLike, cam::Camera2D)
    startpos = RefValue((0.0, 0.0))
    e = events(scene)
    on(
        camera(scene),
        Node.((scene, cam, startpos))...,
        e.mousedrag
    ) do scene, cam, startpos, dragging
        pan = cam.panbutton[]
        mp = e.mouseposition[]
        if ispressed(scene, pan) && is_mouseinside(scene)
            window_area = pixelarea(scene)[]
            if dragging == Mouse.down
                startpos[] = mp
            elseif dragging == Mouse.pressed && ispressed(scene, pan)
                diff = startpos[] .- mp
                startpos[] = mp
                area = cam.area[]
                diff = Vec(diff) .* wscale(window_area, area)
                cam.area[] = FRect(minimum(area) .+ diff, widths(area))
                update_cam!(scene, cam)
            end
        end
        return
    end
end

function add_zoom!(scene::SceneLike, cam::Camera2D)
    e = events(scene)
    on(camera(scene), e.scroll) do x
        @extractvalue cam (zoomspeed, zoombutton, area)
        zoom = Float32(x[2])
        if zoom != 0 && ispressed(scene, zoombutton) && is_mouseinside(scene)
            pa = pixelarea(scene)[]
            z = 1f0 + (zoom * zoomspeed)
            mp = Vec2f0(e.mouseposition[]) - minimum(pa)
            mp = (mp .* wscale(pa, area)) + minimum(area)
            p1, p2 = minimum(area), maximum(area)
            p1, p2 = p1 - mp, p2 - mp # translate to mouse position
            p1, p2 = z * p1, z * p2
            p1, p2 = p1 + mp, p2 + mp
            cam.area[] = FRect(p1, p2 - p1)
            update_cam!(scene, cam)
        end
        return
    end
end

function camspace(scene::SceneLike, cam::Camera2D, point)
    point = Vec(point) .* wscale(pixelarea(scene)[], cam.area[])
    Vec(point) .+ Vec(minimum(cam.area[]))
end

FRect() = FRect(NaN, NaN, NaN, NaN)

function absrect(rect)
    xy, wh = minimum(rect), widths(rect)
    xy = ntuple(Val(2)) do i
        wh[i] < 0 ? xy[i] + wh[i] : xy[i]
    end
    FRect(Vec2f0(xy), Vec2f0(abs.(wh)))
end


function selection_rect!(scene, cam, key)
    rect = RefValue(FRect())
    lw = 2f0
    scene_unscaled = Scene(
        scene, transformation = Transformation(),
        cam = copy(camera(scene)), clear = false
    )
    scene_unscaled.clear = false
    scene_unscaled.updated = Node(false)
    rect_vis = lines!(
        scene_unscaled,
        rect[],
        linestyle = :dot,
        linewidth = 2f0,
        color = (:black, 0.4),
        visible = false,
        raw = true
    ).plots[end]
    waspressed = RefValue(false)
    dragged_rect = on(camera(scene), events(scene).mousedrag, key) do drag, key
        if ispressed(scene, key) && is_mouseinside(scene)
            mp = events(scene).mouseposition[]
            mp = camspace(scene, cam, mp)
            if drag == Mouse.down
                waspressed[] = true
                rect_vis[:visible] = true # start displaying
                rect[] = FRect(mp, 0, 0)
                rect_vis[1] = rect[]
            elseif drag == Mouse.pressed
                mini = minimum(rect[])
                rect[] = FRect(mini, mp - mini)
                # mini, maxi = min(mini, mp), max(mini, mp)
                rect_vis[1] = rect[]
            end
        else
            if drag == Mouse.up && waspressed[]
                waspressed[] = false
                r = absrect(rect[])
                w, h = widths(r)
                if w > 0.0 && h > 0.0
                    update_cam!(scene, cam, r)
                end
                #scene.limits[] = FRect3D(rect[])
                rect[] = FRect()
                rect_vis[1] = rect[]
            end
            # always hide if not the right key is pressed
            rect_vis[:visible] = false # hide
        end
        return rect[]
    end
    rect_vis, dragged_rect
end

function reset!(cam, boundingbox, preserveratio = true)
    w1 = widths(boundingbox)
    if preserveratio
        w2 = widths(cam[Screen][Area])
        ratio = w2 ./ w1
        w1 = if ratio[1] > ratio[2]
            s = w2[1] ./ w2[2]
            Vec2f0(s * w1[2], w1[2])
        else
            s = w2[2] ./ w2[1]
            Vec2f0(w1[1], s * w1[1])
        end
    end
    p = minimum(w1) .* 0.001 # 2mm padding
    update_cam!(cam, FRect(-p, -p, w1 .+ 2p))
    return
end



function add_restriction!(cam, window, rarea::SimpleRectangle, minwidths::Vec)
    area_ref = Base.RefValue(cam[Area])
    restrict_action = paused_action(1.0) do t
        o = lerp(origin(area_ref[]), origin(cam[Area]), t)
        wh = lerp(widths(area_ref[]), widths(cam[Area]), t)
        update_cam!(cam, FRect(o, wh))
    end
    on(window, Mouse.Drag) do drag
        if drag == Mouse.up && !isplaying(restrict_action)
            area = cam[Area]
            o = origin(area)
            maxi = maximum(area)
            newo = max.(o, origin(rarea))
            newmax = min.(maxi, maximum(rarea))
            maxi = maxi - newmax
            newo = newo - maxi
            newwh = newmax - newo
            scale = 1f0
            for (w1, w2) in zip(minwidths, newwh)
                stmp = w1 > w2 ? w1 / w2 : 1f0
                scale = max(scale, stmp)
            end
            newwh = newwh * scale
            area_ref[] = FRect(newo, newwh)
            if area_ref[] != cam[Area]
                play!(restrict_action)
            end
        end
        return
    end
    restrict_action
end

struct PixelCamera <: AbstractCamera end
"""
    campixel!(scene)

Creates a pixel-level camera for the `Scene`.  No controls!
"""
function campixel!(scene)
    scene.updated = Node(false)
    camera(scene).view[] = Mat4f0(I)
    update_once = Observable(false)
    on(camera(scene), update_once, pixelarea(scene)) do u, window_size
        nearclip = -10_000f0
        farclip = 10_000f0
        w, h = Float32.(widths(window_size))
        projection = orthographicprojection(0f0, w, 0f0, h, nearclip, farclip)
        camera(scene).projection[] = projection
        camera(scene).projectionview[] = projection
    end
    cam = PixelCamera()
    cameracontrols!(scene, cam)
    update_once[] = true
    cam
end
