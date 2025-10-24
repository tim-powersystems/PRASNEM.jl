module PRASNEM

using PRAS
using CSV
using Dates
using DataFrames
import Base.Threads
using PISP

# Include the parser files
include("./parser/core.jl")


# Include the functions for running PRAS
include("./studies/core.jl")


end