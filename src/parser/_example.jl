#%% Define the system

const tz = tz"Australia/Melbourne"

empty_str = String[]
empty_int(x) = Matrix{Int}(undef, 0, x)
empty_float(x) = Matrix{Float64}(undef, 0, x)

# Defining the number of timesteps
N = 5
start_time = ZonedDateTime(2010,1,1,0,tz)

#%% Defining new generators
NgensAB = 6 + 5 # 6 generators in area A and 5 in area B
gens = Generators{N,5,Minute,MW}(
    ["Gen1A", "Gen2A", "Gen3A", "Gen4A", "Gen5A", "Gen6A", "Gen1B", "Gen2B", "Gen3B", "Gen4B", "Gen5B"], # Names
    ["Gens", "Gens", "Gens", "Gens", "Gens", "Gens", "Gens", "Gens", "Gens", "Gens", "Gens"], # Categories
    reshape(repeat([100, 100, 100, 100, 100, 250, 100, 100, 100, 100, 200],N), NgensAB, N), # capacity (for each generator (row) for each timestep (column))
    fill(0.02, NgensAB, N), # lambda (failure probability of each generator of each timestep)
    fill(0.98, NgensAB, N))  # mu (repair probability of each generator of each timestep)

#%% Define a storage model (but without units)
stors = Storages{N,5,Minute,MW,MWh}(
    (empty_str for _ in 1:2)..., # Name and categories
    (empty_int(N) for _ in 1:3)..., # charge, discharge, and energy capacity
    (empty_float(N) for _ in 1:3)..., # charge, discharge, carryover efficiency
    (empty_float(N) for _ in 1:2)...) # lambda and mu (failure and repair probability)

#%% Define a generator-storage model (but without units)
genstors = GeneratorStorages{N,5,Minute,MW,MWh}(
    (empty_str for _ in 1:2)..., # Name and categories
    (empty_int(N) for _ in 1:3)..., # charge, discharge, and energy capacity
    (empty_float(N) for _ in 1:3)..., # charge, discharge, carryover efficiency
    (empty_int(N) for _ in 1:3)..., # inflows, gridwithdrawal, and gridinjection capacity
    (empty_float(N) for _ in 1:2)...) # lambda and mu (failure and repair probability)


#%% =======================================
Nregions = 2
regions = Regions{N,MW}( #timesteps, units)
        ["Region A", "Region B"], # Names
        reshape([465, 372, 500, 400, 490, 392, 480, 384, 470, 376], Nregions, N) # Load (in MW) for each region and timestep
        )

interfaces = Interfaces{N,MW}( # timesteps, units
    [1], [2], # from, to
    fill(100, 1, N), # forward capacity (MW) for each interface and timestep
    fill(100, 1, N)  # reverse capacity (MW) for each interface and timestep
    ) 

lines = Lines{N,5,Minute,MW}(
    ["Line 1"], # Names
    ["Line"], # Categories
    fill(100, 1, N), # forward capacity (MW) for each line and timestep
    fill(100, 1, N), # reverse capacity (MW) for each line and timestep
    fill(0., 1, N), # failure rate (λ) for each line and timestep
    fill(1.0, 1, N) # repair rate (μ) for each line and timestep
    )

linesOff = Lines{N,5,Minute,MW}(
    ["Line 1"], # Names
    ["Line"], # Categories
    fill(0, 1, N), # forward capacity (MW) for each line and timestep
    fill(0, 1, N), # reverse capacity (MW) for each line and timestep
    fill(0., 1, N), # failure rate (λ) for each line and timestep
    fill(1.0, 1, N) # repair rate (μ) for each line and timestep
    )


gen_regions = [1:6, 7:11] # Assigning generators to regions (in each region, the indices of the generators)
stor_regions = [1:0, 1:0] # Assigning storages to regions (no storages in this example)
genstor_regions = [1:0, 1:0] # Assigning generator-storages to regions (no generator-storages in this example)
line_interfaces = [1:1] # Assigning lines to interfaces (in this case, line 1 is connected to interface 1)

sys = SystemModel(
        regions, interfaces,
        gens, gen_regions, 
        stors, stor_regions,
        genstors, genstor_regions,
        lines, line_interfaces,
        start_time:Minute(5):start_time + Minute(5) * (N-1) # Timestamps
        ) 