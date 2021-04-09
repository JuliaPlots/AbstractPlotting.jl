using CairoMakie
CairoMakie.activate!(type = "png")

polynomials = ["20x", "3x^2 + 3x", "x^3 - 2x^2 - 10x"]
functions = eval.(Meta.parse.("x -> " .* polynomials))

f = Figure(resolution = (700, 900), fontsize = 12)
ax = Axis(f[1, 1], xlabel = "x", ylabel = "f(x)", title = "Polynomials")

colors = [:tomato, "#04e04c", RGBf0(0.1, 0.3, 1)]

for (f, p, color) in zip(functions, polynomials, colors)
    lines!(-5..5, f, label = p, color = color, linewidth = 2)
end

Legend(f[1, 2], ax, "f(x) =")

function mandelbrot(x, y)
    z = c = x + y*im
    for count in 1:30.0
        abs(z) > 2.0 && return count; z = z^2 + c
    end
    return 0.0
end

ax2, hm = heatmap(f[2, 1:2], -2:0.01:1, -2:0.01:2, mandelbrot,
    interpolate = true, axis = (height = 400, title = "Mandelbrot"))
hidedecorations!(ax2)
Colorbar(f[3, 1:2], hm, height = 20, vertical = false, flipaxis = false)

f

save("paper_example.png", f, px_per_unit = 2)