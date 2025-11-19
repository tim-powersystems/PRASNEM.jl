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
            push!(stats, (length=length(group), sum=sum(group), maximum=maximum(group)))
        else
            i += 1
        end
    end
    return stats
end