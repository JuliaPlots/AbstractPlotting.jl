# AbstractPlotting (deprecated)

Everything from AbstractPlotting.jl got moved to Makie.jl. 
Makie went through a few breaking changes since then
and the version closest to the current AbstractPlotting is [Makie@0.13.0](https://github.com/JuliaPlots/Makie.jl/releases?after=v0.13.1%2Bdocs1).
If you want to upgrade to that new version, simply replace every instance of `AbstractPlotting` by `Makie`. 
If you just want you just want to plot, use one of the backends directly: GLMakie, CairoMakie, WGLMakie.
They re-export all the functionality of Makie.jl.
