# IntervalSlider

The interval slider selects a

```@example
using CairoMakie
AbstractPlotting.inline!(true) # hide
CairoMakie.activate!() # hide


f = Figure()
Axis(f[1, 1], limits = (0, 1, 0, 1))

rs_h = IntervalSlider(f[2, 1], range = LinRange(0, 1, 1000), startvalues = (0.2, 0.8))
rs_v = IntervalSlider(f[1, 2], range = LinRange(0, 1, 1000), startvalues = (0.4, 0.9),
    horizontal = false)

data = rand(Point2f0, 300)

colors = lift(rs_h.values, rs_v.values) do hrange, vrange
    map(data) do d
        (hrange[1] < d[1] < hrange[2]) && (vrange[1] < d[2] < vrange[2])
    end
end

scatter!(data, color = colors, colormap = [:black, :orange], strokewidth = 0)

f
```