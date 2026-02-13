function createStorages(storages_input_file, timeseries_folder, units, regions_selected, start_dt, end_dt; 
    scenario=2, gentech_excluded=[], alias_excluded=[], investment_filter=[0], active_filter=[1], get_only_hydro=false)


    # ================================ Static data =========================================
    stor_data = CSV.read(storages_input_file, DataFrame)


    # Filter only the BESS objects (-> Pumped storage is modelled as genstor)
    if get_only_hydro
        # if option is selected, return only the hydro-storage (for GenStor)
        filter!(row -> row.tech == "PS", stor_data)
    else
        filter!(row -> !(row.tech == "PS"), stor_data)
    end

    # Filter the selected regions
    if !isempty(regions_selected)
        filter!(row -> row.id_bus in regions_selected, stor_data)
    end

    # Filter the gentech and alias exclusions
    filter!(row -> !(row[:alias] in alias_excluded), stor_data)
    filter!(row -> !(row[:tech] in gentech_excluded), stor_data)

    # Filter the investment and active status
    filter!(row -> row[:investment] in investment_filter, stor_data)
    filter!(row -> row[:active] in active_filter, stor_data)

    # Calculate the failure and repair probabilities of the generators from the FOR/MTTR (Formulas: mu = 1/MTTR and lam = FOR / (MTTR * (1 - FOR)))
    if "mttrfull" in names(stor_data)
        stor_data.mttrfull = coalesce.(stor_data.mttrfull, 1.0) # Replace missing mttrfull with 1.0
        stor_data.mttrfull[findall(stor_data.mttrfull .== 0.0)] .= 1.0 # Replace any 0.0 mttrfull with 1.0 to avoid division by zero
    else
        println("No mttrfull column found in storage data. Setting mttrfull to 1.0 for all storages.")
        stor_data.mttrfull = fill(1.0, nrow(stor_data)) # If no mttrfull column, set to 1.0
    end
    if "fullout" in names(stor_data)
        stor_data.fullout = coalesce.(stor_data.fullout, 0.0) # Replace missing fullout with 0.0
    else
        println("No fullout column found in storage data. Setting fullout to 0.0 for all storages.")
        stor_data.fullout = fill(0.0, nrow(stor_data)) # If no fullout column, set to 0.0
    end
    stor_data.repairrate .= 1 ./ stor_data.mttrfull
    stor_data.failurerate .= stor_data.fullout ./ (stor_data.mttrfull .* (1 .- stor_data.fullout))


    # Now sort by id_bus and add new counter
    sort!(stor_data, :id_bus)
    stor_data.id_ascending .= 1:nrow(stor_data)

    # ================================ Timeseries data =========================================
    # Time-varying parameters:
    # n - number of units
    # pmax - discharging capacity
    # emax - energy capacity
    # lmax - charging capacity

    # Get the timeseries data of the n storages
    timeseries_file_n = joinpath(timeseries_folder, "ESS_n_sched.csv")
    n = read_timeseries_file(timeseries_file_n)
    timeseries_n = PISP.filterSortTimeseriesData(n, units, start_dt, end_dt, stor_data, "n", scenario, "id_ess", stor_data.id_ess[:])

    # Update the maximum n in the stor_data dataframe
    timeseries_n_ess_ids = parse.(Int, names(select(timeseries_n, Not(:date))))
    timeseries_n_max = maximum.(eachcol(select(timeseries_n, Not(:date))))
    for i in eachindex(timeseries_n_ess_ids)
        stor_data[stor_data.id_ess .== timeseries_n_ess_ids[i], :n].= timeseries_n_max[i]
    end

    # Get the timeseries data of the storage capacities - DISCHARGE
    timeseries_file_pmax = joinpath(timeseries_folder, "ESS_pmax_sched.csv")
    pmax = read_timeseries_file(timeseries_file_pmax)
    timeseries_pmax = PISP.filterSortTimeseriesData(pmax, units, start_dt, end_dt, stor_data, "pmax", scenario, "id_ess", stor_data.id_ess[:])
    timeseries_pmax_ess_ids = parse.(Int, names(select(timeseries_pmax, Not(:date))))

    # Get the timeseries data of the storage capacities - CHARGE
    timeseries_file_lmax = joinpath(timeseries_folder, "ESS_lmax_sched.csv")
    lmax = read_timeseries_file(timeseries_file_lmax)
    timeseries_lmax = PISP.filterSortTimeseriesData(lmax, units, start_dt, end_dt, stor_data, "lmax", scenario, "id_ess", stor_data.id_ess[:])
    timeseries_lmax_ess_ids = parse.(Int, names(select(timeseries_lmax, Not(:date))))

    # Get the timeseries data of the storage capacities - ENERGY
    timeseries_file_emax = joinpath(timeseries_folder, "ESS_emax_sched.csv")
    emax = read_timeseries_file(timeseries_file_emax)
    timeseries_emax = PISP.filterSortTimeseriesData(emax, units, start_dt, end_dt, stor_data, "emax", scenario, "id_ess", stor_data.id_ess[:])
    timeseries_emax_ess_ids = parse.(Int, names(select(timeseries_emax, Not(:date))))

    # =================================== Create PRAS Object ==================================================

    Nstors = sum(stor_data.n)
    stors_names = Vector{String}(undef, Nstors)
    stors_categories = Vector{String}(undef, Nstors)
    stors_chargecap = zeros(Int, Nstors, units.N)
    stors_dischcap = zeros(Int, Nstors, units.N)
    stors_energycap = zeros(Int, Nstors, units.N)
    stors_chargeeff = zeros(Float64, Nstors, units.N)
    stors_disch_eff = zeros(Float64, Nstors, units.N)
    stors_carryover_eff = zeros(Float64, Nstors, units.N)
    stors_failurerate = zeros(Float64, Nstors, units.N)
    stors_repairrate = zeros(Float64, Nstors, units.N)

    # Iterate through each row
    stor_index_counter = 1
    for row in eachrow(stor_data)
        # If there are no units of this storage in the relevant time: continue
        if row.n == 0
            continue
        end

        # Do for each unit of the storage
        for i in 1:row.n
            stors_names[stor_index_counter] = "$(row.id_ess)_" * string(i)
            stors_categories[stor_index_counter] = row.tech
            if row.name[1:3] == "VPP"
                stors_categories[stor_index_counter] = "VPP"
            end

            # lmax - charging capacity
            if (row.id_ess in timeseries_lmax_ess_ids)
                # If there is time-varying data available
                stors_chargecap[stor_index_counter, :] = round.(Int, timeseries_lmax[!, "$(row.id_ess)"])
            else
                stors_chargecap[stor_index_counter, :] = fill(round(Int, row[:lmax]), units.N)
            end

            # pmax - discharging capacity
            if (row.id_ess in timeseries_pmax_ess_ids)
                # If there is time-varying data available
                stors_dischcap[stor_index_counter, :] = round.(Int, timeseries_pmax[!, "$(row.id_ess)"])
            else
                stors_dischcap[stor_index_counter, :] = fill(round(Int, row[:pmax]), units.N)
            end

            # emax - energy storage capacity
            if (row.id_ess in timeseries_emax_ess_ids)
                # If there is time-varying data available
                stors_energycap[stor_index_counter, :] = round.(Int, timeseries_emax[!, "$(row.id_ess)"])
            else
                stors_energycap[stor_index_counter, :] = fill(round(Int, row[:emax]), units.N)
            end

            # Efficiencies (could add time-varying efficiencies here if needed)
            stors_chargeeff[stor_index_counter, :] = fill(row.ch_eff, units.N)
            stors_disch_eff[stor_index_counter, :] = fill(row.dch_eff, units.N)
            stors_carryover_eff[stor_index_counter, :] = fill(1.0, units.N) # This is an assumption here!

            # Could add a time-varying failure and repair rate here if needed
            stors_failurerate[stor_index_counter, :] = fill(row.failurerate, units.N)
            stors_repairrate[stor_index_counter, :] = fill(row.repairrate, units.N)
            stor_index_counter += 1
        end

        # Now adjust if the number of units is changing over time
        if (row.id_ess in timeseries_n_ess_ids)
            # Check if the number of units changes over time
            if (minimum(timeseries_n[!, "$(row.id_ess)"]) < row.n)
                println("Note: The number of units for storage id_ess $(row.id_ess) changes over time. Adjusting the availability accordingly.")
                # Now iterate through the different unique levels of n
                unique_n = unique(timeseries_n[!, "$(row.id_ess)"])
                sort!(unique_n)
                for un in unique_n
                    # Find all the timesteps when the number of units is equal to un
                    timeseries_n_indices = findall(timeseries_n[!, "$(row.id_ess)"] .== un)
                    # Set all the units that are not on at these time-steps to zero
                    stors_dischcap[stor_index_counter - row.n + un:stor_index_counter - 1, timeseries_n_indices] .*= 0
                    stors_chargecap[stor_index_counter - row.n + un:stor_index_counter - 1, timeseries_n_indices] .*= 0
                    stors_energycap[stor_index_counter - row.n + un:stor_index_counter - 1, timeseries_n_indices] .*= 0
                end
            end
        end
    end

    # Calculate the gen_region_attribution
    if regions_selected == []
        # If copperplate model is desired, all generators are in the same region
        stors_region_attribution = [1:nrow(stor_data)]
    else
        all_bus_ids = vcat([fill(row.id_bus, row.n) for row in eachrow(stor_data)]...)
        stors_region_attribution = get_unit_region_assignment(regions_selected, all_bus_ids)
    end

    return Storages{units.N,units.L,units.T,units.P,units.E}(
        stors_names, # Names
        stors_categories, # Categories
        stors_chargecap, # Charge capacity
        stors_dischcap, # Discharge capacity
        stors_energycap, # Energy capacity
        stors_chargeeff, # Charge efficiency
        stors_disch_eff, # Discharge efficiency
        stors_carryover_eff, # Carryover efficiency
        stors_failurerate, # Failure rate
        stors_repairrate # Repair rate
    ), stors_region_attribution
end