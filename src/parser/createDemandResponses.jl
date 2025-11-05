function createDemandResponses(der_input_file, demand_input_file, timeseries_folder, units, regions_selected, start_dt, end_dt; 
        scenario=2, gentech_excluded=[], alias_excluded=[], investment_filter=[false], active_filter=[true])
        """
        Assumptions taken for now (implicitly):
                - n=1 for all drs (constant) - i.e. not read in from file
                -
        """


        # Read in all the metadata of the DR and demand (to match to buses)
        dr_info = CSV.read(der_input_file, DataFrame)
        dem_info = CSV.read(demand_input_file, DataFrame)
        

        # Filter the data
        filter!(row -> row.investment in investment_filter, dr_info)
        filter!(row -> row.active in active_filter, dr_info)


        # match the id_dem to the id_bus in dem_info
        dr_info = leftjoin(dr_info, dem_info[:, [:id_dem, :id_bus]], on=:id_dem => :id_dem)
        # Filter only the demand responses in the selected regions
        if regions_selected != []
            filter!(row -> row[:id_bus] in regions_selected, dr_info)
        end

        # Exclude unwanted gentech_excluded and alias_excluded
        filter!(row -> !(row[:tech] in gentech_excluded), dr_info)
        filter!(row -> !(row[:name] in alias_excluded), dr_info)

        # Sort the demand responses by the region/bus id_bus
        sort!(dr_info, :id_bus)

        # Create a new ID for the demand responses with the new sorting
        dr_info.id_ascending .= 1:nrow(dr_info)

        # Get the timeseries data of the demand responses
        timeseries_dr_file = joinpath(timeseries_folder, "DER_pred_sched.csv")
        dr_full = read_timeseries_file(timeseries_dr_file)
        dr_timeseries = PISP.filterSortTimeseriesData(dr_full, units, start_dt, end_dt, dr_info, "pred_max", scenario, "id_der", dr_info.id_der[:])

        # Create a "duration" column to artificially create a hierarchy between the dr_types
        dr_info.duration = zeros(Int, nrow(dr_info))
        for i in 1:nrow(dr_info)
            if dr_info.cost_red[i] == 7500.0
                dr_info.duration[i] = 1  
            elseif dr_info.cost_red[i] == 1000.0
                dr_info.duration[i] = 2
            elseif dr_info.cost_red[i] == 500.0
                dr_info.duration[i] = 3
        else
                dr_info.duration[i] = 4
            end
        end

        # Now create the DemandResponses object
        number_of_drs = nrow(dr_info)
        dr_names = string.(dr_info.id_der)
        dr_types = Vector{String}(dr_info.tech[:])
        dr_borrow_power_capacity = zeros(Int, number_of_drs, units.N)
        dr_load_energy_capacity = zeros(Int, number_of_drs, units.N)
        dr_payback_window = zeros(Int, number_of_drs, units.N)
        for i in 1:number_of_drs
            dr_id = dr_info.id_der[i]
            dr_borrow_power_capacity[i, :] = round.(Int, dr_timeseries[!, string(dr_id)])
            dr_payback_window[i, :] .= round(Int, dr_info.duration[i])
            dr_load_energy_capacity[i, :] .= 1000 #dr_borrow_power_capacity[i, :]  # Energy capacity = power capacity * duration (in hours)
        end

        dr_region_attribution = get_unit_region_assignment(regions_selected, dr_info.id_bus[:])

        return DemandResponses{units.N,units.L,units.T,units.P,units.E}(
                dr_names,
                dr_types,
                dr_borrow_power_capacity,   # borrow power capacity
                fill(0, number_of_drs, units.N),   # payback power capacity
                dr_load_energy_capacity,  # load energy capacity
                fill(-1.0, number_of_drs, units.N),  # -100% borrowed energy interest => Energy doesn't need to be paid back
                dr_payback_window,    # 6 hour allowable payback time periods (irrelevant)
                fill(0.0, number_of_drs, units.N),  # 0% outage probability
                fill(1.0, number_of_drs, units.N),  # 100% recovery probability
                ), dr_region_attribution

end