abstract type PathCommand{T} end

struct BezierPath{T}
    commands::Vector{PathCommand{T}}
end

struct MoveTo{T} <: PathCommand{T}
    p::Point2{T}
end

struct LineTo{T} <: PathCommand{T}
    p::Point2{T}
end

struct CurveTo{T} <: PathCommand{T}
    c1::Point2{T}
    c2::Point2{T}
    p::Point2{T}
end

struct EllipticalArc{T} <: PathCommand{T}
    c::Point2{T}
    r1::T
    r2::T
    angle::T
    a1::T
    a2::T
end

struct ClosePath{T} <: PathCommand{T} end

function Base.:+(pc::P, p::Point2) where P <: PathCommand
    fnames = fieldnames(P)
    P(map(f -> getfield(pc, f) + p, fnames)...)
end

Base.:+(pc::EllipticalArc, p::Point2) = EllipticalArc(pc.c + p, pc.r1, pc.r2, pc.angle, pc.a1, pc.a2)
Base.:+(pc::ClosePath, p::Point2) = pc
Base.:+(bp::BezierPath, p::Point2) = BezierPath(bp.commands .+ Ref(p))

# markers with unit area

BezierCircle = let
    r = sqrt(1/pi)
    BezierPath{Float64}([
        EllipticalArc(Point(0.0, 0), r, r, 0.0, 0.0, 2pi),
        ClosePath{Float64}()
    ])
end

BezierUTriangle = let
    r = Float32(sqrt(1 / (3 * sqrt(3) / 4)))
    BezierPath([
        MoveTo(Point2f0(cosd(90), sind(90)) .* r),
        LineTo(Point2f0(cosd(210), sind(210)) .* r),
        LineTo(Point2f0(cosd(330), sind(330)) .* r),
        ClosePath{Float32}()
    ])
end

BezierDTriangle = let
    r = Float32(sqrt(1 / (3 * sqrt(3) / 4)))
    BezierPath([
        MoveTo(Point2f0(cosd(270), sind(270)) .* r),
        LineTo(Point2f0(cosd(390), sind(390)) .* r),
        LineTo(Point2f0(cosd(510), sind(510)) .* r),
        ClosePath{Float32}()
    ])
end

BezierSquare = let
    BezierPath([
        MoveTo(Point2f0(0.5, -0.5)),
        LineTo(Point2f0(0.5, 0.5)),
        LineTo(Point2f0(-0.5, 0.5)),
        LineTo(Point2f0(-0.5, -0.5)),
        ClosePath{Float32}()
    ])
end

BezierCross = let
    cutfraction = 2/3
    # 1 = (2r)^2 - 4 * (r * c) ^ 2
    # c^2 - 1 != 0, r = 1/(2 sqrt(1 - c^2))
    # 
    r = 1/(2 * sqrt(1 - cutfraction^2))
    # test: (2r)^2 - 4 * (r * cutfraction) ^ 2 ≈ 1
    ri = r * (1 - cutfraction)
    
    first_three = Point2f0[(r, ri), (ri, ri), (ri, r)]
    all = map(0:pi/2:3pi/2) do a
        m = AbstractPlotting.Mat2f0(sin(a), cos(a), cos(a), -sin(a))
        Ref(m) .* first_three
    end |> x -> reduce(vcat, x)

    BezierPath([
        MoveTo(all[1]),
        LineTo.(all[2:end])...,
        ClosePath{Float32}()
    ])
end


