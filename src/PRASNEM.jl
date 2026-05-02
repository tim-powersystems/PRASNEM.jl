module PRASNEM

using PRAS
using CSV
using Dates
using DataFrames
import Base.Threads
import Plots
using PISP

# Include customised functions to analyse PRAS output and to handle area/region mappings
include("./analysis/core.jl")

# Include the parser files
include("./parser/core.jl")

# Include customised functions to update PRAS models
include("./updating/core.jl")

# Include customised functions for running PRAS
include("./studies/core.jl")

end