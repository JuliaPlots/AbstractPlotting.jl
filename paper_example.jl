using CairoMakie

polynomials = ["20x", "3x^2 + 3x", "x^3 - 2x^2 - 10x"]
functions = eval.(Meta.parse.("x -> " .* polynomials))

f = Figure(resolution = (700, 500), fontsize = 14, font = "Helvetica")
ax = Axis(f[2, 1], xlabel = "x", ylabel = "f(x)", title = "Polynomials")

colors = [:tomato, "#04e04c", RGBf0(0.1, 0.3, 1)]

for (f, p, color) in zip(functions, polynomials, colors)
    lines!(-5..5, f, label = p, color = color, linewidth = 2)
end

Legend(f[1, 1], ax, orientation = :horizontal, colgap = 20, tellheight = true)

function mandelbrot(x, y)
    z = c = x + y*im
    for i in 1:30.0; abs(z) > 2 && return i; z = z^2 + c; end
    return 0.0
end

ax2, hm = heatmap(f[1:2, 2][1, 1], -2:0.01:1, -2:0.01:2, mandelbrot,
    interpolate = true, colormap = :thermal)
hidedecorations!(ax2)
Colorbar(f[1:2, 2][2, 1], hm, height = 20, vertical = false,
    flipaxis = false, label = "Iterations")

Label(f[0, :], "Makie.jl Example Figure")

f
# save("paper_example.png", f, px_per_unit = 2)
##
save("paper_example.png", f, px_per_unit = 2)