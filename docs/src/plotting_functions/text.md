# text

```@docs
text
```

### Examples

```@example
using CairoMakie
CairoMakie.activate!() # hide
AbstractPlotting.inline!(true) # hide

f = Figure(resolution = (800, 600))

Axis(f[1, 1], aspect = DataAspect())

scatter!(Point2f0(0, 0))
text!("center", position = (0, 0), align = (:center, :center))

circlepoints = [(cos(a), sin(a)) for a in LinRange(0, 2pi, 16)[1:end-1]]
scatter!(circlepoints)
text!(
    string.(1:15),
    position = circlepoints,
    rotation = LinRange(0, 2pi, 16)[1:end-1],
    align = (:right, :baseline),
    color = cgrad(:rainbow, 15)[1:15]
)

f
```

Text in data space

```@example
using CairoMakie
CairoMakie.activate!() # hide
AbstractPlotting.inline!(true) # hide

f = Figure()
LScene(f[1, 1])

text!(
    fill("hello", 10),
    rotation = [i / 10 * 2pi for i in 1:10],
    position = [Point3f0(0, 0, i/3) for i in 1:10],
    color = rand(RGBf0, 10),
    align = (:left, :baseline),
    textsize = 1,
    space = :data
)

f
```
