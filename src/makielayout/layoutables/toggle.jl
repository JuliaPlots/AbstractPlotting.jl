using AbstractPlotting: MouseStateEvent, MouseStateMachine, MouseEventTypes

function Toggle(fig_or_scene; bbox = nothing, kwargs...)

    topscene = get_topscene(fig_or_scene)

    default_attrs = default_attributes(Toggle, topscene).attributes
    theme_attrs = subtheme(topscene, :Toggle)
    attrs = merge!(merge!(Attributes(kwargs), theme_attrs), default_attrs)

    @extract attrs (halign, valign, cornersegments, framecolor_inactive,
        framecolor_active, buttoncolor, active, toggleduration, rimfraction)

    decorations = Dict{Symbol, Any}()

    layoutobservables = LayoutObservables{Toggle}(attrs.width, attrs.height, attrs.tellwidth, attrs.tellheight,
        halign, valign, attrs.alignmode; suggestedbbox = bbox)

    markersize = lift(layoutobservables.computedbbox) do bbox
        min(width(bbox), height(bbox))
    end

    button_endpoint_inactive = lift(markersize) do ms
        bbox = layoutobservables.computedbbox[]
        Point2f0(left(bbox) + ms / 2, bottom(bbox) + ms / 2)
    end

    button_endpoint_active = lift(markersize) do ms
        bbox = layoutobservables.computedbbox[]
        Point2f0(right(bbox) - ms / 2, bottom(bbox) + ms / 2)
    end

    buttonvertices = lift(markersize, cornersegments) do ms, cs
        roundedrectvertices(layoutobservables.computedbbox[], ms * 0.499, cs)
    end

    # trigger bbox
    layoutobservables.suggestedbbox[] = layoutobservables.suggestedbbox[]

    framecolor = Node{Any}(active[] ? framecolor_active[] : framecolor_inactive[])
    frame = poly!(topscene, buttonvertices, color = framecolor, raw = true)
    decorations[:frame] = frame

    animating = Node(false)
    buttonpos = Node(active[] ? [button_endpoint_active[]] : [button_endpoint_inactive[]])

    # make the button stay in the correct place (and start there)
    on(layoutobservables.computedbbox) do bbox
        if !animating[]
            buttonpos[] = active[] ? [button_endpoint_active[]] : [button_endpoint_inactive[]]
        end
    end

    buttonfactor = Node(1.0)
    buttonsize = lift(markersize, rimfraction, buttonfactor) do ms, rf, bf
        ms * (1 - rf) * bf
    end

    button = scatter!(topscene, buttonpos, markersize = buttonsize, color = buttoncolor, strokewidth = 0, raw = true)
    decorations[:button] = button

    # Method 1 - no state machine
    #=
    # since we have an outer reference to the scene we can attach this to a 
    # plot and forget about it
    register!(button, :animation, DEFAULT_UI_PRIORITY) do e::MouseButtonEvent, p
        hovered = mouseover(topscene, button, frame)
        if hovered && (e.button == Mouse.left) && (e.action == Mouse.press)
            animating[] && return false
            animating[] = true

            tstart = time()
            anim_posfrac = Animations.Animation(
                [0, toggleduration[]],
                active[] ? [1.0, 0.0] : [0.0, 1.0],
                Animations.sineio())
            coloranim = Animations.Animation(
                [0, toggleduration[]],
                active[] ? [framecolor_active[], framecolor_inactive[]] : [framecolor_inactive[], framecolor_active[]],
                Animations.sineio())

            active[] = !active[]
            @async while true
                t = time() - tstart
                # request endpoint values in every frame if the layout changes during
                # the animation
                buttonpos[] = [Animations.linear_interpolate(anim_posfrac(t),
                    button_endpoint_inactive[], button_endpoint_active[])]
                framecolor[] = coloranim(t)
                if t >= toggleduration[]
                    animating[] = false
                    break
                end
                sleep(1/FPS[])
            end
        end

        return false
    end

    register!(button, :hover, DEFAULT_UI_PRIORITY) do e::MouseMovedEvent, p
        hovered = mouseover(topscene, button, frame)
        if hovered && (buttonfactor[] != 1.15)
            buttonfactor[] = 1.15
        elseif !hovered && (buttonfactor[] != 1.0)
            buttonfactor[] = 1.0
        end
        return false
    end
    =#

    # Method 2 - with new statemachine
    MouseStateMachine(topscene, button, frame)
    register!(button, :toggle_controller) do e::MouseStateEvent, p
        if e.type == MouseEventTypes.leftdown

            if animating[]
                return true
            end
            animating[] = true
     
            tstart = time()
    
            anim_posfrac = Animations.Animation(
                [0, toggleduration[]],
                active[] ? [1.0, 0.0] : [0.0, 1.0],
                Animations.sineio())
            coloranim = Animations.Animation(
                [0, toggleduration[]],
                if active[]
                    [framecolor_active[], framecolor_inactive[]]
                else
                    [framecolor_inactive[], framecolor_active[]]
                end,
                Animations.sineio())
    
            active[] = !active[]
            @async while true
                t = time() - tstart
                # request endpoint values in every frame if the layout changes during
                # the animation
                buttonpos[] = [Animations.linear_interpolate(anim_posfrac(t),
                    button_endpoint_inactive[], button_endpoint_active[])]
                framecolor[] = coloranim(t)
                if t >= toggleduration[]
                    animating[] = false
                    break
                end
                sleep(1/FPS[])
            end

            return true

        elseif e.type == MouseEventTypes.enter
            buttonfactor[] = 1.15
        elseif e.type == MouseEventTypes.out
            buttonfactor[] = 1.0
        end

        return false
    end

    # mouseevents = addmouseevents!(topscene, button, frame)

    # onmouseleftdown(mouseevents) do event
    #     if animating[]
    #         return
    #     end
    #     animating[] = true

    #     tstart = time()

    #     anim_posfrac = Animations.Animation(
    #         [0, toggleduration[]],
    #         active[] ? [1.0, 0.0] : [0.0, 1.0],
    #         Animations.sineio())
    #     coloranim = Animations.Animation(
    #         [0, toggleduration[]],
    #         active[] ? [framecolor_active[], framecolor_inactive[]] : [framecolor_inactive[], framecolor_active[]],
    #         Animations.sineio())

    #     active[] = !active[]
    #     @async while true
    #         t = time() - tstart
    #         # request endpoint values in every frame if the layout changes during
    #         # the animation
    #         buttonpos[] = [Animations.linear_interpolate(anim_posfrac(t),
    #             button_endpoint_inactive[], button_endpoint_active[])]
    #         framecolor[] = coloranim(t)
    #         if t >= toggleduration[]
    #             animating[] = false
    #             break
    #         end
    #         sleep(1/FPS[])
    #     end
    # end

    # onmouseover(mouseevents) do event
    #     buttonfactor[] = 1.15
    # end

    # onmouseout(mouseevents) do event
    #     buttonfactor[] = 1.0
    # end

    Toggle(fig_or_scene, layoutobservables, attrs, decorations)
end
