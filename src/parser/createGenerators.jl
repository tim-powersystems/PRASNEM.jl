function createGenerators(generator_input_file, timestep_generator_input_file, units, regions_selected, start_dt, end_dt; 
        scenarios=[2], gentech_excluded=[], alias_excluded=[], investment_filter=[0], active_filter=[1])

    # Read in all the metadata of the generators
    gen_info = CSV.read(generator_input_file, DataFrame)

    # Filter all the hydro generators => They are genstor objects
    filter!(row -> !(row[:fuel] == "Hydro"), gen_info)

    # Filter the data
    filter!(row -> row.investment in investment_filter, gen_info)
    filter!(row -> row.active in active_filter, gen_info)

    # Filter only the generators in the selected regions
    if regions_selected != []
        filter!(row -> row[:bus_id] in regions_selected, gen_info)
    end

    # Filter the file for only the relevant selected generators
    filter!(row -> !(row[:alias] in alias_excluded), gen_info)
    filter!(row -> !(row[:tech] in gentech_excluded), gen_info)
    filter!(row -> !(row[:fuel] in gentech_excluded), gen_info)

    # Sort the generators by the region/bus id
    sort!(gen_info, :bus_id)
    # Create a new ID for the generators with the new sorting
    gen_info.id_ascending .= 1:nrow(gen_info)

    # Calculate the failure and repair probabilities of the generators from the FOR/MTTR (Formulas: mu = 1/MTTR and lam = FOR / (MTTR * (1 - FOR)))
    if "MTTR" in names(gen_info)
        gen_info.MTTR = coalesce.(gen_info.MTTR, 1.0) # Replace missing MTTR with 1.0
    else
        gen_info.MTTR = fill(1.0, nrow(gen_info)) # If no MTTR column, set to 1.0
    end
    if "FOR" in names(gen_info)
        gen_info.FOR = coalesce.(gen_info.FOR, 0.0) # Replace missing FOR with 0.0
    else
        gen_info.FOR = fill(0.0, nrow(gen_info)) # If no FOR column, set to 0.0
    end
    gen_info.repairrate .= 1 ./ gen_info.MTTR
    gen_info.failurerate .= gen_info.FOR ./ (gen_info.MTTR .* (1 .- gen_info.FOR))

    # Get the timeseries only for those generators for the relevant time
    filter_timestep_generator = FilterSortTimestepData(timestep_generator_input_file)
    filtered_timestep_generator = execute(filter_timestep_generator; scenarios=scenarios, gen_ids=gen_info.id[:], start_dt=start_dt, end_dt=end_dt)

    
    # Convert the timeseries data into the PRAS format
    gens_cap = zeros(Int, length(gen_info.id), units.N)
    gens_failurerate = zeros(Float64, length(gen_info.id), units.N)
    gens_repairrate = zeros(Float64, length(gen_info.id), units.N)
    for i in 1:nrow(gen_info)
        row = gen_info[i, :]
        time_data = filtered_timestep_generator[filtered_timestep_generator.gen_id .== row.id, :]
        if isempty(time_data)
            # If there is no time-varying data available: Use the registered capacity of all the units
            gens_cap[i, :] = fill(round(Int,row[:capacity] .* row[:n]), units.N)
        else
            if length(time_data.date) != units.N
                println("Mismatch in timestep count for generator ID $(row.id)")
            end
            gens_cap[i, :] = round.(Int, time_data.value)
        end

        gens_failurerate[i, :] = fill(row.failurerate, units.N)
        gens_repairrate[i, :] = fill(row.repairrate, units.N)

    end

    # Calculate the gen_region_attribution
    if regions_selected !== []
        # If copperplate model is desired, all generators are in the same region
        gen_region_attribution = [1:nrow(gen_info)]
    else
        gen_groups = groupby(gen_info[!,[:bus_id, :id_ascending]], :bus_id)
        gen_region_attribution = [first(group.id_ascending):last(group.id_ascending) for group in gen_groups]
    end

    return Generators{units.N, units.L, units.T, units.P}(
        Vector(gen_info[!, :alias]), # Names
        Vector(gen_info[!, :tech]), # Categories
        gens_cap, # capacity (MW) for each generator and timestep
        gens_failurerate, # failure rate (λ) for each generator and timestep
        gens_repairrate # repair rate (μ) for each generator and timestep
    ), gen_region_attribution


end