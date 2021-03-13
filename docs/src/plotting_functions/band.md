## `band`

```@docs
band
```

### Examples

```@example
using GLMakie
AbstractPlotting.inline!(true) # hide

xs = 1:0.2:10
ys_low = -0.2 .* sin.(xs) .- 0.25
ys_high = 0.2 .* sin.(xs) .+ 0.25

band(xs, ys_low, ys_high)
band!(xs, ys_low .- 1, ys_high .-1, color = :red)
current_figure()
```

