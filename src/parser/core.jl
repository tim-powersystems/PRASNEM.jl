
include("./createRegions.jl")
include("./createGenerators.jl")
include("./createStorages.jl")
include("./createGenStorages.jl")
include("./createLinesInterfaces.jl")
include("./createDemandResponses.jl")
include("./utils.jl") # this includes helper functions such as get_unit_region_assignment
include("./scenario_assumptions.jl") # This includes helper function for scenario assumptions, such as when lines should be added

function create_pras_system(start_dt::DateTime, end_dt::DateTime, input_folder::String, timeseries_folder::String;
    output_folder::String="",
    regions_selected::Union{Vector{Any}, Vector{Int}}=collect(1:12), # can select a subset or set to empty for copperplate []
    scenario::Int=2, # 1 is progressive change, 2 is step change, 3 is green hydrogen exports
    gentech_excluded::Union{Vector{Any}, Vector{String}}=[], # can exclude a subset or set to empty for all []
    alias_excluded::Union{Vector{Any}, Vector{String}}=[], # can select a subset or set to empty for all []
    investment_filter::Union{Vector{Any}, Vector{Int}}=[0], # only include assets that are not selected for investment
    active_filter::Union{Vector{Any}, Vector{Int}}=[1], # only include active assets
    line_alias_included::Union{Vector{Any}, Vector{String}}=[], # can include specific lines to be included even if they would be filtered out due to investment/active status
    weather_folder::String="" # Can specify a specific folder with the timeseries weather data that should be used (no capacities are read from here, just normalised timeseries)
    )
    """
    Create a PRAS file from NEM12 input data.

    Optional parameters:
    - output_folder (default=""): Folder to save the PRAS file. If empty, the PRAS file is not saved.
    - regions_selected (default=collect(1:12)): Array of region IDs to include. Empty array for copperplate model.
    - scenario (default=2): ISP scenario to use (1: progressive change, 2: step change, 3: green hydrogen exports).
    - gentech_excluded (default=[]): Array of generator technologies to exclude.
    - alias_excluded (default=[]): Array of generator/storage aliases to exclude.
    - investment_filter (default=[0]): Array indicating which assets to include based on investment status.
    - active_filter (default=[1]): Array indicating which assets to include based on their active status.
    - line_alias_included (default=[]): Array of line aliases to include even if they would be filtered out due to investment/active status.
    - weather_folder (default=""): Folder with weather data timeseries to use (no capacities are read from here, just normalised timeseries for demand, VRE and DSP).
    
    Some further notes:
    - If a different weather folder is specified: 
        - Demand timeseries are read from there instead of the main timeseries folder (normalised to match max demand target year).
        - Generator pmax timeseries for renewables (solar, wind, hydro) are read from there instead of the main timeseries folder (normalised to match max generation target year).
        - Storage genstorage inflow timeseries are read from there instead of the main timeseries folder (not normalised).
        - Demand response timeseries are read from there instead of the main timeseries folder (normalised to match max capacity target year).
    
    """
    # Run function to check if parameters are valid
    check_parameters(regions_selected, weather_folder, start_dt, end_dt)
    
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
    default_hydro_values["reservoir_discharge_time"] = 200 # This is the amount of timesteps that the reservoir can discharge at full capacity. A rough estimate of the tasmanian system is 200 hours = ~8 days of full discharge
    default_hydro_values["reservoir_initial_soc"] = 0.5 # As a factor of the maximum energy capacity (e.g. 0.5 means 50% initial SOC)
    default_hydro_values["pumped_hydro_initial_soc"] = 0.5 # As a factor of the maximum energy capacity (e.g. 0.5 means 50% initial SOC)
    default_hydro_values["run_of_river_discharge_efficiency"] = 1.0
    default_hydro_values["run_of_river_carryover_efficiency"] = 1.0 # Irrelevant when discharge time is zero anyway
    default_hydro_values["reservoir_discharge_efficiency"] = 1.0
    default_hydro_values["reservoir_carryover_efficiency"] = 1.0
    default_hydro_values["default_static_inflow"] = 0.0 # As a factor of the grid injection capacity (e.g. 0.5 means that the inflow is 50% of the grid injection capacity) - this mostly applies to PHSP

    if weather_folder == timeseries_folder
        weather_folder = "" # Skip updating weather folder if it's the same as the main timeseries folder
    end

    # ---- SETUP INPUT AND OUTPUT FILES ----

    # Get the current working directory
    #current_working_directory = pwd()

    # Define the path to the input and output folder (CAN CHANGE AS NEEDED)
    #input_folder = joinpath(current_working_directory, "src", "sample_data", "nem12")
    #output_folder = joinpath(current_working_directory, "src", "sample_data", "pras_files")

    # Define input and output file names (CAN CHANGE AS NEEDED, JUST ENSURE THEY ARE THE SAME FORMAT)
    demand_input_filename = "Demand.csv"
    generator_input_filename = "Generator.csv"
    storages_input_filename = "ESS.csv"
    lines_input_filename = "Line.csv"
    demandresponses_input_filename = "DER.csv"

    # Define input and output full file paths
    demand_input_file = joinpath(input_folder, demand_input_filename)
    generators_input_file = joinpath(input_folder, generator_input_filename)
    timeseries_folder = joinpath(input_folder, timeseries_folder)
    storages_input_file = joinpath(input_folder, storages_input_filename)
    lines_input_file = joinpath(input_folder, lines_input_filename)
    demandresponses_input_file = joinpath(input_folder, demandresponses_input_filename)
    
    # Create output filename
    output_name = string(Date(start_dt), "_to_", Date(end_dt), "_s", scenario, "_")
    if isempty(regions_selected)
        output_name *= "copperplate"
    elseif length(regions_selected) == 12
        output_name *= "all_regions"
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

    if !isempty(line_alias_included) && !isempty(regions_selected)
        lines = CSV.read(lines_input_file, DataFrame)
        line_ids = [lines.id_lin[findfirst(==(alias), lines.alias)] for alias in line_alias_included]
        sort!(line_ids)
        output_name *= "_incl_line_" * join(line_ids, "_")
    end

    if !isempty(weather_folder)
        output_name *= "_w-" * splitext(basename(weather_folder))[1]
    end

    output_filename = string(output_name, ".pras")


    output_filepath = joinpath(output_folder, output_filename)

    if !(output_folder == "") &&  ispath(output_filepath)
        @info("Output file already exists: $output_filepath")
        println("Loading file...")
        sys = SystemModel(output_filepath)
        sys.attrs["case"] = output_name # ensure case name is set
        return sys
    end

    # ---- CREATE PRAS FILE ----
    @info("Creating PRAS file from input data...")
    println("Scenario: ", scenario)
    println("Regions: ", if isempty(regions_selected) "All" else regions_selected end )
    println("Timeseries: ", start_dt,": ", units.T(units.L), " :", end_dt)
    println("Excluded tech/fuel: ", if isempty(gentech_excluded) "None" else gentech_excluded end)
    println("Excluded aliases: ", if isempty(alias_excluded) "None" else alias_excluded end)
    println("Additional lines included: ", if isempty(line_alias_included) "None" else line_alias_included end)
    println("Input folder: ", timeseries_folder)
    if !(weather_folder == "")
        println("Using different weather year from folder: ", weather_folder)
    end
    println("")

    regions = createRegions(demand_input_file, timeseries_folder, units, regions_selected, start_dt, end_dt; scenario=scenario, weather_folder=weather_folder)
    gens, gen_region_attribution = createGenerators(generators_input_file, timeseries_folder, units, regions_selected, start_dt, end_dt; 
        scenario=scenario, gentech_excluded=gentech_excluded, alias_excluded=alias_excluded, investment_filter=investment_filter, active_filter=active_filter)
    stors, stors_region_attribution = createStorages(storages_input_file, timeseries_folder, units, regions_selected, start_dt, end_dt; 
        scenario=scenario, gentech_excluded=gentech_excluded, alias_excluded=alias_excluded, investment_filter=investment_filter, active_filter=active_filter)
    genstors, genstors_region_attribution = createGenStorages(storages_input_file, generators_input_file, timeseries_folder, units, regions_selected, start_dt, end_dt; 
        scenario=scenario, gentech_excluded=gentech_excluded, alias_excluded=alias_excluded, investment_filter=investment_filter, active_filter=active_filter, 
        default_hydro_values=default_hydro_values, weather_folder=weather_folder)
    demandresponses, dr_region_attribution = createDemandResponses(demandresponses_input_file, demand_input_file, timeseries_folder, units, regions_selected, start_dt, end_dt; 
        scenario=scenario, gentech_excluded=gentech_excluded, alias_excluded=alias_excluded, investment_filter=investment_filter, active_filter=active_filter, weather_folder=weather_folder)

    if length(regions_selected) <= 1
        # If copperplate model is desired
        sys = SystemModel(gens, stors, genstors, demandresponses, ZonedDateTime(start_dt, timezone):units.T(units.L):ZonedDateTime(end_dt, timezone), regions.load[1, :], Dict("case"=>output_name) ) # save case name as attribute
    else 
        # Else, get the lines and interfaces for the relevant regions
        lines, interfaces, line_interface_attribution = createLinesInterfaces(lines_input_file, timeseries_folder, units, regions_selected, start_dt, end_dt; 
            scenario=scenario, gentech_excluded=gentech_excluded, alias_excluded=alias_excluded, investment_filter=investment_filter, active_filter=active_filter, line_alias_included=line_alias_included)

        # Create the system model
        sys = SystemModel(
                    regions, interfaces,
                    gens, gen_region_attribution, 
                    stors, stors_region_attribution,
                    genstors, genstors_region_attribution,
                    demandresponses, dr_region_attribution,
                    lines, line_interface_attribution,
                    ZonedDateTime(start_dt, timezone):units.T(units.L):ZonedDateTime(end_dt, timezone), # Timestamps
                    Dict("case"=>output_name) # save case name as attribute
                    )
    end
    if !(output_folder == "")
        if !ispath(output_folder)
            mkpath(output_folder)
        end
        savemodel(sys, output_filepath)
        @info("PRAS file created at: $output_filepath")  
    else
        @info("PRAS system successfully created.")
    end

    return sys


end

# Add former name for backcompatibility
function create_pras_file(start_dt::DateTime, end_dt::DateTime, input_folder::String, timeseries_folder::String;
    output_folder::String="",
    regions_selected=collect(1:12), # can select a subset or set to empty for copperplate []
    scenario::Int=2, # 1 is progressive change, 2 is step change, 3 is green hydrogen exports
    gentech_excluded=[], # can exclude a subset or set to empty for all []
    alias_excluded=[], # can select a subset or set to empty for all []
    investment_filter=[0], # only include assets that are not selected for investment
    active_filter=[1], # only include active assets
    line_alias_included=[] # can include specific lines to be included even if they would be filtered out due to investment/active status
    )
    """
    See `create_pras_system` for details.
    """
    return create_pras_system(start_dt, end_dt, input_folder, timeseries_folder;
        output_folder=output_folder,
        regions_selected=regions_selected,
        scenario=scenario,
        gentech_excluded=gentech_excluded,
        alias_excluded=alias_excluded,
        investment_filter=investment_filter,
        active_filter=active_filter,
        line_alias_included=line_alias_included)
end