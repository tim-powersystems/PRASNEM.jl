"""
   addStorageUnits!(sys; regions=Int[], number=1, size=100, duration=4, type="BESS")

Type may be BESS or PS!

Adds a number of storage units to the given PRAS system model.
"""
function addStorageUnits!(sys; regions=Int[], number=1, capacity=100, duration=4, type="BESS")
    
   if isempty(regions)
        regions = collect(1:length(sys.regions.names))
   end

   unique_adding_number = 1
   if haskey(sys.attrs, "added_storage_units_counter")
      unique_adding_number = parse(Int, sys.attrs["added_storage_units_counter"]) + 1
   end

   units = get_params(sys)

   old = deepcopy(sys.storages)
   old_assignment = deepcopy(sys.region_stor_idxs)
   n_old = length(old.names)
   Nstors = n_old + number * length(regions)
   N = units[1]
   Nregions = length(sys.regions.names)
   default_idx = findfirst(x -> x == type, old.categories)

   # Set default parameters for the new storage units based on the average of existing units, or use predefined defaults if no existing units
   charge_eff_default = n_old > 0 ? maximum(old.charge_efficiency[default_idx,:]) : 0.90
   disch_eff_default = n_old > 0 ? maximum(old.discharge_efficiency[default_idx,:]) : 0.90
   carryover_eff_default = n_old > 0 ? maximum(old.carryover_efficiency[default_idx,:]) : 1.00
   failurerate_default = n_old > 0 ? maximum(old.λ[default_idx,:]) : 0.0
   repairrate_default = n_old > 0 ? maximum(old.μ[default_idx,:]) : 1.0

   # Create the new storage parameters
   stors_names = Vector{String}(undef, Nstors)
   stors_categories = Vector{String}(undef, Nstors)
   stors_chargecap = zeros(Int, Nstors, N)
   stors_dischcap = zeros(Int, Nstors, N)
   stors_energycap = zeros(Int, Nstors, N)
   stors_chargeeff = zeros(Float64, Nstors, N)
   stors_disch_eff = zeros(Float64, Nstors, N)
   stors_carryover_eff = zeros(Float64, Nstors, N)
   stors_failurerate = zeros(Float64, Nstors, N)
   stors_repairrate = zeros(Float64, Nstors, N)

   new_region_stor_idxs = [1:0 for _ in 1:Nregions] # Start with empty indices for each region, will fill in as we go through the regions and add existing + new storages

   # Iterate through all regions and add the specified number of storage units to each region
   total_units_added = 0
   for r in 1:Nregions
      # First add the existing storage units for this region
      existing_idxs = old_assignment[r]
      stors_names[total_units_added .+ (1:length(existing_idxs))] = old.names[existing_idxs]
      stors_categories[total_units_added .+ (1:length(existing_idxs))] = old.categories[existing_idxs]
      stors_chargecap[total_units_added .+ (1:length(existing_idxs)), :] = old.charge_capacity[existing_idxs, :]
      stors_dischcap[total_units_added .+ (1:length(existing_idxs)), :] = old.discharge_capacity[existing_idxs, :]
      stors_energycap[total_units_added .+ (1:length(existing_idxs)), :] = old.energy_capacity[existing_idxs, :]
      stors_chargeeff[total_units_added .+ (1:length(existing_idxs)), :] = old.charge_efficiency[existing_idxs, :]
      stors_disch_eff[total_units_added .+ (1:length(existing_idxs)), :] = old.discharge_efficiency[existing_idxs, :]
      stors_carryover_eff[total_units_added .+ (1:length(existing_idxs)), :] = old.carryover_efficiency[existing_idxs, :]
      stors_failurerate[total_units_added .+ (1:length(existing_idxs)), :] = old.λ[existing_idxs, :]
      stors_repairrate[total_units_added .+ (1:length(existing_idxs)), :] = old.μ[existing_idxs, :]
      total_units_added += length(existing_idxs)

      if r in regions
         # Now add the new storage units for this region
         for i in 1:number
            stors_names[total_units_added + i] = string(type, "_new_", unique_adding_number, "_", r, "_", i)
            stors_categories[total_units_added + i] = type
            stors_chargecap[total_units_added + i, :] .= round(Int, capacity)
            stors_dischcap[total_units_added + i, :] .= round(Int, capacity)
            stors_energycap[total_units_added + i, :] .= round(Int, capacity * duration)
            stors_chargeeff[total_units_added + i, :] .= charge_eff_default
            stors_disch_eff[total_units_added + i, :] .= disch_eff_default
            stors_carryover_eff[total_units_added + i, :] .= carryover_eff_default
            stors_failurerate[total_units_added + i, :] .= failurerate_default
            stors_repairrate[total_units_added + i, :] .= repairrate_default
         end
         total_units_added += number
      end

      new_region_stor_idxs[r] = (r == 1 ? 1 : (new_region_stor_idxs[r-1][end] + 1)): total_units_added

   end

   new_storages = PRAS.Storages{units[1], units[2], units[3], units[4], units[5]}(
         stors_names,
         stors_categories,
         stors_chargecap,
         stors_dischcap,
         stors_energycap,
         stors_chargeeff,
         stors_disch_eff,
         stors_carryover_eff,
         stors_failurerate,
         stors_repairrate
   )

   # Update the unique storage unit counter in the system attributes
   new_attrs = deepcopy(sys.attrs)
   new_attrs["added_storage_units_counter"] = string(unique_adding_number)
   new_attrs["added_storage_units_" * string(unique_adding_number)] = string(number) * "x" * type * ", " * string(capacity) * "MW, " * string(duration) * "h, regions: " * join(regions, ", ")
   sys.attrs["added_storage_units_counter"] = string(unique_adding_number)

   sys = SystemModel(
        sys.regions,
        sys.interfaces,
        sys.generators,
        sys.region_gen_idxs,
        new_storages,
        new_region_stor_idxs,
        sys.generatorstorages,
        sys.region_genstor_idxs,
        sys.demandresponses,
        sys.region_dr_idxs,
        sys.lines,
        sys.interface_line_idxs,
        sys.timestamps,
        new_attrs
    )
   return sys 
