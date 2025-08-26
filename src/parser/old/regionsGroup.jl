
function create_regions_group(hdf_file, timestep_count, regions, df_filtered, number_of_regions)
    
    # Create the "regions" group
    regions_group = create_group(hdf_file, "regions")

    if number_of_regions == 1
        # Only one region: "1"
        region_core_data = fill("1", 1)
        # Write _core dataset as a vector of strings
        create_dataset(regions_group, "_core", String, (1,))
        write(regions_group, "_core", region_core_data)

        # Filter demand for all regions and sum them timestep-wise
        df_all = sort(df_filtered, :date)
        grouped = combine(groupby(df_all, :date), :value => sum => :demand_sum)

        demand_values = grouped.demand_sum
        demand_values_rounded = round.(Int, demand_values)

        # Prepare load_data with shape (timesteps, 1 region)
        load_data = zeros(Int, timestep_count, 1)
        load_data[1:length(demand_values_rounded), 1] .= demand_values_rounded

        if length(demand_values_rounded) < timestep_count
            load_data[(length(demand_values_rounded)+1):timestep_count, 1] .= 0
        end
    else
        # Multiple regions
        region_core_data = string.(regions)
        write(regions_group, "_core", region_core_data)

        load_data = zeros(Int, length(regions), timestep_count)

        for (col_idx, region) in enumerate(regions)
            region_df = sort(df_filtered[df_filtered.dem_id .== region, :], :date)
            demand_values = region_df.value
            demand_values_rounded = round.(Int, demand_values)

            load_data[col_idx, 1:length(demand_values_rounded)] .= demand_values_rounded
            if length(demand_values_rounded) < timestep_count
                load_data[col_idx, (length(demand_values_rounded)+1):timestep_count] .= 0
            end
        end
    end

    # Write load dataset
    write(regions_group, "load", load_data)
end