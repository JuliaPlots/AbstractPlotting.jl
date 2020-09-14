# Help functions

## `help`

```@docs
help
```

Example usage:
```@example
using Makie # hide
help(scatter; extended = true)
```


## `help_arguments`

```@docs
help_arguments
```

Example usage:
```@example
using Makie # hide
help_arguments(stdout, scatter)
```

## `help_attributes`

```@docs
help_attributes
```

Example usage:
```@example
using Makie # hide
help_attributes(stdout, Scatter; extended = true)
```


# Plot styling options
Use these functions to find out the styling options.

## `available_marker_symbols`

```@example
using AbstractPlotting # hide
AbstractPlotting.available_marker_symbols()
```

## `available_gradients`

```@example
using AbstractPlotting # hide
AbstractPlotting.available_gradients()
```

For other plot attributes and their usage, see the section [Plot attributes](@ref).
