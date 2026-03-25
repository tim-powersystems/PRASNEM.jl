# Updating functions are set up to modify an existing model


# Function to remove intra-area constraints (i.e. increase line limits within the same area/state to very high levels)
include("remove_intraarea_constraints.jl")

# Function to redistribute demand response across the states/areas
include("redistribute_DR.jl")

# Functions to update a PRAS model with storage operation
include("updateStorageOperation.jl")

# Function to update a PRAS model with generator commitment and ramping
include("updateGeneratorOperation.jl")

# Function to update a PRAS model with DER dispatch and demand response
include("updateDEROperation.jl")

# Function to update a PRAS model with storage outage derating
include("updateStorageOutageDerating.jl")