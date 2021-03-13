# density

```@docs
density
```

### Examples

```@example
using CairoMakie
CairoMakie.activate!() # hide
AbstractPlotting.inline!(true) # hide

f = Figure(resolution = (800, 600))

density(f[1, 1], randn(200))
density(f[1, 2], randn(200), direction = :y, npoints = 10)
density(f[2, 1], randn(200), color = (:red, 0.3),
    strokecolor = :red, strokewidth = 3, strokearound = true)

Axis(f[2, 2])
vectors = [randn(1000) .+ i/2 for i in 0:5]
for (i, vector) in enumerate(vectors)
    density!(vector, offset = -i/4, color = (:slategray, 0.4),
        bandwidth = 0.1)
end

f
save("example_density_1.svg", f); nothing # hide
```

![example_density_1](example_density_1.svg)

