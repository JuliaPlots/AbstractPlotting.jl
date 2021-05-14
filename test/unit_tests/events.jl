using AbstractPlotting: PriorityObservable, MouseButtonEvent, KeyEvent

@testset "PriorityObservable" begin
    po = PriorityObservable(0)

    first = Node(0.0)
    second = Node(0.0)
    third = Node(0.0)

    on(po, priority=1) do x
        sleep(0)
        first[] = time()
        return false
    end
    on(po, priority=0) do x
        sleep(0)
        second[] = time()
        return isodd(x)
    end
    on(po, priority=-1) do x
        sleep(0)
        third[] = time()
        return false
    end

    x = setindex!(po, 1)
    @test x == true
    @test first[] < second[]
    @test third[] == 0.0

    x = setindex!(po, 2)
    @test x == false
    @test first[] < second[] < third[]

    # redirecting to avoid printing a stacktrace
    old_stderr = stderr
    redirect_stderr()
    msg = "Observer functions of PriorityObservables must return a Bool to specify whether the update is consumed (true) or should propagate (false) to other observer functions. The given function has been wrapped to always return false."
    @test_logs (:warn, msg) on(identity, po)
    redirect_stderr(old_stderr)
end


@testset "Events" begin
    @testset "Mouse and Keyboard state" begin
        events = AbstractPlotting.Events()
        @test isempty(events.mousebuttonstate)
        @test isempty(events.keyboardstate)

        events.mousebutton[] = MouseButtonEvent(Mouse.left, Mouse.press)
        events.keyboardbutton[] = KeyEvent(Keyboard.a, Keyboard.press)
        @test events.mousebuttonstate == Set([Mouse.left])
        @test events.keyboardstate == Set([Keyboard.a])

        events.mousebutton[] = MouseButtonEvent(Mouse.right, Mouse.press)
        events.keyboardbutton[] = KeyEvent(Keyboard.b, Keyboard.press)
        @test events.mousebuttonstate == Set([Mouse.left, Mouse.right])
        @test events.keyboardstate == Set([Keyboard.a, Keyboard.b])

        events.mousebutton[] = MouseButtonEvent(Mouse.left, Mouse.release)
        events.keyboardbutton[] = KeyEvent(Keyboard.a, Keyboard.release)
        @test events.mousebuttonstate == Set([Mouse.right])
        @test events.keyboardstate == Set([Keyboard.b])

        events.mousebutton[] = MouseButtonEvent(Mouse.right, Mouse.release)
        events.keyboardbutton[] = KeyEvent(Keyboard.b, Keyboard.release)
        @test isempty(events.mousebuttonstate)
        @test isempty(events.keyboardstate)
    end

    # This testset is based on the results the current camera system has. If 
    # cam3d! is updated this is likely to break. 
    @testset "cam3d!" begin
        scene = Scene(resolution=(800, 600));
        e = events(scene)
        cam3d!(scene)
        cc = cameracontrols(scene)

        # Verify initial camera state
        @test cc.lookat[]       == Vec3f0(0)
        @test cc.eyeposition[]  == Vec3f0(3)
        @test cc.upvector[]     == Vec3f0(0, 0, 1)

        # Rotation
        # 1) In scene, in drag
        e.mouseposition[] = (400, 250)
        e.mousebutton[] = MouseButtonEvent(Mouse.left, Mouse.press)
        e.mouseposition[] = (600, 250)
        @test cc.lookat[]       ≈ Vec3f0(0)
        @test cc.eyeposition[]  ≈ Vec3f0(4.14532, -0.9035063, 3.0)
        @test cc.upvector[]     ≈ Vec3f0(-0.5641066, 0.12295161, 0.81649655)

        # 2) Outside scene, in drag
        e.mouseposition[] = (1000, 450)
        @test cc.lookat[]       ≈ Vec3f0(0)
        @test cc.eyeposition[]  ≈ Vec3f0(-2.8912058, -3.8524969, -1.9491522)
        @test cc.upvector[]     ≈ Vec3f0(-0.22516009, -0.30002305, 0.92697847)

        # 3) not in drag
        e.mousebutton[] = MouseButtonEvent(Mouse.left, Mouse.release)
        e.mouseposition[] = (400, 250)
        @test cc.lookat[]       ≈ Vec3f0(0)
        @test cc.eyeposition[]  ≈ Vec3f0(-2.8912058, -3.8524969, -1.9491522)
        @test cc.upvector[]     ≈ Vec3f0(-0.22516009, -0.30002305, 0.92697847)



        # Reset state so this is indepentent from the last checks
        scene = Scene(resolution=(800, 600));
        e = events(scene)
        cam3d!(scene)
        cc = cameracontrols(scene)

        # Verify initial camera state
        @test cc.lookat[]       == Vec3f0(0)
        @test cc.eyeposition[]  == Vec3f0(3)
        @test cc.upvector[]     == Vec3f0(0, 0, 1)

        # Pan
        # 1) In scene, in drag
        e.mousebutton[] = MouseButtonEvent(Mouse.right, Mouse.press)
        e.mouseposition[] = (600, 250)
        @test cc.lookat[]       ≈ Vec3f0(2.7556758, -2.7556758, -2.1650634)
        @test cc.eyeposition[]  ≈ Vec3f0(5.755676, 0.2443242, 0.8349366)
        @test cc.upvector[]     ≈ Vec3f0(0.0, 0.0, 1.0)

        # 2) Outside scene, in drag
        e.mouseposition[] = (1000, 450)
        @test cc.lookat[]       ≈ Vec3f0(4.592793, -4.592793, -3.8971143)
        @test cc.eyeposition[]  ≈ Vec3f0(7.592793, -1.592793, -0.89711416)
        @test cc.upvector[]     ≈ Vec3f0(0.0, 0.0, 1.0)

        # 3) not in drag
        e.mousebutton[] = MouseButtonEvent(Mouse.right, Mouse.release)
        e.mouseposition[] = (400, 250)
        @test cc.lookat[]       ≈ Vec3f0(4.592793, -4.592793, -3.8971143)
        @test cc.eyeposition[]  ≈ Vec3f0(7.592793, -1.592793, -0.89711416)
        @test cc.upvector[]     ≈ Vec3f0(0.0, 0.0, 1.0)



        # Reset state
        scene = Scene(resolution=(800, 600));
        e = events(scene)
        cam3d!(scene)
        cc = cameracontrols(scene)

        # Verify initial camera state
        @test cc.lookat[]       == Vec3f0(0)
        @test cc.eyeposition[]  == Vec3f0(3)
        @test cc.upvector[]     == Vec3f0(0, 0, 1)

        # Zoom
        e.scroll[] = (0.0, 4.0)
        @test cc.lookat[]       ≈ Vec3f0(-1.7869571, -1.7869571, 0.0)
        @test cc.eyeposition[]  ≈ Vec3f0(0.18134286, 0.18134286, 1.9682997)
        @test cc.upvector[]     ≈ Vec3f0(0.0, 0.0, 1.0)

        # should not work outside the scene
        e.mouseposition[] = (1000, 450)
        e.scroll[] = (0.0, 4.0)
        @test cc.lookat[]       ≈ Vec3f0(-1.7869571, -1.7869571, 0.0)
        @test cc.eyeposition[]  ≈ Vec3f0(0.18134286, 0.18134286, 1.9682997)
        @test cc.upvector[]     ≈ Vec3f0(0.0, 0.0, 1.0)
    end

    @testset "mouse state machine" begin
        scene = Scene(resolution=(800, 600));
        e = events(scene)
        bbox = Node(Rect2D(200, 200, 400, 300))
        msm = addmouseevents!(scene, bbox, priority=typemax(Int8))
        eventlog = MouseEvent[]
        on(x -> begin push!(eventlog, x); false end, msm.obs)

        e.mouseposition[] = (0, 200)
        @test isempty(eventlog)
        
        # move inside
        e.mouseposition[] = (300, 200)
        @test length(eventlog) == 1
        @test eventlog[1].type == MouseEventTypes.enter
        @test eventlog[1].px == Point2f0(300, 200)
        @test eventlog[1].prev_px == Point2f0(0, 200)
        empty!(eventlog)

        # over
        e.mouseposition[] = (300, 300)
        @test length(eventlog) == 1
        @test eventlog[1].type == MouseEventTypes.over
        @test eventlog[1].px == Point2f0(300, 300)
        @test eventlog[1].prev_px == Point2f0(300, 200)
        empty!(eventlog)

        for button in (:left, :middle, :right)
            # click
            e.mousebutton[] = MouseButtonEvent(getfield(Mouse, button), Mouse.press)
            e.mousebutton[] = MouseButtonEvent(getfield(Mouse, button), Mouse.release)
            @test length(eventlog) == 3
            for (i, t) in enumerate((
                    getfield(MouseEventTypes, Symbol(button, :down)), 
                    getfield(MouseEventTypes, Symbol(button, :click)), 
                    getfield(MouseEventTypes, Symbol(button, :up))
                ))
                @test eventlog[i].type == t
                @test eventlog[i].px == Point2f0(300, 300)
                @test eventlog[i].prev_px == Point2f0(300, 300)
            end
            empty!(eventlog)

            # doubleclick
            e.mousebutton[] = MouseButtonEvent(getfield(Mouse, button), Mouse.press)
            e.mousebutton[] = MouseButtonEvent(getfield(Mouse, button), Mouse.release)
            @test length(eventlog) == 3
            for (i, t) in enumerate((
                    getfield(MouseEventTypes, Symbol(button, :down)), 
                    getfield(MouseEventTypes, Symbol(button, :doubleclick)), 
                    getfield(MouseEventTypes, Symbol(button, :up))
                ))
                @test eventlog[i].type == t
                @test eventlog[i].px == Point2f0(300, 300)
                @test eventlog[i].prev_px == Point2f0(300, 300)
            end
            empty!(eventlog)

            # triple click = click
            e.mousebutton[] = MouseButtonEvent(getfield(Mouse, button), Mouse.press)
            e.mousebutton[] = MouseButtonEvent(getfield(Mouse, button), Mouse.release)
            @test length(eventlog) == 3
            for (i, t) in enumerate((
                    getfield(MouseEventTypes, Symbol(button, :down)), 
                    getfield(MouseEventTypes, Symbol(button, :click)), 
                    getfield(MouseEventTypes, Symbol(button, :up))
                ))
                @test eventlog[i].type == t
                @test eventlog[i].px == Point2f0(300, 300)
                @test eventlog[i].prev_px == Point2f0(300, 300)
            end
            empty!(eventlog)

            # drag
            e.mousebutton[] = MouseButtonEvent(getfield(Mouse, button), Mouse.press)
            e.mouseposition[] = (500, 300)
            e.mouseposition[] = (700, 200)
            e.mousebutton[] = MouseButtonEvent(getfield(Mouse, button), Mouse.release)
            @test length(eventlog) == 6
            prev_px = Point2f0[(300, 300), (300, 300), (300, 300), (500, 300), (700, 200), (700, 200)]
            px      = Point2f0[(300, 300), (500, 300), (500, 300), (700, 200), (700, 200), (700, 200)]
            for (i, t) in enumerate((
                    getfield(MouseEventTypes, Symbol(button, :down)), 
                    getfield(MouseEventTypes, Symbol(button, :dragstart)), 
                    getfield(MouseEventTypes, Symbol(button, :drag)), 
                    getfield(MouseEventTypes, Symbol(button, :drag)), 
                    getfield(MouseEventTypes, Symbol(button, :dragstop)), 
                    getfield(MouseEventTypes, :out),
                    # TODO this is kinda missing an "up outside"
                ))
                @test eventlog[i].type == t
                @test eventlog[i].px == px[i]
                @test eventlog[i].prev_px == prev_px[i]
            end
            e.mouseposition[] = (300, 300)
            empty!(eventlog)
        end

        # TODO: This should probably be:
        # left down > right down > right click > right up > left up
        e.mousebutton[] = MouseButtonEvent(Mouse.left, Mouse.press)
        e.mousebutton[] = MouseButtonEvent(Mouse.right, Mouse.press)
        e.mousebutton[] = MouseButtonEvent(Mouse.right, Mouse.release)
        e.mousebutton[] = MouseButtonEvent(Mouse.left, Mouse.release)
        @test length(eventlog) == 3
        @test eventlog[1].type == MouseEventTypes.leftdown
        @test eventlog[2].type == MouseEventTypes.leftclick
        @test eventlog[3].type == MouseEventTypes.leftup
        empty!(eventlog)

        # double left up? :(
        e.mousebutton[] = MouseButtonEvent(Mouse.left, Mouse.press)
        e.mousebutton[] = MouseButtonEvent(Mouse.right, Mouse.press)
        e.mousebutton[] = MouseButtonEvent(Mouse.left, Mouse.release)
        e.mousebutton[] = MouseButtonEvent(Mouse.right, Mouse.release)
        @test length(eventlog) == 4
        @test eventlog[1].type == MouseEventTypes.leftdown
        @test eventlog[2].type == MouseEventTypes.leftdoubleclick
        @test eventlog[3].type == MouseEventTypes.leftup
        @test eventlog[4].type == MouseEventTypes.leftup
        empty!(eventlog)

        # This should probably be a leftdragstop on right down
        e.mouseposition[] = (300, 300)
        empty!(eventlog)
        e.mousebutton[] = MouseButtonEvent(Mouse.left, Mouse.press)
        e.mouseposition[] = (350, 350)
        e.mousebutton[] = MouseButtonEvent(Mouse.right, Mouse.press)
        e.mouseposition[] = (350, 400)
        e.mousebutton[] = MouseButtonEvent(Mouse.right, Mouse.release)
        e.mouseposition[] = (400, 400)
        e.mousebutton[] = MouseButtonEvent(Mouse.left, Mouse.release)
        @test length(eventlog) == 7
        @test eventlog[1].type == MouseEventTypes.leftdown
        @test eventlog[2].type == MouseEventTypes.leftdragstart
        @test eventlog[3].type == MouseEventTypes.leftdrag
        @test eventlog[4].type == MouseEventTypes.leftdrag
        @test eventlog[5].type == MouseEventTypes.over
        @test eventlog[6].type == MouseEventTypes.leftdragstop
        @test eventlog[7].type == MouseEventTypes.leftup
        @test eventlog[1].px == Point2f0(300, 300)
        @test eventlog[2].px == Point2f0(350, 350)
        @test eventlog[3].px == Point2f0(350, 350)
        @test eventlog[4].px == Point2f0(350, 400)
        @test eventlog[5].px == Point2f0(400, 400)
        @test eventlog[6].px == Point2f0(400, 400)
        @test eventlog[7].px == Point2f0(400, 400)
        empty!(eventlog)
    end
end
