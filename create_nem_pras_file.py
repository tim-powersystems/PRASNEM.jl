import os
import h5py

from datetime import datetime
from src.Parser.src.generators_group import GeneratorsGroup
from src.Parser.src.generatorstorages_group import GeneratorStoragesGroup
from src.Parser.src.hourly_hydro_inflow_calculator import HourlyHydroInflowCalculator
from src.Parser.src.interfaces_lines_group import InterfacesGroup, LinesGroup
from src.Parser.src.filter_sort_timestep_data import FilterSortTimestepData
from src.Parser.src.regions_group import RegionsGroup
from src.Parser.src.storages_group import StoragesGroup


# ---- CHANGE INPUTS HERE ----

number_of_regions = 12 # 1 for copperplate
scenarios = [2]  # 1 is progressive change, 2 is step change, 3 is green hydrogen exports
dem_ids = [1,2,3,4,5,6,7,8,9,10,11,12] # can remove regions if desired
gen_ids = [92,93,94,95,96,97,98,99,100,101,102,103,104,105,106,107,108,109,110,111,112,113,114,115,116,117,118,119,120,121,122,123] #can remove timestep generators if desired
# Only dates in data are FY25-26, FY30-31, FY35-36, FY40-41 and FY50-51
start_date = '2030-07-01 00:00:00' #change as needed
end_date = '2031-06-30 23:00:00' #change as needed

# Find timestep count
start_dt = datetime.strptime(start_date, '%Y-%m-%d %H:%M:%S')
end_dt = datetime.strptime(end_date, '%Y-%m-%d %H:%M:%S')
timestep_count = int((end_dt - start_dt).total_seconds() / (60*60) + 1)

# Hydro inflow inputs
hydro_reference_year = 'Average'
generator_shares_by_location = { 
    "Snowy": {
        "TUMUT3": 0.4436, "BLOWERNG": 0.0197, "UPPTUMUT": 0.1518, "GUTHEGA": 0.0148, "MURRAY1": 0.2341, "MURRAY2": 0.1360,},
    "TAS": {
        "BASTYAN": 0.0367, "LI_WY_CA": 0.0812, "CETHANA": 0.0390, "DEVILS_G":0.0276, "FISHER": 0.0198, "GORDON": 0.1985,
        "JBUTTERS": 0.0662, "LK_ECHO": 0.0149, "LEM_WIL": 0.0375, "MACKNTSH": 0.0367, "MEADOWBK": 0.0184, "POAT110": 0.1378,
        "REECE1": 0.1062, "TARRALEA": 0.0413, "TREVALLN": 0.0427, "TRIBUTE": 0.0380, "TUNGATIN": 0.0574,}
}

# ---- SETUP INPUT AND OUTPUT FILES ----

# Get the current working directory
current_working_directory = os.getcwd()

# Define the path to the input and output folder (CAN CHANGE AS NEEDED)
input_folder = os.path.join(current_working_directory, "src", "Parser", "input")
output_folder = os.path.join(current_working_directory, "src", "Parser", "output")

# Define input and output file names (CAN CHANGE AS NEEDED, JUST ENSURE THEY ARE THE SAME FORMAT)
load_input_filename =  "Demand_load_sched.csv"
load_output_filename = "filtered_timestep_load.csv" 
generator_input_filename = "_orig_Generator.csv"
timestep_generator_input_filename = "Generator_pmax_sched.csv"
timestep_generator_output_filename = "filtered_timestep_generator.csv"
storages_input_filename = "_orig_ESS.csv"
generatorstorage_inflows_input_filename = "Hydro_inflow.csv"
generatorstorage_inflows_output_filename = "calculated_hydro_inflow.csv"
interfaces_input_filename = "Interfaces.csv"
lines_input_filename = "Lines_filtered.csv"
hdf5_output_filename = f"{start_dt.date()}_to_{end_dt.date()}_{number_of_regions}_regions_nem.pras"

# Define input and output full file paths
load_input_file = os.path.join(input_folder, load_input_filename)
load_output_file = os.path.join(output_folder, "temp", load_output_filename)
generator_input_file = os.path.join(input_folder, generator_input_filename)
timestep_generator_input_file = os.path.join(input_folder, timestep_generator_input_filename)
timestep_generator_output_file = os.path.join(output_folder, "temp", timestep_generator_output_filename)
storages_input_file = os.path.join(input_folder, storages_input_filename)
generatorstorage_inflows_input_file = os.path.join(input_folder, generatorstorage_inflows_input_filename)
generatorstorage_inflows_output_file = os.path.join(output_folder, "temp", generatorstorage_inflows_output_filename)
interfaces_input_file = os.path.join(input_folder, interfaces_input_filename)
lines_input_file = os.path.join(input_folder, lines_input_filename)
hdf5_filepath = os.path.join(output_folder, hdf5_output_filename)

# Filter the timestep load file
filter_timestep_load = FilterSortTimestepData(load_input_file)
filtered_timestep_load  = filter_timestep_load.execute(output_file=load_output_file, scenarios=scenarios, dem_ids=dem_ids, start_dt=start_dt, end_dt=end_dt)

# Filter the timestep generator file
filter_timestep_generator = FilterSortTimestepData(timestep_generator_input_file)
filtered_timestep_generator = filter_timestep_generator.execute(output_file=timestep_generator_output_file, gen_ids=gen_ids, scenarios=scenarios, start_dt=start_dt, end_dt=end_dt)

# Calculate the hydro inflows
calculate_hydro_inflow = HourlyHydroInflowCalculator(generatorstorage_inflows_input_file, hydro_reference_year, start_date, end_date, generator_shares_by_location)
calculated_hydro_inflow = calculate_hydro_inflow.execute(output_file = generatorstorage_inflows_output_file)

# ---- CREATE PRAS FILE ----

# Load or create HDF5 file
with h5py.File(hdf5_filepath, "w") as hdf_file:
    # Root attributes
    hdf_file.attrs["pras_dataversion"] = "v0.7.1"
    hdf_file.attrs["start_timestamp"] = start_date.replace(" ", "T") + "+10:00"
    hdf_file.attrs["timestep_count"] = timestep_count
    hdf_file.attrs["timestep_length"] = 1
    hdf_file.attrs["timestep_unit"] = "h"
    hdf_file.attrs["power_unit"] = "MW"
    hdf_file.attrs["energy_unit"] = "MWh"
    # Create group instances and execute.
    RegionsGroup(hdf_file, timestep_count, dem_ids, filtered_timestep_load, number_of_regions).create()
    GeneratorsGroup(hdf_file, timestep_count, generator_input_file, filtered_timestep_generator, number_of_regions).create()
    StoragesGroup(hdf_file, timestep_count, storages_input_file, number_of_regions).create()
    GeneratorStoragesGroup(hdf_file, timestep_count, generator_input_file, storages_input_file, number_of_regions, calculated_hydro_inflow).create()
    if number_of_regions > 1:
        InterfacesGroup(hdf_file, timestep_count, interfaces_input_file).create()
        LinesGroup(hdf_file, timestep_count, lines_input_file).create()

    print(f"PRAS file saved as {hdf5_filepath}")



