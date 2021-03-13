# scatterlines

```@docs
scatterlines
```

### Examples

```@example
using GLMakie
AbstractPlotting.inline!(true) # hide

xs = LinRange(0, 10, 20)
ys = 0.5 .* sin.(xs)

scatterlines(xs, ys, color = :red)
scatterlines!(xs, ys .- 1, color = xs, markercolor = :red)
scatterlines!(xs, ys .- 2, markersize = LinRange(5, 30, 20))
scatterlines!(xs, ys .- 3, marker = :cross, strokewidth = 0,
    strokecolor = :red, markercolor = :cyan)
current_figure()
```

