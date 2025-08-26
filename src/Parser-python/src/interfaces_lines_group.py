import numpy as np
import pandas as pd


class InterfacesGroup:
    def __init__(self, hdf_file, timestep_count, csv_file):
        """
        Initializes the InterfacesGroup class with the necessary parameters.
        
        Parameters:
        - hdf_file (h5py.File): The HDF5 file where the data will be saved.
        - timestep_count (int): Number of timesteps to create.
        - csv_file (str): Path to the CSV file containing interface data.
        """
        self.hdf_file = hdf_file
        self.timestep_count = timestep_count
        self.csv_file = csv_file
        self.interface_data = pd.read_csv(csv_file)
    
    def create(self):
        interfaces_group = self.hdf_file.create_group("interfaces")

        # **Sort the DataFrame by "region_to" and then "region_from" before populating _core**
        self.interface_data = self.interface_data.sort_values(by=["region_from", "region_to"]).reset_index(drop=True)

        # Define the compound datatype for the _core dataset (interface region pairs)
        interface_dtype = np.dtype([("region_from", "S128"), ("region_to", "S128")])
        
        # Pre-allocate _core dataset
        num_interfaces = len(self.interface_data)
        interface_core_data = np.zeros(num_interfaces, dtype=interface_dtype)
        
        # Fill the _core dataset with interface data
        for idx, row in self.interface_data.iterrows():
            interface_core_data[idx] = (
                str(row["region_from"]).encode("ascii"),
                str(row["region_to"]).encode("ascii")
            )

        interfaces_group.create_dataset("_core", data=interface_core_data)

        # Create time-varying datasets for forwardcapacity and backwardcapacity
        forwardcapacity_data = np.zeros((self.timestep_count, num_interfaces), dtype=np.int64)
        backwardcapacity_data = np.zeros((self.timestep_count, num_interfaces), dtype=np.int64)

        # Populate the forwardcapacity and backwardcapacity datasets
        for idx, row in self.interface_data.iterrows():
            forwardcapacity_data[:, idx] = row["forwardcapacity"]
            backwardcapacity_data[:, idx] = row["backwardcapacity"]

        # Create the datasets in the HDF5 file
        interfaces_group.create_dataset("forwardcapacity", data=forwardcapacity_data, dtype=np.int64)
        interfaces_group.create_dataset("backwardcapacity", data=backwardcapacity_data, dtype=np.int64)

class LinesGroup:
    def __init__(self, hdf_file, timestep_count, csv_file):
        self.hdf_file = hdf_file
        self.csv_file = csv_file
        self.timestep_count = timestep_count
        
        # Read the CSV file containing the line data
        self.line_data = pd.read_csv(csv_file)

    def create(self):
        lines_group = self.hdf_file.create_group("lines")

        # **Sort the DataFrame by "region_to" and then "region_from" before populating _core**
        self.line_data = self.line_data.sort_values(by=["region_from", "region_to"]).reset_index(drop=True)

        # Define the compound datatype for the _core dataset
        line_dtype = np.dtype([("name", "S128"), ("category", "S128"), ("region_from", "S128"), ("region_to", "S128")])
        
        # Pre-allocate _core dataset based on the number of lines in the CSV
        line_core_data = np.zeros(len(self.line_data), dtype=line_dtype)
        
        # Fill the _core dataset with line data from the CSV
        for idx, row in self.line_data.iterrows():
            line_core_data[idx] = (
                str(row["name"]).encode("ascii"),
                str(row["category"]).encode("ascii"),
                str(row["region_from"]).encode("ascii"),
                str(row["region_to"]).encode("ascii")
            )

        # Create the _core dataset
        lines_group.create_dataset("_core", data=line_core_data)

        # Initialize time-varying datasets for each of the attributes
        forwardcapacity_data = np.full((self.timestep_count, len(self.line_data)), 0, dtype=np.int64)
        backwardcapacity_data = np.full((self.timestep_count, len(self.line_data)), 0, dtype=np.int64)
        failureprobability_data = np.full((self.timestep_count, len(self.line_data)), 0.0, dtype=np.float64)
        repairprobability_data = np.full((self.timestep_count, len(self.line_data)), 0.0, dtype=np.float64)

        # Populate the time-varying datasets based on the CSV file values
        for idx, row in self.line_data.iterrows():
            forwardcapacity_data[:, idx] = row["forwardcapacity"]
            backwardcapacity_data[:, idx] = row["backwardcapacity"]
            failureprobability_data[:, idx] = row["failureprobability"]
            repairprobability_data[:, idx] = row["repairprobability"]

        # Create the datasets for time-varying data
        lines_group.create_dataset("forwardcapacity", data=forwardcapacity_data, dtype=np.int64)
        lines_group.create_dataset("backwardcapacity", data=backwardcapacity_data, dtype=np.int64)
        lines_group.create_dataset("failureprobability", data=failureprobability_data, dtype=np.float64)
        lines_group.create_dataset("repairprobability", data=repairprobability_data, dtype=np.float64)
