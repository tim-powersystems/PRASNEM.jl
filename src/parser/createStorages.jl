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
        filter!(row -> row.bus_id in regions_selected, stor_data)
    end

    # Filter the gentech and alias exclusions
    filter!(row -> !(row[:alias] in alias_excluded), stor_data)
    filter!(row -> !(row[:tech] in gentech_excluded), stor_data)

    # Filter the investment and active status
    filter!(row -> row[:investment] in investment_filter, stor_data)
    filter!(row -> row[:active] in active_filter, stor_data)

    # Calculate the failure and repair probabilities of the generators from the FOR/MTTR (Formulas: mu = 1/MTTR and lam = FOR / (MTTR * (1 - FOR)))
    if "MTTR" in names(stor_data)
        stor_data.MTTR = coalesce.(stor_data.MTTR, 1.0) # Replace missing MTTR with 1.0
    else
        println("No MTTR column found in storage data. Setting MTTR to 1.0 for all storages.")
        stor_data.MTTR = fill(1.0, nrow(stor_data)) # If no MTTR column, set to 1.0
    end
    if "FOR" in names(stor_data)
        stor_data.FOR = coalesce.(stor_data.FOR, 0.0) # Replace missing FOR with 0.0
    else
        println("No FOR column found in storage data. Setting FOR to 0.0 for all storages.")
        stor_data.FOR = fill(0.0, nrow(stor_data)) # If no FOR column, set to 0.0
    end
    stor_data.repairrate .= 1 ./ stor_data.MTTR
    stor_data.failurerate .= stor_data.FOR ./ (stor_data.MTTR .* (1 .- stor_data.FOR))


    # Now sort by bus_id and add new counter
    sort!(stor_data, :bus_id)
    stor_data.id_ascending .= 1:nrow(stor_data)

    # ================================ Timeseries data =========================================
    # Time-varying parameters:
    # n - number of units
    # pmax - discharging capacity
    # emax - energy capacity
    # lmax - charging capacity

    # Get the timeseries data of the n storages
    timeseries_file_n = joinpath(timeseries_folder, "ESS_n_sched.csv")
    n = CSV.read(timeseries_file_n, DataFrame)
    n.date = DateTime.(n.date, dateformat"yyyy-mm-dd HH:MM:SS")
    timeseries_n = PISP.filterSortTimeseriesData(n, units, start_dt, end_dt, stor_data, "n", scenario, "ess_id", stor_data.id[:])

    # Update the maximum n in the stor_data dataframe
    timeseries_n_ess_ids = parse.(Int, names(select(timeseries_n, Not(:date))))
    timeseries_n_max = maximum.(eachcol(select(timeseries_n, Not(:date))))
    for i in eachindex(timeseries_n_ess_ids)
        stor_data[stor_data.id .== timeseries_n_ess_ids[i], :n].= timeseries_n_max[i]
    end

    # Get the timeseries data of the storage capacities - DISCHARGE
    timeseries_file_pmax = joinpath(timeseries_folder, "ESS_pmax_sched.csv")
    pmax = CSV.read(timeseries_file_pmax, DataFrame)
    pmax.date = DateTime.(pmax.date, dateformat"yyyy-mm-dd HH:MM:SS")
    timeseries_pmax = PISP.filterSortTimeseriesData(pmax, units, start_dt, end_dt, stor_data, "pmax", scenario, "ess_id", stor_data.id[:])
    timeseries_pmax_ess_ids = parse.(Int, names(select(timeseries_pmax, Not(:date))))

    # Get the timeseries data of the storage capacities - CHARGE
    timeseries_file_lmax = joinpath(timeseries_folder, "ESS_lmax_sched.csv")
    lmax = CSV.read(timeseries_file_lmax, DataFrame)
    lmax.date = DateTime.(lmax.date, dateformat"yyyy-mm-dd HH:MM:SS")
    timeseries_lmax = PISP.filterSortTimeseriesData(lmax, units, start_dt, end_dt, stor_data, "lmax", scenario, "ess_id", stor_data.id[:])
    timeseries_lmax_ess_ids = parse.(Int, names(select(timeseries_lmax, Not(:date))))

    # Get the timeseries data of the storage capacities - ENERGY
    timeseries_file_emax = joinpath(timeseries_folder, "ESS_emax_sched.csv")
    emax = CSV.read(timeseries_file_emax, DataFrame)
    emax.date = DateTime.(emax.date, dateformat"yyyy-mm-dd HH:MM:SS")
    timeseries_emax = PISP.filterSortTimeseriesData(emax, units, start_dt, end_dt, stor_data, "emax", scenario, "ess_id", stor_data.id[:])
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
            stors_names[stor_index_counter] = "$(row.id)_" * string(i)
            stors_categories[stor_index_counter] = row.tech

            # lmax - charging capacity
            if (row.id in timeseries_lmax_ess_ids)
                # If there is time-varying data available
                stors_chargecap[stor_index_counter, :] = round.(Int, timeseries_lmax[!, "$(row.id)"])
            else
                stors_chargecap[stor_index_counter, :] = fill(round(Int, row[:lmax]), units.N)
            end

            # pmax - discharging capacity
            if (row.id in timeseries_pmax_ess_ids)
                # If there is time-varying data available
                stors_dischcap[stor_index_counter, :] = round.(Int, timeseries_pmax[!, "$(row.id)"])
            else
                stors_dischcap[stor_index_counter, :] = fill(round(Int, row[:pmax]), units.N)
            end

            # emax - energy storage capacity
            if (row.id in timeseries_emax_ess_ids)
                # If there is time-varying data available
                stors_energycap[stor_index_counter, :] = round.(Int, timeseries_emax[!, "$(row.id)"])
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
        if (row.id in timeseries_n_ess_ids)
            # Check if the number of units changes over time
            if (minimum(timeseries_n[!, "$(row.id)"]) < row.n)
                println("Note: The number of units for storage id $(row.id) changes over time. Adjusting the availability accordingly.")
                # Now iterate through the different unique levels of n
                unique_n = unique(timeseries_n[!, "$(row.id)"])
                sort!(unique_n)
                for un in unique_n
                    # Find all the timesteps when the number of units is equal to un
                    timeseries_n_indices = findall(timeseries_n[!, "$(row.id)"] .== un)
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
        all_bus_ids = vcat([fill(row.bus_id, row.n) for row in eachrow(stor_data)]...)
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