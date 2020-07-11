function LEditBox(scene::Scene; bbox = nothing, kwargs...)

    default_attrs = default_attributes(LEditBox, scene).attributes
    theme_attrs = subtheme(scene, :LEditBox)
    attrs = merge!(merge!(Attributes(kwargs), theme_attrs), default_attrs)

    @extract attrs (padding, textsize, text, font, halign, valign, strokewidth,
        strokecolor, strokecolor_hover, strokecolor_active,
        boxcolor, boxcolor_hover, boxcolor_active,
        textcolor, textcolor_hover, textcolor_active,
        focused, keyboard_layout
    )

    decorations = Dict{Symbol, Any}()

    layoutobservables = LayoutObservables(
        LEditBox, attrs.width, attrs.height, attrs.tellwidth, attrs.tellheight,
        halign, valign, attrs.alignmode; suggestedbbox = bbox
    )

    textpos = Node(Point2f0(0, 0))
    subarea = lift(bbox -> IRect2D(bbox), layoutobservables.computedbbox)
    subscene = Scene(scene, subarea, camera=campixel!)

    boxrect = lift(layoutobservables.computedbbox) do bbox
        BBox(0, width(bbox), 0, height(bbox))
    end

    on(boxrect) do rect
        textpos[] = Point2f0(
            left(rect) + 0.5f0 * width(rect),
            bottom(rect) + 0.5f0 * height(rect)
        )
    end

    bcolor = Node{Any}(boxcolor[])
    scolor = Node{Any}(strokecolor[])
    # One line doesn't show up :(
    # box = poly!(
    #     subscene, boxrect, strokewidth = strokewidth, strokecolor = scolor,
    #     color = bcolor, raw = true
    # )[end]
    box = mesh!(subscene, boxrect, color = bcolor, raw = true, shading=false)[end]
    outline = wireframe!(subscene, boxrect, linewidth = strokewidth, color = scolor, raw = true)[end]
    decorations[:box] = box



    lcolor = Node{Any}(textcolor[])
    proxy_text = map(t -> isempty(t) ? " " : t, text)
    labeltext = text!(
        subscene, proxy_text, position = textpos, textsize = textsize,
        font = font, color = lcolor, align = (:center, :center), raw = true
    )[end]

    # move text in front of background to be sure it's not occluded
    translate!(labeltext, 0, 0, 1)


    onany(text, textsize, font, padding) do text, textsize, font, padding
        textbb = FRect2D(boundingbox(labeltext))
        autowidth = width(textbb) + padding[1] + padding[2]
        autoheight = height(textbb) + padding[3] + padding[4]
        layoutobservables.autosize[] = (autowidth, autoheight)
    end



    mousestate = addmousestate!(scene, box, labeltext, outline)

    onmouseover(mousestate) do state
        if !focused[]
            bcolor[] = boxcolor_hover[]
            lcolor[] = textcolor_hover[]
            scolor[] = strokecolor_hover[]
        end
    end

    onmouseout(mousestate) do state
        if !focused[]
            bcolor[] = boxcolor[]
            lcolor[] = textcolor[]
            scolor[] = strokecolor[]
        end
    end

    on(focused) do focused
        if focused
            bcolor[] = boxcolor_active[]
            lcolor[] = textcolor_active[]
            scolor[] = strokecolor_active[]
        else
            bcolor[] = boxcolor[]
            lcolor[] = textcolor[]
            scolor[] = strokecolor[]
        end
    end

    # TODO: Is there a better way to do this?
    on(AbstractPlotting.root(scene).events.mousebuttons) do buttons
        if Mouse.left in buttons
            if mouseover(scene, box, labeltext)
                focused[] || (focused[] = true)
            else
                focused[] && (focused[] = false)
            end
        end
    end

    on(AbstractPlotting.root(scene).events.keyboardbuttons) do _keys
        focused[] || return
        isempty(_keys) && return

        if Keyboard.enter in _keys
            focused[] = false
            return
        end

        # TODO Should this return?
        if Keyboard.backspace in _keys
            text[] = chop(text[])
            return
        end

        # TODO shift + alt => modifier = 4?
        # This would probably require some fallback system...
        # e.g. if shift+alt is undefined, do shift
        modifier = 1    # None
        if Keyboard.left_shift in _keys;  modifier = 2 end
        if Keyboard.right_shift in _keys; modifier = 2 end
        if Keyboard.right_alt in _keys;   modifier = 3 end

        characters = Char[]
        for key in _keys
            if key in keys(keyboard_layout[])
                try
                    chars = keyboard_layout[][key]
                    push!(characters, chars[modifier <= end ? modifier : 1])
                catch e
                    @warn "Failed to process $key in LEditBox\n" exception=e
                end
            end
        end

        isempty(characters) && return
        text[] = text[] * join(characters)
    end


    text[] = text[]
    # trigger bbox
    layoutobservables.suggestedbbox[] = layoutobservables.suggestedbbox[]

    LEditBox(scene, layoutobservables, attrs, decorations)
end
