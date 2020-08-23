using FreeTypeAbstraction: hadvance, leftinkbound, inkwidth, get_extent, ascender, descender

one_attribute_per_char(attribute, string) = (attribute for char in string)

function one_attribute_per_char(font::NativeFont, string)
    return (find_font_for_char(char, font) for char in string)
end

function attribute_per_char(string, attribute)
    n_words = 0
    if attribute isa AbstractVector
        if length(attribute) == length(string)
            return attribute
        else
            n_words = length(split(string, r"\s+"))
            if length(attribute) == n_words
                i = 1
                return map(collect(string)) do char
                    f = attribute[i]
                    char == "\n" && (i += 1)
                    return f
                end
            end
        end
    else
        return one_attribute_per_char(attribute, string)
    end
    error("A vector of attributes with $(length(attribute)) elements was given but this fits neither the length of '$string' ($(length(string))) nor the number of words ($(n_words))")
end

"""
    Glyphlayout

Stores information about the glyphs in a string that had a layout calculated for them.
`origins` are the character origins relative to the layout's [0,0] point (the alignment)
and rotation anchor). `bboxes` are the glyph bounding boxes relative to the glyphs' own
origins. `hadvances` are the horizontal advance values, those are mostly needed for interactive
purposes, for example to display a cursor at the right offset from a space character.
"""
struct Glyphlayout
    origins::Vector{Point3f0}
    bboxes::Vector{FRect2D}
    hadvances::Vector{Float32}
end

"""
    layout_text(
        string::AbstractString, textsize::Union{AbstractVector, Number},
        font, align, rotation, model, justification, lineheight
    )

Compute a Glyphlayout for a `string` given textsize, font, align, rotation, model, justification, and lineheight.
"""
function layout_text(
        string::AbstractString, textsize::Union{AbstractVector, Number},
        font, align, rotation, model, justification, lineheight
    )

    ft_font = to_font(font)
    rscale = to_textsize(textsize)
    rot = to_rotation(rotation)

    atlas = get_texture_atlas()
    # mpos = model * Vec4f0(to_ndim(Vec3f0, startpos, 0f0)..., 1f0)
    # pos = to_ndim(Point3f0, mpos, 0)

    fontperchar = attribute_per_char(string, ft_font)
    textsizeperchar = attribute_per_char(string, rscale)

    glyphlayout = glyph_positions(string, fontperchar, textsizeperchar, align[1],
        align[2], lineheight, justification, rot)

    return glyphlayout
end

