function createLinesInterfaces(lines_input_file, timeseries_folder, units, regions_selected, start_dt, end_dt; 
    scenario=2, gentech_excluded=[], alias_excluded=[], investment_filter=[0], active_filter=[1])
    """
    Create line and interface data structures from the input lines file.

    Note the optional filters here:
    - `investment_filter`: Filter lines by investment status (default is [0], meaning only existing)
    - `active_filter`: Filter lines by active status (default is [1], meaning only active lines are included)
    - `hvdc_aliases`: List of HVDC line aliases to be used for categorization (for PRAS structure, but not essential)

    """

    # Read in the lines file
    line_data = CSV.read(lines_input_file, DataFrame)

    # Filter the relevant lines (only if not empty)
    if regions_selected != []
        filter!(row -> row.bus_a_id in regions_selected, line_data)
        filter!(row -> row.bus_b_id in regions_selected, line_data)
    end

    # Filter the investment and active columns
    filter!(row -> row.investment in investment_filter, line_data)
    filter!(row -> row.active in active_filter, line_data)

    # Exclude gentech or alias if provided
    filter!(row -> !(row[:alias] in alias_excluded), line_data)
    filter!(row -> !(row[:tech] in gentech_excluded), line_data)

    # Sort by 'from' and 'to' columns (create helper columns first to sort by lowest to highest bus id!)
    line_data[!, :lower_bus_id] = min.(line_data.bus_a_id, line_data.bus_b_id)
    line_data[!, :higher_bus_id] = max.(line_data.bus_a_id, line_data.bus_b_id)
    sort!(line_data, [:lower_bus_id, :higher_bus_id])

    # For the line-interface assignment, create a new ID with the new sorting
    line_data.id_ascending .= 1:nrow(line_data)

    # Calculate the failure and repair rates
    if "mttrfull" in names(line_data)
        line_data.mttrfull = coalesce.(line_data.mttrfull, 1.0) # Replace missing mttrfull with 1.0
    else
        println("No mttrfull column found in line data. Setting mttrfull to 1.0 for all lines.")
        line_data.mttrfull = fill(1.0, nrow(line_data)) # If no mttrfull column, set to 1.0
    end
    if "fullout" in names(line_data)
        line_data.fullout = coalesce.(line_data.fullout, 0.0) # Replace missing fullout with 0.0
    else
        println("No fullout column found in line data. Setting fullout to 0.0 for all lines.")
        line_data.fullout = fill(0.0, nrow(line_data)) # If no fullout column, set to 0.0
    end
    line_data.repair_rate .= 1 ./ line_data.mttrfull
    line_data.failure_rate .= line_data.fullout ./ (line_data.mttrfull .* (1 .- line_data.fullout))

    # Get the timevarying data
    timeseries_tmax_file = joinpath(timeseries_folder, "line_tmax_sched.csv")
    tmax = CSV.read(timeseries_tmax_file, DataFrame)
    tmax.date = DateTime.(tmax.date, dateformat"yyyy-mm-dd HH:MM:SS")
    timeseries_tmax = PISP.filterSortTimeseriesData(tmax, units, start_dt, end_dt, line_data, "tmax", scenario, "lin_id", line_data.id[:])
    timeseries_tmax_lin_ids = parse.(Int, names(select(timeseries_tmax, Not(:date))))

    timeseries_tmin_file = joinpath(timeseries_folder, "line_tmin_sched.csv")
    tmin = CSV.read(timeseries_tmin_file, DataFrame)
    tmin.date = DateTime.(tmin.date, dateformat"yyyy-mm-dd HH:MM:SS")
    timeseries_tmin = PISP.filterSortTimeseriesData(tmin, units, start_dt, end_dt, line_data, "tmin", scenario, "lin_id", line_data.id[:])
    timeseries_tmin_lin_ids = parse.(Int, names(select(timeseries_tmin, Not(:date))))

    # Interpolate the line capacity to all the timesteps
    N_lines = sum(line_data.n)
    line_names = Vector{String}(undef, N_lines)
    line_categories = Vector{String}(undef, N_lines)
    cap_line_forward = zeros(Int, N_lines, units.N)
    cap_line_backward = zeros(Int, N_lines, units.N)
    line_failure_rate = zeros(Float64, N_lines, units.N)
    line_repair_rate = zeros(Float64, N_lines, units.N)
    # helper vectors
    line_bus_from_final = zeros(Int, N_lines)
    line_bus_to_final = zeros(Int, N_lines)

    # Iterate through each row
    line_index_counter = 1
    for row in eachrow(line_data)
        # If there are no lines in the relevant time: continue
        if row.n == 0
            continue
        end

        # Go through each line 
        for i in 1:row.n
            # These are always the same - independent of direction
            line_names[line_index_counter] = "$(row.id)_" * string(i)
            line_categories[line_index_counter] = row.tech
            line_failure_rate[line_index_counter, :] .= row.failure_rate
            line_repair_rate[line_index_counter, :] .= row.repair_rate

            # Check if already in correct direction (from lower to higher bus id)
            if row.lower_bus_id == row.bus_a_id
                # First the details of this line
                line_bus_from_final[line_index_counter] = row.bus_a_id
                line_bus_to_final[line_index_counter] = row.bus_b_id

                # Then add the time-varying data
                if (row.id in timeseries_tmax_lin_ids)
                    # If there is time-varying data available
                    cap_line_forward[line_index_counter, :] = round.(Int,timeseries_tmax[!, string(row.id)][:])
                else
                    cap_line_forward[line_index_counter, :] = fill(round(Int, row[:tmax]), units.N)
                end

                if (row.id in timeseries_tmin_lin_ids)
                    # If there is time-varying data available
                    cap_line_backward[line_index_counter, :] = round.(Int,timeseries_tmin[!, string(row.id)][:])
                else
                    cap_line_backward[line_index_counter, :] = fill(round(Int, row[:tmin]), units.N)
                end
        
            else # if lower_bus_id is bus_b_id
                
                # First the details of this line (now swapped!!)
                line_bus_from_final[line_index_counter] = row.bus_b_id
                line_bus_to_final[line_index_counter] = row.bus_a_id

                # Then add the time-varying data (swap forward and backward)
                if (row.id in timeseries_tmax_lin_ids)
                    # If there is time-varying data available
                    cap_line_backward[line_index_counter, :] = round.(Int,timeseries_tmax[!, string(row.id)][:])
                else
                    cap_line_backward[line_index_counter, :] = fill(round(Int, row[:tmax]), units.N)
                end

                if (row.id in timeseries_tmin_lin_ids)
                    # If there is time-varying data available
                    cap_line_forward[line_index_counter, :] = round.(Int,timeseries_tmin[!, string(row.id)][:])
                else
                    cap_line_forward[line_index_counter, :] = fill(round(Int, row[:tmin]), units.N)
                end

            end # end of switch if lower_bus_id

            line_index_counter += 1
        end
        
    end

    # ========================== Interfaces ===============================
    # Now aggregate the lines to get the interfaces
    line_details = DataFrame(id_ascending = 1:N_lines , idlong = line_names, bus_from = line_bus_from_final, bus_to = line_bus_to_final)
    line_groups = groupby(line_details, [:bus_from, :bus_to])

    N_interfaces = length(line_groups)
    interface_bus_from = zeros(Int, N_interfaces)
    interface_bus_to = zeros(Int, N_interfaces)
    interface_cap_forward = zeros(Int, N_interfaces, units.N)
    interface_cap_backward = zeros(Int, N_interfaces, units.N)
    for (i, group) in enumerate(line_groups)
        #println("Creating interface between region $(first(group.bus_a_id)) and $(first(group.bus_b_id)) with $(nrow(group)) lines.")
        interface_bus_from[i] = first(group.bus_from)
        interface_bus_to[i] = first(group.bus_to)
        idx_lines = group.id_ascending
        interface_cap_forward[i, :] = sum(cap_line_forward[idx_lines, :], dims=1)
        interface_cap_backward[i, :] = sum(cap_line_backward[idx_lines, :], dims=1)
    end

    # ========================== Line-Interface-Assignments ===============================
    # Create the line-interface assignment
    
    # Add the interface ids to the line_details dataframe
    line_details[!, :interface_id] = zeros(Int, N_lines)
    for (i, group) in enumerate(line_groups)
        idx_lines = group.id_ascending
        line_details.interface_id[idx_lines] .= i
    end
    # Now calculate the line-interface assignment
    line_interface_assignment = get_unit_region_assignment(unique(line_details.interface_id), line_details.interface_id)



    return Lines{units.N,units.L,units.T,units.P}(
        line_names, # Names
        line_categories, # Categories
        cap_line_forward, # forward capacity (MW) for each line and timestep
        cap_line_backward, # reverse capacity (MW) for each line and timestep
        line_failure_rate, # failure rate (λ) for each line and timestep
        line_repair_rate # repair rate (μ) for each line and timestep
    ), Interfaces{units.N,units.P}( # timesteps, units
        interface_bus_from, interface_bus_to, # from, to
        interface_cap_forward, interface_cap_backward
    ), line_interface_assignment
end