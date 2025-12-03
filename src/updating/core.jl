# Updating functions are set up to modify an existing model


# Function to remove intra-area constraints (i.e. increase line limits within the same area/state to very high levels)
include("remove_intraarea_constraints.jl")

# Function to redistribute demand response across the states/areas
include("redistribute_DR.jl")
