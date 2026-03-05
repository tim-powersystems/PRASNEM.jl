"""
    updateUnitCommitment!(sys, res)

Update the generator capacities based on commitment status (using 'res.gon').
"""
function updateUnitCommitment!(sys, res)

    # Update generator capacities based on commitment status
    sys.generators.capacity .= sys.generators.capacity .* res.gon

    return sys
end

"""
    updateRamping!(sys, res)

Update the generator ramping constraints based on the expected ramping profiles (using 'res.p_gen_max', which already differentiates between generators affected by ramping and by units without constraints).
"""
function updateRamping!(sys, res)

    # Update generator capacities based on ramping (or commitment status if that is already applied)
    sys.generators.capacity .= min.(sys.generators.capacity, res.p_gen_max)

    return sys
end
