# rangebars

```@docs
rangebars
```

### Examples

```@example
using GLMakie
GLMakie.activate!() # hide
AbstractPlotting.inline!(true) # hide

vals = -1:0.1:1

lows = zeros(length(vals))
highs = LinRange(0.1, 0.4, length(vals))


rangebars(vals, lows, highs, color = :red)
rangebars!(vals, lows, highs, color = LinRange(0, 1, length(vals)),
    whiskerwidth = 3, direction = :x)
current_figure()
```

