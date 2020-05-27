using AbstractPlotting
using AbstractPlotting: automatic

"""
Take a sequence of variable definitions with docstrings above each and turn
them into Attributes, a Dict of varname => docstring pairs and a Dict of
varname => default_value pairs.

# Example

    attrs, docdict, defaultdict = @documented_attributes begin
        "The width."
        width = 10
        "The height."
        height = 20 + x
    end

    attrs == Attributes(
        width = 10,
        height = 20
    )

    docdict == Dict(
        width => "The width.",
        height => "The height."
    )

    defaultdict == Dict(
        width => "10",
        height => "20 + x"
    )
"""
macro documented_attributes(exp)
    if exp.head != :block
        error("Not a block")
    end

    expressions = filter(x -> !(x isa LineNumberNode), exp.args)

    vars_and_exps = map(expressions) do e
        if e.head == :macrocall && e.args[1] == GlobalRef(Core, Symbol("@doc"))
            varname = e.args[4].args[1]
            var_exp = e.args[4].args[2]
            str_exp = e.args[3]
        elseif e.head == Symbol("=")
            varname = e.args[1]
            var_exp = e.args[2]
            str_exp = "no description"
        else
            error("Neither docstringed variable nor normal variable: $e")
        end
        varname, var_exp, str_exp
    end

    # make a dictionary of :variable_name => docstring_expression
    exp_docdict = Expr(:call, :Dict,
        (Expr(:call, Symbol("=>"), QuoteNode(name), strexp)
            for (name, _, strexp) in vars_and_exps)...)

    # make a dictionary of :variable_name => docstring_expression
    defaults_dict = Expr(:call, :Dict,
        (Expr(:call, Symbol("=>"), QuoteNode(name), exp isa String ? "\"$exp\"" : string(exp))
            for (name, exp, _) in vars_and_exps)...)

    # make an Attributes instance with of variable_name = variable_expression
    exp_attrs = Expr(:call, :Attributes,
        (Expr(:kw, name, exp)
            for (name, exp, _) in vars_and_exps)...)

    esc(quote
        ($exp_attrs, $exp_docdict, $defaults_dict)
    end)
end

