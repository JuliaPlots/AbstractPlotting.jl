@testset "Transformations" begin
    @testset "Rotation" begin
        data = ones(10)
        lineplot = lines(data)[end]
        rotate!(lineplot, 0.5π)
        @test AbstractPlotting.project(lineplot.model[], lineplot.converted[1][][1]) .≈ Point2f0(0, 1)
        rotate!(Accum, lineplot, 0.5π)
        @test AbstractPlotting.project(lineplot.model[], lineplot.converted[1][][1]) .≈ Point2f0(-1, -1)
    end
end
