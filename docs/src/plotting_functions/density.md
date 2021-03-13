# density

```@docs
density
```

### Examples

```@example
using GLMakie
AbstractPlotting.inline!(true) # hide

f = Figure()

density(f[1, 1], randn(200))
density(f[1, 2], randn(200), direction = :y, npoints = 10)
density(f[2, 1], randn(200), color = (:red, 0.3),
    strokecolor = :red, strokewidth = 3, strokearound = true)

ax = f[2, 2] = Axis(f)
data = [randn(1000) .+ i/2 for i in 0:5]
for (i, da) in enumerate(data)
    density!(da, offset = -i/4, color = (:slategray, 0.4),
        bandwidth = 0.1)
end
f
```

