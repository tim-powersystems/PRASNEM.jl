function createGenStorages(storages_input_file, generators_input_file, timeseries_folder, units, regions_selected, start_dt, end_dt; 
    scenario=2, gentech_excluded=[], alias_excluded=[], investment_filter=[0], active_filter=[1], 
    default_hydro_values=Dict{String, Any}(),
    weather_folder="")



    # Now use the functions to get hydro generators from the generator and the storages data
    gens,  = createGenerators(generators_input_file, timeseries_folder, units, regions_selected, start_dt, end_dt; 
        scenario=scenario, gentech_excluded=gentech_excluded, alias_excluded=alias_excluded, 
        investment_filter=investment_filter, active_filter=active_filter, get_only_hydro=true)

    stors,  = createStorages(storages_input_file, timeseries_folder, units, regions_selected, start_dt, end_dt;
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
    if weather_folder != "" # If a weather folder is provided, read from there
        inflows_gen_file = joinpath(weather_folder, "Generator_inflow_sched.csv")
        inflows_stor_file = joinpath(weather_folder, "ESS_inflow_sched.csv")
    else 
        inflows_gen_file = joinpath(timeseries_folder, "Generator_inflow_sched.csv")
        inflows_stor_file = joinpath(timeseries_folder, "ESS_inflow_sched.csv")
    end

    if isfile(inflows_gen_file)
        #println("Inflow timeseries file found for hydro generators/storages.")
        timeseries_inflows = read_timeseries_file(inflows_gen_file)
        if weather_folder != ""
            timeseries_inflows = update_dates(timeseries_inflows, year(start_dt)) # To match the year of the main timeseries and adjust for leap years
        end
        inflows_gen_filtered = PISP.filterSortTimeseriesData(timeseries_inflows, units, start_dt, end_dt, DataFrame(), "", scenario, "id_gen", gen_data.id_gen[:])
    else
        inflows_gen_filtered = DataFrame()
        println("WARNING: No inflow timeseries file found for hydro generators. Using default static inflow values: ", default_hydro_values["default_static_inflow"]*100, " % of injection capacity for all hydro generators (run-of-river, reservoir).")
    end

    if isfile(inflows_stor_file)
        timeseries_inflows_stor = read_timeseries_file(inflows_stor_file)
        if weather_folder != ""
            timeseries_inflows_stor = update_dates(timeseries_inflows_stor, year(start_dt)) # To match the year of the main timeseries and adjust for leap years
        end
        inflows_stor_filtered = PISP.filterSortTimeseriesData(timeseries_inflows_stor, units, start_dt, end_dt, DataFrame(), "", scenario, "id_ess", stor_data.id_ess[:])
    else
        inflows_stor_filtered = DataFrame()
        println("WARNING: No inflow timeseries file found for hydro storages. Using default static inflow values: ", default_hydro_values["default_static_inflow"]*100, " % of injection capacity for all hydro storages (pumped hydro).")
    end

    # Add here the timevarying data for the storages if available in the future
    # Currently, there is no time-varying (capacity / efficiency) data for the storages in the model
    

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

        # Set the inflow data and initial state of charge (via "initial soc" inflow - this should be changed a a later time)
        if string(row.id_gen) in names(inflows_gen_filtered)
            inflow_data[idx, :] = round.(Int, inflows_gen_filtered[!, string(row.id_gen)])
            inflow_data[idx, 1] += round.(Int, default_hydro_values["reservoir_initial_soc"] * energycapacity_data[idx, 1])
        elseif string(row.id_ess) in names(inflows_stor_filtered)
            inflow_data[idx, :] = round.(Int, inflows_stor_filtered[!, string(row.id_ess)])
            inflow_data[idx, 1] += round.(Int, default_hydro_values["pumped_hydro_initial_soc"] * energycapacity_data[idx, 1])
        else
            inflow_data[idx, :] .= round.(Int, gridinjectioncapacity_data[idx, :] * default_hydro_values["default_static_inflow"])
        end

        # For all objects: Set the charging capacity as grid withdrawal + inflows for each timestep (to always allow for the inflows)
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