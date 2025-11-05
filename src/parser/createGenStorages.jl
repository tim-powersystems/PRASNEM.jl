function createGenStorages(storages_input_file, generators_input_file, timeseries_folder, units, regions_selected, start_dt, end_dt; 
    scenario=2, gentech_excluded=[], alias_excluded=[], investment_filter=[0], active_filter=[1], 
    default_hydro_values=Dict{String, Any}())



    # Now use the functions to get hydro generators from the generator and the storages data
    gens, gen_region_attribution = createGenerators(generators_input_file, timeseries_folder, units, regions_selected, start_dt, end_dt; 
        scenario=scenario, gentech_excluded=gentech_excluded, alias_excluded=alias_excluded, 
        investment_filter=investment_filter, active_filter=active_filter, get_only_hydro=true)

    stors, stors_region_attribution = createStorages(storages_input_file, timeseries_folder, units, regions_selected, start_dt, end_dt;
        scenario=scenario, gentech_excluded=gentech_excluded, alias_excluded=alias_excluded, 
        investment_filter=investment_filter, active_filter=active_filter, get_only_hydro=true)

    # =====================================================
    # Collect more information about the objects
    # Collect all the hydro generators
    gen_data = CSV.read(generators_input_file, DataFrame)
    filter!(row -> row[:fuel] == "Hydro", gen_data)
    # And collect all the pumped hydro storages
    stor_data = CSV.read(storages_input_file, DataFrame)
    filter!(row -> row[:tech] == "PS", stor_data)

    # =====================================================
    # Now read in the time-varying data for the genstor objects
    
    # Inflow data (optional)
    inflows_file = joinpath(timeseries_folder, "Generator_inflow_sched.csv")
    if isfile(inflows_file)
        #println("Inflow timeseries file found for hydro generators/storages.")
        timeseries_inflows = read_timeseries_file(inflows_file)
        inflows_filtered = PISP.filterSortTimeseriesData(timeseries_inflows, units, start_dt, end_dt, DataFrame(), "", scenario, "id_gen", gen_data.id_gen[:])
    else
        inflows_filtered = DataFrame()
        println("WARNING: No inflow timeseries file found for hydro generators/storages. Using default static inflow values: ", default_hydro_values["default_static_inflow"]*100, " % of injection capacity for all hydro generators-storages.")
    end


    # Add here the timevarying data for the storages if available in the future
    # Currently, there is no time-varying data for the storages in the model
    
    # Filter for hydro year is deactivated for now
    #if hydro_year in unique(timeseries_inflows.hydro_year)
        # If the provided hydro year is available, filter by it
    #    filter!(row -> row[:hydro_year] == hydro_year, timeseries_inflows)
    #else
    #    error("Provided hydro year $hydro_year not found in inflow data! Available years are: $(unique(timeseries_inflows.hydro_year))")
    #end
    #filter!(row -> row[:hydro_year] == hydro_year, timeseries_inflows)
    

    # =====================================================
    # Now combine both dataframes

    # Add a new genstor ID column to the combined data
    gen_data[!, "id_genstor"] = gen_data.id_gen
    stor_data[!, "id_genstor"] = stor_data.id_ess
    combined_data_detailed = vcat(gen_data, stor_data, cols=:union)

    # Ensure that there are no duplicate IDs in the combined data (i.e. no overlapping IDs between generators and storages)
    if nrow(combined_data_detailed) != length(unique(combined_data_detailed.id_genstor))
        error("There are duplicate IDs in the combined generator and storage data! Please ensure that all IDs are unique across both datasets OR adjust code in PRASNEM.jl accordingly.")
    end

    combined_data = DataFrame(longid=vcat(gens.names, stors.names))
    combined_data[!, "id_genstor"] = parse.(Int, [split(s, "_")[1] for s in combined_data[!, "longid"]])
    combined_data = leftjoin(combined_data, combined_data_detailed, on="id_genstor")

    # And sort by region/bus id
    sort!(combined_data, [:id_bus])
    combined_data.id_ascending .= 1:nrow(combined_data)

    # =====================================================

    # Initialise the data for the GenStor Object
    num_generatorstorages = nrow(combined_data)
    inflow_data = zeros(Int, num_generatorstorages, units.N)
    chargecapacity_data = zeros(Int, num_generatorstorages, units.N)
    dischargecapacity_data = zeros(Int, num_generatorstorages, units.N)
    energycapacity_data = zeros(Int, num_generatorstorages, units.N)
    gridwithdrawalcapacity_data = zeros(Int, num_generatorstorages, units.N)
    gridinjectioncapacity_data = zeros(Int, num_generatorstorages, units.N)
    chargeefficiency_data = zeros(Float64, num_generatorstorages, units.N)
    dischargeefficiency_data = zeros(Float64, num_generatorstorages, units.N)
    carryoverefficiency_data = zeros(Float64, num_generatorstorages, units.N)
    failureprobability_data = zeros(Float64, num_generatorstorages, units.N)
    repairprobability_data = zeros(Float64, num_generatorstorages, units.N)

    # Now iterate through each entry in the combined_data and populate the GenStor Object Data
    for row in eachrow(combined_data)
        idx = findfirst(combined_data.longid .== row.longid)

        if row["tech"] == "PS"
            # If pumped hydro
            idx_stors = findfirst(stors.names .== row.longid)
            # Select the grid charge/discharge capacities as with the storage data
            gridwithdrawalcapacity_data[idx, :] = stors.charge_capacity[idx_stors, :]
            gridinjectioncapacity_data[idx, :] = stors.discharge_capacity[idx_stors, :]
            # Select the energy capacity as with the storage data
            energycapacity_data[idx, :] = stors.energy_capacity[idx_stors, :]
            # Set the efficiencies as in the storage object
            chargeefficiency_data[idx, :] .= stors.charge_efficiency[idx_stors, :]
            dischargeefficiency_data[idx, :] .= stors.discharge_efficiency[idx_stors, :]
            carryoverefficiency_data[idx, :] .= stors.carryover_efficiency[idx_stors, :]
            # Set the failure and repair probabilities
            failureprobability_data[idx, :] .= stors.λ[idx_stors, :]
            repairprobability_data[idx, :] .= stors.μ[idx_stors, :]
        else
            # If run-of-river/reservoir
            idx_gens = findfirst(gens.names .== row.longid)
            # select the grid charge to zero, and the discharge to the capacity
            gridwithdrawalcapacity_data[idx, :] .= 0
            chargeefficiency_data[idx, :] .= 1.0 # Irrelevant
            gridinjectioncapacity_data[idx, :] .= gens.capacity[idx_gens, :]
            if row.tech == "Run-of-River"
                energycapacity_data[idx, :] .= round.(Int, gens.capacity[idx_gens, :] * default_hydro_values["run_of_river_discharge_time"])
                dischargeefficiency_data[idx, :] .= default_hydro_values["run_of_river_discharge_efficiency"]
                carryoverefficiency_data[idx, :] .= default_hydro_values["run_of_river_carryover_efficiency"]
            else # Reservoir
                energycapacity_data[idx, :] .= round.(Int, gens.capacity[idx_gens, :] * default_hydro_values["reservoir_discharge_time"])
                dischargeefficiency_data[idx, :] .= default_hydro_values["reservoir_discharge_efficiency"]
                carryoverefficiency_data[idx, :] .= default_hydro_values["reservoir_carryover_efficiency"]
            end

            # Set the failure and repair probabilities
            failureprobability_data[idx, :] .= gens.λ[idx_gens, :]
            repairprobability_data[idx, :] .= gens.μ[idx_gens, :]
        end

        # Set the inflow data
        if string(row.id_gen) in names(inflows_filtered)
            inflow_data[idx, :] = round.(Int, inflows_filtered[!, string(row.id_gen)])
        else
            inflow_data[idx, :] .= round.(Int, gridinjectioncapacity_data[idx, :] * default_hydro_values["default_static_inflow"])
        end

        # For all objects: Set the charging capacity as grid withdrawal + inflows for each timestep (to always allow for the inflows) - this charge capacity doesnt matter too much
        chargecapacity_data[idx, :] .= gridwithdrawalcapacity_data[idx, :] .+ inflow_data[idx, :]
        dischargecapacity_data[idx, :] .= gridinjectioncapacity_data[idx, :]

    end


    # And finally attribute the genstors to the regions
    if regions_selected == []
        # If copperplate model is desired, all generators are in the same region
        genstor_region_attribution = [1:num_generatorstorages]
    else
        # The combined data already includes the individual units, so no need to repeat bus_ids
        genstor_region_attribution = get_unit_region_assignment(regions_selected, combined_data.id_bus)
    end


    return GeneratorStorages{units.N,units.L,units.T,units.P,units.E}(
        combined_data[!, "longid"], # name
        Vector{String}(combined_data[!, "tech"]), # categories
        chargecapacity_data, # charge capacity
        dischargecapacity_data, # discharge capacity
        energycapacity_data, # energy capacity
        chargeefficiency_data, # charge efficiency
        dischargeefficiency_data, # discharge efficiency
        carryoverefficiency_data, # carryover efficiency
        inflow_data, # inflows
        gridwithdrawalcapacity_data, # grid withdrawal capacity
        gridinjectioncapacity_data, # grid injection capacity
        failureprobability_data, # lambda
        repairprobability_data), # mu
        genstor_region_attribution

end