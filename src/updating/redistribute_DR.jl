function redistribute_DR(sys; mode::String="default", region_area_mapping::Dict{Int64,Int64}=get_region_area_map())

    vaild_modes = ["default", "equal", "max demand", "total energy"]
    if !(mode in vaild_modes)
        error("Unsupported demand response redistribution mode: $mode. Supported modes are: $(join(vaild_modes, ", "))")
    end

    for area in unique(values(region_area_mapping))
        regions_in_area = [region for (region, a) in region_area_mapping if a == area]
        n_regions = length(regions_in_area)
        total_DR_borrow_capacity = sum(sys.demandresponses.borrow_capacity[sys.region_dr_idxs[r],:] for r in regions_in_area)
        total_DR_energy_capacity = sum(sys.demandresponses.energy_capacity[sys.region_dr_idxs[r],:] for r in regions_in_area)
        if mode == "default"
            # Assign all DSP to the main load region in the area
            total_energies = zeros(Float64, n_regions)
            total_energy = 0.0
            for (i, r) in enumerate(regions_in_area)
                total_energies[i] = sum(sys.regions.load[r, :])
                total_energy += total_energies[i]
            end
            main_region_idx = argmax(total_energies)
            for (i, r) in enumerate(regions_in_area)
                if i == main_region_idx
                    sys.demandresponses.borrow_capacity[sys.region_dr_idxs[r],:] .= total_DR_borrow_capacity
                    sys.demandresponses.energy_capacity[sys.region_dr_idxs[r],:] .= total_DR_energy_capacity
                else
                    sys.demandresponses.borrow_capacity[sys.region_dr_idxs[r],:] .= 0
                    sys.demandresponses.energy_capacity[sys.region_dr_idxs[r],:] .= 0
                end
            end

        elseif mode == "equal"
            # Equal redistribution among regions in the area
            for r in regions_in_area
                sys.demandresponses.borrow_capacity[sys.region_dr_idxs[r],:] .= round.(Int, total_DR_borrow_capacity ./ n_regions)
                sys.demandresponses.energy_capacity[sys.region_dr_idxs[r],:] .= round.(Int, total_DR_energy_capacity ./ n_regions)
            end
        elseif mode == "max demand"
            # Redistribution based on maximum demand of each region
            max_demands = zeros(Float64, n_regions)
            total_max_demand = 0.0
            for (i, r) in enumerate(regions_in_area)
                max_demands[i] = maximum(sys.regions.load[r, :])
                total_max_demand += max_demands[i]
            end
            for (i, r) in enumerate(regions_in_area)
                proportion = max_demands[i] / total_max_demand
                sys.demandresponses.borrow_capacity[sys.region_dr_idxs[r],:] .= round.(Int,total_DR_borrow_capacity .* proportion)
                sys.demandresponses.energy_capacity[sys.region_dr_idxs[r],:] .= round.(Int,total_DR_energy_capacity .* proportion)
            end
        elseif mode == "total energy"
            # Redistribution based on total energy consumption of each region
            total_energies = zeros(Float64, n_regions)
            total_energy = 0.0
            for (i, r) in enumerate(regions_in_area)
                total_energies[i] = sum(sys.regions.load[r, :])
                total_energy += total_energies[i]
            end
            for (i, r) in enumerate(regions_in_area)
                proportion = total_energies[i] / total_energy
                sys.demandresponses.borrow_capacity[sys.region_dr_idxs[r],:] .= round.(Int,total_DR_borrow_capacity .* proportion)
                sys.demandresponses.energy_capacity[sys.region_dr_idxs[r],:] .= round.(Int,total_DR_energy_capacity .* proportion)
            end
        end
    end

    return sys
end