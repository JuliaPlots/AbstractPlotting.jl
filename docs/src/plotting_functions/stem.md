# stem

```@docs
stem
```

### Examples

```@example
using GLMakie
GLMakie.activate!() # hide
AbstractPlotting.inline!(true) # hide

xs = LinRange(0, 4pi, 30)

f = Figure()
stem(f[1, 1], xs, sin.(xs))
stem(f[1, 2], xs, sin,
    offset = 0.5, trunkcolor = :blue, marker = :rect,
    stemcolor = :red, color = :orange,
    markersize = 15, strokecolor = :red, strokewidth = 3,
    trunklinestyle = :dash, stemlinestyle = :dashdot)
stem(f[2, 1], xs, sin.(xs),
    offset = LinRange(-0.5, 0.5, 30),
    color = LinRange(0, 1, 30), colorrange = (0, 0.5),
    trunkcolor = LinRange(0, 1, 30), trunkwidth = 5)
stem(f[2, 2], 0.5xs, 2 .* sin.(xs), 2 .* cos.(xs),
    offset = Point3f0.(0.5xs, sin.(xs), cos.(xs)),
    stemcolor = LinRange(0, 1, 30), stemcolormap = :Spectral, stemcolorrange = (0, 0.5))
f
```


