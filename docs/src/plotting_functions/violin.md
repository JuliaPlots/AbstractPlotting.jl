# violin

```@docs
violin
```

### Examples

```@example
using CairoMakie
CairoMakie.activate!() # hide
AbstractPlotting.inline!(true) # hide

xs = rand(["a", "b", "c"], 1000)
ys = randn(1000)

violin(xs, ys)
```

```@example
using CairoMakie
CairoMakie.activate!() # hide
AbstractPlotting.inline!(true) # hide

xs1 = rand(["a", "b", "c"], 1000)
ys1 = randn(1000)
dodge1 = rand(1:2, 1000)

xs2 = rand(["a", "b", "c"], 1000)
ys2 = randn(1000)
dodge2 = rand(1:2, 1000)

violin(xs1, ys1, dodge = dodge1, side = :left, color = "orange")
violin!(xs2, ys2, dodge = dodge2, side = :right, color = "teal")
```
