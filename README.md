# PRASNEM

[![Build Status](https://github.com/ARPST-UniMelb/PRASNEM.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/ARPST-UniMelb/PRASNEM.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/ARPST-UniMelb/PRASNEM.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/ARPST-UniMelb/PRASNEM.jl)

The goal of this package is to provide a model of the Australian National Electricity Market (NEM) to use in the Probabilistic Resource Adequacy Suite (PRAS) for to perform resource adequacy / reliability studies. 

PRAS is developed and maintained by NREL and can be found here: https://github.com/NREL/PRAS

This repository contains:
- All the parser scripts to create a PRAS model from ISP data
- Some PRAS model files, ready to go

## Getting Started

Install the dependency [`PISP.jl`](https://github.com/ARPST-UniMelb/PISP.jl#),

```julia
using Pkg
Pkg.develop(path="../PISP.jl")
```

then develop the package PRASNEM by running
```Julia
using Pkg; Pkg.develop(path="./PRASNEM")
```

#### Creating a new PRAS case file
Example:
```Julia
using PRASNEM
using Dates

start_dt = DateTime("2025-01-07 00:00:00", dateformat"yyyy-mm-dd HH:MM:SS")
end_dt = DateTime("2025-01-13 23:00:00", dateformat"yyyy-mm-dd HH:MM:SS")
input_folder = joinpath(pwd(), "src", "sample_data", "nem12")
output_folder = joinpath(pwd(), "src", "sample_data", "pras_files")
timeseries_folder = joinpath(input_folder, "schedule-1w")
sys = PRASNEM.create_pras_system(start_dt, end_dt, input_folder, timeseries_folder; output_folder=output_folder, regions_selected=collect(1:12));
```

#### Evaulating reliability
Example if system was created above and is available in memory:
```Julia
PRASNEM.run_pras_study(sys, 100)
```

Example if reading system from file:
```Julia
using PRASNEM
file_name = "src/sample_data/pras_files/2025-01-07_to_2025-01-13_s2_123456789101112_regions.pras"
PRASNEM.run_pras_study(file_name, 100)
```

Or if just PRAS should be used:
```Julia
using PRAS

file_name = "src/sample_data/pras_files/2025-01-07_to_2025-01-13_s2_123456789101112_regions.pras"
sys = SystemModel(file_name)
sf, = assess(sys, SequentialMonteCarlo(samples=100), Shortfall())

println(LOLE(sf))
println(NEUE(sf))
```

## Optional parameters of PRASNEM.create_pras_system
There are multiple optional parameters that can be adjusted when creating the pras system:
| Parameter           | Default       | Description                                                                                                                        |
| ------------------- | ------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| output_folder       | ""            | Folder to save the PRAS file. If empty, the PRAS file is not saved.                                                                |
| regions_selected    | collect(1:12) | Array of region IDs to include (needs to be in ascending order). Empty array for copperplate model.                                |
| scenario            | 2             | ISP scenario to use (1: progressive change, 2: step change, 3: green hydrogen exports)                                             |
| gentech_excluded    | []            | Array of generator technologies to exclude (can be fuel or technology, e.g. "Coal", "RoofPV", ...)                                 |
| alias_excluded      | []            | Array of generator/storage/DER aliases to exclude (e.g. "GSTONE1")                                                                 |
| investment_filer    | [0]           | Array indicating which assets to include based on investment status (if investment candidate or not)                               |
| active_filter       | [1]           | Array indicating which assets to include based on their active status                                                              |
| line_alias_included | []            | Array of line aliases to include even if they would be filtered out due to investment/active status                                |
| weather_folder      | ""            | Folder with weather data timeseries to use (no capacities are read from here, only normalised timeseries for demand, VRE, and DSP). Inflows are considered in full (not normalised).|

## Tips for more efficient usage

- **Using the optional parameter output_folder**:If you are using the same systems regularly, try to specify an ```output_folder```. If the PRAS-file is saved there, the function ```create_pras_system``` will automatically load this file instead of creating the same system again from scratch.
- **Fixing the seed of PRAS runs**: While fixing the seed of a simulation in PRAS will ensure the same result for a given system, it might not result in the same samples for a system with different components. Therefore, the standard deviation which is also computed by PRAS is important to consider. If exactly the same outage samples are required, consider using the same system for both cases but just "disabling" the components by setting the capacities to zero. (More details see [PRAS github](https://github.com/NREL/PRAS/issues/37).)


## Further PRAS functions
For reference, these are a number of possible outputs from PRAS (full list can be found in the PRAS documentation [here](https://nrel.github.io/PRAS/stable/PRAS/results/)):
```Julia
using PRAS

# Assuming that sys is already in memory (see above)
nsamples = 100
shortfalls, surplus, genavail, storage_energy, generator_storage_energy, flow = assess(
    sys, SequentialMonteCarlo(samples=nsamples),
    Shortfall(), Surplus(), GeneratorAvailability(), StorageEnergy(), GeneratorStorageEnergy(), Flow());
```