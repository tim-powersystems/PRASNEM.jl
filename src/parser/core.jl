
include("./scenario_assumptions.jl") # This includes helper function for scenario assumptions, such as when lines should be added
include("./createRegions.jl")
include("./createGenerators.jl")
include("./createStorages.jl")
include("./createGenStorages.jl")
include("./createLinesInterfaces.jl")
include("./createDemandResponses.jl")
include("./utils.jl") # this includes helper functions such as get_unit_region_assignment

function create_pras_system(start_dt::DateTime, end_dt::DateTime, input_folder::String, timeseries_folder::String;
    output_folder::String="",
    regions_selected::Union{Vector{Any}, Vector{Int}}=collect(1:12), # can select a subset or set to empty for copperplate []
    scenario::Int=2, # 1 is progressive change, 2 is step change, 3 is green hydrogen exports
    gentech_excluded::Union{Vector{Any}, Vector{String}}=[], # can exclude a subset or set to empty for all []
    alias_excluded::Union{Vector{Any}, Vector{String}}=[], # can select a subset or set to empty for all []
    investment_filter::Union{Vector{Any}, Vector{Int}}=[0], # only include assets that are not selected for investment
    active_filter::Union{Vector{Any}, Vector{Int}}=[1], # only include active assets
    line_alias_included::Union{Vector{Any}, Vector{String}}=[], # can include specific lines to be included even if they would be filtered out due to investment/active status
    weather_folder::String="", # Can specify a specific folder with the timeseries weather data that should be used (no capacities are read from here, just normalised timeseries)
    DER_parameters=get_DER_parameters(), # Additional parameters for DER (e.g. whether to include EV flexibility or not)
    hydro_parameters=get_hydro_parameters() # Default parameters for hydro generators and genstorages (can be updated based on scenario assumptions)
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
    
    # TimeZones only works until 2038 (see: https://juliatime.github.io/TimeZones.jl/stable/faq/) - therefore use UTC for dates beyond that
    if end_dt > Date(2038)
        timezone = tz"UTC"
    else
        # Set to NEM timezone by default (UTC+10, not winter/summer time, see https://wattclarity.com.au/other-resources/glossary/nem-time/)
        timezone = tz"UTC+10"
    end
    timesteps = ZonedDateTime(start_dt, timezone):Hour(1):ZonedDateTime(end_dt, timezone)

    units = (N = length(timesteps), # Number of timesteps
        L = 1, # Timestep Length
        T = Hour, # Time unit
        P = MW, # Power Unit
        E = MWh # Energy Unit
    )

    # Additional offset for dispatch problem
    #          This is a "cost" that pushes storages, generatorstorages, demandresponses to also charge/discharge from gens further away (i.e. up to 12 hops)
    #          This is only enabled/enforced for the custom PRASCore version, that is available at https://github.com/ARPST-UniMelb/PRAS.jl
    additional_offset_DispatchProblem = 12 

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

    if timeseries_folder[end-3:end] != string(Dates.year(start_dt))
        @warn "The timeseries folder specified does not match the year of the start date. Please ensure that the timeseries data in this folder is appropriate for the desired time period."
    end


    output_filepath = joinpath(output_folder, output_filename)

    if !(output_folder == "") &&  ispath(output_filepath)
        @info("Output file already exists: $output_filepath")
        println("Loading file...")
        sys = SystemModel(output_filepath)
        sys.attrs["case"] = output_name # ensure case name is set
        return sys
    end

    # Print the parameters for the case being created
    der_considered = []
    if DER_parameters["RoofPV"]
        push!(der_considered, "RoofPV")
    else
        push!(alias_excluded, "RoofPV")
    end
    if DER_parameters["DSP_flexibility"]
        push!(der_considered, "DSP")
    else
        push!(gentech_excluded, "DSP")
    end
    if DER_parameters["EV_charge_flexibility"]
        push!(der_considered, "EV (charge flexibility)")
    else
        push!(gentech_excluded, "EV")
    end
    if DER_parameters["VPP_flexibility"]
        push!(der_considered, "VPP")
    else
        push!(gentech_excluded, "VPP")
    end

    # ---- CREATE PRAS FILE ----
    @info("Creating PRAS file from input data...")
    println("Scenario: ", scenario)
    println("Regions: ", if isempty(regions_selected) "All" else regions_selected end )
    println("Timeseries: ", start_dt,": ", units.T(units.L), " :", end_dt)
    println("Excluded tech/fuel: ", if isempty(gentech_excluded) "None" else gentech_excluded end)
    println("Excluded aliases: ", if isempty(alias_excluded) "None" else alias_excluded end)
    println("Additional lines included: ", if isempty(line_alias_included) "None" else line_alias_included end)
    println("DER considered: ", if isempty(der_considered) "None" else der_considered end)
    println("Input folder: ", timeseries_folder)
    if !(weather_folder == "")
        println("Using different weather year from folder: ", weather_folder)
        @warn "Different weather folder is experimental. It is recommended to create the system based on data from different weather trace obtained via PISP."
    end
    println("")

    regions = createRegions(demand_input_file, timeseries_folder, units, regions_selected, start_dt, end_dt; scenario=scenario, weather_folder=weather_folder)
    gens, gen_region_attribution = createGenerators(generators_input_file, timeseries_folder, units, regions_selected, start_dt, end_dt; 
        scenario=scenario, gentech_excluded=gentech_excluded, alias_excluded=alias_excluded, investment_filter=investment_filter, active_filter=active_filter)
    stors, stors_region_attribution = createStorages(storages_input_file, timeseries_folder, units, regions_selected, start_dt, end_dt; 
        scenario=scenario, gentech_excluded=gentech_excluded, alias_excluded=alias_excluded, investment_filter=investment_filter, active_filter=active_filter)
    genstors, genstors_region_attribution = createGenStorages(storages_input_file, generators_input_file, timeseries_folder, units, regions_selected, start_dt, end_dt; 
        scenario=scenario, gentech_excluded=gentech_excluded, alias_excluded=alias_excluded, investment_filter=investment_filter, active_filter=active_filter, 
        hydro_parameters=hydro_parameters, weather_folder=weather_folder)
    demandresponses, dr_region_attribution = createDemandResponses(demandresponses_input_file, demand_input_file, timeseries_folder, units, regions_selected, start_dt, end_dt; 
        scenario=scenario, gentech_excluded=gentech_excluded, alias_excluded=alias_excluded, investment_filter=investment_filter, active_filter=active_filter, weather_folder=weather_folder, DER_parameters=DER_parameters)

    if length(regions_selected) <= 1
        # If copperplate model is desired
        sys = SystemModel(gens, stors, genstors, demandresponses, 
        timesteps, 
        regions.load[1, :], 
        Dict("case"=>output_name) ) # save case name as attribute
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
                    timesteps, # Timestamps
                    Dict("case"=>output_name, "additional_offset_DispatchProblem"=>string(additional_offset_DispatchProblem)) # save case name as attribute, and optional parameter to add additional offset for scheduling problem (only enabled for custom PRAS version that includes this as an option)
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