function BezierPath(svg::AbstractString, T = Float64)

    # args = [e.match for e in eachmatch(r"([a-zA-Z])|(\-?\d*\.?\d+)", svg)]
    args = [e.match for e in eachmatch(r"(?:0(?=\d))|(?:[a-zA-Z])|(?:\-?\d*\.?\d+)", svg)]

    i = 1

    commands = PathCommand{T}[]
    lastcomm = nothing
    function lastp()
        if isnothing(lastcomm)
            Point{T}(0, 0)
        elseif commands[end] isa ClosePath
            r = reverse(commands)
            backto = findlast(x -> !(x isa ClosePath), r)
            if isnothing(backto)
                error("No point to go back to")
            end
            r[backto].p
        else
            commands[end].p
        end
    end

    while i <= length(args)

        comm = args[i]

        # command letter is omitted, use last command
        if isnothing(match(r"[a-zA-Z]", comm))
            comm = lastcomm
            i -= 1
        end

        if comm == "M"
            x, y = parse.(Float64, args[i+1:i+2])
            push!(commands, MoveTo{T}(Point2{T}(x, y)))
            i += 3
        elseif comm == "m"
            x, y = parse.(Float64, args[i+1:i+2])
            push!(commands, MoveTo{T}(Point2{T}(x, y) + lastp()))
            i += 3
        elseif comm == "L"
            x, y = parse.(Float64, args[i+1:i+2])
            push!(commands, LineTo{T}(Point2{T}(x, y)))
            i += 3
        elseif comm == "l"
            x, y = parse.(Float64, args[i+1:i+2])
            push!(commands, LineTo{T}(Point2{T}(x, y) + lastp()))
            i += 3
        elseif comm == "H"
            x = parse(Float64, args[i+1])
            push!(commands, LineTo{T}(Point2{T}(x, lastp().y)))
            i += 2
        elseif comm == "h"
            x = parse(Float64, args[i+1])
            push!(commands, LineTo{T}(X(x) + lastp()))
            i += 2
        elseif comm == "Z"
            push!(commands, ClosePath{T}())
            i += 1
        elseif comm == "z"
            push!(commands, ClosePath{T}())
            i += 1
        elseif comm == "C"
            x1, y1, x2, y2, x3, y3 = parse.(Float64, args[i+1:i+6])
            push!(commands, CurveTo{T}(Point2{T}(x1, y1), Point2{T}(x2, y2), Point2{T}(x3, y3)))
            i += 7
        elseif comm == "c"
            x1, y1, x2, y2, x3, y3 = parse.(Float64, args[i+1:i+6])
            l = lastp()
            push!(commands, CurveTo{T}(Point2{T}(x1, y1) + l, Point2{T}(x2, y2) + l, Point2{T}(x3, y3) + l))
            i += 7
        elseif comm == "S"
            x1, y1, x2, y2 = parse.(Float64, args[i+1:i+4])
            prev = commands[end]
            reflected = prev.p + (prev.p - prev.c2)
            push!(commands, CurveTo{T}(reflected, Point2{T}(x1, y1), Point2{T}(x2, y2)))
            i += 5
        elseif comm == "s"
            x1, y1, x2, y2 = parse.(Float64, args[i+1:i+4])
            prev = commands[end]
            reflected = prev.p + (prev.p - prev.c2)
            l = lastp()
            push!(commands, CurveTo{T}(reflected, Point2{T}(x1, y1) + l, Point2{T}(x2, y2) + l))
            i += 5
        elseif comm == "A"
            @show args[i+1:i+7]
            r1, r2 = parse.(Float64, args[i+1:i+2])
            angle = parse(Float64, args[i+3])
            large_arc_flag, sweep_flag = parse.(Bool, args[i+4:i+5])
            x2, y2 = parse.(Float64, args[i+6:i+7])
            x1, y1 = lastp()

            x1p, x2p = []
            # push!(commands, ClosePath{T}())
            i += 8
            error("A not implemented correctly yet")
        else
            for c in commands
                println(c)
            end
            error("Parsing $comm not implemented.")
        end

        lastcomm = comm

    end

    BezierPath{Float64}(commands)

end

# function EllipticalArc(x1, y1, x2, y2, r1, r2, angle, largearc, sweepflag)
#     p1 = [x1, y1]
#     p2 = [x2, y2]

# end