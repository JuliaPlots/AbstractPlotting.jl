using AbstractPlotting: 
    NoConversion,
    convert_arguments, 
    conversion_trait

@testset "Conversions" begin

    # NoConversion
    struct NoConversionTestType end
    conversion_trait(::NoConversionTestType) = NoConversion()

    let nctt = NoConversionTestType(), 
        ncttt = conversion_trait(nctt)
        @test convert_arguments(ncttt, 1, 2, 3) == (1, 2, 3)
    end

end

@testset "functions" begin
    x = -pi..pi
    s = convert_arguments(Lines, x, sin)
    xy = s.args[1]
    @test xy[1][1] ≈ -pi
    @test xy[end][1] ≈ pi
    for (val, fval) in xy
        @test fval ≈ sin(val) atol=1f-6
    end

    x = range(-pi, stop=pi, length=100)
    s = convert_arguments(Lines, x, sin)
    xy = s.args[1]
    @test xy[1][1] ≈ -pi
    @test xy[end][1] ≈ pi
    for (val, fval) in xy
        @test fval ≈ sin(val) atol=1f-6
    end

    pts = [Point(1, 2), Point(4,5), Point(10, 8), Point(1, 2)]
    ls=LineString(pts)
    p = convert_arguments(AbstractPlotting.PointBased(), ls)
    @test p[1] == pts

    pts1 = [Point(5, 2), Point(4,8), Point(2, 8), Point(5, 2)]
    ls1 = LineString(pts1)
    lsa = [ls, ls1]
    p1 = convert_arguments(AbstractPlotting.PointBased(), lsa)
    @test p1[1][1:4] == pts
    @test p1[1][6:9] == pts1
    
    mls = MultiLineString(lsa)
    p2 = convert_arguments(AbstractPlotting.PointBased(), mls)
    @test p2[1][1:4] == pts
    @test p2[1][6:9] == pts1

    pol_e = Polygon(ls)
    p3_e = convert_arguments(AbstractPlotting.PointBased(), pol_e)
    @test p3_e[1] == pts

    pol = Polygon(ls, [ls1])
    p3 = convert_arguments(AbstractPlotting.PointBased(), pol)
    @test p3[1][1:4] == pts
    @test p3[1][6:9] == pts1

    pts2 = Point{2, Int}[(5, 1), (3, 3), (4, 8), (1, 2), (5, 1)]
    pts3 = Point{2, Int}[(2, 2), (2, 3),(3, 4), (2, 2)]
    pts4 = Point{2, Int}[(2, 2), (3, 8),(5, 6), (3, 4), (2, 2)]
    ls2 = LineString(pts2)
    ls3 = LineString(pts3)
    ls4 = LineString(pts4)
    pol1 = Polygon(ls2, [ls3, ls4])
    apol = [pol, pol1]
    p4 = convert_arguments(AbstractPlotting.PointBased(), apol)
    mpol = MultiPolygon([pol, pol1])
    @test p4[1][1:4] == pts
    @test p4[1][6:9] == pts1
    @test p4[1][11:15] == pts2 
    @test p4[1][17:20] == pts3
    @test p4[1][22:26] == pts4
end

@testset "Categorical values" begin
    # AbstractPlotting.jl#345
    a = Any[Int64(1), Int32(1), Int128(2)] # vector of categorical values of different types
    ilabels = AbstractPlotting.categoric_labels(a)
    @test ilabels == [1, 2]
    @test AbstractPlotting.categoric_position.(a, Ref(ilabels)) == [1, 1, 2]
end

using AbstractPlotting: check_line_pattern, line_diff_pattern

@testset "Linetype" begin
    @test isnothing(check_line_pattern("-."))
    @test isnothing(check_line_pattern("--"))
    @test_throws ArgumentError check_line_pattern("-.*")

    # for readability, the length of dash and dot
    dash, dot = 3.0, 1.0
    
    @test line_diff_pattern(:dash)             ==
          line_diff_pattern("-",   :normal)    == [dash, 3.0]
    @test line_diff_pattern(:dot)              == 
          line_diff_pattern(".",   :normal)    == [dot, 2.0]
    @test line_diff_pattern(:dashdot)          ==
          line_diff_pattern("-.",  :normal)    == [dash, 3.0, dot, 3.0]
    @test line_diff_pattern(:dashdotdot)       == 
          line_diff_pattern("-..", :normal)    == [dash, 3.0, dot, 2.0, dot, 3.0]
        
    @test line_diff_pattern(:dash, :loose)     == [dash, 6.0]
    @test line_diff_pattern(:dot,  :loose)     == [dot, 4.0]
    @test line_diff_pattern("-",   :dense)     == [dash, 2.0]
    @test line_diff_pattern(".",   :dense)     == [dot, 1.0]
    @test line_diff_pattern(:dash, 0.5)        == [dash, 0.5]
    @test line_diff_pattern(:dot,  0.5)        == [dot, 0.5]
    @test line_diff_pattern("-",   (0.4, 0.6)) == [dash, 0.6]
    @test line_diff_pattern(:dot,  (0.4, 0.6)) == [dot, 0.4]
    @test line_diff_pattern("-..", (0.4, 0.6)) == [dash, 0.6, dot, 0.4, dot, 0.6]

    # gaps must be Symbol, a number, or two numbers
    @test_throws ArgumentError line_diff_pattern(:dash, :NORMAL)
    @test_throws ArgumentError line_diff_pattern(:dash, ()) 
    @test_throws ArgumentError line_diff_pattern(:dash, (1, 2, 3))
end

using AbstractPlotting: SurfaceLike, convert_arguments

@testset "Surface" begin


    a = Array{Union{Float64,Missing},2}(undef,10,10)
    b = ones(Float32,10,10)
    [a[1:10,i] .= 1.0 for i in [1,3,5,7,9]]
    [b[1:10,i] .= NaN32 for i in [2,4,6,8,10]]

    x = y = collect(1:10)

    converted = convert_arguments(SurfaceLike(),x,y,a)

    @test converted[1] == Float32.(x)
    @test converted[2] == Float32.(x)
    @test isequal(converted[3],b)
    

end
