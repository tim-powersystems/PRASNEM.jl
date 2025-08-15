import numpy as np
import pandas as pd


class StoragesGroup:
    def __init__(self, hdf_file, timestep_count, csv_file, number_of_regions):
        self.hdf_file = hdf_file
        self.timestep_count = timestep_count
        self.csv_file = csv_file
        self.number_of_regions = number_of_regions

    def create(self):
        # Read the CSV file into a DataFrame
        df = pd.read_csv(self.csv_file)

        # Filter rows where "tech" is "BESS"
        df_bess = df[df["tech"] == "BESS"].copy()

        # Sort by bus number
        df_bess["region_sort"] = df_bess["bus_id"].astype(int)  # Added sorting step
        df_bess = df_bess.sort_values(by="region_sort").reset_index(drop=True)  # Sorting by region_sort
        df_bess.drop(columns="region_sort", inplace=True)  # Drop the helper column

        # Get the number of storages from the filtered DataFrame
        self.num_storages = len(df_bess)

        # Assign all generators to region "1" if number_of_regions == 1
        if self.number_of_regions == 1:
            df_bess["bus_id"] = "1"

        # Create the "storages" group in the HDF5 file
        storages_group = self.hdf_file.create_group("storages")

        # Define the compound datatype for the _core dataset
        storage_dtype = np.dtype([("name", "S128"), ("category", "S128"), ("region", "S128")])
        
        # Pre-allocate _core dataset
        storage_core_data = np.zeros(self.num_storages, dtype=storage_dtype)
        
        # Fill the _core dataset with storage data from the filtered DataFrame
        for storage_idx, row in df_bess.iterrows():
            storage_core_data[storage_idx] = (
                row["alias"].encode("ascii"),          # name from "alias" column
                row["tech"].encode("ascii"),           # category from "tech" column
                str(row["bus_id"]).encode("ascii")     # region from "bus_id" column
            )

        # Create the _core dataset in the HDF5 file
        storages_group.create_dataset("_core", data=storage_core_data)

        # Initialize time-varying datasets for each of the attributes
        chargecapacity_data = np.full((self.timestep_count, self.num_storages), 0, dtype=np.int64)
        dischargecapacity_data = np.full((self.timestep_count, self.num_storages), 0, dtype=np.int64)
        energycapacity_data = np.full((self.timestep_count, self.num_storages), 0, dtype=np.int64)
        chargeefficiency_data = np.full((self.timestep_count, self.num_storages), 0.0, dtype=np.float64)
        dischargeefficiency_data = np.full((self.timestep_count, self.num_storages), 0.0, dtype=np.float64)
        carryoverefficiency_data = np.full((self.timestep_count, self.num_storages), 0.0, dtype=np.float64)
        failureprobability_data = np.full((self.timestep_count, self.num_storages), 0.0, dtype=np.float64)
        repairprobability_data = np.full((self.timestep_count, self.num_storages), 0.0, dtype=np.float64)

        # Populate the time-varying datasets based on the CSV file values
        for idx, row in df_bess.iterrows():
            # Each attribute (column) in the CSV file will be the same across all timesteps
            chargecapacity_data[:, idx] = np.round(row["chargecapacity"]).astype(np.int64)
            dischargecapacity_data[:, idx] = np.round(row["dischargecapacity"]).astype(np.int64)
            energycapacity_data[:, idx] = np.round(row["energycapacity"]).astype(np.int64)
            chargeefficiency_data[:, idx] = row["chargeefficiency"]
            dischargeefficiency_data[:, idx] = row["dischargeefficiency"]
            carryoverefficiency_data[:, idx] = row["carryoverefficiency"]
            failureprobability_data[:, idx] = row["failureprobability"]
            repairprobability_data[:, idx] = row["repairprobability"]

        # Create the datasets for time-varying data
        storages_group.create_dataset("chargecapacity", data=chargecapacity_data, dtype=np.int64)
        storages_group.create_dataset("dischargecapacity", data=dischargecapacity_data, dtype=np.int64)
        storages_group.create_dataset("energycapacity", data=energycapacity_data, dtype=np.int64)
        storages_group.create_dataset("chargeefficiency", data=chargeefficiency_data, dtype=np.float64)
        storages_group.create_dataset("dischargeefficiency", data=dischargeefficiency_data, dtype=np.float64)
        storages_group.create_dataset("carryoverefficiency", data=carryoverefficiency_data, dtype=np.float64)
        storages_group.create_dataset("failureprobability", data=failureprobability_data, dtype=np.float64)
        storages_group.create_dataset("repairprobability", data=repairprobability_data, dtype=np.float64)