# Layoutables

!!! note
    All examples in this section are presented as static CairoMakie vector graphics for clarity of visuals
    Keep in mind that CairoMakie is not interactive.
    Use GLMakie for interactive widgets, as WGLMakie currently doesn't have picking implemented.

Layoutables are objects which can be added to a Figure or Scene and have their location and size controlled by a `GridLayout`.
A `Figure` has its own internal `GridLayout` and therefore offers simplified syntax for adding layoutables to it.
If you want to work with a bare `Scene`, you can attach a `GridLayout` to its pixel area.
The `layoutscene` function is supplied for this purpose.

```@example
using CairoMakie
CairoMakie.activate!() # hide
AbstractPlotting.inline!(true) # hide

f = Figure(resolution = (800, 600))
ax = Axis(f[1, 1])
f
save("layoutables_figure.svg", f); nothing # hide
```

![layoutables_figure](layoutables_figure.svg)

```@example
using CairoMakie
CairoMakie.activate!() # hide
AbstractPlotting.inline!(true) # hide

scene, layout = layoutscene(resolution = (800, 600))
ax = layout[1, 1] = Axis(scene)
scene
save("layoutables_scene.svg", scene); nothing # hide
```

![layoutables_scene](layoutables_scene.svg)


## Deleting Layoutables

To remove layoutables from their layout and the figure or scene, use `delete!(layoutable)`.
