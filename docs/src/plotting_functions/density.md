# density

```@docs
density
```

### Examples

```@example
using CairoMakie
CairoMakie.activate!() # hide
AbstractPlotting.inline!(true) # hide

f = Figure()
Axis(f[1, 1])

density!(randn(200))

f
```


```@example
using CairoMakie
CairoMakie.activate!() # hide
AbstractPlotting.inline!(true) # hide

f = Figure()
Axis(f[1, 1])

density!(randn(200), direction = :y, npoints = 10)

f
```


```@example
using CairoMakie
CairoMakie.activate!() # hide
AbstractPlotting.inline!(true) # hide

f = Figure()
Axis(f[1, 1])

density!(randn(200), color = (:red, 0.3),
    strokecolor = :red, strokewidth = 3, strokearound = true)

f
```


```@example
using CairoMakie
CairoMakie.activate!() # hide
AbstractPlotting.inline!(true) # hide

f = Figure()
Axis(f[1, 1])

vectors = [randn(1000) .+ i/2 for i in 0:5]

for (i, vector) in enumerate(vectors)
    density!(vector, offset = -i/4, color = (:slategray, 0.4),
        bandwidth = 0.1)
end

f
```

#### Gradients

You can color density plots with gradients, either along the `:value` or `:density` dimension.
In the horizontal default case, `:value` means along the horizontal and `:density` along the vertical.

```@example
using CairoMakie
CairoMakie.activate!() # hide
AbstractPlotting.inline!(true) # hide

months = ["January", "February", "March", "April",
    "May", "June", "July", "August", "September",
    "October", "November", "December"]

f = Figure()
Axis(f[1, 1], title = "Fictive temperatures",
    yticks = ((1:12) ./ 4,  reverse(months)))

for i in 12:-1:1
    d = density!(randn(200) .- 2sin((i+3)/6*pi), offset = i / 4,
        color = :value, colormap = :thermal, colorrange = (-5, 5))
    # this helps with layering in GLMakie
    translate!(d, 0, 0, -0.1i)
end
f
```

Due to technical limitations, if you color the `:density` dimension, only a colormap made with just two colors can currently work:

```@example
using CairoMakie
CairoMakie.activate!() # hide
AbstractPlotting.inline!(true) # hide

f = Figure()
Axis(f[1, 1])
for x in 1:5
    d = density!(x * randn(200) .+ 3x,
        color = :density, colormap = [:darkblue, :gray95])
end
f
```
