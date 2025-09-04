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

    # Sort by 'from' and 'to' columns
    sort!(line_data, [:bus_a_id, :bus_b_id])

    # For the line-interface assignment, create a new ID with the new sorting
    line_data.id_ascending .= 1:nrow(line_data)

    # Calculate the failure and repair rates
    if "MTTR" in names(line_data)
        line_data.MTTR = coalesce.(line_data.MTTR, 1.0) # Replace missing MTTR with 1.0
    else
        println("No MTTR column found in line data. Setting MTTR to 1.0 for all lines.")
        line_data.MTTR = fill(1.0, nrow(line_data)) # If no MTTR column, set to 1.0
    end
    if "FOR" in names(line_data)
        line_data.FOR = coalesce.(line_data.FOR, 0.0) # Replace missing FOR with 0.0
    else
        println("No FOR column found in line data. Setting FOR to 0.0 for all lines.")
        line_data.FOR = fill(0.0, nrow(line_data)) # If no FOR column, set to 0.0
    end
    line_data.repair_rate .= 1 ./ line_data.MTTR
    line_data.failure_rate .= line_data.FOR ./ (line_data.MTTR .* (1 .- line_data.FOR))

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
    line_bus_a = zeros(Int, N_lines)
    line_bus_b = zeros(Int, N_lines)

    # Iterate through each row
    line_index_counter = 1
    for row in eachrow(line_data)
        # If there are no lines in the relevant time: continue
        if row.n == 0
            continue
        end

        
        for i in 1:row.n
            # First the details of this line
            line_names[line_index_counter] = "$(row.id)_" * string(i)
            line_categories[line_index_counter] = row.tech
            line_bus_a[line_index_counter] = row.bus_a_id
            line_bus_b[line_index_counter] = row.bus_b_id

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

            line_failure_rate[line_index_counter, :] .= row.failure_rate
            line_repair_rate[line_index_counter, :] .= row.repair_rate

            line_index_counter += 1
        end
        
    end

    # ========================== Interfaces ===============================
    # Now aggregate the lines to get the interfaces
    line_details = DataFrame(id_ascending = 1:N_lines , idlong = line_names, bus_a_id = line_bus_a, bus_b_id = line_bus_b)
    line_groups = groupby(line_details, [:bus_a_id, :bus_b_id])

    N_interfaces = length(line_groups)
    interface_bus_a = zeros(Int, N_interfaces)
    interface_bus_b = zeros(Int, N_interfaces)
    interface_cap_forward = zeros(Int, N_interfaces, units.N)
    interface_cap_backward = zeros(Int, N_interfaces, units.N)
    for (i, group) in enumerate(line_groups)
        #println("Creating interface between region $(first(group.bus_a_id)) and $(first(group.bus_b_id)) with $(nrow(group)) lines.")
        interface_bus_a[i] = first(group.bus_a_id)
        interface_bus_b[i] = first(group.bus_b_id)
        idx_lines = group.id_ascending
        interface_cap_forward[i, :] = sum(cap_line_forward[idx_lines, :], dims=1)
        interface_cap_backward[i, :] = sum(cap_line_backward[idx_lines, :], dims=1)
    end

    # ========================== Line-Interface-Assignments ===============================
    # Create the line-interface assignment
    line_interface_assignment = [first(group.id_ascending):last(group.id_ascending) for group in line_groups]


    return Lines{units.N,units.L,units.T,units.P}(
        line_names, # Names
        line_categories, # Categories
        cap_line_forward, # forward capacity (MW) for each line and timestep
        cap_line_backward, # reverse capacity (MW) for each line and timestep
        line_failure_rate, # failure rate (λ) for each line and timestep
        line_repair_rate # repair rate (μ) for each line and timestep
    ), Interfaces{units.N,units.P}( # timesteps, units
        interface_bus_a, interface_bus_b, # from, to
        interface_cap_forward, interface_cap_backward
    ), line_interface_assignment
end