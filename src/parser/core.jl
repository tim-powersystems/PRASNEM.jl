
include("./createRegions.jl")
include("./createGenerators.jl")
include("./createStorages.jl")
include("./createGenStorages.jl")
include("./createLinesInterfaces.jl")
include("./utils.jl") # this includes helper functions such as get_unit_region_assignment


function create_pras_file(start_dt::DateTime, end_dt::DateTime, input_folder, output_folder,
    timeseries_folder::String;
    regions_selected=collect(1:12), # can select a subset or set to empty for copperplate []
    scenario::Int=2, # 1 is progressive change, 2 is step change, 3 is green hydrogen exports
    gentech_excluded=[], # can exclude a subset or set to empty for all []
    alias_excluded=[], # can select a subset or set to empty for all []
    investment_filter=[0], # only include assets that are not selected for investment
    active_filter=[1] # only include active assets
    )
    
    timezone = tz"Australia/Sydney"
    timestep_count = Int(round((Dates.value(end_dt - start_dt) / (60*60*1000)) + 1)) # Dates.value returns ms

    units = (N = timestep_count, # Number of timesteps
        L = 1, # Timestep Length
        T = Hour, # Time unit
        P = MW, # Power Unit
        E = MWh # Energy Unit
    )

    # Hydro default parameters
    default_hydro_values = Dict{String, Any}()
    default_hydro_values["run_of_river_discharge_time"] = 0 # This is the amount of timesteps that the run-of-river can discharge at full capacity (e.g. 0 = no storage)
    default_hydro_values["reservoir_discharge_time"] = 24 * 30 # This is the amount of timesteps that the reservoir can discharge at full capacity (e.g. 24*30 = 30 days at hourly resolution)
    default_hydro_values["run_of_river_discharge_efficiency"] = 1.0
    default_hydro_values["run_of_river_carryover_efficiency"] = 1.0 # Irrelevant when discharge time is zero anyway
    default_hydro_values["reservoir_discharge_efficiency"] = 1.0
    default_hydro_values["reservoir_carryover_efficiency"] = 1.0
    default_hydro_values["default_static_inflow"] = 0.0 # As a factor of the grid injection capacity (e.g. 0.5 means that the inflow is 50% of the grid injection capacity) - this mostly applies to PHSP

    

    # ---- SETUP INPUT AND OUTPUT FILES ----

    # Get the current working directory
    #current_working_directory = pwd()

    # Define the path to the input and output folder (CAN CHANGE AS NEEDED)
    #input_folder = joinpath(current_working_directory, "src", "sample_data", "nem12")
    #output_folder = joinpath(current_working_directory, "src", "sample_data", "pras_files")

    # Define input and output file names (CAN CHANGE AS NEEDED, JUST ENSURE THEY ARE THE SAME FORMAT)
    generator_input_filename = "Generator.csv"
    storages_input_filename = "ESS.csv"
    lines_input_filename = "Line.csv"
    
    # Create output filename
    output_name = string(Date(start_dt), "_to_", Date(end_dt), "_s", scenario, "_")
    if isempty(regions_selected)
        output_name *= "copperplate"
    else
        output_name *= prod(string.(regions_selected)) * "_regions"
    end

    if !isempty(gentech_excluded)
        output_name *= "_no_" * join(gentech_excluded, "_")
    end

    if !isempty(alias_excluded)
        if !isempty(gentech_excluded)
            output_name *= "_" 
        else
            output_name *= "_no_"
        end
        output_name *= join(alias_excluded, "_")
    end

    output_filename = string(output_name, ".pras")

    # Define input and output full file paths
    generators_input_file = joinpath(input_folder, generator_input_filename)
    timeseries_folder = joinpath(input_folder, timeseries_folder)
    storages_input_file = joinpath(input_folder, storages_input_filename)
    lines_input_file = joinpath(input_folder, lines_input_filename)
    output_filepath = joinpath(output_folder, output_filename)


    # ---- CREATE PRAS FILE ----
    println("Creating PRAS file from input data...")
    println("Scenario: ", scenario)
    println("Regions: ", if isempty(regions_selected) "All" else regions_selected end )
    println("Timeseries: ", start_dt,": ", units.T(units.L), " :", end_dt)
    println("Excluded tech/fuel: ", if isempty(gentech_excluded) "None" else gentech_excluded end)
    println("Excluded aliases: ", if isempty(alias_excluded) "None" else alias_excluded end)
    println("Input folder: ", timeseries_folder)

    regions = createRegions(timeseries_folder, units, regions_selected, scenario, start_dt, end_dt)
    gens, gen_region_attribution = createGenerators(generators_input_file, timeseries_folder, units, regions_selected, start_dt, end_dt; 
        scenario=scenario, gentech_excluded=gentech_excluded, alias_excluded=alias_excluded, investment_filter=investment_filter, active_filter=active_filter)
    stors, stors_region_attribution = createStorages(storages_input_file, timeseries_folder, units, regions_selected, start_dt, end_dt; 
        scenario=scenario, gentech_excluded=gentech_excluded, alias_excluded=alias_excluded, investment_filter=investment_filter, active_filter=active_filter)
    genstors, genstors_region_attribution = createGenStorages(storages_input_file, generators_input_file, timeseries_folder, units, regions_selected, start_dt, end_dt; 
        scenario=scenario, gentech_excluded=gentech_excluded, alias_excluded=alias_excluded, investment_filter=investment_filter, active_filter=active_filter, 
        default_hydro_values=default_hydro_values)

    if length(regions_selected) <= 1
        # If copperplate model is desired
        sys = SystemModel(gens, stors, genstors, ZonedDateTime(start_dt, timezone):units.T(units.L):ZonedDateTime(end_dt, timezone), regions.load[1, :])
    else 
        # Else, get the lines and interfaces for the relevant regions
        lines, interfaces, line_interface_attribution = createLinesInterfaces(lines_input_file, timeseries_folder, units, regions_selected, start_dt, end_dt; 
            scenario=scenario, gentech_excluded=gentech_excluded, alias_excluded=alias_excluded, investment_filter=investment_filter, active_filter=active_filter)

        # Create the system model
        sys = SystemModel(
                    regions, interfaces,
                    gens, gen_region_attribution, 
                    stors, stors_region_attribution,
                    genstors, genstors_region_attribution,
                    lines, line_interface_attribution,
                    ZonedDateTime(start_dt, timezone):units.T(units.L):ZonedDateTime(end_dt, timezone) # Timestamps
                    )
    end 

    savemodel(sys, output_filepath)
    println("PRAS file created at: ", output_filepath)

    return sys


end