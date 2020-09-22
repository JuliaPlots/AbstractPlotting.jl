function _precompile_()
    ccall(:jl_generating_output, Cint, ()) == 1 || return nothing
    # for T in (Float32, Float64, Int)
    #     @assert precompile(plot, (Vector{T},))
    # end
    # @assert precompile(plot!, (Annotations,))
    # @assert precompile(plot!, (SceneLike, PlotFunc, Attributes, Tuple{Vararg{Node}}, Node))
    @assert precompile(peaks, ())
    @assert precompile(logo, ())
    @assert precompile(poly_convert, (Vector{Vector{Point{2,Float32}}},))
    @assert precompile(poly_convert, (Vector{GeometryBasics.HyperRectangle{2,Float32}},))
    @assert precompile(poly_convert, (Vector{GeometryBasics.HyperRectangle{2,Int}},))
    @assert precompile(poly_convert, (Vector{HyperSphere{2,Float32}},))
    @assert precompile(rotatedrect, (GeometryBasics.HyperRectangle{2,Float32}, Float32))
    @assert precompile(display, (PlotDisplay, Scene))
    @assert precompile(push!, (Scene, AbstractPlot))

    @assert precompile(Core.kwfunc(axis2d!), (NamedTuple{(:ticks,), Tuple{NamedTuple{(:ranges, :labels), Tuple{Automatic, Automatic}}}}, typeof(axis2d!), Scene, Vararg{Any}))
    @assert precompile(Core.kwfunc(poly!), (NamedTuple{(:color, :strokewidth, :raw),Tuple{Observable{Any},Int64,Bool}}, typeof(poly!), Scene, Vararg{Any}))
end
