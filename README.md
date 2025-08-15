# PRASNEM

[![Build Status](https://github.com/ARPST-UniMelb/PRASNEM.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/ARPST-UniMelb/PRASNEM.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/ARPST-UniMelb/PRASNEM.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/ARPST-UniMelb/PRASNEM.jl)

The goal of this package is to provide a model of the Australian National Electricity Market (NEM) to use in the Probabilistic Resource Adequacy Suite (PRAS) for to perform resource adequacy / reliability studies. 

PRAS is developed and maintained by NREL and can be found here: https://github.com/NREL/PRAS

This repository contains:
- All the parser scripts to create a PRAS model from ISP data
- Some PRAS model files, ready to go

## Getting Started

1. Download and install Git Large File Share as described here: https://www.git-lfs.com
2. Creating a new PRAS case file (*python*)
    - Install python environment including the packages `os` and `h5py`
    - In the file `create_nem_pras_file.py`:
        - Adjust the parameters to desired case (including study year, network model, ISP scenario)
        - Run the file. The output will be saved as a `*.pras` file in the hdf5-format.
3. Run PRASNEM (*julia*)
    - Develop the package PRASNEM by running
        ```Julia
            using Pkg; Pkg.develop("./PRASNEM")
        ```
    - Run the package
        ```Julia
            using PRASNEM
            file_name = "src/Parser/output/2030-07-01_to_2031-06-30_12_regions_nem.pras"
            PRASNEM.run_pras_study(example_file, 1000)
        ```
