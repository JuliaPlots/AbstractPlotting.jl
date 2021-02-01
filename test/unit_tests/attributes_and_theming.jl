@testset "theme priorization" begin
    set_theme!()
    recipe_markersize = AbstractPlotting.default_theme(nothing, Scatter).markersize[]

    scene = Scene()
    sc = scatter!(scene, randn(100, 2))
    @test sc.markersize[] == recipe_markersize

    scene2 = Scene(Scatter = (markersize = 30,))
    sc2 = scatter!(scene2, randn(100, 2))
    @test sc2.markersize[] == 30

    theme_markersize = 40
    set_theme!(Scatter = (markersize = theme_markersize,))

    scene3 = Scene(Scatter = (markersize = 30,))
    sc3 = scatter!(scene3, randn(100, 2))
    @test sc3.markersize[] == 30

    scene4 = Scene()
    sc4 = scatter!(scene4, randn(100, 2))
    @test sc4.markersize[] == theme_markersize

    scene5 = Scene(Scatter = (markersize = 50,))
    sc5 = scatter!(scene5, randn(100, 2), markersize = 60)
    @test sc5.markersize[] == 60

    _, _, sc6 = scatter(randn(100, 2))
    @test sc6.markersize[] == theme_markersize

    _, _, sc7 = scatter(randn(100, 2), markersize = 80)
    @test sc7.markersize[] == 80

    fig = Figure(Scatter = (markersize = 90,))
    ax, sc8 = scatter(fig[1, 1], randn(100, 2))
    @test fig.scene.attributes.Scatter.markersize[] == 90
    @test ax.scene.attributes.Scatter.markersize[] == 90
    # why doesn't this work?
    @test sc8.markersize[] == 90
end