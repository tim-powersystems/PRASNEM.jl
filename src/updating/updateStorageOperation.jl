# These functions are for updating a PRAS model with storage operation

# The following functions are available:
#       - `updateEnergyDerating`: Derate short-term energy storage capacities based on a provided mapping (or AEMO mapping by default).
#       - `updateStorageMarketDecisionDispatch`: Dispatch storage based on market decisions - charging only when expected to charge. Hoever, the amount still remains flexible.
#       - `updateExpectationDispatch`: Adjust load with expected storage / genstorage dispatch. Then disable the storage/genstors by setting their capacities to zero (not remove to allow consistency across seeds). Additionally, demandresponse needs to be removed to avoid it charging storage. Therefore, a subsequent "reoptimisation" is needed to obtain the accurate adequacy results.



"""
    updateEnergyDerating(sys; derating_mapping = Dict(1.5 => 0.5, 3.5 => 0.75, 7.5 => 0.9))

This function is derating short-term energy storage capacities based on a provided mapping (or AEMO mapping by default).
The derating_mapping is a Dict where keys are energy storage duration thresholds (in hours) and values are the derating factors (between 0 and 1).

"""
function updateEnergyDerating(sys; derating_mapping = Dict(1.5 => 0.5, 3.5 => 0.75, 7.5 => 0.9))

    lower_bound_hours  = 0.0
    for (derating_hours, derating_factor) in sort(derating_mapping)
        println("<",derating_hours, " hours energy storage derated to ", derating_factor * 100, "% capacity.")
        for s in 1:length(sys.storages.names)
            ecap = maximum(sys.storages.energy_capacity[s, :])
            pcap = maximum(sys.storages.discharge_capacity[s, :])  # Assuming capacity is constant over time
            energy_hours = ecap / pcap
            if energy_hours > lower_bound_hours && energy_hours <= derating_hours
                sys.storages.energy_capacity[s, :] .= round.(Int, ecap * derating_factor)
            end
        end
        lower_bound_hours = derating_hours
    end

    return sys
end

# ==================================================================================================================================================
"""
    Dispatch: Charging is only limited to the times when storage is expected to charge.
"""

function updateStorageMarketDecisionDispatch(sys, res; include_genstorage=true)
    

    sys.storages.charge_capacity[findall(x -> x == 0, res.stor_charging)] .= 0
    if include_genstorage
        sys.generatorstorages.gridwithdrawal_capacity[findall(x -> x == 0, res.genstor_charging)] .= 0
    end
    
    #sys.storages.charge_capacity[findall(x -> x > 0, res.stor_discharging)] .= 0
    #sys.generatorstorages.gridwithdrawal_capacity[findall(x -> x > 0, res.genstor_discharging)] .= 0
 
    return sys
end
# ==================================================================================================================================================

"""
    updateExpectationDispatch(sys, res; include_genstorage=true)

Adjust load with expected storage / genstorage dispatch. 
Then disable the storage/genstors by setting their capacities to zero (not remove to allow consistency across seeds).
Additionally, demandresponse needs to be removed to avoid it charging storage. Therefore, a subsequent "reoptimisation" is needed to obtain the accurate adequacy results. 

# Inputs
- `sys`: The PRAS system model to be updated.
- `res`: The results from the storage operation dispatch, containing the expected charging and discharging profiles for both storage and generator storage.
- `include_genstorage`: A boolean flag indicating whether to include generator storage in the load adjustment and capacity disabling process (default is true).

"""

function updateExpectationDispatch(sys, res; include_genstorage=true)
    
    for r in 1:length(sys.regions.names)
        # Increase load by charging
        sys.regions.load[r, :] .+= sum(res.stor_charging[sys.region_stor_idxs[r], :], dims=1)[:]
        if include_genstorage
            sys.regions.load[r, :] .+= sum(res.genstor_charging[sys.region_genstor_idxs[r], :], dims=1)[:]
        end
        
        # Decrease load by discharging
        sys.regions.load[r, :] .-= sum(res.stor_discharging[sys.region_stor_idxs[r], :], dims=1)[:]
        if include_genstorage
            sys.regions.load[r, :] .-= sum(res.genstor_discharging[sys.region_genstor_idxs[r], :], dims=1)[:]
        end
    end
    # Disable storage / genstorage 
    sys.storages.discharge_capacity .= 0
    sys.storages.charge_capacity .= 0
    sys.storages.energy_capacity .= 0
    if include_genstorage
        sys.generatorstorages.gridinjection_capacity .= 0
        sys.generatorstorages.discharge_capacity .= 0
        sys.generatorstorages.energy_capacity .= 0
        sys.generatorstorages.inflow .= 0
    end

    # Disable demand response to avoid it charging storage
    sys.demandresponses.borrow_capacity .= 0
    
    return sys
end


