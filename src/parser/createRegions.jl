function createRegions(demand_input_file, timeseries_folder, units, region_names::Union{Vector{Int}, Vector{Any},UnitRange{Int64}}=[], scenario::Int=2, start_dt::Union{Nothing, DateTime}=nothing, end_dt::Union{Nothing, DateTime}=nothing)

    # First, get the region names and demand ids
    dem_info = CSV.read(demand_input_file, DataFrame)

    # Filter only the demand in the selected regions
    if region_names != []
        filter!(row -> row[:id_bus] in region_names, dem_info)
    end

    # Exclude all the DSP objects - they are included as demandresponse objects
    filter!(row -> !occursin("DSP", row[:name]), dem_info)

    # Read and filter the timestep load file
    load_input_file = joinpath(timeseries_folder, "Demand_load_sched.csv")
    load_data = read_timeseries_file(load_input_file)
    df_filtered = PISP.filterSortTimeseriesData(load_data, units, start_dt, end_dt, dem_info, "", scenario, "id_dem", dem_info.id_dem[:])

    number_of_regions = length(region_names)

    if number_of_regions == 0

        # Sum up all the demand into one vector
        demand = sum.(eachrow(select(df_filtered,Not("date"))))

        # Check if the number of timesteps is less than expected
        if length(demand) < units.N
            println("WARNING: Fewer timesteps in the load data than expected. Padding with zeros.")
            # If there are fewer timesteps than expected, pad with zeros
            demand_values_rounded = vcat(round.(Int, demand), zeros(Int, units.N - length(demand)))
        else
            demand_values_rounded = round.(Int, demand)
        end

        return Regions{units.N,units.P}( #timesteps, units
            ["All"], # Names
            reshape(demand_values_rounded, 1, units.N) # Load (in MW) for the single region and all timesteps
        )
    else

        demand_values_rounded = zeros(Int, number_of_regions, units.N)
        for (i, region) in enumerate(region_names)
            
            # Find all the demand that is in this region
            dem_ids_in_region = dem_info.id_dem[findall(dem_info.id_bus .== region)]
            # Sum up the demand for all the demand ids in this region
            demand_values_rounded[i, :] = round.(Int, sum.(eachrow(df_filtered[!, string.(dem_ids_in_region)])))
        end

        return Regions{units.N,units.P}( #timesteps, units
            string.(region_names), # Names
            reshape(demand_values_rounded, number_of_regions, units.N) # Load (in MW) for each region and timestep
            )
    end

end