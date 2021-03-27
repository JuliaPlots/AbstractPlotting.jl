function layoutable(::Type{Textbox}, fig_or_scene; bbox = nothing, kwargs...)

    topscene = get_topscene(fig_or_scene)

    attrs = merge!(
        Attributes(kwargs),
        default_attributes(Textbox, topscene).attributes)

    @extract attrs (halign, valign, textsize, stored_string, placeholder,
        textcolor, textcolor_placeholder, displayed_string,
        boxcolor, boxcolor_focused_invalid, boxcolor_focused, boxcolor_hover,
        bordercolor, textpadding, bordercolor_focused, bordercolor_hover, focused,
        bordercolor_focused_invalid,
        borderwidth, cornerradius, cornersegments, boxcolor_focused,
        validator, restriction, cursorcolor, reset_on_defocus, defocus_on_submit)

    decorations = Dict{Symbol, Any}()

    layoutobservables = LayoutObservables{Textbox}(attrs.width, attrs.height,
        attrs.tellwidth, attrs.tellheight,
        halign, valign, attrs.alignmode; suggestedbbox = bbox)

    scenearea = lift(layoutobservables.computedbbox) do bb
        Rect(round.(Int, bb.origin), round.(Int, bb.widths))
    end

    scene = Scene(topscene, scenearea, raw = true, camera = campixel!)

    cursorindex = Node(0)
    ltextbox = Textbox(fig_or_scene, layoutobservables, attrs, decorations, cursorindex, nothing)



    bbox = lift(FRect2D ∘ AbstractPlotting.zero_origin, scenearea)

    roundedrectpoints = lift(roundedrectvertices, scenearea, cornerradius, cornersegments)

    displayed_string[] = isnothing(stored_string[]) ? placeholder[] : stored_string[]

    displayed_is_valid = lift(displayed_string, validator) do str, validator
        valid::Bool = validate_textbox(str, validator)
    end

    hovering = Node(false)

    realbordercolor = lift(bordercolor, bordercolor_focused,
        bordercolor_focused_invalid, bordercolor_hover, focused, displayed_is_valid, hovering,
        typ = Any) do bc, bcf, bcfi, bch, focused, valid, hovering

        if focused
            valid ? bcf : bcfi
        else
            hovering ? bch : bc
        end
    end

    realboxcolor = lift(boxcolor, boxcolor_focused,
        boxcolor_focused_invalid, boxcolor_hover, focused, displayed_is_valid, hovering,
        typ = Any) do bc, bcf, bcfi, bch, focused, valid, hovering

        if focused
            valid ? bcf : bcfi
        else
            hovering ? bch : bc
        end
    end

    box = poly!(topscene, roundedrectpoints, strokewidth = borderwidth,
        strokecolor = realbordercolor,
        color = realboxcolor, raw = true)
    decorations[:box] = box

    displayed_chars = @lift([c for c in $displayed_string])

    realtextcolor = lift(textcolor, textcolor_placeholder, focused, stored_string, displayed_string, typ = Any) do tc, tcph, foc, cont, disp
        # the textbox has normal text color if it's focused
        # if it's defocused, the displayed text has to match the stored text in order
        # to be normal colored
        if foc || cont == disp
            tc
        else
            tcph
        end
    end

    t = Label(scene, text = displayed_string, bbox = bbox, halign = :left, valign = :top,
        width = Auto(true), height = Auto(true), color = realtextcolor,
        textsize = textsize, padding = textpadding)

    displayed_charbbs = lift(t.layoutobservables.reportedsize) do sz
        charbbs(t.elements[:text])
    end

    cursorpoints = lift(cursorindex, displayed_charbbs) do ci, bbs

        hadvances = t.elements[:text]._glyphlayout[].hadvances::Vector{Float32}

        if ci > length(bbs)
            # correct cursorindex if it's outside of the displayed charbbs range
            cursorindex[] = length(bbs)
            return
        end

        if 0 < ci < length(bbs)
            [leftline(bbs[ci+1])...]
        elseif ci == 0
            [leftline(bbs[1])...]
        else
            [leftline(bbs[ci])...] .+ Point2f0(hadvances[ci], 0)
        end
    end

    cursor = linesegments!(scene, cursorpoints, color = cursorcolor, linewidth = 2)

    cursoranimtask = nothing

    on(t.layoutobservables.reportedsize) do sz
        layoutobservables.autosize[] = sz
    end

    # trigger text for autosize
    t.text = displayed_string[]

    # trigger bbox
    layoutobservables.suggestedbbox[] = layoutobservables.suggestedbbox[]

    mousestate = addmouseevents!(scene)

    onmouseleftdown(mousestate) do state
        focus!(ltextbox)

        if displayed_string[] == placeholder[] || displayed_string[] == " "
            displayed_string[] = " "
            cursorindex[] = 0
            return
        end

        pos = state.data
        closest_charindex = argmin(
            [sum((pos .- center(bb)).^2) for bb in displayed_charbbs[]]
        )
        # set cursor to index of closest char if right of center, or previous char if left of center
        cursorindex[] = if (pos .- center(displayed_charbbs[][closest_charindex]))[1] > 0
            closest_charindex
        else
            closest_charindex - 1
        end
    end

    onmouseover(mousestate) do state
        hovering[] = true
    end

    onmouseout(mousestate) do state
        hovering[] = false
    end

    onmousedownoutside(mousestate) do state
        if reset_on_defocus[]
            reset_to_stored()
        end
        defocus!(ltextbox)
    end

    function insertchar!(c, index)
        if displayed_chars[] == [' ']
            empty!(displayed_chars[])
            index = 1
        end
        newchars = [displayed_chars[][1:index-1]; c; displayed_chars[][index:end]]
        displayed_string[] = join(newchars)
        cursorindex[] = index
    end

    function appendchar!(c)
        insertchar!(c, length(displayed_string[]))
    end

    function removechar!(index)
        newchars = [displayed_chars[][1:index-1]; displayed_chars[][index+1:end]]

        if isempty(newchars)
            newchars = [' ']
        end

        if cursorindex[] >= index
            cursorindex[] = max(0, cursorindex[] - 1)
        end

        displayed_string[] = join(newchars)
    end

    on(events(scene).unicode_input) do char_array
        if !focused[] || isempty(char_array)
            return
        end

        for c in char_array
            if is_allowed(c, restriction[])
                insertchar!(c, cursorindex[] + 1)
            end
        end
    end


    function submit()
        if displayed_is_valid[]
            stored_string[] = displayed_string[]
        end
    end

    function reset_to_stored()
        cursorindex[] = 0
        if isnothing(stored_string[])
            displayed_string[] = placeholder[]
        else
            displayed_string[] = stored_string[]
        end
    end

    function cursor_forward()
        if displayed_string[] != " "
            cursorindex[] = min(length(displayed_string[]), cursorindex[] + 1)
        end
    end

    function cursor_backward()
        cursorindex[] = max(0, cursorindex[] - 1)
    end


    on(events(scene).keyboardbuttons) do button_set
        if !focused[] || isempty(button_set)
            return
        end

        for key in button_set
            if key == Keyboard.backspace
                removechar!(cursorindex[])
            elseif key == Keyboard.delete
                removechar!(cursorindex[] + 1)
            elseif key == Keyboard.enter
                submit()
                if defocus_on_submit[]
                    defocus!(ltextbox)
                end
            elseif key == Keyboard.escape
                if reset_on_defocus[]
                    reset_to_stored()
                end
                defocus!(ltextbox)
            elseif key == Keyboard.right
                cursor_forward()
            elseif key == Keyboard.left
                cursor_backward()
            end
        end
    end

    ltextbox
