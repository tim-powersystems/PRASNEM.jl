"""
   updateVREDroughtLength!(sys; consecutive_days=1, consider_regions=1:12, window=24)

This function modifies the VRE generation and demand profiles in the system to simulate a VRE drought of a specified length. 
It identifies the day with the worst residual demand (demand minus VRE generation) and then sets the VRE generation and demand for the subsequent days to be the same, effectively simulating a prolonged VRE drought.

"""
function updateVREDroughtLength!(sys; consecutive_days::Int=1, regions::Vector{Int}=collect(1:12), window::Int=24, repeat_demand::Bool=false)

   if consecutive_days == 1
      @info "VRE drought length set to 1 day. No changes made to the system."
      return sys
   end

   if window != 24
      @warn "Window size of $window hours considered for extending the VRE drought days!"
   end

   # Get the VRE generation data for the specified regions
   all_vre_idxs = findall(x -> x in ["Wind", "LargePV", "RoofPV"], sys.generators.categories)
   vre_in_regions = intersect(all_vre_idxs, vcat(sys.region_gen_idxs[regions]...))
   vre = sum(sys.generators.capacity[vre_in_regions, :], dims=1)[:]
   vre_cap = sum(maximum(sys.generators.capacity[vre_in_regions, :], dims=2)[:])
   dem = sum(sys.regions.load[regions, :], dims=1)[:]

   # Calculate the residual demand
   daily_idxs = [((i-1)*window+1):min(i*window, length(sys.timestamps)) for i in 1:ceil(Int, length(sys.timestamps)/window)]
   daily_res_demand = [sum((dem .- vre)[idxs]) for idxs in daily_idxs] ./ 1e3
   daily_vre_share = [sum(vre[idxs]) / sum(dem[idxs]) for idxs in daily_idxs]
   vre_cf = [sum(vre[idxs]) / (vre_cap * window) for idxs in daily_idxs]

   # Find the worst residual demand day
   worst_day_idx = argmax(daily_res_demand)
   worst_day_start = (worst_day_idx - 1) * window + 1
   worst_day_end = worst_day_start + window - 1
   @info "Worst residual demand day in regions $regions: $(Date.(sys.timestamps[worst_day_start])) (idxs: $worst_day_start:$worst_day_end)\nResidual demand of $(round(daily_res_demand[worst_day_idx], digits=2)) GWh\nVRE share of $(round(daily_vre_share[worst_day_idx], digits=2) * 100)%\nVRE capacity factor of $(round(vre_cf[worst_day_idx], digits=2) * 100)%."

   # Set VRE generation capacity and demand to the same for the number of consecutive days specified
   vre_drought_days = 1
   for day in 1:(consecutive_days-1)
      day_start = worst_day_start + day * window
      day_end = worst_day_end + day * window
      if day_end > length(sys.timestamps)
         @warn "Not enough timestamps to set VRE drought for $(consecutive_days) consecutive days. Stopping at day $(day)."
         break
      end
      sys.generators.capacity[vre_in_regions, day_start:day_end] .= sys.generators.capacity[vre_in_regions, worst_day_start:worst_day_end]
      if repeat_demand
         sys.regions.load[regions, day_start:day_end] .= sys.regions.load[regions, worst_day_start:worst_day_end]
      end
      vre_drought_days += 1
      @info "Repeated VRE drought on day $(Date.(sys.timestamps[day_start])) $(repeat_demand ? " (VRE availability and demand)" : " (only VRE availability)")."
   end
   sys.attrs["VRE_drought_length"] = string(vre_drought_days)

   return sys
end