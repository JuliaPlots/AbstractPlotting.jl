using CairoMakie
using GLMakie
GLMakie.activate!()

##
function heatmap_with_labels()
    fig = Figure(resolution = (600, 600))
    ax = fig[1, 1] = Axis(fig)
    tightlimits!(ax)
    values = rand(100)

    poly!(ax, [FRect2D(x, y, 1, 1) for x in 1:10 for y in 1:10], color = values,
        strokecolor = :black, strokewidth = 1)

    text!(ax,
        string.(round.(values, digits = 2)),
        position = [Point2f0(x, y) .+ 0.5 for x in 1:10 for y in 1:10],
        align = (:center, :center),
        color = ifelse.(values .< 0.3, :white, :black),
        textsize = 12)
    display(fig)
end

heatmap_with_labels()

begin
    pos = [Point2f0(0, 0), Point2f0(10, 10)]
    fig = text(
        ["0 is the ORIGIN of this", "10 says hi"],
        position = pos,
        aspect = DataAspect(),
        space = :data,
        align = (:center, :center),
        textsize = 2)
    scatter!(pos)
    display(fig)
end

function single_strings_single_positions()
    scene = Scene(camera = campixel!, show_axis = false, resolution = (800, 800))

    points = [Point(x, y) .* 200 for x in 1:3 for y in 1:3]
    scatter!(scene, points, marker = :circle, markersize = 10px)

    i = 1
    for halign in (:right, :center, :left), valign in (:top, :center, :bottom)

        for rotation in (-pi/6, 0.0, pi/6)
            text!(scene, string(halign) * "/" * string(valign) *
                    " " * string(round(rad2deg(rotation), digits = 0)) * "°",
                color = (:black, 0.5),
                position = points[i],
                align = (halign, valign),
                rotation = rotation)
        end
        i += 1
    end

    display(scene)
end

single_strings_single_positions()


function multi_strings_multi_positions()
    scene = Scene(camera = campixel!, show_axis = false, resolution = (800, 800))

    angles = (-pi/6, 0.0, pi/6)
    points = [Point(x, y) .* 200 for x in 1:3 for y in 1:3 for angle in angles]
    aligns = [(halign, valign) for halign in
        (:right, :center, :left) for valign in (:top, :center, :bottom) for rotation in angles]
    rotations = [rotation for _ in
        (:right, :center, :left) for _ in (:top, :center, :bottom) for rotation in angles]

    strings = [string(halign) * "/" * string(valign) *
        " " * string(round(rad2deg(rotation), digits = 0)) * "°"
            for halign in (:right, :center, :left)
            for valign in (:top, :center, :bottom)
            for rotation in angles]

    scatter!(scene, points, marker = :circle, markersize = 10px)


    text!(scene, strings, position = points, align = aligns, rotation = rotations,
        color = [(:black, alpha) for alpha in LinRange(0.3, 0.7, length(points))])

    display(scene)
end

multi_strings_multi_positions()


# this is not implemented for now

# function single_string_multi_positions()
#     scene = Scene(camera = campixel!, show_axis = false, resolution = (800, 800))

#     str = "multistring"
#     points = decompose(Point2f0, Circle(Point2f0(400, 400), 200f0), length(str))

#     text!(scene, str, position = points)

#     scene
# end

# single_string_multi_positions()


function single_strings_single_positions_justification()
    scene = Scene(camera = campixel!, show_axis = false, resolution = (800, 800))

    points = [Point(x, y) .* 200 for x in 1:3 for y in 1:3]
    scatter!(scene, points, marker = :circle, markersize = 10px)

    i = 1
    for halign in (:left, :center, :right), justification in (:left, :center, :right)

        t = text!(scene, "AA\nBBB\nCCCC\nDDDD",
            color = (:black, 0.5),
            position = points[i],
            align = (halign, :center),
            space = :data,
            justification = justification)

        bb = boundingbox(t)
        wireframe!(scene, bb, color = (:red, 0.2))

        i += 1
    end

    for (p, al) in zip(points[3:3:end], (:left, :center, :right))
        text!(scene, "align " * string(al), position = p .+ (0, 80),
            align = (:center, :baseline))
    end

    for (p, al) in zip(points[7:9], (:left, :center, :right))
        text!(scene, "justif " * string(al), position = p .+ (80, 0),
            align = (:center, :baseline), rotation = pi/2)
    end

    scene
end

single_strings_single_positions_justification()


function multi_boundingboxes()
    scene = Scene(camera = campixel!, show_axis = false, resolution = (800, 800))

    t1 = text!(scene,
        fill("makie", 8),
        position = [(200, 200) .+ 60 * Point2f0(cos(a), sin(a)) for a in 0:pi/4:7pi/4],
        rotation = 0:pi/4:7pi/4,
        align = (:left, :center),
        textsize = 30,
        space = :data
    )

    wireframe!(scene, boundingbox(t1), color = (:blue, 0.3))

    t2 = text!(scene,
        fill("makie", 8),
        position = [(200, 600) .+ 60 * Point2f0(cos(a), sin(a)) for a in 0:pi/4:7pi/4],
        rotation = 0:pi/4:7pi/4,
        align = (:left, :center),
        textsize = 30,
        space = :screen
    )

    wireframe!(scene, boundingbox(t2), color = (:red, 0.3))

    scene
end

multi_boundingboxes()

function single_boundingboxes()
    scene = Scene(camera = campixel!, show_axis = false, resolution = (800, 800))

    for a in 0:pi/4:7pi/4

        t = text!(scene,
            "makie",
            position = (200, 200) .+ 60 * Point2f0(cos(a), sin(a)),
            rotation = a,
            align = (:left, :center),
            textsize = 30,
            space = :data
        )

        wireframe!(scene, boundingbox(t), color = (:blue, 0.3))

        t2 = text!(scene,
            "makie",
            position = (200, 600) .+ 60 * Point2f0(cos(a), sin(a)),
            rotation = a,
            align = (:left, :center),
            textsize = 30,
            space = :screen
        )

        # these boundingboxes should be invisible because they only enclose the anchor
        wireframe!(scene, boundingbox(t2), color = (:red, 0.3))

    end

    
    scene
end

single_boundingboxes()



function text_in_3d_axis()
    text(
        fill("Makie", 7),
        rotation = [i / 7 * 1.5pi for i in 1:7],
        position = [Point3f0(0, 0, i/2) for i in 1:7],
        color = [cgrad(:viridis)[x] for x in LinRange(0, 1, 7)],
        align = (:left, :baseline),
        textsize = 1,
        space = :data
    )
end

text_in_3d_axis()


function empty_lines()
    scene = Scene(camera = campixel!, show_axis = false, resolution = (800, 800))

    t1 = text!(scene, "Line1\nLine 2\n\nLine4",
        position = (200, 400), align = (:center, :center), space = :data)

    wireframe!(scene, boundingbox(t1), color = (:red, 0.3))

    t2 = text!(scene, "\nLine 2\nLine 3\n\n\nLine6\n\n",
        position = (400, 400), align = (:center, :center), space = :data)

    wireframe!(scene, boundingbox(t2), color = (:blue, 0.3))

    scene
end

empty_lines()