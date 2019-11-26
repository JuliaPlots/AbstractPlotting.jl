"""
Backend independent enums which
represent keyboard buttons.
"""
module Keyboard

    using ..AbstractPlotting: INSTANCES # import the docstring extensions
    """
        Keyboard.Button

    Enumerates all keyboard buttons.
    See the implementation for details.
    """
    @enum(Button,
            unknown            = -1,
            # printable keys,
            space              = 32,
            apostrophe         = 39,  # ',
            comma              = 44,  # ,,
            minus              = 45,  # -,
            period             = 46,  # .,
            slash              = 47,  # /,
            _0                  = 48,
            _1                  = 49,
            _2                  = 50,
            _3                  = 51,
            _4                  = 52,
            _5                  = 53,
            _6                  = 54,
            _7                  = 55,
            _8                  = 56,
            _9                  = 57,
            semicolon          = 59,  # ;,
            equal              = 61,  # =,
            a                  = 65,
            b                  = 66,
            c                  = 67,
            d                  = 68,
            e                  = 69,
            f                  = 70,
            g                  = 71,
            h                  = 72,
            i                  = 73,
            j                  = 74,
            k                  = 75,
            l                  = 76,
            m                  = 77,
            n                  = 78,
            o                  = 79,
            p                  = 80,
            q                  = 81,
            r                  = 82,
            s                  = 83,
            t                  = 84,
            u                  = 85,
            v                  = 86,
            w                  = 87,
            x                  = 88,
            y                  = 89,
            z                  = 90,
            left_bracket       = 91,  # [,
            backslash          = 92,  # ,
            right_bracket      = 93,  # ],
            grave_accent       = 96,  # `,
            world_1            = 161, # non-us #1,
            world_2            = 162, # non-us #2,
            # function keys,
            escape             = 256,
            enter              = 257,
            tab                = 258,
            backspace          = 259,
            insert             = 260,
            delete             = 261,
            right              = 262,
            left               = 263,
            down               = 264,
            up                 = 265,
            page_up            = 266,
            page_down          = 267,
            home               = 268,
            _end               = 269,
            caps_lock          = 280,
            scroll_lock        = 281,
            num_lock           = 282,
            print_screen       = 283,
            pause              = 284,
            f1                 = 290,
            f2                 = 291,
            f3                 = 292,
            f4                 = 293,
            f5                 = 294,
            f6                 = 295,
            f7                 = 296,
            f8                 = 297,
            f9                 = 298,
            f10                = 299,
            f11                = 300,
            f12                = 301,
            f13                = 302,
            f14                = 303,
            f15                = 304,
            f16                = 305,
            f17                = 306,
            f18                = 307,
            f19                = 308,
            f20                = 309,
            f21                = 310,
            f22                = 311,
            f23                = 312,
            f24                = 313,
            f25                = 314,
            kp_0               = 320,
            kp_1               = 321,
            kp_2               = 322,
            kp_3               = 323,
            kp_4               = 324,
            kp_5               = 325,
            kp_6               = 326,
            kp_7               = 327,
            kp_8               = 328,
            kp_9               = 329,
            kp_decimal         = 330,
            kp_divide          = 331,
            kp_multiply        = 332,
            kp_subtract        = 333,
            kp_add             = 334,
            kp_enter           = 335,
            kp_equal           = 336,
            left_shift         = 340,
            left_control       = 341,
            left_alt           = 342,
            left_super         = 343,
            right_shift        = 344,
            right_control      = 345,
            right_alt          = 346,
            right_super        = 347,
            menu               = 348,
    )

    """
    """

end

"""
Backend independent enums and fields which
represent mouse actions.
"""
module Mouse
    using ..AbstractPlotting: INSTANCES # import the docstring extensions

    """
        Mouse.Button

    Enumerates all mouse buttons, in accordance with the GLFW spec.

    $(INSTANCES)
    """
    @enum Button begin
        left = 0
        middle = 2
        right = 1 # Conform to GLFW
    end

    """
        Mouse.DragEnum

    Enumerates the drag states of the mouse.

    $(INSTANCES)
    """
    @enum DragEnum begin
        down
        up
        pressed
        notpressed
    end

end

abstract type AbstractMouseState end
struct MouseOut <: AbstractMouseState end
struct MouseEnter <: AbstractMouseState end
struct MouseOver <: AbstractMouseState end
struct MouseLeave <: AbstractMouseState end
struct MouseDown <: AbstractMouseState end
struct MouseUp <: AbstractMouseState end
struct MouseDragStart <: AbstractMouseState end
struct MouseDrag <: AbstractMouseState end
struct MouseDragStop <: AbstractMouseState end
struct MouseClick <: AbstractMouseState end
struct MouseDoubleclick <: AbstractMouseState end

