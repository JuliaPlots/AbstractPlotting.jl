using AbstractPlotting

using Test

include("quaternions.jl")

# if get(ENV, "IS_TRAVIS_CI", "false") == "false"
#   exit(0);
# end

## begin CI-only testing

# TODO replace this with test/REQUIRE

# import Pkg; Pkg.add("MakieGallery#soft-only") . # or whatever that branch is called, where GL is not a requirement

# import Pkg; Pkg.add("MakieGallery")

using MakieGallery

database = MakieGallery.load_database()

for ex in database
  
  try
    
    print("Running " * ex.title)
    
    MakieGallery.eval_example(ex);
    
  catch err
    
    if isa(y, ArgumentError) 
      
      print("Test " * ex.title * " probably uses a GL package and therefore failed.\nThis is probably fine.")
        
    else
      
        throw(y) # throw that error - it's not a Pkg error
      
    end
    
  end
end

# TODO write some AbstractPlotting specific tests... So far functionality is tested in Makie.jl
