using RecipePipeline, Plots
using AbstractPlotting: Scene, lines!
# Define overrides for RecipesPipeline hooks.

function RecipePipeline._recipe_init!(sc::Scene, plotattributes, args)
    @info "Init"
end

function RecipePipeline._recipe_after_user!(sc::Scene, plotattributes, args)
    @info "User complete"
end

function RecipePipeline._recipe_after_plot!(sc::Scene, plotattributes, args)
    @info "Plot complete"
end

function RecipePipeline._recipe_before_series!(sc::Scene, plotattributes, args)
    @info "Series initializing"
    return plotattributes
end

function RecipePipeline._recipe_finish!(sc::Scene, plotattributes, args)
    @info "Finished!"
    return sc
end

# Allow a series type to be plotted.

RecipePipeline.is_st_supported(sc::Scene, st) = true

RecipePipeline._preprocess_args(sc::Scene, args...) = RecipePipeline._preprocess_args(Plots.Plot(), args...)

function RecipePipeline.finalize_subplot!(plt::Scene, st, plotattributes)
    if st != :scatter
        @warn "What are you doing?"
    end

    for (k, v) in pairs(plotattributes)
        isnothing(v) && delete!(plotattributes, k)
    end

    @show plotattributes

    if !haskey(plotattributes, :z)
        @info "No z"
        AbstractPlotting.scatter!(plt, plotattributes[:x], plotattributes[:y]; plotattributes...)
    else
        @info "Z"
        AbstractPlotting.scatter!(plt, plotattributes[:x], plotattributes[:y], plotattributes[:z]; plotattributes...)
    end
end


RecipePipeline._process_userrecipe(plt::Scene, kw_list, recipedata) = RecipePipeline._process_userrecipe(Plots.Plot(), kw_list, recipedata)

RecipesBase.apply_recipe(plotattributes::Plots.AKW, ::Type{T}, ::AbstractPlotting.Scene) where T = throw(MethodError("Unmatched plot type: $T"))

sc = Scene()

RecipePipeline.recipe_pipeline!(sc, Dict(:color => :blue, :seriestype => :scatter), (1:10, 1:10))
