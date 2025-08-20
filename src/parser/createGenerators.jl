function createGenerators(generator_input_file, timestep_generator_input_file, units, regions_selected, investment_filter=[0], active_filter=[1])

    # Read in all the metadata of the generators
    gen_info = CSV.read(generator_input_file, DataFrame)

    # Filter the data
    filter!(row -> row[:investment] in investment_filter && row[:active] in active_filter, gen_info)


    # Filter the timestep generator files
    filter_timestep_generator = FilterSortTimestepData(timestep_generator_input_file)
    filtered_timestep_generator = execute(filter_timestep_generator; output_file=timestep_generator_output_file, scenarios=scenarios, gen_ids=gen_ids, start_dt=start_dt, end_dt=end_dt)


end