# Basic Tutorial

Here is a quick tutorial to get you started. We assume you have [Julia](https://julialang.org/) and `GLMakie.jl` (or one of the other backends) installed already.

First, we import GLMakie, which might take a little bit of time because there is a lot to precompile. Just sit tight!
For this tutorial, we also call `AbstractPlotting.inline!(true)` so plots appear inline after each example.
If you set `AbstractPlotting.inline!(false)` and the currently active backend supports windows, an interactive window will open whenever you return a `Figure`.

```@example 1
using GLMakie
GLMakie.activate!() # hide
AbstractPlotting.inline!(true)
nothing # hide
```

!!! note
    A `Figure` is usually displayed whenever it is returned in global scope (e.g. in the REPL).
    To display a Figure from within a local scope, like from within a function, you can directly call `display(figure)`.  

## First plot

Makie has many different plotting functions, one of the most common ones is `lines`.
You can just call such a function and your plot will appear if your coding environment can show png or svg files.
Remember that we called `AbstractPlotting.inline!(true)`, so no window will open.

```@example
using GLMakie

x = LinRange(0, 10, 100)
y = sin.(x)
lines(x, y)
```

Another common function is `scatter`.

```@example
using GLMakie

x = LinRange(0, 10, 100)
y = sin.(x)
scatter(x, y)
```

## Multiple plots

Every plotting function has a version with and one without `!`.
For example, there's `scatter` and `scatter!`, `lines` and `lines!`, etc.
The functions without a `!` always create a new axis with a plot inside, while the functions with `!` plot into an already existing axis.

Here's how you could plot two lines on top of each other.

```@example
using GLMakie

x = LinRange(0, 10, 100)
y1 = sin.(x)
y2 = cos.(x)

lines(x, y1)
lines!(x, y2)
current_figure()
```

The second `lines!` call plots into the axis created by the first `lines` call.
If you don't specify an axis to plot into, it's as if you had called `lines!(current_axis(), ...)`.

The call to `current_figure` is necessary here, because functions with `!` return only the newly created plot object, but this alone does not cause the figure to display when returned.

## Attributes

Every plotting function has attributes which you can set through keyword arguments.
The lines in the previous example both have the same default color, which we can change easily.

```@example
using GLMakie

x = LinRange(0, 10, 100)
y1 = sin.(x)
y2 = cos.(x)

lines(x, y1, color = :red)
lines!(x, y2, color = :blue)
current_figure()
```

Other plotting functions have different attributes.
The function `scatter`, for example, does not only have the `color` attribute, but also a `markersize` attribute.

```@example
using GLMakie

x = LinRange(0, 10, 100)
y1 = sin.(x)
y2 = cos.(x)

scatter(x, y1, color = :red, markersize = 5)
scatter!(x, y2, color = :blue, markersize = 10)
current_figure()
```

If you save the plot object returned from a call like `scatter!`, you can also manipulate its attributes later with the syntax `plot.attribute = new_value`.

```@example
using GLMakie

x = LinRange(0, 10, 100)
y1 = sin.(x)
y2 = cos.(x)

scatter(x, y1, color = :red, markersize = 5)
sc = scatter!(x, y2, color = :blue, markersize = 10)
sc.color = :green
sc.markersize = 20
current_figure()
```


## Simple legend

If you add label attributes to your plots, you can call the `axislegend` function to add a legend with all labeled plots to the current axis.

```@example
using GLMakie

x = LinRange(0, 10, 100)
y1 = sin.(x)
y2 = cos.(x)

lines(x, y1, color = :red, label = "sin")
lines!(x, y2, color = :blue, label = "cos")
axislegend()
current_figure()
```

## Subplots

Makie uses a powerful layout system under the hood, which allows you to create very complex figures with many subplots.
For the easiest way to do this, we need a `Figure` object.
So far, we haven't seen this explicitly, it was created in the background in the first plotting function call.

We can also create a `Figure` directly and then continue working with it.
We can make subplots by giving the location of the subplot in our layout grid as the first argument to our plotting function.
The basic syntax for specifying the location in a figure is `fig[row, col]`.

```@example
using GLMakie

x = LinRange(0, 10, 100)
y = sin.(x)

fig = Figure()
lines(fig[1, 1], x, y, color = :red)
lines(fig[1, 2], x, y, color = :blue)
lines(fig[2, 1:2], x, y, color = :green)

fig
```

Each `lines` call creates a new axis in the position given as the first argument, that's why we use `lines` and not `lines!` here.

## Constructing axes manually

Like `Figure`s, we can also create axes manually.
This is useful if we want to prepare an empty axis to then plot into it later.

The default 2D axis that we have created implicitly so far is called [`Axis`](@ref) and can also be created in a specific position in the figure by passing that position as the first argument.

For example, we can create a figure with three axes.

```@example manual_axes
using GLMakie
 
f = Figure()
ax1 = Axis(f[1, 1])
ax2 = Axis(f[1, 2])
ax3 = Axis(f[2, 1:2])
f
```

And then we can continue to plot into these empty axes.

```@example manual_axes
lines!(ax1, 0..10, sin)
lines!(ax2, 0..10, cos)
lines!(ax3, 0..10, sqrt)
f
```

Axes also have many attributes that you can set, for example to give them a title.

```@example manual_axes 
ax1.title = "sin"
ax2.title = "cos"
ax3.title = "sqrt"
f
```

## Legend and Colorbar

We have seen two `Layoutables` so far, the [`Axis`](@ref) and the [`Legend`](@ref) which was created by the function `axislegend`.
All `Layoutable`s can be placed into the layout of a figure at arbitrary positions, which makes it easy to assemble complex figures.

In the same way as with the [`Axis`](@ref) before, you can also create a [`Legend`](@ref) manually and then place it freely, wherever you want, in the figure.
There are multiple ways to create [`Legend`](@ref)s, for one of them you pass one vector of plot objects and one vector of label strings.

You can see here that we can deconstruct the return value from the two `lines` calls into one newly created axis and one plot object each.
We can then feed the plot objects to the legend constructor.
We place the legend in the second column and across both rows, which centers it nicely next to the two axes.

```@example
using GLMakie

f = Figure()
ax1, l1 = lines(f[1, 1], 0..10, sin, color = :red)
ax2, l2 = lines(f[2, 1], 0..10, cos, color = :blue)
Legend(f[1:2, 2], [l1, l2], ["sin", "cos"])
f
```

The [`Colorbar`](@ref) works in a very similar way.
We just need to pass a position in the figure to it, and one plot object.
In this example, we use a `heatmap`.

You can see here that we split the return value of `heatmap` into three parts: the newly created figure, the axis and the heatmap plot object.
This is useful as we can then continue with the figure `f` and the heatmap `hm` which we need for the colorbar.

```@example
using GLMakie

f, ax, hm = heatmap(randn(20, 20))
Colorbar(f[1, 2], hm, width = 20)
f
```

The previous short syntax is basically equivalent to this longer, manual version.
You can switch between those workflows however you please.

```@example
using GLMakie

f = Figure()
ax = Axis(f[1, 1])
hm = heatmap!(ax, randn(20, 20))
Colorbar(f[1, 2], hm, width = 20)
f
```

## Next steps

We've only looked at a small subset of Makie's functionality here.

You can read about the different available plotting functions with examples in the `Plotting Functions` section.

If you want to learn about making complex figures with nested sublayouts, have a look at the [Layout Tutorial](@ref).

If you're interested in creating interactive visualizations that use Makie's special `Observables` workflow, this is explained in more detail in the [Observables & Interaction](@ref) section.

If you want to create animated movies, you can find more information in the [Animations](@ref) chapter.