function axis_attributes()
    attrs, docdict, defaultdict = @documented_attributes begin
        "The xlabel string."
        xlabel = " "

        "The ylabel string."
        ylabel = " "

        "The axis title string."
        title = " "

        "The font family of the title."
        titlefont = "DejaVu Sans"

        "The title's font size."
        titlesize = 20

        "The gap between axis and title."
        titlegap = 10f0

        "Controls if the title is visible."
        titlevisible = true

        "The horizontal alignment of the title."
        titlealign = :center

        "The font family of the xlabel."
        xlabelfont = "DejaVu Sans"

        "The font family of the ylabel."
        ylabelfont = "DejaVu Sans"

        "The color of the xlabel."
        xlabelcolor = RGBf0(0, 0, 0)

        "The color of the ylabel."
        ylabelcolor = RGBf0(0, 0, 0)

        "The font size of the xlabel."
        xlabelsize = 20

        "The font size of the ylabel."
        ylabelsize = 20

        "Controls if the xlabel is visible."
        xlabelvisible = true

        "Controls if the ylabel is visible."
        ylabelvisible = true

        "The padding between the xlabel and the ticks or axis."
        xlabelpadding = 15f0

        "The padding between the ylabel and the ticks or axis."
        ylabelpadding = 15f0 # because of boundingbox inaccuracies of ticklabels

        "The font family of the xticklabels."
        xticklabelfont = "DejaVu Sans"

        "The font family of the yticklabels."
        yticklabelfont = "DejaVu Sans"

        "The color of xticklabels."
        xticklabelcolor = RGBf0(0, 0, 0)

        "The color of yticklabels."
        yticklabelcolor = RGBf0(0, 0, 0)

        "The font size of the xticklabels."
        xticklabelsize = 20

        "The font size of the yticklabels."
        yticklabelsize = 20

        "Controls if the xticklabels are visible."
        xticklabelsvisible = true

        "Controls if the yticklabels are visible."
        yticklabelsvisible = true

        "The space reserved for the xticklabels."
        xticklabelspace = automatic

        "The space reserved for the yticklabels."
        yticklabelspace = automatic

        "The space between xticks and xticklabels."
        xticklabelpad = 5f0

        "The space between yticks and yticklabels."
        yticklabelpad = 5f0

        "The counterclockwise rotation of the xticklabels in radians."
        xticklabelrotation = 0f0

        "The counterclockwise rotation of the yticklabels in radians."
        yticklabelrotation = 0f0

        "The horizontal and vertical alignment of the xticklabels."
        xticklabelalign = (:center, :top)

        "The horizontal and vertical alignment of the yticklabels."
        yticklabelalign = (:right, :center)

        "The size of the xtick marks."
        xticksize = 10f0

        "The size of the ytick marks."
        yticksize = 10f0

        "Controls if the xtick marks are visible."
        xticksvisible = true

        "Controls if the ytick marks are visible."
        yticksvisible = true

        "The alignment of the xtick marks relative to the axis spine (0 = out, 1 = in)."
        xtickalign = 0f0

        "The alignment of the ytick marks relative to the axis spine (0 = out, 1 = in)."
        ytickalign = 0f0

        "The width of the xtick marks."
        xtickwidth = 1f0

        "The width of the ytick marks."
        ytickwidth = 1f0

        "The color of the xtick marks."
        xtickcolor = RGBf0(0, 0, 0)

        "The color of the ytick marks."
        ytickcolor = RGBf0(0, 0, 0)

        "Locks interactive panning in the x direction."
        xpanlock = false

        "Locks interactive panning in the y direction."
        ypanlock = false

        "Locks interactive zooming in the x direction."
        xzoomlock = false

        "Locks interactive zooming in the y direction."
        yzoomlock = false

        "The width of the axis spines."
        spinewidth = 1f0

        "Controls if the x grid lines are visible."
        xgridvisible = true

        "Controls if the y grid lines are visible."
        ygridvisible = true

        "The width of the x grid lines."
        xgridwidth = 1f0

        "The width of the y grid lines."
        ygridwidth = 1f0

        "The color of the x grid lines."
        xgridcolor = RGBAf0(0, 0, 0, 0.1)

        "The color of the y grid lines."
        ygridcolor = RGBAf0(0, 0, 0, 0.1)

        "The linestyle of the x grid lines."
        xgridstyle = nothing

        "The linestyle of the y grid lines."
        ygridstyle = nothing

        "Controls if the bottom axis spine is visible."
        bottomspinevisible = true

        "Controls if the left axis spine is visible."
        leftspinevisible = true

        "Controls if the top axis spine is visible."
        topspinevisible = true

        "Controls if the right axis spine is visible."
        rightspinevisible = true

        "The color of the bottom axis spine."
        bottomspinecolor = :black

        "The color of the left axis spine."
        leftspinecolor = :black

        "The color of the top axis spine."
        topspinecolor = :black

        "The color of the right axis spine."
        rightspinecolor = :black

        "The forced aspect ratio of the axis. `nothing` leaves the axis unconstrained, `DataAspect()` forces the same ratio as the ratio in data limits between x and y axis, `AxisAspect(ratio)` sets a manual ratio."
        aspect = nothing

        "The vertical alignment of the axis within its suggested bounding box."
        valign = :center

        "The horizontal alignment of the axis within its suggested bounding box."
        halign = :center

        "The width of the axis."
        width = nothing

        "The height of the axis."
        height = nothing

        "Controls if the parent layout can adjust to this element's width"
        tellwidth = true

        "Controls if the parent layout can adjust to this element's height"
        tellheight = true

        "The relative margins added to the autolimits in x direction."
        xautolimitmargin = (0.05f0, 0.05f0)

        "The relative margins added to the autolimits in y direction."
        yautolimitmargin = (0.05f0, 0.05f0)

        "The xticks."
        xticks = automatic

        "Format for xticks."
        xtickformat = automatic

        "The yticks."
        yticks = automatic

        "Format for yticks."
        ytickformat = automatic

        "The button for panning."
        panbutton = Mouse.right

        "The key for limiting panning to the x direction."
        xpankey = Keyboard.x

        "The key for limiting panning to the y direction."
        ypankey = Keyboard.y

        "The key for limiting zooming to the x direction."
        xzoomkey = Keyboard.x

        "The key for limiting zooming to the y direction."
        yzoomkey = Keyboard.y

        "The position of the x axis (`:bottom` or `:top`)."
        xaxisposition = :bottom

        "The position of the y axis (`:left` or `:right`)."
        yaxisposition = :left

        "Controls if the x spine is limited to the furthest tick marks or not."
        xtrimspine = false

        "Controls if the y spine is limited to the furthest tick marks or not."
        ytrimspine = false

        "The background color of the axis."
        backgroundcolor = :white

        "Controls if the ylabel's rotation is flipped."
        flip_ylabel = false

        "Constrains the data aspect ratio (`nothing` leaves the ratio unconstrained)."
        autolimitaspect = nothing

        targetlimits = FRect2D(0, 0, 1000, 1000)
        "The align mode of the axis in its parent GridLayout."
        alignmode = Inside()
        "Controls if the y axis goes upwards (false) or downwards (true)"
        yreversed = false

        "Controls if the x axis goes rightwards (false) or leftwards (true)"
        xreversed = false
    end

    return (attributes = attrs, documentation = docdict, defaults = defaultdict)
