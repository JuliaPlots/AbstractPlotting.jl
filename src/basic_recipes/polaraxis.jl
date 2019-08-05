using AbstractPlotting

using AbstractPlotting: default_ticks, automatic, TextBuffer, start!, finish!

using CoordinateTransformations

function θformatter(theta::Number)
    return string(theta / π) * "π"
end

function rformatter(r::Number)
    return string(r)
end

rmax, rmin = (5e0, 0e0)

θmax, θmin = (2π, 0e0)

provided_θticks = collect(0:π/4:2π)[1:end-1]
provided_rticks = automatic

rscalefunc = identity
θscalefunc = identity

rticks = default_ticks(rmin, rmax, provided_rticks, rscalefunc)
θticks = default_ticks(θmin, θmax, provided_θticks, θscalefunc)

sc = Scene(scale_plot = false, resolution = (2000, 2000))

for r in rticks
    lines!(sc, Circle(Point2f0(0), r |> Float32))
end

anglelines = zeros(Point2f0, 2*length(θticks))

for (i, θ) in enumerate(θticks)
    anglelines[i*2] = Point2f0(rmax * cos(θ), rmax * sin(θ))
end

linesegments!(sc, anglelines)


# Now for the ticks - thetas first!


tickbuffer = TextBuffer(sc, Point{2})

start!(tickbuffer)

θticks_pos = Point2f0.(((θ) -> 1.2 .* rticks[end] .* (cos(θ), sin(θ))).(θticks))

# deleteat!(θticks_pos, [lastindex(θticks)],)
# deleteat!(θticks,     [lastindex(θticks)])

for (θ, pos) in zip(θticks, θticks_pos)
    push!(tickbuffer, θformatter(θ), pos, color = AbstractPlotting.to_color(:black), rotation = Quaternionf0(0,0,0,1), textsize = 0.5, font = to_font("default"), align = (:center, :middle))
end

finish!(tickbuffer)

using GLMakie

sc

save("polar.png", sc; resolution = (2000, 2000))
using UnicodeFun
sc = text()
update!(sc)
sc |> save("fun.png")

# TODO draw theta-ticks
# TODO draw r-ticks
# TODO theme
UnicodeFun.to_subscript('A':'Z' .|> string)
