import os
import pandas as pd
from calendar import monthrange

class HourlyHydroInflowCalculator:
    def __init__(self, csv_path, reference_year, start_datetime_str, end_datetime_str, generator_shares_by_location):
        """ Takes hydro inflow data and transforms it into time-series input for PRAS file creation """
        self.csv_path = csv_path
        self.reference_year = reference_year
        self.start_datetime = pd.to_datetime(start_datetime_str)
        self.end_datetime = pd.to_datetime(end_datetime_str)
        self.generator_shares_by_location = generator_shares_by_location
        self.hourly_records = []

        # Month name to number mapping
        self.month_mapping = {
            'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
            'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12
        }

    def _get_ordered_months(self):
        """Returns list of (month_abbreviation, month_number) tuples starting from self.start_month"""
        sorted_months = sorted(self.month_mapping.items(), key=lambda x: (x[1] - self.start_datetime.month) % 12)
        return sorted_months

    def _generate_hourly_range(self, year_adjusted, month_idx):
        days_in_month = monthrange(year_adjusted, month_idx)[1]
        hours_in_month = days_in_month * 24
        start_time = f"{year_adjusted}-{month_idx:02d}-01"
        return pd.date_range(start=start_time, periods=hours_in_month, freq="h"), hours_in_month

    def _add_hourly_records(self, alias, location, gwh, month_idx):
        if pd.isna(gwh):
            return

        # Determine the adjusted year based on fiscal calendar
        year_adjusted = self.start_datetime.year + (1 if month_idx < self.start_datetime.month else 0)
        hourly_range, hours_in_month = self._generate_hourly_range(year_adjusted, month_idx)
        mwh_per_hour = (gwh * 1000) / hours_in_month

        for timestamp in hourly_range:
            if self.start_datetime <= timestamp <= self.end_datetime:
                self.hourly_records.append({
                    "timestamp": timestamp,
                    "alias": alias,
                    "value": mwh_per_hour,
                    "location": location
                })


    def execute(self, output_file):
        df = pd.read_csv(self.csv_path)
        months_ordered = self._get_ordered_months()

        # ---- 1. Process Standard Location Rows ----
        df_reference_year = df[df['Reference Year (FYE)'] == self.reference_year]

        for location, generator_shares in self.generator_shares_by_location.items():
            location_data = df_reference_year[df_reference_year["Location"] == location]

            if location_data.empty:
                raise ValueError(f"No data found for {location} in the reference year {self.reference_year}")

            monthly_gwh = location_data.iloc[0, 2:]  # Skip Year + Location columns

            for month_abbr, month_idx in months_ordered:
                gwh = monthly_gwh.loc[month_abbr]
                for alias, share in generator_shares.items():
                    self._add_hourly_records(alias, location, gwh * share, month_idx)

        # ---- 2. Process Fixed Generator Rows ----
        df_fixed = df[df['Reference Year (FYE)'] == "Fixed"]

        for _, row in df_fixed.iterrows():
            alias = row["Location"]
            monthly_gwh = row.iloc[2:]  # Skip Year + Location

            for month_abbr, month_idx in months_ordered:
                gwh = monthly_gwh.loc[month_abbr]
                self._add_hourly_records(alias, alias, gwh, month_idx)

        output_df = pd.DataFrame(self.hourly_records)
        output_df.to_csv(output_file, index=False) # can comment this out if we don't want to save the filtered csv file. 
        print(f"Hydro timestep CSV saved as {output_file}")
        return output_df





