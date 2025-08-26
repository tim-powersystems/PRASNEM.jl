import numpy as np

class RegionsGroup:
    def __init__(self, hdf_file, timestep_count, regions, df_filtered, number_of_regions):
        self.hdf_file = hdf_file
        self.timestep_count = timestep_count
        self.regions = regions
        self.df_filtered = df_filtered
        self.number_of_regions = number_of_regions

    def create(self):
        regions_group = self.hdf_file.create_group("regions")

        if self.number_of_regions == 1:
            # Only one region: "1"
            region_core_data = np.zeros(1, dtype=[("name", "S128")])
            region_core_data[0] = ("1".encode("ascii"),)
            regions_group.create_dataset("_core", data=region_core_data)

            # Filter demand for all regions and sum them timestep-wise
            df_all = self.df_filtered.sort_values("date")
            grouped = df_all.groupby("date")["value"].sum()

            demand_values = grouped.values
            demand_values_rounded = np.round(demand_values).astype(np.int64)

            # Prepare load_data with shape (timesteps, 1 region)
            load_data = np.zeros((self.timestep_count, 1), dtype=np.int64)
            load_data[:len(demand_values_rounded), 0] = demand_values_rounded

            if len(demand_values_rounded) < self.timestep_count:
                load_data[len(demand_values_rounded):, 0] = 0

        else:
            # Original behavior with multiple regions
            region_dtype = np.dtype([("name", "S128")])
            region_core_data = np.zeros(len(self.regions), dtype=region_dtype)

            for i, region in enumerate(self.regions):
                region_core_data[i] = (str(region).encode("ascii"),)

            regions_group.create_dataset("_core", data=region_core_data)

            load_data = np.zeros((self.timestep_count, len(self.regions)), dtype=np.int64)

            for col_idx, region in enumerate(self.regions):
                region_df = self.df_filtered[self.df_filtered["dem_id"] == region].sort_values("date")
                demand_values = region_df["value"].values
                demand_values_rounded = np.round(demand_values).astype(np.int64)

                load_data[:len(demand_values_rounded), col_idx] = demand_values_rounded
                if len(demand_values_rounded) < self.timestep_count:
                    load_data[len(demand_values_rounded):, col_idx] = 0

        # Write load dataset
        regions_group.create_dataset("load", data=load_data, dtype=np.int64)
