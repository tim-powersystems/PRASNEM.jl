import pandas as pd
import os
from datetime import datetime


class FilterSortTimestepData:
    def __init__(self, input_file):
        """
        Initializes the FilterTimestepData class with an input file.
        
        Parameters:
        - input_file (str): Path to the input CSV file.
        """
        self.input_file = input_file
        # self.df = pd.read_csv(input_file, parse_dates=['date'])
        self.df = pd.read_csv(input_file)
        self.df['date'] = pd.to_datetime(self.df['date'], errors='coerce')
    
    def execute(self, output_file, scenarios=None, dem_ids=None, gen_ids =None, start_dt=None, end_dt=None):
        """
        Filters rows based on provided conditions and saves the filtered data.

        Parameters:
        - output_file (str): Path to save the filtered CSV file.
        - scenarios (list, optional): List of scenario values to keep.
        - dem_ids (list, optional): List of dem_id values to keep.
        - start_date (str, optional): Start date in 'YYYY-MM-DD HH:MM:SS' format.
        - end_date (str, optional): End date in 'YYYY-MM-DD HH:MM:SS' format.
        """
            
        df_filtered = self.df.copy()
    
        if scenarios is not None:
            df_filtered = df_filtered[df_filtered['scenario'].isin(scenarios)]   
        if dem_ids is not None:
            df_filtered = df_filtered[df_filtered['dem_id'].isin(dem_ids)]  
        if gen_ids is not None:
            df_filtered = df_filtered[df_filtered['gen_id'].isin(gen_ids)]
        if start_dt is not None:
            df_filtered = df_filtered[df_filtered['date'] >= start_dt]
        if end_dt is not None:
            df_filtered = df_filtered[df_filtered['date'] <= end_dt]

        if dem_ids is not None:
            df_filtered.sort_values(by=["dem_id", "date"])
        if gen_ids is not None:
            df_filtered.sort_values(by=["gen_id", "date"])
        
        df_filtered.to_csv(output_file, index=False) # can comment this out if we don't want to save the filtered csv file. 
        print(f"Filtered and sorted CSV saved as {output_file}")
        return df_filtered
    
# The following code is only to test the implementation. The class itself will be called in the main file

#current_working_directory = os.getcwd()

#input_folder = os.path.join(current_working_directory, "Python", "input")
#output_folder = os.path.join(current_working_directory, "Python", "output")

#load_input_filename =  "Demand_load_sched.csv"
#load_output_filename = "filtered_timestep_load_FY26.csv"

#load_input_file = os.path.join(input_folder, load_input_filename)
#load_output_file = os.path.join(output_folder, load_output_filename)

#start_date = '2025-07-01 00:00:00' #change as needed
#end_date = '2026-06-30 23:00:00' #change as needed

#start_dt = datetime.strptime(start_date, '%Y-%m-%d %H:%M:%S')
#end_dt = datetime.strptime(end_date, '%Y-%m-%d %H:%M:%S')

#FilterSortTimestepData(load_input_file).execute(load_output_file, scenarios=[2], start_dt=start_dt, end_dt=end_dt)
        
