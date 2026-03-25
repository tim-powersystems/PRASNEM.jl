"""
    updateStorageOutageDerating(sys; from_FOR_to_lam=false)
Converting the storage failure and repair rates to capacity derating (or reverse if from_FOR_to_lam=true) and update the storage capacities accordingly.

    Formula: 
        FOR = failure_rate / (failure_rate + repair_rate)

"""
function updateStorageOutageDerating!(sys; include_genstorages=true)


    # Apply the 
    failure_rates_stors = sys.storages.λ
    repair_rates_stors = sys.storages.μ

    if sum(failure_rates_stors) == 0.0
        @warn "No storage failure rates in the system (seems like the system already has the outage derating applied?). Skipping updateStorageOutageDerating."
        return sys
    end
    
    for_storages = failure_rates_stors ./ (failure_rates_stors .+ repair_rates_stors)
    sys.storages.discharge_capacity .= round.(Int, sys.storages.discharge_capacity .* (1 .- for_storages))
    sys.storages.charge_capacity .= round.(Int, sys.storages.charge_capacity .* (1 .- for_storages))
    
    # Then set the failure rate to zero
    sys.storages.λ .= 0.0
    sys.storages.μ .= 1.0

    if include_genstorages

        failure_rates_genstors = sys.generatorstorages.λ
        repair_rates_genstors = sys.generatorstorages.μ
        for_genstors = failure_rates_genstors ./ (failure_rates_genstors .+ repair_rates_genstors)
        sys.generatorstorages.gridinjection_capacity .= round.(Int, sys.generatorstorages.gridinjection_capacity .* (1 .- for_genstors))
        sys.generatorstorages.gridwithdrawal_capacity .= round.(Int, sys.generatorstorages.gridwithdrawal_capacity .* (1 .- for_genstors))
    
        # Then set the failure rate to zero
        sys.generatorstorages.λ .= 0.0
        sys.generatorstorages.μ .= 1.0
    end

    return sys
end