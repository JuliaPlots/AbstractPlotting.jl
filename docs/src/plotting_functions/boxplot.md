# boxplot

```@docs
boxplot
```

### Examples

```@example
using CairoMakie
CairoMakie.activate!() # hide
AbstractPlotting.inline!(true) # hide

xs = rand(["a", "b", "c"], 1000)
ys = randn(1000)

boxplot(xs, ys)
```

```@example
using CairoMakie
CairoMakie.activate!() # hide
AbstractPlotting.inline!(true) # hide

xs = rand(["a", "b", "c"], 1000)
ys = randn(1000)
dodge = rand(1:2, 1000)
color = ["orange", "teal", "orange", "teal", "orange", "teal"]

boxplot(xs, ys, dodge = dodge, color = color, show_notch = true)
```
