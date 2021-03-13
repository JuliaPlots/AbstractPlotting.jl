# poly

```@docs
poly
```

### Examples

```@example
using GLMakie
using AbstractPlotting.GeometryBasics
AbstractPlotting.inline!(true) # hide


f, _ = poly(Point2f0[(0, 0), (2, 0), (3, 1), (1, 1)], color = :red, strokecolor = :black, strokewidth = 1)

# polygon with hole
p = Polygon(
    Point2f0[(0, 0), (2, 0), (3, 1), (1, 1)],
    [Point2f0[(0.75, 0.25), (1.75, 0.25), (2.25, 0.75), (1.25, 0.75)]]
)
poly(f[1, 2], p, color = :blue)

# vector of shapes
poly(f[2, 1],
    [Rect(i, j, 0.75, 0.5) for i in 1:5 for j in 1:3],
    color = 1:15,
    colormap = :heat
)

# shape decomposition
poly(f[2, 2], Circle(Point2f0(0, 0), 15f0), color = :pink,
    axis = (autolimitaspect = 1,))

# vector of polygons
ps = [Polygon(rand(Point2f0, 3) .+ Point2f0(i, j))
    for i in 1:5 for j in 1:10]
poly(f[1:2, 3], ps, color = rand(RGBf0, length(ps)),
    axis = (backgroundcolor = :gray15,))

f
```

