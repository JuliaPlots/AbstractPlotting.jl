using GLMakie, GLMakie.FileIO, GLMakie.GeometryBasics
set_window_config!(pause_rendering = true)
AbstractPlotting.inline!(true)

let
    f = Figure(resolution = (1400, 1000), font = "Helvetica")

    functions = [x -> sin(x) - x + 10, x -> cos(x) + x]
    xs = rand(50_000_000) .* 10
    ys = [f.(xs) .+ 3 .* randn(50_000_000) for f in functions]

    Axis(f[1, 1], limits = (0, 10, -10, 20), title = "100 million points")
    for (i, color) in zip(1:2, [:red, :blue])
        scatter!(xs, ys[i], markersize = 0.5, color = (color, 0.01), strokewidth = 0)
        lines!(0..10, functions[i], color = color, linewidth = 3)
    end

    # GLMakie.volume(f[2, 1], [sin(x*y*z) / (x*y*z) for x in -8:8:30, y in -8:8:30, z in -8:8:30],
    #     algorithm = :iso, isorange = 0.05, isovalue = 0.9)

    function mandelbrot(x, y)
        z = c = x + y*im
        for i in 1:30.0; abs(z) > 2 && return i; z = z^2 + c; end
        return 0.0
    end

    ax2, hm = heatmap(f[1:2, 2][1, 2], -2:0.005:1, -1.1:0.005:1.1, mandelbrot,
        interpolate = true, colormap = :thermal, axis = (title = "Mandelbrot set",))
    hidedecorations!(ax2)
    Colorbar(f[1:2, 2][1, 1], hm, flipaxis = false, label = "Iterations", height = 300)

    Axis3(f[1:2, 2][2, 1:2], aspect = :data, title = "Brain mesh")
    brain = load(assetpath("brain.stl"))
    color = [GeometryBasics.norm(tri[1] .- Point3f0(-40, 10, 45)) for tri in brain for i in 1:3]
    mesh!(brain, color = color, colormap = Reverse(:thermal))

    Label(f[0, :], "Makie.jl Example Figure")

    save("paper_example.png", f)
    nothing
end