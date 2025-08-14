# PRASNEM

[![Build Status](https://github.com/ARPST-UniMelb/PRASNEM.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/ARPST-UniMelb/PRASNEM.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/ARPST-UniMelb/PRASNEM.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/ARPST-UniMelb/PRASNEM.jl)

The goal of this package is to provide a model of the Australian National Electricity Market (NEM) to use in the Probabilistic Resource Adequacy Suite (PRAS) for to perform resource adequacy / reliability studies. 

PRAS is developed and maintained by NREL and can be found here: https://github.com/NREL/PRAS

This repository contains:
- All the parser scripts to create a PRAS model from ISP data
- Some PRAS model files, ready to go
- Some PRAS scripts to perform studies

## Getting Started

1. Creating a new PRAS case file (*python*)
    - Install python environment including the packages `os` and `h5py`
    - In the file `1_create_nem_pras_file.py`:
        - Adjust the parameters to desired case (including study year, network model, ISP scenario)
        - Run the file. The output will be saved as a `*.pras` file in the hdf5-format.
2. Run PRAS  (*julia*)
    - Install the package `PRAS`
    - Run the file `2_run_pras_study.jl`