end

using AbstractPlotting: @extract


function axis2d(parent, bbox; kw...)
    attrs = merge(axis_attributes().attributes, Attributes(kw))
    
    parent = Scene(camera=cam2d!, scale_plot=false)

    decorations = Dict{Symbol, Any}()
    @extract attrs (
        title, titlefont, titlesize, titlegap, titlevisible, titlealign,
        xlabel, ylabel, xlabelcolor, ylabelcolor, xlabelsize, ylabelsize,
        xlabelvisible, ylabelvisible, xlabelpadding, ylabelpadding,
        xticklabelsize, xticklabelcolor, yticklabelsize, xticklabelsvisible, yticklabelsvisible,
        xticksize, yticksize, xticksvisible, yticksvisible,
        xticklabelspace, yticklabelspace, yticklabelcolor, xticklabelpad, yticklabelpad,
        xticklabelrotation, yticklabelrotation, xticklabelalign, yticklabelalign,
        xtickalign, ytickalign, xtickwidth, ytickwidth, xtickcolor, ytickcolor,
        xpanlock, ypanlock, xzoomlock, yzoomlock,
        spinewidth, xtrimspine, ytrimspine,
        xgridvisible, ygridvisible, xgridwidth, ygridwidth, xgridcolor, ygridcolor,
        xgridstyle, ygridstyle,
        aspect, halign, valign, xticks, yticks, xtickformat, ytickformat, panbutton,
        xpankey, ypankey, xzoomkey, yzoomkey,
        xaxisposition, yaxisposition,
        bottomspinevisible, leftspinevisible, topspinevisible, rightspinevisible,
        bottomspinecolor, leftspinecolor, topspinecolor, rightspinecolor,
        backgroundcolor,
        xlabelfont, ylabelfont, xticklabelfont, yticklabelfont,
        flip_ylabel, xreversed, yreversed,
    )

    limits = Node(FRect(0, 0, 1000, 1000))

    scenearea = limits

    scene = Scene(parent, scenearea, raw = true)

    background = poly!(parent, scenearea, color = backgroundcolor, strokewidth = 0, raw = true)[end]
    translate!(background, 0, 0, -100)
    decorations[:background] = background

    block_limit_linking = Node(false)

    xaxislinks = []
    yaxislinks = []
    protrusions = Node(GridLayoutBase.RectSides{Float32}(0,0,0,0))
    campixel!(scene)

    xgridnode = Node(Point2f0[])
    xgridlines = linesegments!(
        parent, xgridnode, linewidth = xgridwidth, show_axis = false, visible = xgridvisible,
        color = xgridcolor, linestyle = xgridstyle,
    )[end]
    # put gridlines behind the zero plane so they don't overlay plots
    translate!(xgridlines, 0, 0, -10)
    decorations[:xgridlines] = xgridlines

    ygridnode = Node(Point2f0[])
    ygridlines = linesegments!(
        parent, ygridnode, linewidth = ygridwidth, show_axis = false, visible = ygridvisible,
        color = ygridcolor, linestyle = ygridstyle,
    )[end]
    # put gridlines behind the zero plane so they don't overlay plots
    translate!(ygridlines, 0, 0, -10)
    decorations[:ygridlines] = ygridlines

    onany(limits, xreversed, yreversed) do lims, xrev, yrev

        nearclip = -10_000f0
        farclip = 10_000f0

        left, bottom = minimum(lims)
        right, top = maximum(lims)

        leftright = xrev ? (right, left) : (left, right)
        bottomtop = yrev ? (top, bottom) : (bottom, top)

        projection = AbstractPlotting.orthographicprojection(
            leftright..., bottomtop..., nearclip, farclip)
        camera(scene).projection[] = projection
        camera(scene).projectionview[] = projection
    end

    latest_tlimits = Ref(limits[])
    isupdating = Ref(false)
    missedupdate = Ref(false)

    xaxis_endpoints = lift(xaxisposition, scene.px_area) do xaxisposition, area
        if xaxisposition == :bottom
            bottomline(FRect2D(area))
        elseif xaxisposition == :top
            topline(FRect2D(area))
        else
            error("Invalid xaxisposition $xaxisposition")
        end
    end

    yaxis_endpoints = lift(yaxisposition, scene.px_area) do yaxisposition, area
        if yaxisposition == :left
            leftline(FRect2D(area))
        elseif yaxisposition == :right
            rightline(FRect2D(area))
        else
            error("Invalid xaxisposition $xaxisposition")
        end
    end

    xaxis_flipped = lift(x->x == :top, xaxisposition)
    yaxis_flipped = lift(x->x == :right, yaxisposition)

    xspinevisible = lift(xaxis_flipped, bottomspinevisible, topspinevisible) do xflip, bv, tv
        xflip ? tv : bv
    end
    xoppositespinevisible = lift(xaxis_flipped, bottomspinevisible, topspinevisible) do xflip, bv, tv
        xflip ? bv : tv
    end
    yspinevisible = lift(yaxis_flipped, leftspinevisible, rightspinevisible) do yflip, lv, rv
        yflip ? rv : lv
    end
    yoppositespinevisible = lift(yaxis_flipped, leftspinevisible, rightspinevisible) do yflip, lv, rv
        yflip ? lv : rv
    end
    xspinecolor = lift(xaxis_flipped, bottomspinecolor, topspinecolor) do xflip, bc, tc
        xflip ? tc : bc
    end
    xoppositespinecolor = lift(xaxis_flipped, bottomspinecolor, topspinecolor) do xflip, bc, tc
        xflip ? bc : tc
    end
    yspinecolor = lift(yaxis_flipped, leftspinecolor, rightspinecolor) do yflip, lc, rc
        yflip ? rc : lc
    end
    yoppositespinecolor = lift(yaxis_flipped, leftspinecolor, rightspinecolor) do yflip, lc, rc
        yflip ? lc : rc
    end

    xaxis = LineAxis(parent, endpoints = xaxis_endpoints, limits = lift(xlimits, limits),
        flipped = xaxis_flipped, ticklabelrotation = xticklabelrotation,
        ticklabelalign = xticklabelalign, labelsize = xlabelsize,
        labelpadding = xlabelpadding, ticklabelpad = xticklabelpad, labelvisible = xlabelvisible,
        label = xlabel, labelfont = xlabelfont, ticklabelfont = xticklabelfont, ticklabelcolor = xticklabelcolor, labelcolor = xlabelcolor, tickalign = xtickalign,
        ticklabelspace = xticklabelspace, ticks = xticks, tickformat = xtickformat, ticklabelsvisible = xticklabelsvisible,
        ticksvisible = xticksvisible, spinevisible = xspinevisible, spinecolor = xspinecolor, spinewidth = spinewidth,
        ticklabelsize = xticklabelsize, trimspine = xtrimspine, ticksize = xticksize,
        reversed = xreversed, tickwidth = xtickwidth)
    decorations[:xaxis] = xaxis

    yaxis = LineAxis(parent, endpoints = yaxis_endpoints, limits = lift(ylimits, limits),
        flipped = yaxis_flipped, ticklabelrotation = yticklabelrotation,
        ticklabelalign = yticklabelalign, labelsize = ylabelsize,
        labelpadding = ylabelpadding, ticklabelpad = yticklabelpad, labelvisible = ylabelvisible,
        label = ylabel, labelfont = ylabelfont, ticklabelfont = yticklabelfont, ticklabelcolor = yticklabelcolor, labelcolor = ylabelcolor, tickalign = ytickalign,
        ticklabelspace = yticklabelspace, ticks = yticks, tickformat = ytickformat, ticklabelsvisible = yticklabelsvisible,
        ticksvisible = yticksvisible, spinevisible = yspinevisible, spinecolor = yspinecolor, spinewidth = spinewidth,
        trimspine = ytrimspine, ticklabelsize = yticklabelsize, ticksize = yticksize, flip_vertical_label = flip_ylabel, reversed = yreversed, tickwidth = ytickwidth)
    decorations[:yaxis] = yaxis

    xoppositelinepoints = lift(scene.px_area, spinewidth, xaxisposition) do r, sw, xaxpos
        if xaxpos == :top
            y = bottom(r) - 0.5f0 * sw
            p1 = Point2(left(r) - sw, y)
            p2 = Point2(right(r) + sw, y)
            [p1, p2]
        else
            y = top(r) + 0.5f0 * sw
            p1 = Point2(left(r) - sw, y)
            p2 = Point2(right(r) + sw, y)
            [p1, p2]
        end
    end

    yoppositelinepoints = lift(scene.px_area, spinewidth, yaxisposition) do r, sw, yaxpos
        if yaxpos == :right
            x = left(r) - 0.5f0 * sw
            p1 = Point2(x, bottom(r) - sw)
            p2 = Point2(x, top(r) + sw)
            [p1, p2]
        else
            x = right(r) + 0.5f0 * sw
            p1 = Point2(x, bottom(r) - sw)
            p2 = Point2(x, top(r) + sw)
            [p1, p2]
        end
    end

    xoppositeline = lines!(parent, xoppositelinepoints, linewidth = spinewidth,
        visible = xoppositespinevisible, color = xoppositespinecolor)[end]
    decorations[:xoppositeline] = xoppositeline
    yoppositeline = lines!(parent, yoppositelinepoints, linewidth = spinewidth,
        visible = yoppositespinevisible, color = yoppositespinecolor)[end]
    decorations[:yoppositeline] = yoppositeline

    on(xaxis.tickpositions) do tickpos
        pxheight = height(scene.px_area[])
        offset = xaxisposition[] == :bottom ? pxheight : -pxheight
        opposite_tickpos = tickpos .+ Ref(Point2f0(0, offset))
        xgridnode[] = interleave_vectors(tickpos, opposite_tickpos)
    end

    on(yaxis.tickpositions) do tickpos
        pxwidth = width(scene.px_area[])
        offset = yaxisposition[] == :left ? pxwidth : -pxwidth
        opposite_tickpos = tickpos .+ Ref(Point2f0(offset, 0))
        ygridnode[] = interleave_vectors(tickpos, opposite_tickpos)
    end

    titlepos = lift(scene.px_area, titlegap, titlealign, xaxisposition, xaxis.protrusion) do a,
            titlegap, align, xaxisposition, xaxisprotrusion

        x = if align == :center
            a.origin[1] + a.widths[1] / 2
        elseif align == :left
            a.origin[1]
        elseif align == :right
            a.origin[1] + a.widths[1]
        else
            error("Title align $align not supported.")
        end

        yoffset = top(a) + titlegap + (xaxisposition == :top ? xaxisprotrusion : 0f0)

        Point2(x, yoffset)
    end

    titlealignnode = lift(titlealign) do align
        (align, :bottom)
    end

    titlet = text!(
        parent, title,
        position = titlepos,
        visible = titlevisible,
        textsize = titlesize,
        align = titlealignnode,
        font = titlefont,
        show_axis=false)[end]
    decorations[:title] = titlet

    function compute_protrusions(title, titlesize, titlegap, titlevisible, spinewidth,
                topspinevisible, bottomspinevisible, leftspinevisible, rightspinevisible,
                xaxisprotrusion, yaxisprotrusion, xaxisposition, yaxisposition)

        left, right, bottom, top = 0f0, 0f0, 0f0, 0f0

        if xaxisposition == :bottom
            topspinevisible && (top = spinewidth)
            bottom = xaxisprotrusion
        else
            bottomspinevisible && (bottom = spinewidth)
            top = xaxisprotrusion
        end

        titlespace = if !titlevisible || iswhitespace(title)
            0f0
        else
            boundingbox(titlet).widths[2] + titlegap
        end
        top += titlespace

        if yaxisposition == :left
            rightspinevisible && (right = spinewidth)
            left = yaxisprotrusion
        else
            leftspinevisible && (left = spinewidth)
            right = yaxisprotrusion
        end

        GridLayoutBase.RectSides{Float32}(left, right, bottom, top)
    end

    onany(title, titlesize, titlegap, titlevisible, spinewidth,
            topspinevisible, bottomspinevisible, leftspinevisible, rightspinevisible,
            xaxis.protrusion, yaxis.protrusion, xaxisposition, yaxisposition) do args...
        protrusions[] = compute_protrusions(args...)
    end

    # trigger first protrusions with one of the observables
    title[] = title[]

    # trigger a layout update whenever the protrusions change
    # on(protrusions) do prot
    #     needs_update[] = true
    # end

    # trigger bboxnode so the axis layouts itself even if not connected to a
    # layout
    return parent
end
