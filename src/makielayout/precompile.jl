function _precompile_()
    ccall(:jl_generating_output, Cint, ()) == 1 || return nothing
    @assert precompile(LLegend, (Scene, Node{Vector{Tuple{Optional{String}, Vector{LegendEntry}}}}))
    @assert precompile(LLegend, (Scene, AbstractArray, Vector{String}))
    @assert precompile(LColorbar, (Scene,))
    @assert precompile(LAxis, (Scene,))
    @assert precompile(LMenu, (Scene,))
    @assert precompile(LButton, (Scene,))
    @assert precompile(LSlider, (Scene,))
    @assert precompile(LTextbox, (Scene,))

    @assert precompile(layoutscene, ())
end
