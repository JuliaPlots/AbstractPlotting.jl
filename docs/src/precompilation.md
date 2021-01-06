## Precompilation

You can compile a binary for Makie and add it to your system image for fast plotting times with no JIT overhead.
To do that, you need to check out the additional packages for precompilation.
Then you can build a system image like this:

```julia
using Pkg
# add PackageCompiler and other dependencies
pkg"add PackageCompiler"
# Make sure you have v1.0 or higher of PackageCompiler!

using PackageCompiler

# This will create a system image in the current directory, which you can
# use by launching Julia with `julia -J ./MakieSys.so`.
PackageCompiler.create_sysimage(
    :Makie;
    sysimage_path="MakieSys.so",
    precompile_execution_file=joinpath(pkgdir(Makie), "test", "test_for_precompile.jl")
)
```

Should the display not work after compilation, call `AbstractPlotting.__init__()` immediately after `using Makie`.
