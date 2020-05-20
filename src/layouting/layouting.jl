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


function layout_text(
        string::AbstractString, textsize::Union{AbstractVector, Number},
        font, align, rotation, model, justification, lineheight
    ) where {N, T}

    offset_vec = to_align(align)
    ft_font = to_font(font)
    rscale = to_textsize(textsize)
    rot = to_rotation(rotation)

    atlas = get_texture_atlas()
    # mpos = model * Vec4f0(to_ndim(Vec3f0, startpos, 0f0)..., 1f0)
    # pos = to_ndim(Point3f0, mpos, 0)

    fontperchar = attribute_per_char(string, ft_font)
    textsizeperchar = attribute_per_char(string, rscale)

    glyphpos, height_insensitive_bbs = glyph_positions(string, fontperchar, textsizeperchar, offset_vec[1],
        offset_vec[2], lineheight, justification)

    positions = Point3f0[]
    bbs = FRect2D[]

    for (i, (group, hi_bbs)) in enumerate(zip(glyphpos, height_insensitive_bbs))
        for (gp, hi_bb) in zip(group, hi_bbs)
            p = to_ndim(Point3f0, gp, 0)
            # rotate around the alignment point (this is now at [0, 0, 0])
            p_rotated = rot * p
            push!(positions, p_rotated)
            push!(bbs, hi_bb)
        end

        # between groups, push a zero point for newline, this should be ignored later
        # and serves only as a placeholder to make iteration over the string easier
        if i < length(glyphpos)
            push!(positions, Point3f0(0, 0, 0))
            # just take a random extent, just as a filler
            # easier than constructing one
            push!(bbs, hi_bbs[1])
        end
    end

    return positions, bbs
end

function glyph_positions(str::AbstractString, font_per_char, fontscale_px, halign, valign, lineheight_factor, justification)

    isempty(str) && return Vec2f0[]

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

    ys_aligned = ys .- first_line_ascender .+ (1 - valign) .* overall_height

    height_insensitive_bbs = map(cfs_groups, extents) do group, extent
        map(group, extent) do (char, font, scale), ext
            unscaled_hi_bb = height_insensitive_boundingbox(get_extent(font, char), font)
            FRect2D(AbstractPlotting.origin(unscaled_hi_bb) * scale, widths(unscaled_hi_bb) * scale)
        end
    end


    charorigins = [Vec2.(xsgroup, y) for (xsgroup, y) in zip(xs_aligned, ys_aligned)]
    return charorigins, height_insensitive_bbs
end

function alignment2num(x::Symbol)
    (x == :center) && return 0.5f0
    (x in (:left, :bottom)) && return 0.0f0
    (x in (:right, :top)) && return 1.0f0
    return 0.0f0 # 0 default, or better to error?
end
