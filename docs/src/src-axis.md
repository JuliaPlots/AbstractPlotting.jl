# Axis

The axis is just a scene object, making it easy to manipulate and share between plots.
Axis objects also contains the mapping you want to apply to the data and can interactively be changed.
An Axis object can be created from any boundingbox and inserted into any plot.

There are two types of axes: `Axis2D` and `Axis3D`.

## Interacting with the Axis

One can quite easily interact with the attributes of the axis like with any other plot.

You can access the axis of a `scene` by doing

```
axis = scene[Axis]
```

The axis attributes are nested, and there are different attributes depending on whether it is an `Axis2D` or `Axis3D` object.

You can access the nested attributes in multiple ways. Take the nested attribute `axis -> :names -> :axisnames`, for example:

1. `axis[:names, :axisnames] = ("x", "y", "z")`
1. `axis[:names][:axisnames] = ("x", "y", "z")`
1. `axis = (names = (axisnames = ("x", "y", "z"),),)`