end

# ==================================================================================================================================================
"""
   addGasUnits!(sys; regions=Int[], number=1, capacity=100, type="CCGT")

"""

function addGeneratorUnits!(sys; regions=Int[], number=1, capacity=100, type="CCGT")
    # Similar structure to addStorageUnits!, but for generators instead of storages
    
    if isempty(regions)
        regions = collect(1:length(sys.regions.names))
   end

   unique_adding_number = 1
   if haskey(sys.attrs, "added_gens_units_counter")
      unique_adding_number = parse(Int, sys.attrs["added_gens_units_counter"]) + 1
   end

   units = get_params(sys)

   old = deepcopy(sys.generators)
   old_assignment = deepcopy(sys.region_gen_idxs)
   n_old = length(old.names)
   Ngens = n_old + number * length(regions)
   N = units[1]
   Nregions = length(sys.regions.names)
   default_idx = findfirst(x -> x == type, old.categories)
   if isnothing(default_idx)
      @error("No existing generator of type $type found to use as default parameters for the new generators. Please ensure the type is correct or add a generator of this type before using this function.")
      return sys
   end

   # Set default parameters for the new storage units based on the average of existing units, or use predefined defaults if no existing units
   failurerate_default = n_old > 0 ? maximum(old.λ[default_idx,:]) : 0.0
   repairrate_default = n_old > 0 ? maximum(old.μ[default_idx,:]) : 1.0

   # Create the new generator parameters
   gen_names = Vector{String}(undef, Ngens)
   gen_categories = repeat(["CCGT"], Ngens)
   gen_capacity = zeros(Int, Ngens, N)
   gen_failurerate = zeros(Float64, Ngens, N)
   gen_repairrate = zeros(Float64, Ngens, N)

   region_gen_idxs = [1:0 for _ in 1:Nregions] # Start with empty indices for each region, will fill in as we go through the regions and add existing + new generators

   # Iterate through all regions and add the specified number of generator units to each region
   total_units_added = 0
   for r in 1:Nregions
      idxs = old_assignment[r]
      gen_names[total_units_added .+ (1:length(idxs))] = old.names[idxs]
      gen_categories[total_units_added .+ (1:length(idxs))] = old.categories[idxs]
      gen_capacity[total_units_added .+ (1:length(idxs)), :] = old.capacity[idxs, :]
      gen_failurerate[total_units_added .+ (1:length(idxs)), :] = old.λ[idxs, :]
      gen_repairrate[total_units_added .+ (1:length(idxs)), :] = old.μ[idxs, :]
      total_units_added += length(idxs)

      if r in regions
         for i in 1:number
            gen_names[total_units_added + i] = string(type, "_new_", unique_adding_number, "_", r, "_", i)
            gen_categories[total_units_added + i] = type
            gen_capacity[total_units_added + i, :] .= round(Int, capacity)
            gen_failurerate[total_units_added + i, :] .= failurerate_default
            gen_repairrate[total_units_added + i, :] .= repairrate_default
         end
         total_units_added += number
      end

      region_gen_idxs[r] = (r == 1 ? 1 : (region_gen_idxs[r-1][end] + 1)): total_units_added

   end

   new_generators = PRAS.Generators{units[1], units[2], units[3], units[4]}(
         gen_names,
         gen_categories,
         gen_capacity,
         gen_failurerate,
         gen_repairrate
   )

   # Update the unique generator unit counter in the system attributes
   new_attrs = deepcopy(sys.attrs)
   new_attrs["added_gens_units_counter"] = string(unique_adding_number)
   new_attrs["added_gens_units_" * string(unique_adding_number)] = string(number) * "x" * type * ", " * string(capacity) * "MW, regions: " * join(regions, ", ")


   sys = SystemModel(
        sys.regions,
        sys.interfaces,
        new_generators,
        region_gen_idxs,
        sys.storages,
        sys.region_stor_idxs,
        sys.generatorstorages,
        sys.region_genstor_idxs,
        sys.demandresponses,
        sys.region_dr_idxs,
        sys.lines,
        sys.interface_line_idxs,
        sys.timestamps,
        new_attrs
    )

   return sys
end
