function createLines(lines_input_file, units, regions_selected)

    # Read the line data
    line_data = CSV.read(lines_input_file, DataFrame)

    # Filter the relevant lines
    filter!(row -> row.region_from in regions_selected, line_data)
    filter!(row -> row.region_to in regions_selected, line_data)

    # Sort the lines
    sort!(line_data, [:region_from, :region_to])

    # Expand the static data to dynamic values
    N_lines = length(line_data[!,:name])
    cap_forward = reshape(repeat(line_data[!, :forwardcapacity], units.N), N_lines, units.N)
    cap_backward = reshape(repeat(line_data[!, :backwardcapacity], units.N), N_lines, units.N)
    fail_rate = reshape(repeat(line_data[!, :failureprobability], units.N), N_lines, units.N)
    repair_rate = reshape(repeat(line_data[!, :repairprobability], units.N), N_lines, units.N)

    return lines = Lines{N,5,Minute,MW}(
        line_data[!, :name], # Names
        line_data[!, :category], # Categories
        fill(100, 1, N), # forward capacity (MW) for each line and timestep
        fill(100, 1, N), # reverse capacity (MW) for each line and timestep
        fill(0., 1, N), # failure rate (λ) for each line and timestep
        fill(1.0, 1, N) # repair rate (μ) for each line and timestep
        )
end