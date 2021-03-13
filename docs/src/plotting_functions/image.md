## `image`

```@docs
image
```

### Examples

```@example
using GLMakie
AbstractPlotting.inline!(true) # hide
using FileIO

img = rotr90(load("../assets/cow.png"))

image(img)
```


