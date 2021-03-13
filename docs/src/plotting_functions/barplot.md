## `barplot`

```@docs
barplot
```

### Examples

```@example
using GLMakie
AbstractPlotting.inline!(true) # hide

xs = 1:0.2:10
ys = 0.5 .* sin.(xs)

barplot(xs, ys, color = :red, strokecolor = :black, strokewidth = 1)
barplot!(xs, ys .- 1, fillto = -1, color = xs, strokecolor = :black, strokewidth = 1)
current_figure()
```

