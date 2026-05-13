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
function updateEnergyDerating!(sys; derating_mapping = Dict(1.5 => 0.5, 3.5 => 0.75, 7.5 => 0.9), derate_VPPs=0.5)

    lower_bound_hours  = 0.0
    for (derating_hours, derating_factor) in sort(derating_mapping)
        @info("<" * string(derating_hours) * " hours large-scale energy storage derated to " * string(derating_factor * 100) * "% capacity (excl. VPPs).")
        for s in 1:length(sys.storages.names)
            
            ecap = maximum(sys.storages.energy_capacity[s, :])
            pcap = maximum(sys.storages.discharge_capacity[s, :])  # Assuming capacity is constant over time

            if (sys.storages.categories[s] == "VPP") && (derate_VPPs < 1.0)
                continue # Skip derating for VPPs as they will be derated at the end
            else
                # Derate all other storages based on their energy duration
                energy_hours = ecap / pcap
                if energy_hours >= lower_bound_hours && energy_hours < derating_hours
                    sys.storages.energy_capacity[s, :] .= round.(Int, sys.storages.energy_capacity[s, :] * derating_factor)
                end
            end

        end
        lower_bound_hours = derating_hours
    end

    if any(sys.storages.categories .== "VPP") && (derate_VPPs < 1.0)
        @info "VPPs are present in the system and will be derated by a factor of $(derate_VPPs * 100)% regardless of their energy duration."
        for s in 1:length(sys.storages.names)
            if sys.storages.categories[s] == "VPP"
                sys.storages.energy_capacity[s, :] .= round.(Int, sys.storages.energy_capacity[s, :] * derate_VPPs)
            end
        end
    end

    return sys
end

# ==================================================================================================================================================
"""
    Dispatch: Charging is only limited to the times when storage is expected to charge.
"""

function updateStorageMarketDecisionDispatch!(sys, res; include_genstorage=true)
    

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

function updateStorageExpectationDispatch!(sys, res; include_genstorage=true)

    N = length(res.stor_charging[1, :]) # Number of timesteps
    
    for r in 1:length(sys.regions.names)
        # Increase load by charging
        sys.regions.load[r, 1:N] .+= sum(res.stor_charging[sys.region_stor_idxs[r], :], dims=1)[:]
        if include_genstorage
            sys.regions.load[r, 1:N] .+= sum(res.genstor_charging[sys.region_genstor_idxs[r], :], dims=1)[:]
        end
        
        # Decrease load by discharging
        sys.regions.load[r, 1:N] .-= sum(res.stor_discharging[sys.region_stor_idxs[r], :], dims=1)[:]
        if include_genstorage
            sys.regions.load[r, 1:N] .-= sum(res.genstor_discharging[sys.region_genstor_idxs[r], :], dims=1)[:]
        end
    end
    # Disable storage / genstorage 
    sys.storages.discharge_capacity[:, 1:N] .= 0
    sys.storages.charge_capacity[:, 1:N] .= 0
    sys.storages.energy_capacity[:, 1:N] .= 0
    if include_genstorage
        sys.generatorstorages.gridinjection_capacity[:, 1:N] .= 0
        sys.generatorstorages.discharge_capacity[:, 1:N] .= 0
        sys.generatorstorages.energy_capacity[:, 1:N] .= 0
        sys.generatorstorages.inflow[:, 1:N] .= 0
    end

    if sum(sys.demandresponses.borrow_capacity) > 0
        @warn "Demand response borrowing capacity is greater than zero which may allow it to charge storage. Use `PRASNEM.updateDERExpectationDispatch!` to adjust load and disable demand response to avoid this issue."
    end

end


