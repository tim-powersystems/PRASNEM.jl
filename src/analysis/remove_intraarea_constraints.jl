
function remove_intraarea_constraints(sys; bus_file_path::String="../sample_data/nem12/Bus.csv", high_limit::Int=1_000_000)
    """
    Removes intra area constraints from the system based on the provided bus_region_map.
    E.g. Increase all line limits within the same area to a very high value.
    """
    
    bus_info = CSV.read(bus_file_path, DataFrame)
    for group in groupby(bus_info, :id_area)
        #println(group)
        region_buses = group.id_bus

        for i in eachindex(region_buses)
            bus_i = region_buses[i]
            for j in i+1:length(region_buses)
                bus_j = region_buses[j]
                # Find the interface between bus_i and bus_j
                for k in 1:length(sys.interfaces.regions_from)
                    if (sys.interfaces.regions_from[k] == bus_i && sys.interfaces.regions_to[k] == bus_j) || (sys.interfaces.regions_from[k] == bus_j && sys.interfaces.regions_to[k] == bus_i)
                        # Increase the limits of the interfaces
                        sys.interfaces.limit_backward[k,:] .= high_limit
                        sys.interfaces.limit_forward[k,:] .= high_limit
                        # And of the lines
                        line_idxs = sys.interface_line_idxs[k]
                        sys.lines.backward_capacity[line_idxs,:] .= high_limit
                        sys.lines.forward_capacity[line_idxs,:] .= high_limit

                        println("Increased limit of interface $k between bus $bus_i and bus $bus_j to $high_limit")
                    end
                end
            end
        end
        
        
    end




    return sys
end