function createLinesInterfaces(lines_input_file, units, region_ids, investment_filter=[0], active_filter=[1], hvdc_aliases = ["Heywood", "Murraylink", "Basslink"])
    """
    Create line and interface data structures from the input lines file.

    Note the optional filters here:
    - `investment_filter`: Filter lines by investment status (default is [0], meaning only existing)
    - `active_filter`: Filter lines by active status (default is [1], meaning only active lines are included)
    - `hvdc_aliases`: List of HVDC line aliases to be used for categorization (for PRAS structure, but not essential)

    """


    # Read in the lines file
    line_data = CSV.read(lines_input_file, DataFrame)

    # Filter the relevant lines
    filter!(row -> row.bus_a_id in region_ids, line_data)
    filter!(row -> row.bus_b_id in region_ids, line_data)

    # Filter the investment and active columns
    filter!(row -> row.investment in investment_filter, line_data)
    filter!(row -> row.active in active_filter, line_data)

    # Sort by 'from' and 'to' columns
    sort!(line_data, [:bus_a_id, :bus_b_id])

    # For the line-interface assignment, create a new ID with the new sorting
    line_data.id_ascending .= 1:nrow(line_data)

    # Calculate the failure and repair rates
    line_data.repair_rate .= 1 ./ line_data.MTTR
    line_data.failure_rate .= line_data.FOR ./ (line_data.MTTR .* (1 .- line_data.FOR))

    # Add the line categories
    line_data.category .= "interregion_AC"
    line_data[findall(in(hvdc_aliases), line_data.alias), :category] .= "interregion_HVDC"

    # Interpolate the line capacity to all the timesteps
    N_lines = nrow(line_data)
    cap_line_forward = reshape(repeat(line_data[!, :capacity], units.N), N_lines, units.N)
    cap_line_backward = reshape(repeat(line_data[!, :capacity], units.N), N_lines, units.N)
    line_failure_rate = reshape(repeat(line_data[!, :failure_rate], units.N), N_lines, units.N)
    line_repair_rate = reshape(repeat(line_data[!, :repair_rate], units.N), N_lines, units.N)

    # Now aggregate the lines to get the interfaces
    line_groups = groupby(line_data, [:bus_a_id, :bus_b_id])
    interfaces_data = combine(line_groups, :capacity => sum => :agg_capacity)
    N_interfaces = nrow(interfaces_data)
    cap_interface_forward = reshape(repeat(interfaces_data[!, :agg_capacity], units.N), N_interfaces, units.N)
    cap_interface_backward = reshape(repeat(interfaces_data[!, :agg_capacity], units.N), N_interfaces, units.N)

    # Create the line-interface assignment
    line_interface_assignment = [first(group.id_ascending):last(group.id_ascending) for group in line_groups]


    return Lines{units.N,units.L,units.T,units.P}(
        line_data[!, :alias], # Names
        line_data[!, :category], # Categories
        cap_line_forward, # forward capacity (MW) for each line and timestep
        cap_line_backward, # reverse capacity (MW) for each line and timestep
        line_failure_rate, # failure rate (λ) for each line and timestep
        line_repair_rate # repair rate (μ) for each line and timestep
    ), Interfaces{units.N,units.P}( # timesteps, units
        interfaces_data[!, :bus_a_id], interfaces_data[!, :bus_b_id], # from, to
        cap_interface_forward, cap_interface_backward
    ), line_interface_assignment
end