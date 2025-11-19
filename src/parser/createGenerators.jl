function createGenerators(generators_input_file, timeseries_folder, units, regions_selected, start_dt, end_dt; 
        scenario=2, gentech_excluded=[], alias_excluded=[], investment_filter=[0], active_filter=[1], get_only_hydro=false, 
        weather_folder="", update_gentech_with_weather_year=["Solar","Wind", "Hydro"])

    # Read in all the metadata of the generators
    gen_info = CSV.read(generators_input_file, DataFrame)

    # Filter all the hydro generators => They are genstor objects
    if get_only_hydro
        filter!(row -> row[:fuel] == "Hydro", gen_info)
    else
        filter!(row -> !(row[:fuel] == "Hydro"), gen_info)
    end

    # Filter the data
    filter!(row -> row.investment in investment_filter, gen_info)
    filter!(row -> row.active in active_filter, gen_info)

    # Filter only the generators in the selected regions
    if regions_selected != []
        filter!(row -> row[:id_bus] in regions_selected, gen_info)
    end

    # Filter the file for only the relevant selected generators
    filter!(row -> !(row[:alias] in alias_excluded), gen_info)
    filter!(row -> !(row[:tech] in gentech_excluded), gen_info)
    filter!(row -> !(row[:fuel] in gentech_excluded), gen_info)

    # Sort the generators by the region/bus id_gen
    sort!(gen_info, :id_bus)
    # Create a new ID for the generators with the new sorting
    gen_info.id_ascending .= 1:nrow(gen_info)

    # Calculate the failure and repair probabilities of the generators from the FOR/MTTR (Formulas: mu = 1/MTTR and lam = FOR / (MTTR * (1 - FOR)))
    if "mttrfull" in names(gen_info)
        gen_info.mttrfull = coalesce.(gen_info.mttrfull, 1.0) # Replace missing mttrfull with 1.0
        gen_info.mttrfull[findall(gen_info.mttrfull .== 0.0)] .= 1.0 # Replace any 0.0 mttrfull with 1.0 to avoid division by zero
    else
        println("No mttrfull column found in generator data. Setting mttrfull to 1.0 for all generators.")
        gen_info.mttrfull = fill(1.0, nrow(gen_info)) # If no mttrfull column, set to 1.0
    end
    if "fullout" in names(gen_info)
        gen_info.fullout = coalesce.(gen_info.fullout, 0.0) # Replace missing fullout with 0.0
    else
        println("No fullout column found in generator data. Setting fullout to 0.0 for all generators.")
        gen_info.fullout = fill(0.0, nrow(gen_info)) # If no fullout column, set to 0.0
    end
    gen_info.repairrate .= 1 ./ gen_info.mttrfull
    gen_info.failurerate .= gen_info.fullout ./ (gen_info.mttrfull .* (1 .- gen_info.fullout))

    # Get the timeseries data of the n generators
    timeseries_file_n = joinpath(timeseries_folder, "Generator_n_sched.csv")
    n = read_timeseries_file(timeseries_file_n)
    timeseries_n = PISP.filterSortTimeseriesData(n, units, start_dt, end_dt, gen_info, "n", scenario, "id_gen", gen_info.id_gen[:])
    
    # Update the maximum n in the gen_info dataframe
    timeseries_n_gen_ids = parse.(Int, names(select(timeseries_n, Not(:date))))
    timeseries_n_max = maximum.(eachcol(select(timeseries_n, Not(:date))))
    for i in eachindex(timeseries_n_gen_ids)
        gen_info[gen_info.id_gen .== timeseries_n_gen_ids[i], :n].= timeseries_n_max[i]
    end

    # Get the timeseries data of the generator capacities (for renewables)
    timeseries_file_pmax = joinpath(timeseries_folder, "Generator_pmax_sched.csv")
    pmax = read_timeseries_file(timeseries_file_pmax)
    timeseries_pmax = PISP.filterSortTimeseriesData(pmax, units, start_dt, end_dt, gen_info, "pmax", scenario, "id_gen", gen_info.id_gen[:])
    timeseries_pmax_gen_ids = parse.(Int, names(select(timeseries_pmax, Not(:date))))

    # If a different weather year is specified, read and filter that file instead
    if weather_folder != ""
        timeseries_file_pmax_weather = joinpath(weather_folder, "Generator_pmax_sched.csv")
        pmax_weather = read_timeseries_file(timeseries_file_pmax_weather)
        
        # Select only the relevant generators to update
        update_gentech_with_weather_year_ids = [row[:id_gen] for row in eachrow(gen_info) if row[:fuel] in update_gentech_with_weather_year]
        filter(row -> row[:id_gen] in update_gentech_with_weather_year_ids, pmax_weather)
        
        pmax_weather = update_dates(pmax_weather, year(start_dt)) # To match the year of the main timeseries and adjust for leap years
        df_filtered_weather = PISP.filterSortTimeseriesData(pmax_weather, units, start_dt, end_dt, gen_info, "pmax", scenario, "id_gen", gen_info.id_gen[:])

        timeseries_pmax = update_with_weather_year(timeseries_pmax, df_filtered_weather; timeseries_name="Generator Pmax")
    end


    # Convert the timeseries data into the PRAS format
    Ngens = sum(gen_info.n)
    gens_names = Vector{String}(undef, Ngens)
    gens_categories = Vector{String}(undef, Ngens)
    gens_cap = zeros(Int, Ngens, units.N)
    gens_failurerate = zeros(Float64, Ngens, units.N)
    gens_repairrate = zeros(Float64, Ngens, units.N)
    # Iterate through each row
    gen_index_counter = 1
    for row in eachrow(gen_info)
        # If there are no units of this generator in the relevant time: continue
        if row.n == 0
            continue
        end

        # Do for each unit of the generator
        for i in 1:row.n
            gens_names[gen_index_counter] = "$(row.id_gen)_" * string(i)
            gens_categories[gen_index_counter] = row.tech

            if (row.id_gen in timeseries_pmax_gen_ids)
                # If there is time-varying data available
                gens_cap[gen_index_counter, :] = round.(Int, timeseries_pmax[!, "$(row.id_gen)"])
            else
                gens_cap[gen_index_counter, :] = fill(round(Int, row[:capacity]), units.N)
            end
            # Could add a time-varying failure and repair rate here if needed
            gens_failurerate[gen_index_counter, :] = fill(row.failurerate, units.N)
            gens_repairrate[gen_index_counter, :] = fill(row.repairrate, units.N)
            gen_index_counter += 1
        end

        if (row.id_gen in timeseries_n_gen_ids)
            # Check if the number of units changes over time
            if (minimum(timeseries_n[!, "$(row.id_gen)"]) < row.n)
                println("Note: The number of units for generator id_gen $(row.id_gen) changes over time. Adjusting the availability accordingly.")
                # Now iterate through the different unique levels of n
                unique_n = unique(timeseries_n[!, "$(row.id_gen)"])
                sort!(unique_n)
                for un in unique_n
                    # Find all the timesteps when the number of units is equal to un
                    timeseries_n_indices = findall(timeseries_n[!, "$(row.id_gen)"] .== un)
                    # Set all the generators that are not on at these time-steps to zero
                    gens_cap[gen_index_counter - row.n + un:gen_index_counter - 1, timeseries_n_indices] .*= 0
                end
            end
        end
    end

    # ====================== Gen-Region Attribution ===========================
    # Calculate the gen_region_attribution
    if regions_selected == []
        # If copperplate model is desired, all generators are in the same region
        gen_region_attribution = [1:Ngens]
    else
        all_bus_ids = vcat([fill(row.id_bus, row.n) for row in eachrow(gen_info)]...)
        gen_region_attribution = get_unit_region_assignment(regions_selected, all_bus_ids)
    end

    return Generators{units.N, units.L, units.T, units.P}(
        gens_names, # Names
        gens_categories, # Categories
        gens_cap, # capacity (MW) for each generator and timestep
        gens_failurerate, # failure rate (λ) for each generator and timestep
        gens_repairrate # repair rate (μ) for each generator and timestep
    ), gen_region_attribution


end