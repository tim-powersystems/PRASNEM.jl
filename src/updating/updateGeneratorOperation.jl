"""
    updateUnitCommitment!(sys, res)

Update the generator capacities based on commitment status (using 'res.gon').

The flag consider_ramping determines whether to consider generators that are not ramping limited as always available. Else their availability might be reduced to zero in timesteps when they are not committed/producing.
"""
function updateUnitCommitment!(sys, res; consider_ramping=true)

    N = length(res.gon[1, :]) # Number of timesteps
    # Update generator capacities based on commitment status

    if consider_ramping
        not_ramping_limited = zeros(size(res.gon))
        not_ramping_limited[findall(res.p_gen_max .== sys.generators.capacity[:, 1:N])] .= 1
        sys.generators.capacity[:, 1:N] .= sys.generators.capacity[:, 1:N] .* max.(res.gon, not_ramping_limited)
    else
        
        sys.generators.capacity[:, 1:N] .= sys.generators.capacity[:, 1:N] .* res.gon
    end

    return sys
end

"""
    updateRamping!(sys, res)

Update the generator ramping constraints based on the expected ramping profiles (using 'res.p_gen_max', which already differentiates between generators affected by ramping and by units without constraints).
"""
function updateRamping!(sys, res)

    N = length(res.gon[1, :]) # Number of timesteps

    # Update generator capacities based on ramping (or commitment status if that is already applied)
    sys.generators.capacity[:, 1:N] .= min.(sys.generators.capacity[:, 1:N], res.p_gen_max)

    return sys
end
