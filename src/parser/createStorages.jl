function createStorages(storages_input_file, units, regions_selected; 
    gentech_excluded=gentech_excluded, alias_excluded=alias_excluded, investment_filter=[0], active_filter=[1])

    stor_data = CSV.read(storages_input_file, DataFrame)

    # Filter only the BESS objects (-> Pumped storage is modelled as genstor)
    filter!(row -> row.tech == "BESS", stor_data)

    # Filter the selected regions
    if !isempty(regions_selected)
        filter!(row -> row.region in regions_selected, stor_data)
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

    # Now create the new capacity matrices (all capacity is constant across the time period)
    Nstorage = nrow(stor_data)
    cap_charging = reshape(repeat(round.(Int,stor_data[!,:pmax]), units.N), Nstorage, units.N)
    cap_discharging = reshape(repeat(round.(Int,stor_data[!,:pmax]), units.N), Nstorage, units.N)
    cap_energy = reshape(repeat(round.(Int,stor_data[!,:emax]), units.N), Nstorage, units.N)

    # Create the efficiencies matrices
    eff_charging = reshape(repeat(stor_data[!,:ch_eff], units.N), Nstorage, units.N)
    eff_discharging = reshape(repeat(stor_data[!,:dch_eff], units.N), Nstorage, units.N)
    eff_carryover = reshape(repeat([1.0], units.N*Nstorage), Nstorage, units.N) # carryover efficiency is set to one

    # Create the failure and repair matrices
    stors_failurerate = reshape(repeat(stor_data[!,:failurerate], units.N), Nstorage, units.N)
    stors_repairrate = reshape(repeat(stor_data[!,:repairrate], units.N), Nstorage, units.N)


    # Calculate the gen_region_attribution
    if regions_selected !== []
        # If copperplate model is desired, all generators are in the same region
        stors_region_attribution = [1:nrow(stor_data)]
    else
        stors_groups = groupby(stor_data[!,[:bus_id, :id_ascending]], :bus_id)
        stors_region_attribution = [first(group.id_ascending):last(group.id_ascending) for group in stors_groups]
    end

    return Storages{units.N,units.L,units.T,units.P,units.E}(
        Vector(stor_data[!,:alias]), # Names
        Vector(stor_data[!,:tech]), # Categories
        cap_charging, # Charge capacity
        cap_discharging, # Discharge capacity
        cap_energy, # Energy capacity
        eff_charging, # Charge efficiency
        eff_discharging, # Discharge efficiency
        eff_carryover, # Carryover efficiency
        stors_failurerate, # Failure rate
        stors_repairrate # Repair rate
    ), stors_region_attribution
end