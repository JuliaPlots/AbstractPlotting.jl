# contour

```@docs
contour
```

### Examples

```@example
using GLMakie
AbstractPlotting.inline!(true) # hide

xs = LinRange(0, 10, 100)
ys = LinRange(0, 15, 100)
zs = [cos(x) * sin(y) for x in xs, y in ys]

contour(xs, ys, zs)
```