end


function charbbs(text)
    glyphlayout = text._glyphlayout[]
    if !(glyphlayout isa AbstractPlotting.Glyphlayout)
        error("Expected a single Glyphlayout from the textbox string, got a $(typeof(glyphlayout)).")
    end
    pos = Point2f0(text.position[])
    map(glyphlayout.bboxes, glyphlayout.origins) do bb, ori
        FRect2D(Point2f0(ori) + bb.origin + pos, bb.widths)
    end
end

function validate_textbox(str, validator::Function)
    validator(str)
end

function validate_textbox(str, T::Type)
    !isnothing(tryparse(T, str))
end

function validate_textbox(str, validator::Regex)
    m = match(validator, str)
    # check that the validator matches the whole string
    !isnothing(m) && m.match == str
end

function is_allowed(char, restriction::Nothing)
    true
end

function is_allowed(char, restriction::Function)
    allowed::Bool = restriction(char)
end

"""
    reset!(tb::Textbox)
Resets the stored_string of the given `Textbox` to `nothing` without triggering listeners, and resets the `Textbox` to the `placeholder` text.
"""
function reset!(tb::Textbox)
    tb.stored_string.val = nothing
    tb.displayed_string = tb.placeholder[]
    defocus!(tb)
    nothing
end

"""
    set!(tb::Textbox, string::String)
Sets the stored_string of the given `Textbox` to `string`, triggering listeners of `tb.stored_string`.
"""
function set!(tb::Textbox, string::String)
    if !validate_textbox(string, tb.validator[])
        error("Invalid string \"$(string)\" for textbox.")
    end

    tb.displayed_string = string
    tb.stored_string = string
    nothing
end

"""
    focus!(tb::Textbox)
Focuses an `Textbox` and makes it ready to receive keyboard input.
"""
function focus!(tb::Textbox)
    if !tb.focused[]
        tb.focused = true

        cursoranim = Animations.Loop(
            Animations.Animation(
                [0, 1.0],
                [Colors.alphacolor(COLOR_ACCENT[], 0), Colors.alphacolor(COLOR_ACCENT[], 1)],
                Animations.sineio(n = 2, yoyo = true, postwait = 0.2)),
                0.0, 0.0, 1000)

        if !isnothing(tb.cursoranimtask)
            Animations.stop(tb.cursoranimtask)
            tb.cursoranimtask = nothing
        end

        tb.cursoranimtask = Animations.animate_async(cursoranim; fps = 30) do t, color
            tb.cursorcolor = color
        end
    end
    nothing
end

"""
    defocus!(tb::Textbox)
Defocuses a `Textbox` so it doesn't receive keyboard input.
"""
function defocus!(tb::Textbox)

    if tb.displayed_string[] in (" ", "")
        tb.displayed_string[] = tb.placeholder[]
    end

    if !isnothing(tb.cursoranimtask)
        Animations.stop(tb.cursoranimtask)
        tb.cursoranimtask = nothing
    end
    tb.cursorcolor = :transparent
    tb.focused = false
    nothing
end
