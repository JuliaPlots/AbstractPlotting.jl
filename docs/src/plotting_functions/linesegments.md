## `linesegments`

```@docs
linesegments
```

### Examples

```@example
using GLMakie
AbstractPlotting.inline!(true) # hide

xs = 1:0.2:10
ys = sin.(xs)

linesegments(xs, ys)
linesegments!(xs, ys .- 1, linewidth = 5)
linesegments!(xs, ys .- 2, linewidth = LinRange(1, 10, length(xs)))
linesegments!(xs, ys .- 3, linewidth = 5, color = LinRange(1, 5, length(xs)))
current_figure()
```


