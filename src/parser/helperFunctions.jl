

function get_unit_region_assignment(regions_selected, bus_id_list)
    """
    Given a list of selected regions and a list of bus IDs for each unit (generator, storage, genstorage),
    this function returns a vector of ranges, where each inner vector contains the indices of units in that region.

        Note: regions_selected and bus_id_list must both be in ascending order!
    """
    # This function takes in a list of regions selected and a list of bus IDs for each unit
    unit_region_attribution = repeat([1:0], length(regions_selected))
    data = DataFrame(bus_id=bus_id_list, id_ascending=1:length(bus_id_list))
    counter = 1
    for i in 1:length(regions_selected)
        region_id = regions_selected[i]
        group = data[findall(data.bus_id .== region_id), [:id_ascending]]
        if isempty(group) && counter == 1
            unit_region_attribution[i] = 1:0 # If first region doesnt have any unit, set to empty
        elseif isempty(group)
            unit_region_attribution[i] = last(unit_region_attribution[i-1])+1:last(unit_region_attribution[i-1]) # If region doesnt have any unit, set to last index of previous region
        else
            unit_region_attribution[i] = first(group.id_ascending):last(group.id_ascending)
        end
        counter += 1
    end

    return unit_region_attribution
end