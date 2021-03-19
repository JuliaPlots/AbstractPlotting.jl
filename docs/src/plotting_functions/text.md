# text

```@docs
text
```

### Examples

By default, text is drawn in screen space.
The text anchor is given in data coordinates, but the size of the glyphs is independent of data scaling.
The boundingbox of the text will include every data point or every text anchor point.
This also means that `autolimits!` might cut off your text, because the glyphs don't have a meaningful size in data coordinates, and you have to take some care to manually place it such that it is fully visible.

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

For text whose dimensions are meaningful in data space, set `space = :data`.
This means that the boundingbox of the text in data coordinates will include every glyph.

```@example
using CairoMakie
CairoMakie.activate!() # hide
AbstractPlotting.inline!(true) # hide

f = Figure(resolution = (800, 600))
LScene(f[1, 1])

text!(
    fill("Makie", 7),
    rotation = [i / 7 * 1.5pi for i in 1:7],
    position = [Point3f0(0, 0, i/2) for i in 1:7],
    color = [cgrad(:viridis)[x] for x in LinRange(0, 1, 7)],
    align = (:left, :baseline),
    textsize = 1,
    space = :data
)

f
```
