import numpy as np
import pandas as pd


class GeneratorStoragesGroup:
    def __init__(self, hdf_file, timestep_count, generator_csv, ess_csv, number_of_regions, inflow_df=None):
        self.hdf_file = hdf_file
        self.generator_csv = generator_csv  # CSV with 'alias', 'fuel', 'bus_id'
        self.ess_csv = ess_csv  # CSV with 'alias', 'tech', 'bus_id'
        self.timestep_count = timestep_count
        self.inflow_df = inflow_df
        self.number_of_regions = number_of_regions

    def create(self):
        generatorstorages_group = self.hdf_file.create_group("generatorstorages")
        
        # Read and filter first CSV (Hydro only)
        generator_df = pd.read_csv(self.generator_csv)
        generator_df = generator_df[generator_df["fuel"] == "Hydro"]
        generator_df = generator_df.rename(columns={"fuel": "category"})
        
        # Read and filter second CSV (PS only)
        ess_df = pd.read_csv(self.ess_csv)
        ess_df = ess_df[ess_df["tech"] == "PS"]
        ess_df = ess_df.rename(columns={"tech": "category"})
        
        # Combine the filtered data
        combined_df = pd.concat([generator_df, ess_df], ignore_index=True)
        combined_df["region_sort"] = combined_df["bus_id"].astype(int)
        combined_df = combined_df.sort_values(by="region_sort").reset_index(drop=True)
        combined_df.drop(columns="region_sort", inplace=True)  # Drop the helper column

        # Assign all generators to region "1" if number_of_regions == 1
        if self.number_of_regions == 1:
            combined_df["bus_id"] = "1"

        num_generatorstorages = len(combined_df)
        
        # Define the _core dataset
        generatorstorage_dtype = np.dtype([("name", "S128"), ("category", "S128"), ("region", "S128")])
        generatorstorage_core_data = np.zeros(num_generatorstorages, dtype=generatorstorage_dtype)
        
        for idx, row in combined_df.iterrows():
            generatorstorage_core_data[idx] = (
                row["alias"].encode("ascii"),
                row["category"].encode("ascii"),
                str(row["bus_id"]).encode("ascii")
            )
        
        generatorstorages_group.create_dataset("_core", data=generatorstorage_core_data)
        
        # Initialize time-varying datasets for each of the attributes
        inflow_data = np.full((self.timestep_count, num_generatorstorages), 0, dtype=np.int64)
        gridwithdrawalcapacity_data = np.full((self.timestep_count, num_generatorstorages), 0, dtype=np.int64)
        gridinjectioncapacity_data = np.full((self.timestep_count, num_generatorstorages), 0, dtype=np.int64)
        chargecapacity_data = np.full((self.timestep_count, num_generatorstorages), 0, dtype=np.int64)
        dischargecapacity_data = np.full((self.timestep_count, num_generatorstorages), 0, dtype=np.int64)
        energycapacity_data = np.full((self.timestep_count, num_generatorstorages), 0, dtype=np.int64)
        chargeefficiency_data = np.full((self.timestep_count, num_generatorstorages), 0.0, dtype=np.float64)
        dischargeefficiency_data = np.full((self.timestep_count, num_generatorstorages), 0.0, dtype=np.float64)
        carryoverefficiency_data = np.full((self.timestep_count, num_generatorstorages), 0.0, dtype=np.float64)
        failureprobability_data = np.full((self.timestep_count, num_generatorstorages), 0.0, dtype=np.float64)
        repairprobability_data = np.full((self.timestep_count, num_generatorstorages), 0.0, dtype=np.float64)

        if self.inflow_df is not None:
            # Ensure inflow_df is sorted by alias and timestamp
            inflow_dict = (
                self.inflow_df
                .sort_values(["alias", "timestamp"])
                .groupby("alias")["value"]
                .apply(lambda x: list(np.round(x).astype(np.int64)))
                .to_dict()
            )

        # Populate the time-varying datasets based on the CSV file values
        for idx, row in combined_df.iterrows():
            # Each attribute (column) in the CSV file will be the same across all timesteps
            gridwithdrawalcapacity_data[:, idx] = np.round(row["gridwithdrawalcapacity"]).astype(np.int64)
            gridinjectioncapacity_data[:, idx] = np.round(row["gridinjectioncapacity"]).astype(np.int64)
            chargecapacity_data[:, idx] = np.round(row["chargecapacity"]).astype(np.int64)
            dischargecapacity = np.round(row["dischargecapacity"]).astype(np.int64)
            dischargecapacity_data[:, idx] = dischargecapacity
            energycapacity= np.round(row["energycapacity"]).astype(np.int64)
            energycapacity_data[:, idx] = energycapacity
            chargeefficiency_data[:, idx] = row["chargeefficiency"]
            dischargeefficiency_data[:, idx] = row["dischargeefficiency"]
            carryoverefficiency_data[:, idx] = row["carryoverefficiency"]
            failureprobability_data[:, idx] = row["failureprobability"]
            repairprobability_data[:, idx] = row["repairprobability"]
        
            if self.inflow_df is not None:
                # Determine if Hydro or PS
                category = row["category"]
                # Find time-varying "inflow" data for specific generator-storage
                generatorstorage_id = row["alias"]
                time_series = inflow_dict.get(generatorstorage_id, [])
                
                if category == "Hydro":
                    inflow_data[0, idx] = dischargecapacity * 24 * 30 # 30 days worth of energy initially
                elif category == "PS":
                    inflow_data[0, idx] = energycapacity // 2 # if PS, assume it is half full
                # Ensure we have the correct number of timesteps
                if len(time_series) == self.timestep_count:
                    inflow_data[1:, idx] = np.round(time_series[1:]).astype(np.int64)
                        
                else:
                    raise ValueError(f"Mismatch in timestep count for generator ID {generatorstorage_id}")

        # Create the datasets
        generatorstorages_group.create_dataset("inflow", data=inflow_data, dtype=np.int64)
        generatorstorages_group.create_dataset("gridwithdrawalcapacity", data=gridwithdrawalcapacity_data, dtype=np.int64)
        generatorstorages_group.create_dataset("gridinjectioncapacity", data=gridinjectioncapacity_data, dtype=np.int64)
        generatorstorages_group.create_dataset("chargecapacity", data=chargecapacity_data, dtype=np.int64)
        generatorstorages_group.create_dataset("dischargecapacity", data=dischargecapacity_data, dtype=np.int64)
        generatorstorages_group.create_dataset("energycapacity", data=energycapacity_data, dtype=np.int64)
        generatorstorages_group.create_dataset("chargeefficiency", data=chargeefficiency_data, dtype=np.float64)
        generatorstorages_group.create_dataset("dischargeefficiency", data=dischargeefficiency_data, dtype=np.float64)
        generatorstorages_group.create_dataset("carryoverefficiency", data=carryoverefficiency_data, dtype=np.float64)
        generatorstorages_group.create_dataset("failureprobability", data=failureprobability_data, dtype=np.float64)
        generatorstorages_group.create_dataset("repairprobability", data=repairprobability_data, dtype=np.float64)


