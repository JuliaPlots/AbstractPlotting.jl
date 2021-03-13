# contourf

```@docs
contourf
```

```@example
using GLMakie
AbstractPlotting.inline!(true) # hide

xs = LinRange(0, 10, 100)
ys = LinRange(0, 10, 100)
zs = [cos(x) * sin(y) for x in xs, y in ys]

f = Figure()

_, co1 = contourf(f[1, 1][1, 1], xs, ys, zs, levels = 10)
Colorbar(f[1, 1][1, 2], co1, width = 20)

_, co2 = contourf(f[1, 2][1, 1], xs, ys, zs, levels = -0.75:0.25:0.5,
    extendlow = :cyan, extendhigh = :magenta)
Colorbar(f[1, 2][1, 2], co2, width = 20)

_, co3 = contourf(f[2, 1][1, 1], xs, ys, zs,
    levels = -0.75:0.25:0.5,
    extendlow = :auto, extendhigh = :auto)
Colorbar(f[2, 1][1, 2], co3, width = 20)

f
```

