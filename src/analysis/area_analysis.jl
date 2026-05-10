"""
    get_region_area_map(system="ISP24")    

Returns a dictionary mapping region numbers to area numbers. Note this is for the ISP 2024 12-bus system.
"""
function get_region_area_map(; system="ISP24", rev=false)
    
    if system != "ISP24"
        error("Region to area mapping is only defined for the ISP24 system.")
    end
    if rev
        return Dict(1 => [1,2,3,4], 2 => [5,6,7,8], 3 => [9], 4 => [10], 5 => [11,12])
    end
    return Dict(1=>1, 2=>1, 3=>1, 4=>1, 5=>2, 6=>2, 7=>2, 8=>2, 9=>3, 10=>4, 11=>5, 12=>5)
end
"""
    get_region_names(;system="ISP24")

Returns a list of region names for the specified system. Note this is so far only for the ISP 2024 12-bus system.
"""
function get_region_names(;system="ISP24")
    if system != "ISP24"
        error("Region names are only defined for the ISP24 system.")
    end
    return ["NQ", "CQ", "GG", "SQ", "NNSW", "CNSW", "SNW", "SNSW", "VIC", "TAS", "CSA", "SESA"]
end

"""
    NEUE_area(sys, sf; bus_file_path::String="../sample_data/nem12/Bus.csv")

Calculates the normalised expected unserved energy (NEUE) for each area in the system. The NEUE is calculated as the average NEUE across all buses in the area, weighted by the load at each bus.
"""
function NEUE_area(sys, sf; bus_file_path::String="../sample_data/nem12/Bus.csv")

    bus_info = CSV.read(bus_file_path, DataFrame)
    
    area_ids = unique(bus_info.id_area)
    area_names = Dict{Int,String}(1=>"QLD", 2=>"NSW", 3=>"VIC", 4=>"TAS", 5=>"SA")

    neue_areas = zeros(length(area_ids))

    for area_id in area_ids
        area_buses = bus_info.id_bus[bus_info.id_area .== area_id]
        bus_names = string.(area_buses)
        if !isempty(area_buses)
            neue_bus = val.(NEUE.(sf, bus_names))
            load_weights = sum(sys.regions.load[area_buses,:], dims=2) ./ sum(sys.regions.load[area_buses,:])
            avg_neue = sum(neue_bus .* load_weights ) / length(neue_bus)
            neue_areas[area_id] = avg_neue
            @info("$(area_names[area_id]) - Average NEUE: $(round(avg_neue, digits=2)) ppm")
        end
    end

    return neue_areas
end