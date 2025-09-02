function createGenStorages(storages_input_file, generators_input_file, timeseries_folder, units, regions_selected, start_dt, end_dt; 
    scenario=2, gentech_excluded=[], alias_excluded=[], investment_filter=[0], active_filter=[1])


    # Collect all the hydro generators
    gen_data = CSV.read(generators_input_file, DataFrame)
    filter!(row -> row[:fuel] == "Hydro", gen_data)
    # And collect all the pumped hydro storages
    stor_data = CSV.read(storages_input_file, DataFrame)
    filter!(row -> row[:tech] == "PS", stor_data)

    # Now combine both dataframes
    combined_data = vcat(gen_data, stor_data, cols=:union)
    # And sort by region/bus id
    sort!(combined_data, [:bus_id])

    # Now read in all the timevarying data
    









    return combined_data
end