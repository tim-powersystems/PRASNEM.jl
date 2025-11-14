function createLinesInterfaces(lines_input_file, timeseries_folder, units, regions_selected, start_dt, end_dt; 
    scenario=2, gentech_excluded=[], alias_excluded=[], investment_filter=[0], active_filter=[1], line_alias_included=[])
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
        filter!(row -> row.id_bus_from in regions_selected, line_data)
        filter!(row -> row.id_bus_to in regions_selected, line_data)
    end

    if !isempty(line_alias_included)
        # Check if all the specific lines to include exist between the selected regions
        line_alias_not_found = setdiff(line_alias_included, line_data.alias)
        if !isempty(line_alias_not_found)
            println("WARNING: Couldn't find lines $line_alias_not_found between the selected regions! Check for spelling and/or region selection.")
        end
        # Include specific lines even if they would be filtered out
        filter!(row -> (row.alias in line_alias_included) || (row.investment in investment_filter && row.active in active_filter), line_data)
    else
        # Just apply the normal filters
        filter!(row -> (row.investment in investment_filter && row.active in active_filter), line_data)
    end

    # Exclude gentech or alias if provided and relevant
    filter!(row -> !(row[:alias] in alias_excluded), line_data)
    filter!(row -> !(row[:tech] in gentech_excluded), line_data)

    # Now, we need to update the bus_ids in the lines to match the PRAS region IDs (which might be different from the original bus IDs if less regions are selected)
    bus_id_mapping = Dict{Int, Int}()
    for i in eachindex(regions_selected)
        original_id = regions_selected[i]
        bus_id_mapping[original_id] = i
    end

    # Update the bus ids in the line data
    line_data.id_bus_from_original = copy(line_data.id_bus_from) # keep original for reference
    line_data.id_bus_to_original = copy(line_data.id_bus_to)     # keep original for reference
    line_data.id_bus_from = [bus_id_mapping[id] for id in line_data.id_bus_from]
    line_data.id_bus_to = [bus_id_mapping[id] for id in line_data.id_bus_to]

    # Sort by 'from' and 'to' columns (create helper columns first to sort by lowest to highest bus id!)
    line_data[!, :lower_bus_id] = min.(line_data.id_bus_from, line_data.id_bus_to)
    line_data[!, :higher_bus_id] = max.(line_data.id_bus_from, line_data.id_bus_to)
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
    tmax = read_timeseries_file(timeseries_tmax_file)
    timeseries_tmax = PISP.filterSortTimeseriesData(tmax, units, start_dt, end_dt, line_data, "tmax", scenario, "id_lin", line_data.id_lin[:])
    timeseries_tmax_lin_ids = parse.(Int, names(select(timeseries_tmax, Not(:date))))

    timeseries_tmin_file = joinpath(timeseries_folder, "line_tmin_sched.csv")
    tmin = read_timeseries_file(timeseries_tmin_file)
    timeseries_tmin = PISP.filterSortTimeseriesData(tmin, units, start_dt, end_dt, line_data, "tmin", scenario, "id_lin", line_data.id_lin[:])
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
            line_names[line_index_counter] = "$(row.id_lin)_" * string(i)
            line_categories[line_index_counter] = row.tech
            line_failure_rate[line_index_counter, :] .= row.failure_rate
            line_repair_rate[line_index_counter, :] .= row.repair_rate

            # Check if already in correct direction (from lower to higher bus id_lin)
            if row.lower_bus_id == row.id_bus_from
                # First the details of this line
                line_bus_from_final[line_index_counter] = row.id_bus_from
                line_bus_to_final[line_index_counter] = row.id_bus_to

                # Then add the time-varying data
                if (row.id_lin in timeseries_tmax_lin_ids)
                    # If there is time-varying data available
                    cap_line_forward[line_index_counter, :] = round.(Int,timeseries_tmax[!, string(row.id_lin)][:])
                else
                    cap_line_forward[line_index_counter, :] = fill(round(Int, row[:tmax]), units.N)
                end

                if (row.id_lin in timeseries_tmin_lin_ids)
                    # If there is time-varying data available
                    cap_line_backward[line_index_counter, :] = round.(Int,timeseries_tmin[!, string(row.id_lin)][:])
                else
                    cap_line_backward[line_index_counter, :] = fill(round(Int, row[:tmin]), units.N)
                end
        
            else # if lower_bus_id is id_bus_to
                
                # First the details of this line (now swapped!!)
                line_bus_from_final[line_index_counter] = row.id_bus_to
                line_bus_to_final[line_index_counter] = row.id_bus_from

                # Then add the time-varying data (swap forward and backward)
                if (row.id_lin in timeseries_tmax_lin_ids)
                    # If there is time-varying data available
                    cap_line_backward[line_index_counter, :] = round.(Int,timeseries_tmax[!, string(row.id_lin)][:])
                else
                    cap_line_backward[line_index_counter, :] = fill(round(Int, row[:tmax]), units.N)
                end

                if (row.id_lin in timeseries_tmin_lin_ids)
                    # If there is time-varying data available
                    cap_line_forward[line_index_counter, :] = round.(Int,timeseries_tmin[!, string(row.id_lin)][:])
                else
                    cap_line_forward[line_index_counter, :] = fill(round(Int, row[:tmin]), units.N)
                end

            end # end of switch if lower_bus_id

            line_index_counter += 1
        end
        
    end

    # ========================== Interfaces ===============================
    # Now aggregate the lines to get the interfaces
    line_details = DataFrame(id_ascending = 1:N_lines , idlong = line_names, id_bus_from = line_bus_from_final, id_bus_to = line_bus_to_final)
    line_groups = groupby(line_details, [:id_bus_from, :id_bus_to])

    N_interfaces = length(line_groups)
    interface_bus_from = zeros(Int, N_interfaces)
    interface_bus_to = zeros(Int, N_interfaces)
    interface_cap_forward = zeros(Int, N_interfaces, units.N)
    interface_cap_backward = zeros(Int, N_interfaces, units.N)
    for (i, group) in enumerate(line_groups)
        #println("Creating interface between region $(first(group.id_bus_from)) and $(first(group.id_bus_to)) with $(nrow(group)) lines.")
        interface_bus_from[i] = first(group.id_bus_from)
        interface_bus_to[i] = first(group.id_bus_to)
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