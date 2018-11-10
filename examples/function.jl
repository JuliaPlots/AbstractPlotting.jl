using KernelDensity

to_tuple(t::Tuple) = t
to_tuple(t) = (t,)

function convert_arguments(P::Type{<:AbstractPlot}, f::Function, args...; kwargs...)
    tmp = f(args...; Iterators.filter(t -> last(t) != automatic, kwargs)...) |> to_tuple
    convert_arguments(P, tmp...)
end

# remove convert_arguments(P, f, x) = (x, f.(x))
convert_arguments(P::Type{<: AbstractPlot}, d::KernelDensity.UnivariateKDE) =
    Lines => convert_arguments(P, d.x, d.density)

convert_arguments(P::Type{<: AbstractPlot}, d::KernelDensity.BivariateKDE) =
    Heatmap => convert_arguments(P, d.x, d.y, d.density)

plot(kde, rand(100)) #line plot
scatter(kde, rand(100))

plot(kde, rand(100, 2)) #heatmap
surface(kde, rand(100, 2))
