## `errorbars`

```@docs
errorbars
```

### Examples

```@example
using GLMakie
AbstractPlotting.inline!(true) # hide

xs = 0:0.5:10
ys1 = 0.5 .* sin.(xs)
ys2 = ys1 .- 1
ys3 = ys1 .- 2

lowerrors = fill(0.1, length(xs))
higherrors = LinRange(0.1, 0.4, length(xs))


errorbars(xs, ys1, higherrors, color = :red) # same low and high error
errorbars!(xs, ys2, lowerrors, higherrors, color = LinRange(0, 1, length(xs)))
errorbars!(xs, ys3, lowerrors, higherrors, whiskerwidth = 3, direction = :x)

# plot position scatters so low and high errors can be discriminated
scatter!(xs, ys1, markersize = 3, color = :black)
scatter!(xs, ys2, markersize = 3, color = :black)
scatter!(xs, ys3, markersize = 3, color = :black)
current_figure()
```

