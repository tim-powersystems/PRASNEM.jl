"""
   apply_generator_derating!(sys::PRAS.System, resilience_folder::String)

Applies generator derating to the system based on the derating timeseries files in the specified resilience folder. 
The function looks for files with specific keywords in their names to identify which generators they correspond to and applies the derating accordingly.

Derating functions: 
   - For wind and thermal generators: min(max(cap) * correction_factor, original_capacity)
   - For large PV and roof PV generators: original_capacity * derating_factor (where derating_factor is the minimum of the inverter and module correction factors)

"""
function applyGenHeatwaveDerating!(sys, resilience_folder::String)
   @info("Applying generator derating to the system...\n     Folder: $(resilience_folder)")
   
   if ispath(resilience_folder)
      resil_files = readdir(resilience_folder)
   else
      @error("Resilience folder path $(resilience_folder) does not exist. Skipping generator derating.")
      return sys
   end

   # Get the maximum capacity of all the generators from the timeseries data
   gen_cap = maximum(sys.generators.capacity, dims=2)[:]

   # ==========================================================================
   # WIND DERATING - min(original capacity, new derated capacity)
   # ==========================================================================
   file_id = findfirst(occursin.(r"generator_cf_wind", lowercase.(resil_files)))
   if isnothing(file_id)
      @warn("No wind derating file found with name containing 'generator_cf_wind'. Skipping wind derating.")
   else

      file_wind_derating = joinpath(resilience_folder, resil_files[findfirst(occursin.(r"generator_cf_wind", lowercase.(resil_files)))])
      @info("Derating wind generators using file:\n$(file_wind_derating)")
      w_cf = PRASNEM.read_timeseries_file(file_wind_derating) # CF here is "correction factor"
      w_cf_unstacked = unstack(w_cf, :date, :id_gen, :value)
      w_ids = parse.(Int, names(select(w_cf_unstacked, Not(:date))))

      diff = year(w_cf_unstacked.date[1]) - year(sys.timestamps[1])
      w_cf_unstacked.date .= w_cf_unstacked.date .- Year(diff) # Shift the dates to match the system timestamps
      t = findfirst(w_cf_unstacked.date[1] .== DateTime.(collect(sys.timestamps))):findfirst(w_cf_unstacked.date[end] .== DateTime.(collect(sys.timestamps)))

      # Wind derating
      for id in w_ids
         # Find all the unit indices in the system that correspond to this generator id   
         rel_gen_idxs = findall(x -> split(x, "_")[1] == "$(id)", sys.generators.names)
         if isempty(rel_gen_idxs)
            continue
         end
         # For each of those unit indices, update the pmax timeseries with the correction factor
         new_cap = round.(Int, gen_cap[rel_gen_idxs] .* reshape(w_cf_unstacked[!, "$(id)"], 1, :))
         if any(new_cap .< sys.generators.capacity[rel_gen_idxs, t])
            n_timesteps = sum(new_cap .< sys.generators.capacity[rel_gen_idxs, t])
            @info("Derating wind generator $(id) for $n_timesteps timesteps.")
            sys.generators.capacity[rel_gen_idxs, t] .= min.(sys.generators.capacity[rel_gen_idxs, t], new_cap)
         end
      end
   end


   #%%

   # ==========================================================================
   # LargePV DERATING - original capacity * derating factor
   # ==========================================================================
   file_id = findfirst(occursin.(r"generator_cf_largepv_pvinv", lowercase.(resil_files)))
   if isnothing(file_id)
      @warn("No large PV derating files found with names containing 'generator_cf_largepv_pvinv'. Skipping large PV derating.")
   else
      # Inverters
      file_largepv_inv_derating = joinpath(resilience_folder, resil_files[findfirst(occursin.(r"generator_cf_largepv_pvinv", lowercase.(resil_files)))])
      # Modules
      file_largepv_mod_derating = joinpath(resilience_folder, resil_files[findfirst(occursin.(r"generator_cf_largepv_pvmod", lowercase.(resil_files)))])

      @info("Derating large PV generators using files:\nInverters: $(file_largepv_inv_derating)\nModules: $(file_largepv_mod_derating)")

      lpv_inv_cf = PRASNEM.read_timeseries_file(file_largepv_inv_derating) # CF here is "correction factor"
      lpv_mod_cf = PRASNEM.read_timeseries_file(file_largepv_mod_derating) # CF here is "correction factor"
      lpv_inv_cf_unstacked = unstack(lpv_inv_cf, :date, :id_gen, :value)
      lpv_mod_cf_unstacked = unstack(lpv_mod_cf, :date, :id_gen, :value)
      lp_ids = unique(vcat(parse.(Int, names(select(lpv_inv_cf_unstacked, Not(:date)))), parse.(Int, names(select(lpv_mod_cf_unstacked, Not(:date))))))

      diff = year(lpv_inv_cf_unstacked.date[1]) - year(sys.timestamps[1])
      lpv_inv_cf_unstacked.date .= lpv_inv_cf_unstacked.date .- Year(diff) # Shift the dates to match the system timestamps, assuming module derating is the same
      t = findfirst(lpv_inv_cf_unstacked.date[1] .== DateTime.(collect(sys.timestamps))):findfirst(lpv_inv_cf_unstacked.date[end] .== DateTime.(collect(sys.timestamps)))

      # LargePV derating
      for id in lp_ids
         # Find all the unit indices in the system that correspond to this generator id   
         rel_gen_idxs = findall(x -> split(x, "_")[1] == "$(id)", sys.generators.names)
         if isempty(rel_gen_idxs)
            continue
         end
         # For each of those unit indices, update the pmax timeseries with the correction factor
         correction_factor = reshape(min.(lpv_inv_cf_unstacked[!, "$(id)"], lpv_mod_cf_unstacked[!, "$(id)"]), 1, :)
         if any(correction_factor .< 1.0)
            n_timesteps = sum(correction_factor .< 1.0)
            @info("Derating large PV generator $(id) for $n_timesteps timesteps.")
            sys.generators.capacity[rel_gen_idxs, t] .= round.(Int, sys.generators.capacity[rel_gen_idxs, t] .* correction_factor)
         end
      end
   end


   #%%
   # ==========================================================================
   # RoofPV DERATING - original capacity * derating factor
   # ==========================================================================
   file_id = findfirst(occursin.(r"generator_cf_roofpv_pvinv", lowercase.(resil_files)))
   if isnothing(file_id)
      @warn("No roof PV derating file found with name containing 'generator_cf_roofpv_pvinv'. Skipping roof PV derating.")
   else
      # Inverters
      file_roofpv_inv_derating = joinpath(resilience_folder, resil_files[findfirst(occursin.(r"generator_cf_roofpv_pvinv", lowercase.(resil_files)))])
      # Modules
      file_roofpv_mod_derating = joinpath(resilience_folder, resil_files[findfirst(occursin.(r"generator_cf_roofpv_pvmod", lowercase.(resil_files)))])
   

      @info("Derating roof PV generators using files:\nInverters: $(file_roofpv_inv_derating)\nModules: $(file_roofpv_mod_derating)")

      rpv_inv_cf = PRASNEM.read_timeseries_file(file_roofpv_inv_derating) # CF here is "correction factor"
      rpv_mod_cf = PRASNEM.read_timeseries_file(file_roofpv_mod_derating) # CF here is "correction factor"
      rpv_inv_cf_unstacked = unstack(rpv_inv_cf, :date, :id_gen, :value)
      rpv_mod_cf_unstacked = unstack(rpv_mod_cf, :date, :id_gen, :value)
      rp_ids = unique(vcat(parse.(Int, names(select(rpv_inv_cf_unstacked, Not(:date)))), parse.(Int, names(select(rpv_mod_cf_unstacked, Not(:date))))))

      diff = year(rpv_inv_cf_unstacked.date[1]) - year(sys.timestamps[1])
      rpv_inv_cf_unstacked.date .= rpv_inv_cf_unstacked.date .- Year(diff) # Shift the dates to match the system timestamps, assuming module derating is the same
      t = findfirst(rpv_inv_cf_unstacked.date[1] .== DateTime.(collect(sys.timestamps))):findfirst(rpv_inv_cf_unstacked.date[end] .== DateTime.(collect(sys.timestamps)))

      for id in rp_ids
         # Find all the unit indices in the system that correspond to this generator id   
         rel_gen_idxs = findall(x -> split(x, "_")[1] == "$(id)", sys.generators.names)
         if isempty(rel_gen_idxs)
            continue
         end
         # For each of those unit indices, update the pmax timeseries with the correction factor
         correction_factor = reshape(min.(rpv_inv_cf_unstacked[!, "$(id)"], rpv_mod_cf_unstacked[!, "$(id)"]), 1, :)
         if any(correction_factor .< 1.0)
            n_timesteps = sum(correction_factor .< 1.0)
            @info("Derating roofPV generator $(id) for $n_timesteps timesteps.")
            sys.generators.capacity[rel_gen_idxs, t] .= round.(Int, sys.generators.capacity[rel_gen_idxs, t] .* correction_factor)
         end
      end
   end


   #%%
   # ==========================================================================
   # THERMAL DERATING - min(original capacity, new derated capacity)
   # ==========================================================================
   # 
   file_id = findfirst(occursin.(r"generator_cf_thermal", lowercase.(resil_files)))
   if isnothing(file_id)
      @warn("No thermal derating file found with name containing 'generator_cf_thermal'. Skipping thermal derating.")
   else
      @info("Derating thermal generators using file:\n$(joinpath(resilience_folder, resil_files[file_id]))")
      t_cf = PRASNEM.read_timeseries_file(joinpath(resilience_folder, resil_files[file_id])) # CF here is "correction factor"
      t_cf_unstacked = unstack(t_cf, :date, :id_gen, :value)
      t_ids = parse.(Int, names(select(t_cf_unstacked, Not(:date))))

      diff = year(t_cf_unstacked.date[1]) - year(sys.timestamps[1])
      t_cf_unstacked.date .= t_cf_unstacked.date .- Year(diff) # Shift the dates to match the system timestamps
      t = findfirst(t_cf_unstacked.date[1] .== DateTime.(collect(sys.timestamps))):findfirst(t_cf_unstacked.date[end] .== DateTime.(collect(sys.timestamps)))

      for id in t_ids
         # Find all the unit indices in the system that correspond to this generator id   
         rel_gen_idxs = findall(x -> split(x, "_")[1] == "$(id)", sys.generators.names)
         if isempty(rel_gen_idxs)
            continue
         end
         # For each of those unit indices, update the pmax timeseries with the correction factor
         new_cap = round.(Int, gen_cap[rel_gen_idxs] .* reshape(t_cf_unstacked[!, "$(id)"], 1, :))
         if any(new_cap .< sys.generators.capacity[rel_gen_idxs, t])
               n_timesteps = sum(new_cap .< sys.generators.capacity[rel_gen_idxs, t])
               @info("Derating thermal generator $(id) for $(n_timesteps) timesteps*units.")
               sys.generators.capacity[rel_gen_idxs, t] .= min.(sys.generators.capacity[rel_gen_idxs, t], new_cap)
         end
      end
   end



   return sys

end
