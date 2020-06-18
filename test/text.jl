using AbstractPlotting
using AbstractPlotting.MakieLayout
using CairoMakie

##
function heatmap_with_labels()
    scene, layout = layoutscene(resolution = (600, 600))
    ax = layout[1, 1] = LAxis(scene)
    tightlimits!(ax)
    values = randn(100)
    
    poly!(ax, [FRect2D(x, y, 1, 1) for x in 1:10 for y in 1:10], color = values,
        strokecolor = :black, strokewidth = 1)

    text!(ax,
        string.(round.(values, digits = 2)),
        position = [Point2f0(x, y) .+ 0.5 for x in 1:10 for y in 1:10],
        space = :screen,
        align = (:center, :center),
        textsize = 10)
    scene
end

heatmap_with_labels()

function scene_layout_ax(; kwargs...)
    scene, layout = layoutscene(; kwargs...)
    ax = layout[1, 1] = LAxis(scene)
    scene, layout, ax
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

    scene
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

    scene
end

multi_strings_multi_positions()


function single_string_multi_positions()
    scene = Scene(camera = campixel!, show_axis = false, resolution = (800, 800))

    str = "multistring"
    points = decompose(Point2f0, Circle(Point2f0(400, 400), 200f0), length(str))
    
    text!(scene, str, position = points)

    scene
end

single_string_multi_positions()


function single_strings_single_positions_justification()
    scene = Scene(camera = campixel!, show_axis = false, resolution = (800, 800))
    
    points = [Point(x, y) .* 200 for x in 1:3 for y in 1:3]
    scatter!(scene, points, marker = :circle, markersize = 10px)

    i = 1
    for halign in (:right, :center, :left), justification in (0, 0.5, 1)

        text!(scene, "First\nSecond\nThird",
            color = (:black, 0.5),
            position = points[i],
            align = (halign, :center),
            justification = justification)

        i += 1
    end

    scene
end

single_strings_single_positions_justification()