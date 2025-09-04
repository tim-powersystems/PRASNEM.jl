# PRASNEM

[![Build Status](https://github.com/ARPST-UniMelb/PRASNEM.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/ARPST-UniMelb/PRASNEM.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/ARPST-UniMelb/PRASNEM.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/ARPST-UniMelb/PRASNEM.jl)

The goal of this package is to provide a model of the Australian National Electricity Market (NEM) to use in the Probabilistic Resource Adequacy Suite (PRAS) for to perform resource adequacy / reliability studies. 

PRAS is developed and maintained by NREL and can be found here: https://github.com/NREL/PRAS

This repository contains:
- All the parser scripts to create a PRAS model from ISP data
- Some PRAS model files, ready to go

## Getting Started

Develop the package PRASNEM by running
```Julia
using Pkg; Pkg.develop("./PRASNEM")
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
sys = PRASNEM.parser_to_pras_format(start_dt, end_dt, input_folder, output_folder, timeseries_folder);
```

#### Evaulating reliability
Example if system was created above:
```Julia
PRASNEM.run_pras_study(sys, 100)
```
Example if reading system from file:
```Julia
using PRASNEM
file_name = "src/sample_data/pras_files/2025-01-07_to_2025-01-13_123456789101112_regions_nem.pras"
PRASNEM.run_pras_study(file_name, 100)
```
