"""
    updateDERExpectationDispatch!(sys, res)

Include the DER dispatch within the load and disable demand response to avoid it charging storage.
"""
function updateDERExpectationDispatch!(sys, res)

    # Decrease load by borrowing energy
    for r in 1:length(sys.regions.names)
        sys.regions.load[r, :] .-= sum(res.drs_borrowing[sys.region_dr_idxs[r], :], dims=1)[:]
    end

    # Increase load with payback
    for r in 1:length(sys.regions.names)
        sys.regions.load[r, :] .+= sum(res.drs_payback[sys.region_dr_idxs[r], :], dims=1)[:]
    end

    # Disable demand response to avoid it charging storage
    sys.demandresponses.borrow_capacity .= 0

    return sys
end