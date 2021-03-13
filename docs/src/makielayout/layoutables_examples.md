```@eval
using CairoMakie
CairoMakie.activate!()
```

# Layoutables & Widgets

!!! note
    All examples here are presented as CairoMakie svg's for clarity of visuals, but keep in mind that CairoMakie is not interactive. Use GLMakie for interactive widgets, WGLMakie currently doesn't have picking implemented which is needed for them.

```@contents
Pages = ["layoutables_examples.md"]
Depth = 2
```





## Deleting Layoutables

To remove axes, colorbars and other layoutables from their layout and the figure or scene,
use `delete!(layoutable)`.

```@eval
using GLMakie
GLMakie.activate!()
```