struct MouseState{T<:AbstractMouseState}
    state::T
    t::Float64
    pos::Point2f0
    tprev::Float64
    prev::Point2f0
end

function Base.show(io::IO, ms::MouseState{T}) where T
    print(io, "$T(t: $(ms.t), pos: $(ms.pos[1]), $(ms.pos[2]), tprev: $(ms.tprev), prev: $(ms.prev[1]), $(ms.prev[2]))")
end

function addmousestate!(scene, element)

    mouse_downed_inside = Ref(false)
    drag_ongoing = Ref(false)
    mouse_was_inside = Ref(false)
    prev = Ref(Point2f0(0, 0))
    tprev = Ref(0.0)
    t_last_click = Ref(0.0)
    dblclick_max_interval = 0.4
    last_click_was_double = Ref(false)

    mousestate = Node{MouseState}(MouseState(MouseOut(), 0.0, Point2f0(0, 0), 0.0, Point2f0(0, 0)))

    onany(events(scene).mouseposition, events(scene).mousedrag) do mp, dragstate
        pos = mouseposition(rootparent(scene))
        t = time()

        if drag_ongoing[]
            if dragstate == Mouse.pressed
                mousestate[] = MouseState(MouseDrag(), t, pos, tprev[], prev[])
            else
                # one last drag event
                mousestate[] = MouseState(MouseDrag(), t, pos, tprev[], prev[])
                mousestate[] = MouseState(MouseDragStop(), t, pos, tprev[], prev[])
                mousestate[] = MouseState(MouseUp(), t, pos, tprev[], prev[])
                mouse_downed_inside[] = false
                # check after drag is over if we're also outside of the element now
                if !mouseover(scene, element)
                    mousestate[] = MouseState(MouseLeave(), t, pos, tprev[], prev[])
                    mousestate[] = MouseState(MouseOut(), t, pos, tprev[], prev[])
                    mouse_was_inside[] = false
                else
                    mousestate[] = MouseState(MouseOver(), t, pos, tprev[], prev[])
                end
                drag_ongoing[] = false
            end
        # no dragging already ongoing
        else
            if mouseover(scene, element)
                # guard against mouse coming in from outside when pressed
                if !mouse_was_inside[] && dragstate != Mouse.pressed
                    mousestate[] = MouseState(MouseEnter(), t, pos, tprev[], prev[])
                    mouse_was_inside[] = true
                end

                if dragstate == Mouse.down
                    # guard against pressed mouse dragged in from somewhere else
                    mouse_downed_inside[] = true
                    mousestate[] = MouseState(MouseDown(), t, pos, tprev[], prev[])
                elseif dragstate == Mouse.up

                    mousestate[] = MouseState(MouseUp(), t, pos, tprev[], prev[])
                    t = time()
                    dt_last_click = t - t_last_click[]
                    t_last_click[] = t
                    # guard against mouse coming in from outside, then mouse upping
                    if mouse_downed_inside[]
                        if dt_last_click < dblclick_max_interval && !last_click_was_double[]
                            mousestate[] = MouseState(MouseDoubleclick(), t, pos, tprev[], prev[])
                            last_click_was_double[] = true
                        else
                            mousestate[] = MouseState(MouseClick(), t, pos, tprev[], prev[])
                            last_click_was_double[] = false
                        end
                    end
                    mouse_downed_inside[] = false
                    # trigger mouseposition event to determine what happens after the click
                    # the item might have moved?
                    events(scene).mouseposition[] = events(scene).mouseposition[]
                elseif dragstate == Mouse.pressed && mouse_downed_inside[]
                    mousestate[] = MouseState(MouseDragStart(), t, pos, tprev[], prev[])
                    drag_ongoing[] = true
                elseif dragstate == Mouse.notpressed
                    mousestate[] = MouseState(MouseOver(), t, pos, tprev[], prev[])
                end
            else
                if mouse_was_inside[]
                    mousestate[] = MouseState(MouseLeave(), t, pos, tprev[], prev[])
                    mousestate[] = MouseState(MouseOut(), t, pos, tprev[], prev[])
                    mouse_was_inside[] = false
                end
            end
        end

        prev[] = pos
        tprev[] = t
    end

    mousestate
end

# Void for no button needs to be pressed,
const ButtonTypes = Union{Nothing, Mouse.Button, Keyboard.Button}
