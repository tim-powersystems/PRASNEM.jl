import os
import h5py
import numpy as np
from datetime import datetime

### This file is used to generate a small 2-region system to test desired outcomes where all inputs can be controlled, and expected output behaviour can be predicted. 

# ---- CHANGE INPUTS HERE ----

start_date = '2025-07-01 01:00:00' #change as needed
end_date = '2025-07-01 04:00:00' #change as needed

# Find timestep count
start_dt = datetime.strptime(start_date, '%Y-%m-%d %H:%M:%S')
end_dt = datetime.strptime(end_date, '%Y-%m-%d %H:%M:%S')
timestep_count = int((end_dt - start_dt).total_seconds() / (60*60) + 1)

# ---- SETUP INPUT AND OUTPUT FILES ----

# Get the current working directory
current_working_directory = os.getcwd()

# Define the path to the input and output folder (CAN CHANGE AS NEEDED)
input_folder = os.path.join(current_working_directory, "Python", "dummy_input")
output_folder = os.path.join(current_working_directory, "Python", "dummy_output")

hdf5_output_filename = f"{start_dt.date()}_to_{end_dt.date()}_dummy.pras"
hdf5_filepath = os.path.join(output_folder, hdf5_output_filename)

# ---- DUMMMY INPUTS ----
"""Needs to be filled out to test the demand response concept"""

# Define Regions _core
region_names = [b"Region1", b"Region2"]
region_dtype = np.dtype([("name", "S128")])  # 128-byte ASCII strings
region_core_data = np.array([(name,) for name in region_names], dtype=region_dtype)

# Define time-varying load data for each region
load_data = np.array([
    [500, 625, 750, 875],  
    [500, 625, 750, 875]  
], dtype=np.int64).T


# Define Generators _core
generator_info = [
    (b"GenA", b"Coal", b"Region1"),
    (b"GenB", b"Wind", b"Region2")
]
generator_dtype = np.dtype([
    ("name", "S128"),
    ("category", "S128"),
    ("region", "S128")
])
generator_core_data = np.array(generator_info, dtype=generator_dtype)

# Define time-varying data for each generator
capacity_data = np.array([
    [800, 800, 800, 800],   
    [400, 400, 400, 400]    
], dtype=np.int64).T

failure_prob_data = np.array([
    [0.00, 0.00, 0.00, 0.00],  
    [0.00, 0.00, 0.00, 0.00]   
], dtype=np.float64).T

repair_prob_data = np.array([
    [1.00, 1.00, 1.00, 1.00],      
    [1.00, 1.00, 1.00, 1.00]   
], dtype=np.float64).T


# Define Storages _core
storage_info = [
    (b"StoreA", b"BESS", b"Region1"),
    (b"StoreB", b"BESS", b"Region2")
]
storage_dtype = np.dtype([
    ("name", "S128"),
    ("category", "S128"),
    ("region", "S128")
])
storage_core_data = np.array(storage_info, dtype=storage_dtype)

# Define time-varying data for each storage
storage_charge_capacity = np.array([
    [100, 100, 100, 100],
    [50, 50, 50, 50]
], dtype=np.int64).T

storage_discharge_capacity = np.array([
    [100, 100, 100, 100],
    [50, 50, 50, 50]
], dtype=np.int64).T

storage_energy_capacity = np.array([
    [300, 300, 300, 300],
    [150, 150, 150, 150]
], dtype=np.int64).T

storage_charge_efficiency = np.array([
    [1.00, 1.00, 1.00, 1.00],
    [1.00, 1.00, 1.00, 1.00]
], dtype=np.float64).T

storage_discharge_efficiency = np.array([
    [1.00, 1.00, 1.00, 1.00],
    [1.00, 1.00, 1.00, 1.00]
], dtype=np.float64).T

storage_carryover_efficiency = np.array([
    [1.00, 1.00, 1.00, 1.00],
    [1.00, 1.00, 1.00, 1.00]
], dtype=np.float64).T

storage_failure_probability = np.array([
    [0.00, 0.00, 0.00, 0.00],  
    [0.00, 0.00, 0.00, 0.00]   
], dtype=np.float64).T

