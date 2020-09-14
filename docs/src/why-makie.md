# Why `Makie`?

`Makie` is a high level plotting library with a focus on interactivity and speed.

It can also be seen as a prototype for a new design of [`Plots.jl`](https://github.com/JuliaPlots/Plots.jl),
since it will implement a very similar interface and incorporate a lot of the ideas.

A fresh start instead of the already available `GLVisualize` backend for `Plots.jl` was needed for the following reasons:

1. `Plots.jl` was written to create static plots without any interaction. This is deeply reflected in the internal design
   and makes it hard to integrate the high performance interaction possibilities from `GLVisualize`.
1. `Plots.jl` has many high level plotting packages as a backend which lead to a very inconsistent design for the backends.
   For example, there is no straight interface a backend needs to implement. The backend abstraction happens at a very high level
   and the `Plots.jl` design relies on the high-level backends to fill in a lot of functionality - which lead to a lot of duplicated work
   for the lower level backends and a lot of inconsistent behavior since the code isn't shared between backends.
   It also means that it is a lot of work to maintain a backend.
1. The attributes a plot/series contains and where the default creation happens is opaque and not well documented.
   Sometimes it's the task of the backend to create defaults for missing attributes, sometimes `Plots.jl` creates the defaults.
   A missing attribute is signalled in too many different ways (e.g. `false`, `nothing`, `""`) which then needs to be checked and filled in by the backend.
   This leads to making it very challenging to e.g. find the color of a line for different plot types and creates buggy, inconsistent and messy backend code.
1. As mentioned in point 2, there is not a single consistent low level drawing API.
   This also influences recipes, since there is not a straight mapping to a low level drawing API and therefore it's not that easy to compose.
   There should be a finite set of "atomic" drawing operations (which can't be decomposed further) which a backend
   needs to implement and the rest should be implemented via recipes using those atomic operations.
   So once a backend implements those, it will support all of the plotting operations and only minor maintenance work needs to be done from that point on.
1. Backend loading is done in `Plots.jl` via evaling the backend code. This has at 4 negative consequences:
   1. Backend code can't be precompiled leading to longer load times
   1. Backend dependencies are not in the `Plots.jl` `REQUIRE` file
   1. Backend dependencies get loaded via a function that gets evaled, so it's a bit awkward to use those dependencies in the function inside a backend
   1. World age issues because of the `eval`
