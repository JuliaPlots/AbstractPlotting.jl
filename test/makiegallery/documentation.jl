@block AnthonyWang [documentation] begin
    @cell "pong" [animated, scatter, updating, record, "2d"] begin
        # init speed and velocity vector
        xyvec = rand(Point2f0, (2)) .* 5 .+ 1
        velvec = rand(Point2f0, (2)) .* 10
        # define some other parameters
        t = 0
        ts = 0.03
        balldiameter = 1
        origin = Point2f0(0, 0)
        xybounds = Point2f0(10, 10)
        N = 200
        scene = scatter(
            xyvec,
            markersize = balldiameter,
            color = rand(RGBf0, 2),
            limits = FRect(0, 0, xybounds)
        )
        s = scene[end] # last plot in scene

        record(scene, @replace_with_a_path(mp4), 1:N) do i
            # calculate new ball position
            global t = t + ts
            global xyvec = xyvec .+ velvec .* ts
            global velvec = map(xyvec, xybounds, origin, velvec) do p, b, o, vel
                boolvec = ((p .+ balldiameter/2) .> b) .| ((p .- balldiameter/2) .< o)
                velvec = map(boolvec, vel) do b, v
                    b ? -v : v
                end
            end
            # plot
            s[1] = xyvec
        end
    end

    @cell "pulsing marker" [animated, scatter, markersize, updating, record, "2d"] begin
        N = 100
        scene = scatter([0], [0], marker = '❤', markersize = 0.5, color = :red, raw = true)
        s = scene[end] # last plot in scene
        record(scene, @replace_with_a_path(mp4), range(0, stop = 10pi, length = N)) do i
            s[:markersize] = (cos(i) + 1) / 4 + 0.2
        end
    end

    @cell "Travelling wave" [animated, lines, updating, interaction, record, "2d"] begin
        scene = Scene()
        mytime = Node(0.0)
        f(v, t) = sin(v + t)
        scene = lines!(
            scene,
            lift(t -> f.(range(0, stop = 2pi, length = 50), t), mytime),
            color = :blue)
        p1 = scene[end];
        N = 100
        record(scene, @replace_with_a_path(mp4), range(0, stop = 4pi, length = N)) do i
            mytime[] = i
        end
    end

    @cell "Viridis scatter" ["2d", scatter, color, viridis, colormap] begin
        N = 30
        scatter(1:N, 1:N, markersize = 2, color = to_colormap(:viridis, N))
    end

    @cell "Viridis meshscatter" ["3d", scatter, color, viridis, colormap] begin
        N = 30
        R = 2
        theta = 4pi
        h = 5
        x = [R .* (t/3) .* cos(t) for t = range(0, stop = theta, length = N)]
        y = [R .* (t/3) .* sin(t) for t = range(0, stop = theta, length = N)]
        z = range(0, stop = h, length = N)
        meshscatter(x, y, z, markersize = 0.5, color = to_colormap(:viridis, N))
    end

    @cell "Marker sizes + Marker colors" ["2d", scatter, markersize, color] begin
        scatter(
            rand(20), rand(20),
            markersize = rand(20) ./20 .+ 0.02,
            color = rand(RGBf0, 20)
        )
    end

    @cell "Marker offset" [scatter, marker_offset, "2d"] begin
        scene = Scene()
        points = Point2f0[(0,0), (1,1), (2,2)]
        offset = rand(Point2f0, 3)./5
        scatter!(scene, points)
        scatter!(scene, points, marker_offset = offset, color = :red)
    end

    @cell "colormaps" [image, translate, colormap, meta, camera, "2d"] begin
        h = 0.0
        offset = 0.1
        scene = Scene()
        cam2d!(scene)
        plot = map(collect(AbstractPlotting.all_gradient_names)) do cmap
            global h
            c = to_colormap(cmap)
            cbar = image!(
                scene,
                range(0, stop = 10, length = length(c)),
                range(0, stop = 1, length = length(c)),
                reshape(c, (length(c),1)),
                show_axis = false
            )[end]
            text!(
                scene,
                string(cmap, ":"),
                position = Point2f0(-0.1, 0.5 + h),
                align = (:right, :center),
                show_axis = false,
                textsize = 1
            )
            translate!(cbar, 0, h, 0)
            h -= (1 + offset)
        end
        scene
    end

    @cell "Available markers" [annotations, markers, meta, "2d"] begin
        marker = collect(AbstractPlotting._marker_map)
        positions = Point2f0.(0, 1:length(marker))
        scene = scatter(
            positions,
            marker = last.(marker),
            markersize = 0.8,
            marker_offset = Vec2f0(0.5, -0.4),
            show_axis = false,
        )
        annotations!(
            scene,
            string.(":", first.(marker)),
            positions,
            align = (:right, :center),
            textsize = 0.4,
            raw = true
        )
        update_cam!(scene, FRect(-2.5, 0, 2, length(marker) + 2))
        scene
    end

    #TODO: this doesn't work starting on step 9
    # @cell "Theming" [theme, scatter, surface, set_theme, stepper] begin
    #     new_theme = Theme(
    #         resolution = (500, 500),
    #         linewidth = 3,
    #         colormap = :RdYlGn,
    #         color = :red,
    #         scatter = Theme(
    #             marker = '⊝',
    #             markersize = 0.03,
    #             strokecolor = :black,
    #             strokewidth = 0.1,
    #         ),
    #     )
    #     AbstractPlotting.set_theme!(new_theme)
    #     scene = scatter(rand(100), rand(100))
    #     st = Stepper(scene, @replace_with_a_path)
    #     step!(st)
    #     new_theme[:color] = :blue
    #     step!(st)
    #     new_theme[:scatter, :marker] = '◍'
    #     step!(st)
    #     new_theme[:scatter, :markersize] = 0.05
    #     step!(st)
    #     new_theme[:scatter, :strokewidth] = 0.1
    #     step!(st)
    #     new_theme[:scatter, :strokecolor] = :green
    #     step!(st)
    #     empty!(scene)
    #     scene = scatter!(rand(100), rand(100))
    #     step!(st)
    #     scene[end][:marker] = 'π'
    #     step!(st)
    #
    #     r = range(-0.5pi, stop = pi + pi/4, length = 100)
    #     AbstractPlotting.set_theme!(new_theme)
    #     empty!(scene)
    #     scene = surface!(r, r, (x, y)-> sin(2x) + cos(2y))
    #     step!(st)
    #     scene[end][:colormap] = :PuOr
    #     step!(st)
    #     surface!(r + 2pi - pi/4, r, (x, y)-> sin(2x) + cos(2y))
    #     step!(st)
    #     AbstractPlotting.set_theme!(resolution = (500, 500))
    #     empty!(scene)
    #     surface!(r + 2pi - pi/4, r, (x, y)-> sin(2x) + cos(2y))
    #     step!(st)
    #     st
    # end

    @cell "Axis theming" [stepper, axis, lines, stepper, "2d"] begin
        using GeometryBasics
        scene = Scene()
        points = decompose(Point2f0, Circle(Point2f0(10), 10f0), 9)
        lines!(
            scene,
            points,
            linewidth = 8,
            color = :black
        )

        axis = scene[Axis] # get axis

        st = Stepper(scene, @replace_with_a_path)
        step!(st);
        axis[:frame][:linewidth] = 5
        step!(st)
        axis[:grid][:linewidth] = (1, 5)
        step!(st)
        axis[:grid][:linecolor] = ((:red, 0.3), (:blue, 0.5))
        step!(st)
        axis[:names][:axisnames] = ("x", "y   ")
        step!(st)
        axis[:ticks][:title_gap] = 1
        step!(st)
        axis[:names][:rotation] = (0.0, -3/8*pi)
        step!(st)
        axis[:names][:textcolor] = ((:red, 1.0), (:blue, 1.0))
        step!(st)
        axis[:ticks][:font] = ("Dejavu Sans", "Helvetica")
        step!(st)
        axis[:ticks][:rotation] = (0.0, -pi/2)
        step!(st)
        axis[:ticks][:textsize] = (3, 7)
        step!(st)
        axis[:ticks][:gap] = 5
        step!(st)
    end

    @cell "Stepper demo" [stepper, text, annotation, "2d"] begin
        function stepper_demo()
            scene = Scene()
            pos = (50, 50)
            steps = ["Step 1", "Step 2", "Step 3"]
            colors = AbstractPlotting.ColorBrewer.palette("Set1", length(steps))
            lines!(scene, Rect(0,0,500,500), linewidth = 0.0001)
            # initialize the stepper and give it an output destination
            st = Stepper(scene, @replace_with_a_path)

            for i = 1:length(steps)
                text!(
                    scene,
                    steps[i],
                    position = pos,
                    align = (:left, :bottom),
                    textsize = 100,
                    font = "Blackchancery",
                    color = colors[i],
                    scale_plot = false
                )
                pos = pos .+ 100
                step!(st) # saves the step and increments the step by one
            end
            st
        end
        stepper_demo()
    end

    @cell "Legend" [legend, linesegments, vbox, "2d"] begin
        scene = Scene(resolution = (500, 500))
        x = map([:dot, :dash, :dashdot], [2, 3, 4]) do ls, lw
            linesegments!(
                range(1, stop = 5, length = 100), rand(100), rand(100),
                linestyle = ls, linewidth = lw,
                color = rand(RGBAf0)
            )[end]
        end
        x = [x..., scatter!(range(1, stop=5, length=100), rand(100), rand(100))[end]]
        center!(scene)
        ls = AbstractPlotting.legend(x, ["attribute $i" for i in 1:4], camera = campixel!, raw = true)

        st = Stepper(vbox(scene, ls), @replace_with_a_path)
        l = ls[end]
        l[:strokecolor] = RGBAf0(0.8, 0.8, 0.8)
        step!(st)
        l[:gap] = 15
        step!(st)
        l[:textsize] = 12
        step!(st)
        l[:linepattern] = Point2f0[(0,-0.2), (0.5, 0.2), (0.5, 0.2), (1.0, -0.2)]
        step!(st)
        l[:scatterpattern] = decompose(Point2f0, Circle(Point2f0(0.5, 0), 0.3f0), 9)
        l[:markersize] = 2f0
        step!(st)
        st
    end
    @cell "Color Legend" [surface, colorlegend, camera, "3d"] begin
        s = surface(0..1, 0..1, rand(100, 100))
        ls = colorlegend(s[end], raw = true, camera = campixel!)
        st = Stepper(vbox(s, ls), @replace_with_a_path)
        l = ls[end]
        l[:textcolor] = :blue
        step!(st)
        l[:strokecolor] = :green
        step!(st)
        l[:strokewidth] = 4
        step!(st)
        l[:textsize] = 12
        step!(st)
        l[:textgap] = 5
        step!(st)
        st
    end
end
#
# using Makie
#
# scene = scatter(rand(100), rand(100))
# empty!(scene)
# scene = scatter!(rand(100), rand(100))
#
# r = range(-0.5pi, stop = pi + pi/4, length = 100)
# empty!(scene)
# scene = surface!(r, r, (x, y)-> sin(2x) + cos(2y))
# scene.camera_controls[]
#
# scene[end][:colormap] = :PuOr
# surface!(r + 2pi - pi/4, r, (x, y)-> sin(2x) + cos(2y))
# AbstractPlotting.set_theme!(resolution = (500, 500))
# empty!(scene)
# surface!(r + 2pi - pi/4, r, (x, y)-> sin(2x) + cos(2y))
