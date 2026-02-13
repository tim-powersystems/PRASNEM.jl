function createDemandResponses(der_input_file, demand_input_file, timeseries_folder, units, regions_selected, start_dt, end_dt; 
        scenario=2, gentech_excluded=[], alias_excluded=[], investment_filter=[false], active_filter=[true], weather_folder="", 
        DER_parameters=Dict(
            "DSP_flexibility"=>false, "DSP_payback_window"=>24, "DSP_interest"=>-1.0, "DSP_max_energy_factor"=>100.0,
            "EV_charge_flexibility"=>false, "EV_payback_window"=>8, "EV_interest"=>0.0, "EV_max_energy_factor"=>100.0)
        )
        """
        Assumptions taken for now (implicitly):
                - n=1 for all drs (constant) - i.e. not read in from file
                -
        """

        # If DSP or EV flexibility is not included, add them to the list of technologies to be excluded
        if !DER_parameters["EV_charge_flexibility"]
            push!(gentech_excluded, "EV")
        end
        if !DER_parameters["DSP_flexibility"]
            push!(gentech_excluded, "DSP")
        end

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

        # If a different weather year is specified, read and filter that file instead
        if weather_folder != ""
            timeseries_dr_file_weather = joinpath(weather_folder, "DER_pred_sched.csv")
            dr_full_weather = read_timeseries_file(timeseries_dr_file_weather)
            dr_full_weather = update_dates(dr_full_weather, year(start_dt)) # To match the year of the main timeseries and adjust for leap years
            dr_timeseries_weather = PISP.filterSortTimeseriesData(dr_full_weather, units, start_dt, end_dt, dr_info, "pred_max", scenario, "id_der", dr_info.id_der[:])

            dr_timeseries = update_with_weather_year(dr_timeseries, dr_timeseries_weather; timeseries_name="DER")
        end

        # Create a "duration" column to artificially create a hierarchy between the dr_types
        dr_info.duration = fill(1, nrow(dr_info))
        dr_info.payback_window = fill(2, nrow(dr_info)) # Default irrelevant
        dr_info.energy_interest = fill(-1.0, nrow(dr_info)) # Default is -100% borrowed energy interest => Energy doesn't need to be paid back
        for i in 1:nrow(dr_info)
            if dr_info.tech[i] == "EV"
                dr_info.duration[i] = DER_parameters["EV_max_energy_factor"]
                dr_info.payback_window[i] = DER_parameters["EV_payback_window"]
                dr_info.energy_interest[i] = DER_parameters["EV_interest"]
            elseif dr_info.tech[i] == "DSP"
                dr_info.duration[i] = DER_parameters["DSP_max_energy_factor"]
                dr_info.payback_window[i] = DER_parameters["DSP_payback_window"]
                dr_info.energy_interest[i] = DER_parameters["DSP_interest"]
            end
        end

        # Now create the DemandResponses object
        number_of_drs = nrow(dr_info)
        dr_names = string.(dr_info.id_der)
        dr_types = Vector{String}(dr_info.tech[:])
        dr_borrow_power_capacity = zeros(Int, number_of_drs, units.N)
        dr_payback_power_capacity = zeros(Int, number_of_drs, units.N) 
        dr_energy_capacity = zeros(Int, number_of_drs, units.N)
        dr_energy_interest = fill(-1.0, number_of_drs, units.N)  # Default is -100% borrowed energy interest => Energy doesn't need to be paid back
        dr_payback_window = zeros(Int, number_of_drs, units.N)
        for i in 1:number_of_drs
            dr_id = dr_info.id_der[i]
            dr_borrow_power_capacity[i, :] = round.(Int, dr_timeseries[!, string(dr_id)])
            dr_payback_power_capacity[i, :] .= dr_borrow_power_capacity[i, :] # Assuming the same power capacity for borrowing and payback for now
            dr_payback_window[i, :] .= round.(Int, dr_info.payback_window[i])
            dr_energy_capacity[i, :] .= round.(Int, dr_borrow_power_capacity[i, :] * dr_info.duration[i]) # Energy capacity = power capacity * duration (in hours)
            dr_energy_interest[i, :] .= dr_info.energy_interest[i]
        end

        dr_region_attribution = get_unit_region_assignment(regions_selected, dr_info.id_bus[:])

        return DemandResponses{units.N,units.L,units.T,units.P,units.E}(
                dr_names,
                dr_types,
                dr_borrow_power_capacity,   # borrow power capacity
                dr_payback_power_capacity,   # payback power capacity
                dr_energy_capacity,  # load energy capacity
                dr_energy_interest,  # energy interest rate (borrowed energy interest) - between -1.0 and 1.0
                dr_payback_window,    # payback window in timesteps
                fill(0.0, number_of_drs, units.N),  # 0% outage probability
                fill(1.0, number_of_drs, units.N),  # 100% recovery probability
                ), dr_region_attribution

end