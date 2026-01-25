# Functions to facilitate analysis of results

function get_region_area_map(system="ISP24")
    """
    Returns a dictionary mapping region numbers to area numbers. Note this is for the ISP 2024 12-bus system.
    """
    if system != "ISP24"
        error("Region to area mapping is only defined for the ISP24 system.")
    end
    return Dict(1=>1, 2=>1, 3=>1, 4=>1, 5=>2, 6=>2, 7=>2, 8=>2, 9=>3, 10=>4, 11=>5, 12=>5)
end

include("area_analysis.jl")
include("eventDetails.jl")