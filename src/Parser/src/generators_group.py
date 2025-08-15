import numpy as np
import pandas as pd

class GeneratorsGroup:
    def __init__(self, hdf_file, timestep_count, csv_file, time_varying_df, number_of_regions):
        self.hdf_file = hdf_file
        self.timestep_count = timestep_count
        self.csv_file = csv_file
        self.time_varying_df = time_varying_df
        self.number_of_regions = number_of_regions

    def create(self):
        # Read the main CSV file into a DataFrame
        df = pd.read_csv(self.csv_file)

        # Filter out the rows where the "fuel" column is "Hydro"
        df = df[df["fuel"] != "Hydro"].reset_index(drop=True)

        # Assign all generators to region "1" if number_of_regions == 1
        if self.number_of_regions == 1:
            df["bus_id"] = "1"

        # Sort by region numerically
        df["region_sort"] = df["bus_id"].astype(int)
        df = df.sort_values(by="region_sort").reset_index(drop=True)

        # Define the compound datatype for the _core dataset
        generator_dtype = np.dtype([("name", "S128"), ("category", "S128"), ("region", "S128")])
        
        # Pre-allocate _core dataset
        generator_core_data = np.zeros(len(df), dtype=generator_dtype)

        # Fill the _core dataset with generator data
        for idx, row in df.iterrows():
            generator_core_data[idx] = (
                row["alias"].encode("ascii"),  # 'name' from "alias" column
                row["tech"].encode("ascii"),   # 'category' from "tech" column
                str(row["bus_id"]).encode("ascii")  # 'region' from "bus_id" column
            )

        # Create the _core dataset in the HDF5 file
        generators_group = self.hdf_file.create_group("generators")
        generators_group.create_dataset("_core", data=generator_core_data)

        # Initialize time-varying datasets (some values fixed for the timesteps)
        capacity_data = np.full((self.timestep_count, len(df)), 0, dtype=np.int64)
        failureprobability_data = np.full((self.timestep_count, len(df)), 0.0, dtype=np.float64)
        repairprobability_data = np.full((self.timestep_count, len(df)), 0.0, dtype=np.float64)

        time_varying_dict = self.time_varying_df.groupby("gen_id")["value"].apply(list).to_dict()
        # Populate the time-varying datasets based on the CSV file values
        for idx, row in df.iterrows():
            generator_id = row["id"]  # Use ID instead of name
            fuel_type = row["fuel"]

            if fuel_type in ["Solar", "Wind"]:
                # Find the time-varying data for this generator ID
                time_series = time_varying_dict.get(generator_id, [])

                # Ensure we have the correct number of timesteps
                if len(time_series) == self.timestep_count:
                    capacity_data[:, idx] = np.round(time_series).astype(np.int64)
                    failureprobability_data[:, idx] = row["failureprobability"]
                    repairprobability_data[:, idx] = row["repairprobability"]
                else:
                    raise ValueError(f"Mismatch in timestep count for generator ID {generator_id}")

            else:
                # For other generators, use fixed values
                capacity_data[:, idx] = row["totalcapacity"]
                failureprobability_data[:, idx] = row["failureprobability"]
                repairprobability_data[:, idx] = row["repairprobability"]

        # Create the datasets for time-varying data
        generators_group.create_dataset("capacity", data=capacity_data, dtype=np.int64)
        generators_group.create_dataset("failureprobability", data=failureprobability_data, dtype=np.float64)
        generators_group.create_dataset("repairprobability", data=repairprobability_data, dtype=np.float64)