"""
    glyph_positions(str::AbstractString, font_per_char, fontscale_px, halign, valign, lineheight_factor, justification, rotation)

Calculate the positions for each glyph in a string given a certain font, font size, alignment, etc.
This layout in text coordinates, relative to the anchor point [0,0] can then be translated and
rotated to wherever it is needed in the plot.
"""
function glyph_positions(str::AbstractString, font_per_char, fontscale_px, halign, valign, lineheight_factor, justification, rotation)

    isempty(str) && return Vec2f0[]

    halign = if halign isa Number
        Float32(halign)
    elseif halign == :left
        0.0f0
    elseif halign == :center
        0.5f0
    elseif halign == :right
        1.0f0
    else
        error("Invalid halign $halign. Valid values are <:Number, :left, :center and :right.")
    end

    char_font_scale = collect(zip([c for c in str], font_per_char, fontscale_px))

    linebreak_indices = (i for (i, c) in enumerate(str) if c == '\n')

    groupstarts = [1; linebreak_indices .+ 1]
    groupstops = [linebreak_indices .- 1; length(str)]

    cfs_groups = map(groupstarts, groupstops) do start, stop
        char_font_scale[start:stop]
    end

    extents = map(cfs_groups) do group
        # TODO: scale as SVector not Number
        [get_extent(font, char) .* SVector(scale, scale) for (char, font, scale) in group]
    end

    # we need the advances for correct cursor placement
    hadvances = map(extents) do extgroup
        hadvance.(extgroup)
    end

    # add or subtract kernings?
    xs = map(extents) do extgroup
        cumsum([isempty(extgroup) ? 0.0 : -leftinkbound(extgroup[1]); hadvance.(extgroup[1:end-1])])
    end

    # each linewidth is the last origin plus inkwidth
    linewidths = last.(xs) .+ [isempty(extgroup) ? 0.0 : inkwidth(extgroup[end]) for extgroup in extents]
    maxwidth = maximum(linewidths)

    width_differences = maxwidth .- linewidths

    xs_justified = map(xs, width_differences) do xsgroup, wd
        xsgroup .+ wd * justification
    end

    # make lineheight a multiple of the largest lineheight in each line
    lineheights = map(cfs_groups) do group
        # guard from empty reduction
        isempty(group) && return 0f0

        maximum(group) do (char, font, scale)
            Float32(font.height / font.units_per_EM * lineheight_factor * scale)
        end
    end

    # how to define line height relative to font size?
    ys = cumsum([0; -lineheights[2:end]])


    # x alignment
    xs_aligned = [xsgroup .- halign * maxwidth for xsgroup in xs_justified]

    # y alignment
    # first_max_ascent = maximum(hbearing_ori_to_top, extents[1])
    # last_max_descent = maximum(x -> inkheight(x) - hbearing_ori_to_top(x), extents[end])

    first_line_ascender = maximum(cfs_groups[1]) do (char, font, scale)
        ascender(font) * scale
    end

    last_line_descender = minimum(cfs_groups[end]) do (char, font, scale)
        descender(font) * scale
    end

    overall_height = first_line_ascender - ys[end] - last_line_descender

    ys_aligned = if valign == :baseline
        ys .- first_line_ascender .+ overall_height .+ last_line_descender
    else
        va = if valign isa Number
            Float32(valign)
        elseif valign == :top
            1f0
        elseif valign == :bottom
            0f0
        elseif valign == :center
            0.5f0
        else
            error("Invalid valign $valign. Valid values are <:Number, :bottom, :baseline, :top, and :center.")
        end

        ys .- first_line_ascender .+ (1 - va) .* overall_height
    end

    height_insensitive_bbs = map(cfs_groups, extents) do group, extent
        map(group, extent) do (char, font, scale), ext
            unscaled_hi_bb = height_insensitive_boundingbox(get_extent(font, char), font)
            FRect2D(AbstractPlotting.origin(unscaled_hi_bb) * scale, widths(unscaled_hi_bb) * scale)
        end
    end

    charorigins = [Ref(rotation) .* Point3f0.(xsgroup, y, 0) for (xsgroup, y) in zip(xs_aligned, ys_aligned)]

    # concantenate all line-related vectors into one. fill info for '\n' chars with NaN data, doesn't matter
    charorigins_vec = padded_vcat(charorigins, Point3f0(NaN))
    height_insensitive_bbs_vec = padded_vcat(height_insensitive_bbs, FRect2D())
    hadvances_vec = padded_vcat(hadvances, NaN)

    return Glyphlayout(charorigins_vec, height_insensitive_bbs_vec, hadvances_vec)
end

# function to concatenate vectors with a value between every pair
function padded_vcat(arrs::AbstractVector{T}, fillvalue) where T <: AbstractVector{S} where S
    n = sum(length.(arrs))
    arr = fill(convert(S, fillvalue), n + length(arrs) - 1)

    counter = 1
    @inbounds for a in arrs
        for v in a
            arr[counter] = v
            counter += 1
        end
        counter += 1
    end
    arr
end

function alignment2num(x::Symbol)
    (x == :center) && return 0.5f0
    (x in (:left, :bottom)) && return 0.0f0
    (x in (:right, :top)) && return 1.0f0
    return 0.0f0 # 0 default, or better to error?
end
