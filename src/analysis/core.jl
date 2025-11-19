
include("remove_intraarea_constraints.jl")
include("area_analysis.jl")
include("get_event_details.jl")

function get_region_area_map()
    return Dict(1=>1, 2=>1, 3=>1, 4=>1, 5=>2, 6=>2, 7=>2, 8=>2, 9=>3, 10=>4, 11=>5, 12=>5)
end