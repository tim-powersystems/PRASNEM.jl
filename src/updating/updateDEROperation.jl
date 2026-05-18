"""
    updateDERExpectationDispatch!(sys, res)

Legacy function for backward compatibility. Please use `updateDRExpectationDispatch!` instead to adjust load and disable demand response to avoid it charging storage. The `updateDERExpectationDispatch!` function will be removed in a future release.
"""
function updateDERExpectationDispatch!(sys, res)
    @warn "The `updateDERExpectationDispatch!` function is a legacy function. Please use 'updateDRExpectationDispatch!' instead to adjust load and disable demand response to avoid it charging storage. The `updateDERExpectationDispatch!` function will be removed in a future release."
    sys = updateDRExpectationDispatch!(sys, res)
    return sys
end


"""
    updateDRExpectationDispatch!(sys, res)

Include the demand response (DR) dispatch within the load and disable demand response.
"""
function updateDRExpectationDispatch!(sys, res)

    if sys.demandresponses.names == []
        @info "No demand response resources, skipping updateDRExpectationDispatch!"
        return sys
    end

    N = length(res.drs_borrowing[1, :]) # Number of timesteps

    # Decrease load by borrowing energy
    for r in 1:length(sys.regions.names)
        sys.regions.load[r, 1:N] .-= sum(res.drs_borrowing[sys.region_dr_idxs[r], :], dims=1)[:]
    end

    # Increase load with payback
    for r in 1:length(sys.regions.names)
        sys.regions.load[r, 1:N] .+= sum(res.drs_payback[sys.region_dr_idxs[r], :], dims=1)[:]
    end

    # Disable demand response to avoid it charging storage
    sys.demandresponses.borrow_capacity .= 0

    return sys
end
"""
    updateVPPExpectationDispatch!(sys, res)

"""
function updateVPPExpectationDispatch!(sys, res)
    vpp_idxs = findall(x -> x == "VPP", sys.storages.categories)
    if isempty(vpp_idxs)
        @info "No VPP storage resources, skipping updateVPPExpectationDispatch!"
        return sys
    end
    N = length(sys.timestamps) # Number of timesteps
    
    for r in 1:length(sys.regions.names)
        vpp_in_region = intersect(sys.region_stor_idxs[r], vpp_idxs)
        if isempty(vpp_in_region)
            continue
        end
        # Increase load by charging
        sys.regions.load[r, 1:N] .+= sum(res.stor_charging[vpp_in_region, :], dims=1)[:]
        
        # Decrease load by discharging
        sys.regions.load[r, 1:N] .-= sum(res.stor_discharging[vpp_in_region, :], dims=1)[:]
    end

    # Disable storage / genstorage 
    sys.storages.discharge_capacity[vpp_idxs, 1:N] .= 0
    sys.storages.charge_capacity[vpp_idxs, 1:N] .= 0
    sys.storages.energy_capacity[vpp_idxs, 1:N] .= 0

    return sys
end
