function createRegions(load_input_file, units, region_names::Union{Vector{Int}, Vector{Any},UnitRange{Int64}}=[], scenarios::Union{Nothing, Vector{Int}}=nothing, start_dt::Union{Nothing, DateTime}=nothing, end_dt::Union{Nothing, DateTime}=nothing)


    # Read and filter the timestep load file
    filter_timestep_load = FilterSortTimestepData(load_input_file)
    df_filtered = execute(filter_timestep_load; scenarios=scenarios, dem_ids=collect(region_names), start_dt=start_dt, end_dt=end_dt)

    number_of_regions = length(region_names)

    if number_of_regions == 0

        # Sum up all the demand
        grouped = combine(groupby(df_filtered, :date), :value => sum => :demand_sum)

        # Check if the number of timesteps is less than expected
        if length(grouped.demand_sum) < units.N
            println("WARNING: Fewer timesteps in the load data than expected. Padding with zeros.")
            # If there are fewer timesteps than expected, pad with zeros
            demand_values_rounded = vcat(round.(Int, grouped.demand_sum), zeros(Int, units.N - length(grouped.demand_sum)))
        else
            demand_values_rounded = round.(Int, grouped.demand_sum)
        end

        return Regions{units.N,units.P}( #timesteps, units
            ["All"], # Names
            reshape(demand_values_rounded, 1, units.N) # Load (in MW) for the single region and all timesteps
        )
    else

        demand_values_rounded = zeros(Int, number_of_regions, units.N)
        for (i, region) in enumerate(region_names)
            if length(df_filtered[df_filtered.dem_id .== region, :value]) < units.N
                println("WARNING: Fewer timesteps in the load data than expected for region: ", region)
            end
            demand_values_rounded[i, :] = round.(Int, df_filtered[df_filtered.dem_id .== region, :value])
        end


        return Regions{units.N,units.P}( #timesteps, units
            string.(region_names), # Names
            reshape(demand_values_rounded, number_of_regions, units.N) # Load (in MW) for each region and timestep
            )
    end

end