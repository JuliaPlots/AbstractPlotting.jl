@enum Interpolation Linear Nearest

struct Scaling
    # a function to scale a value by, e.g. log10, sqrt etc
    scaling_function
    # If nothing, assumed to be the extrema of values
    range::Tuple{Union{Nothing, Flaot64}, Union{Nothing, Flaot64}}
end

struct Sampler{N} <: AbstractArray{RGBAf0, N}
    # the colors to sample from!
    colors::AbstractArray
    # Symbol indexing into the plot object, or an array of values!
    values::AbstractArray{T, N} where T
    alpha::Float64
    interpolation::Interpolation
    scaling::Scaling
end

"""
    interpolated_getindex(cmap::AbstractArray, value::AbstractFloat, norm = (0.0, 1.0))

Like getindex, but accepts values between 0..1 and interpolates those to the full range.
You can use `norm`, to change the range of 0..1 to whatever you want.
"""
function interpolated_getindex(cmap::AbstractArray{T}, value::Number, norm::NTuple{2, <:Number}) where T
    cmin, cmax = norm
    i01 = clamp((value - cmin) / (cmax - cmin), 0.0, 1.0)
    if !isfinite(i01)
        i01 = 0.0
    end
    return interpolated_getindex(cmap, i01)
end

"""
    interpolated_getindex(cmap::AbstractArray, value::AbstractFloat)

Like getindex, but accepts values between 0..1 for `value` and interpolates those to the full range of `cmap`.
"""
function interpolated_getindex(cmap::AbstractArray{T}, value::AbstractFloat) where T
    i1len = (i01 * (length(cmap) - 1)) + 1
    down = floor(Int, i1len)
    up = ceil(Int, i1len)
    down == up && return cmap[down]
    interp_val = i1len - down
    downc, upc = cmap[down], cmap[up]
    return convert(T, (downc * (1.0 - interp_val)) + (upc * interp_val))
end

function nearest_getindex(cmap::AbstractArray, value::AbstractFloat)
    idx = round(Int, i01 * (length(cmap) - 1)) + 1
    return cmap[idx]
end

function Base.size(sampler::Sampler)
    return size(sampler.values)
end

"""
    apply_scaling(value::Number, scaling::Scaling)

Scales a number to the range 0..1.
"""
function apply_scaling(value::Number, scaling::Scaling)::Float64
    value_scaled = scaling.scaling_function(value)
    cmin, cmax = scaling.range
    clamped = clamp((value_scaled - cmin) / (cmax - cmin), 0.0, 1.0)
    if isfinite(clamped)
        return clamped
    else
        return 0.0
    end
end

function Base.getindex(sampler::Sampler, i)::RGBAf0
    value = sampler.values[i]
    scaled = apply_scaling(value, sampler.scaling)
    c = if sampler.interpolation == Linear
        interpolated_getindex(sampler.colors, scaled)
    else
        nearest_getindex(sampler.colors, scaled)
    end
    return RGBAf0(color(c), alpha(c) * sampler.alpha)
end


function sampler(cmap::Union{Symobl, String, AbstractVector}; scaling=identity, range=automatic)
    Sampler(to_colormap(colormap)