storage_repair_probability = np.array([
    [1.00, 1.00, 1.00, 1.00],
    [1.00, 1.00, 1.00, 1.00]
], dtype=np.float64).T


# Define GeneratorStorages _core
genstorage_info = [
    (b"GenStoreA", b"PumpedHydro", b"Region1"),
    (b"GenStoreB", b"FlexibleDemand", b"Region2")
]
genstorage_dtype = np.dtype([
    ("name", "S128"),
    ("category", "S128"),
    ("region", "S128")
])
genstorage_core_data = np.array(genstorage_info, dtype=genstorage_dtype)

# Define time-varying data for each genstorage
genstorage_charge_capacity = np.array([
    [100, 100, 100, 100],
    [0, 0, 0, 0]
], dtype=np.int64).T

genstorage_discharge_capacity = np.array([
    [100, 100, 100, 100],
    [0, 100, 200, 300]
], dtype=np.int64).T

genstorage_energy_capacity = np.array([
    [200, 200, 200, 200],
    [1, 100, 1, 1]
], dtype=np.int64).T

genstorage_charge_efficiency = np.array([
    [1.00, 1.00, 1.00, 1.00],
    [1.00, 1.00, 1.00, 1.00]
], dtype=np.float64).T

genstorage_discharge_efficiency = np.array([
    [1.00, 1.00, 1.00, 1.00],
    [1.00, 1.00, 1.00, 1.00]
], dtype=np.float64).T

genstorage_carryover_efficiency = np.array([
    [1.00, 1.00, 1.00, 1.00],
    [0.00, 0.00, 0.00, 0.00]
], dtype=np.float64).T

genstorage_failure_probability = np.array([
    [0.00, 0.00, 0.00, 0.00],  
    [0.00, 0.00, 0.00, 0.00]   
], dtype=np.float64).T

genstorage_repair_probability = np.array([
    [1.00, 1.00, 1.00, 1.00],
    [1.00, 1.00, 1.00, 1.00]
], dtype=np.float64).T

genstorage_gridwithdrawalcapacity = np.array([
    [100, 100, 100, 100],
    [0, 0, 0, 0]
], dtype=np.int64).T

genstorage_gridinjectioncapacity = np.array([
    [100, 100, 100, 100],
    [0, 100, 200, 300]
], dtype=np.int64).T

genstorage_inflow = np.array([
    [0, 0, 0, 0],
    [0, 100, 200, 300]
], dtype=np.int64).T


# Define Interfaces _core data
interface_info = [
    (b"Region1", b"Region2")
]
interface_dtype = np.dtype([
    ("region_from", "S128"),
    ("region_to", "S128")
])
interface_core_data = np.array(interface_info, dtype=interface_dtype)

# Define time-varying data for each interface
forward_capacity_interface = np.array([
    [1000, 1000, 1000, 1000]
], dtype=np.int64).T

backward_capacity_interface = np.array([
    [1000, 1000, 1000, 1000]
], dtype=np.int64).T


# Define Lines _core data
line_info = [
    (b"LineA", b"AC", b"Region1", b"Region2"),
    (b"LineB", b"DC", b"Region1", b"Region2")
]
line_dtype = np.dtype([
    ("name", "S128"),
    ("category", "S128"),
    ("region_from", "S128"),
    ("region_to", "S128")
])
line_core_data = np.array(line_info, dtype=line_dtype)

# Define time-varying data for each line
forward_capacity_lines = np.array([
    [500, 500, 500, 500],
    [500, 500, 500, 500]
], dtype=np.int64).T

backward_capacity_lines = np.array([
    [500, 500, 500, 500],
    [500, 500, 500, 500]
], dtype=np.int64).T

failure_probability_lines = np.array([
    [0.00, 0.00, 0.00, 0.00],
    [0.00, 0.00, 0.00, 0.00]
], dtype=np.float64).T

repair_probability_lines = np.array([
    [1.00, 1.00, 1.00, 1.00],
    [1.00, 1.00, 1.00, 1.00]
], dtype=np.float64).T

# ---- CREATE PRAS FILE ----

