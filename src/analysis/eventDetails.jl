

function get_event_details(vec)
    """
    Analyses and groups the non-zero entries in the input vector `vec`, returning a list of tuples. Each tuple contains:
        - length: The number of consecutive non-zero entries in the group.
        - sum: The sum of the entries in the group.
        - maximum: The maximum value in the group.
        - start_index: The starting index of the group in the original vector.
        - end_index: The ending index of the group in the original vector.
    """       
    stats = []
    i = 1
    while i <= length(vec)
        if vec[i] != 0
            start = i
            while i <= length(vec) && vec[i] != 0
                i += 1
            end
            group = vec[start:i-1]
            push!(stats, (length=length(group), sum=sum(group), maximum=maximum(group), start_index=start, end_index=i-1))
        else
            i += 1
        end
    end
    return stats
end

function get_all_event_details(sfsamples; sesamples=nothing, sys=nothing)
    """
    Analyzes all samples in `sfsamples` and returns a DataFrame with event details for each region and area.
        The DataFrame contains the following columns:
            - length: Length of the event (number of consecutive non-zero entries).
            - sum: Sum of unserved energy in the event.
            - maximum: Maximum value in the event.
            - region: Region number.
            - area: Area number corresponding to the region.
            - sample: Sample index.
            - start_index: Starting index of the event in the time series.
            - end_index: Ending index of the event in the time series.
    """
    df = DataFrame(length=Int[], sum=Int[], maximum=Int[], start_index=Int[], end_index=Int[], region=Int[], area=Int[], sample=Int[], storages_energy_before=Float64[])

    if isnothing(sesamples)
        total_energy = zeros(Float64, 1, size(sfsamples.shortfall, 2), size(sfsamples.shortfall, 3))
        total_energy .= NaN
    else
        df.storages_energy_before = zeros(Float64, 0)
        total_energy = sum(sesamples.energy, dims=1)
        if sys === nothing
            @warn "System not specified, energy at each event is returned in energy values (not percentage of total energy)."
        else
            total_energy = total_energy ./ sum(sys.storages.energy_capacity, dims=1)
        end
    end

    Nregions = size(sfsamples.shortfall, 1)
    Nsamples = size(sfsamples.shortfall, 3)

    region_area_map = get_region_area_map() # Map region to area

    for i in 1:Nsamples
        for r in 1:Nregions
            t = get_event_details(sfsamples.shortfall[r,:,i])
            for event in t
                push!(df, (event.length, event.sum, event.maximum, event.start_index, event.end_index, r, region_area_map[r], i, total_energy[1,event.start_index-1,i]))
            end
        end
    end

    return df

end