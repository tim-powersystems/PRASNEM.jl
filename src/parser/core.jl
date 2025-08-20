

include("./filterSortTimestepData.jl")
include("./createRegions.jl")
include("./createLinesInterfaces.jl")


function parse_to_pras_format()

    # ---- CHANGE INPUTS HERE ----

    scenarios = [2]  # 1 is progressive change, 2 is step change, 3 is green hydrogen exports
    dem_ids = [1,2,3,4,5,6,7,8,9,10,11,12] # can remove regions if desired
    gen_ids = [92,93,94,95,96,97,98,99,100,101,102,103,104,105,106,107,108,109,110,111,112,113,114,115,116,117,118,119,120,121,122,123] #can remove timestep generators if desired
    regions_selected = collect(1:12) # can just select a subset or leave empty for copperplate
    
    # Only dates in data are FY25-26, FY30-31, FY35-36, FY40-41 and FY50-51
    start_date = "2030-07-01 00:00:00" #change as needed
    end_date = "2031-06-30 23:00:00" #change as needed

    # Find timestep count
    start_dt = DateTime(start_date, dateformat"yyyy-mm-dd HH:MM:SS")
    end_dt = DateTime(end_date, dateformat"yyyy-mm-dd HH:MM:SS")
    timestep_count = Int(round((Dates.value(end_dt - start_dt) / (60*60*1000)) + 1)) # Dates.value returns ms

    units = (N = timestep_count, # Number of timesteps
        L = 1, # Timestep Length
        T = Hour, # Time unit
        P = MW, # Power Unit
        E = MWh # Energy Unit
    )



    # Hydro inflow inputs
    hydro_reference_year = "Average"
    generator_shares_by_location = Dict(
        "Snowy" => Dict(
            "TUMUT3" => 0.4436, "BLOWERNG" => 0.0197, "UPPTUMUT" => 0.1518, "GUTHEGA" => 0.0148, "MURRAY1" => 0.2341, "MURRAY2" => 0.1360),
        "TAS" => Dict(
            "BASTYAN" => 0.0367, "LI_WY_CA" => 0.0812, "CETHANA" => 0.0390, "DEVILS_G" => 0.0276, "FISHER" => 0.0198, "GORDON" => 0.1985,
            "JBUTTERS" => 0.0662, "LK_ECHO" => 0.0149, "LEM_WIL" => 0.0375, "MACKNTSH" => 0.0367, "MEADOWBK" => 0.0184, "POAT110" => 0.1378,
            "REECE1" => 0.1062, "TARRALEA" => 0.0413, "TREVALLN" => 0.0427, "TRIBUTE" => 0.0380, "TUNGATIN" => 0.0574)
    )

    

    # ---- SETUP INPUT AND OUTPUT FILES ----

    # Get the current working directory
    current_working_directory = pwd()

    # Define the path to the input and output folder (CAN CHANGE AS NEEDED)
    input_folder = joinpath(current_working_directory, "src", "sample_data", "input")
    output_folder = joinpath(current_working_directory, "src", "sample_data", "output", "testing")

    # Define input and output file names (CAN CHANGE AS NEEDED, JUST ENSURE THEY ARE THE SAME FORMAT)
    load_input_filename =  "Demand_load_sched.csv"
    load_output_filename = "filtered_timestep_load.csv"
    generator_input_filename = "_orig_Generator.csv"
    timestep_generator_input_filename = "Generator_pmax_sched.csv"
    timestep_generator_output_filename = "filtered_timestep_generator.csv"
    storages_input_filename = "_orig_ESS.csv"
    generatorstorage_inflows_input_filename = "Hydro_inflow.csv"
    generatorstorage_inflows_output_filename = "calculated_hydro_inflow.csv"
    #interfaces_input_filename = "Interfaces.csv"
    lines_input_filename = "Line.csv"
    hdf5_output_filename = string(Date(start_dt), "_to_", Date(end_dt), "_", number_of_regions, "_regions_nem.pras")

    # Define input and output full file paths
    load_input_file = joinpath(input_folder, load_input_filename)
    load_output_file = joinpath(output_folder, "temp", load_output_filename)
    generator_input_file = joinpath(input_folder, generator_input_filename)
    timestep_generator_input_file = joinpath(input_folder, timestep_generator_input_filename)
    timestep_generator_output_file = joinpath(output_folder, "temp", timestep_generator_output_filename)
    storages_input_file = joinpath(input_folder, storages_input_filename)
    generatorstorage_inflows_input_file = joinpath(input_folder, generatorstorage_inflows_input_filename)
    generatorstorage_inflows_output_file = joinpath(output_folder, "temp", generatorstorage_inflows_output_filename)
    interfaces_input_file = joinpath(input_folder, interfaces_input_filename)
    lines_input_file = joinpath(input_folder, lines_input_filename)
    hdf5_filepath = joinpath(output_folder, hdf5_output_filename)




    # ---- CREATE PRAS FILE ----

    regions = createRegions(load_input_file, units, regions_selected, scenarios, start_dt, end_dt)
    gens = createGenerators(generator_input_file, timestep_generator_input_file, units, regions_selected)
    # stors = 
    # genstors = 

    
    if length(regions_selected) == 0
        # If copperplate model is desired
        
        #TODO: Add the SystemModel creation function here
        sys = SystemModel(gens, stors, genstors, start_dt:units.T(units.L):end_dt, regions.load[1, :])
    else
        
        lines, interfaces, line_interface_assignment = createLinesInterfaces(lines_input_file, units, regions_selected)

        # TODO: Update the SystemModel function here
        sys = SystemModel(
                    regions, interfaces,
                    gens, gen_regions, 
                    stors, stor_regions,
                    genstors, genstor_regions,
                    lines, line_interface_assignment,
                    start_dt:units.T(units.L):end_dt # Timestamps
                    )

    end 

    savemodel(sys, outfile=hdf5_filepath)

    return sys


end