with h5py.File(hdf5_filepath, "w") as hdf_file:
    # Root attributes
    hdf_file.attrs["pras_dataversion"] = "v0.7.1"
    hdf_file.attrs["start_timestamp"] = start_date.replace(" ", "T") + "+10:00"
    hdf_file.attrs["timestep_count"] = timestep_count
    hdf_file.attrs["timestep_length"] = 1
    hdf_file.attrs["timestep_unit"] = "h"
    hdf_file.attrs["power_unit"] = "MW"
    hdf_file.attrs["energy_unit"] = "MWh"
    # Create Regions group and datasets
    regions_group = hdf_file.create_group("regions")
    regions_group.create_dataset("_core", data=region_core_data)
    regions_group.create_dataset("load", data=load_data)
    # Create Generators group and datasets
    generators_group = hdf_file.create_group("generators")
    generators_group.create_dataset("_core", data=generator_core_data)
    generators_group.create_dataset("capacity", data=capacity_data)
    generators_group.create_dataset("failureprobability", data=failure_prob_data)
    generators_group.create_dataset("repairprobability", data=repair_prob_data)
    # Create Storages group and datasets
    storages_group = hdf_file.create_group("storages")
    storages_group.create_dataset("_core", data=storage_core_data)
    storages_group.create_dataset("chargecapacity", data=storage_charge_capacity)
    storages_group.create_dataset("dischargecapacity", data=storage_discharge_capacity)
    storages_group.create_dataset("energycapacity", data=storage_energy_capacity)
    storages_group.create_dataset("chargeefficiency", data=storage_charge_efficiency)
    storages_group.create_dataset("dischargeefficiency", data=storage_discharge_efficiency)
    storages_group.create_dataset("carryoverefficiency", data=storage_carryover_efficiency)
    storages_group.create_dataset("failureprobability", data=storage_failure_probability)
    storages_group.create_dataset("repairprobability", data=storage_repair_probability)
    # Create GeneratorStorages group and datasets
    generatorstorages_group = hdf_file.create_group("generatorstorages")
    generatorstorages_group.create_dataset("_core", data=genstorage_core_data)
    generatorstorages_group.create_dataset("chargecapacity", data=genstorage_charge_capacity)
    generatorstorages_group.create_dataset("dischargecapacity", data=genstorage_discharge_capacity)
    generatorstorages_group.create_dataset("energycapacity", data=genstorage_energy_capacity)
    generatorstorages_group.create_dataset("chargeefficiency", data=genstorage_charge_efficiency)
    generatorstorages_group.create_dataset("dischargeefficiency", data=genstorage_discharge_efficiency)
    generatorstorages_group.create_dataset("carryoverefficiency", data=genstorage_carryover_efficiency)
    generatorstorages_group.create_dataset("failureprobability", data=genstorage_failure_probability)
    generatorstorages_group.create_dataset("repairprobability", data=genstorage_repair_probability)
    generatorstorages_group.create_dataset("inflow", data=genstorage_inflow)
    generatorstorages_group.create_dataset("gridwithdrawalcapacity", data=genstorage_gridwithdrawalcapacity)
    generatorstorages_group.create_dataset("gridinjectioncapacity", data=genstorage_gridinjectioncapacity)
    # Create Interfaces group and datasets
    interfaces_group = hdf_file.create_group("interfaces")
    interfaces_group.create_dataset("_core", data=interface_core_data)
    interfaces_group.create_dataset("forwardcapacity", data=forward_capacity_interface)
    interfaces_group.create_dataset("backwardcapacity", data=backward_capacity_interface)
    # Create Lines group and datasets
    lines_group = hdf_file.create_group("lines")
    lines_group.create_dataset("_core", data=line_core_data)
    lines_group.create_dataset("forwardcapacity", data=forward_capacity_lines)
    lines_group.create_dataset("backwardcapacity", data=backward_capacity_lines)
    lines_group.create_dataset("failureprobability", data=failure_probability_lines)
    lines_group.create_dataset("repairprobability", data=repair_probability_lines)

    print(f"PRAS file saved as {hdf5_filepath}")



