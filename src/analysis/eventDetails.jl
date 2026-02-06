
"""
    get_event_details(vec)

Analyses and groups the non-zero entries in the input vector `vec`, returning a list of tuples. Each tuple contains:
    - length: The number of consecutive non-zero entries in the group.
    - sum: The sum of the entries in the group.
    - maximum: The maximum value in the group.
    - start_index: The starting index of the group in the original vector.
    - end_index: The ending index of the group in the original vector.
"""  
function get_event_details(vec)
     
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




"""
    get_storage_energy_at_start_of_critical_event(df_nostor::DataFrame, sample_number::Int, event_start_index::Int)

IMPORTANT: Assuming that df_nostor had the same seed as the data in sample_number.

"""
function find_start_of_critical_event(df_nostor::DataFrame, sample_number::Int, event_start_index::Int)

    condition_same_sample = df_nostor.sample .== sample_number
    condition_start_before_event = df_nostor.start_index .<= event_start_index
    condition_end_after_event = df_nostor.end_index .>= event_start_index

    all_start_indices = df_nostor[findall(condition_same_sample .&& condition_start_before_event .&& condition_end_after_event), :start_index]
    if isempty(all_start_indices)
        # In case there is no critical event that overlaps with the start of the USE event, return 0 to indicate that there is no critical event in the df_nostor event.
        return 0
    else
        # Using the minimum in case there are multiple overlapping events
        return minimum(all_start_indices)
    end
end



"""
    aggregate_overlapping_events(df_event_details)

Given that some events may happen at the same time across different regions, this function aggregates such events into single entries.

# Arguments
    - `df_event_details::DataFrame`: A DataFrame containing event details with columns: `:sample`, `:start_index`, `:end_index`, `:length`, `:sum`, `:maximum`, `:region`, and `:area`.

# Returns
    - `DataFrame`: A new DataFrame with overlapping events aggregated into single entries. They can be identified by having `region` and `area` set to `0`.

"""
function aggregate_overlapping_events(df_event_details)

    df_new = DataFrame()
    for group in groupby(df_event_details, [:sample])

        # Sort by start index and then by end index
        sorted_group = sort(group, [:start_index, :end_index])

        # Find all events that overlap with the next event
        idx_into_next = findfirst(sorted_group[1:end-1,:end_index] .>= sorted_group[2:end,:start_index])

        while !isnothing(idx_into_next)

            # Indices of the overlapping events
            a = idx_into_next
            b = idx_into_next + 1

            # Merge the overlapping events
            sorted_group.start_index[idx_into_next] = min(sorted_group.start_index[a], sorted_group.start_index[b])
            sorted_group.end_index[idx_into_next] = max(sorted_group.end_index[a], sorted_group.end_index[b])
            sorted_group.length[idx_into_next] = sorted_group.end_index[idx_into_next] - sorted_group.start_index[idx_into_next] + 1
            sorted_group.sum[idx_into_next] = sum(sorted_group.sum[a:b])
            sorted_group.maximum[idx_into_next] = max(sorted_group.maximum[a], sorted_group.maximum[b])
            sorted_group.region[idx_into_next] = 0
            sorted_group.area[idx_into_next] = 0

            # Remove the next event
            deleteat!(sorted_group, idx_into_next + 1)

            # Check for further overlaps
            idx_into_next = findfirst(sorted_group[1:end-1,:end_index] .>= sorted_group[2:end,:start_index])
        end
        
        df_new = vcat(df_new, sorted_group)

    end
    
    return df_new
end


"""
    get_all_event_details(sfsamples; sesamples=nothing, sys=nothing, df_nostor=nothing)

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
        - storages_energy_before: Total storage energy before the start of the USE event (as a fraction of total capacity if `sys` is provided).

"""
function get_all_event_details(sfsamples; sesamples=nothing, sys=nothing, df_nostor=nothing)
    
    df = DataFrame(length=Int[], sum=Int[], maximum=Int[], start_index=Int[], end_index=Int[], start_critical_index=Int[], region=Int[], area=Int[], sample=Int[], storages_energy_before=Float64[], storages_energy_start_critical_period=Float64[])

    if isnothing(sesamples)
        total_energy = zeros(Float64, 1, size(sfsamples.shortfall, 2), size(sfsamples.shortfall, 3))
        total_energy .= NaN
    else
        df.storages_energy_before = zeros(Float64, 0)
        df.storages_energy_start_critical_period = zeros(Float64, 0)
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
                if event.start_index == 1
                    @info "Load shedding in the first time step of sample $i in region $r. Energy before event is set to NaN."
                    push!(df, (event.length, event.sum, event.maximum, event.start_index, event.end_index, event.start_index, r, region_area_map[r], i, NaN, NaN))
                else
                    if isnothing(df_nostor)
                        start_critical_index = 0
                        total_energy_at_critical_index = NaN
                    else
                        start_critical_index = find_start_of_critical_event(df_nostor, i, event.start_index)
                        if start_critical_index == 0
                            total_energy_at_critical_index = NaN
                        else
                            total_energy_at_critical_index = total_energy[1,start_critical_index-1,i]
                        end
                    end
                    push!(df, (event.length, event.sum, event.maximum, event.start_index, event.end_index, start_critical_index, r, region_area_map[r], i, total_energy[1,event.start_index-1,i], total_energy_at_critical_index))
                end
            end
        end
    end

    return df

end