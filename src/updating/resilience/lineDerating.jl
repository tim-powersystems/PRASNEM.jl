"""
   apply_line_derating(sys, resilience_folder::String)

Apply line derating to the system based on the forward and reverse capacity timeseries found in the specified resilience folder. 
The function looks for files containing "line_fwcap" and "line_rvcap" in their names to identify the forward and reverse capacity correction factors, respectively. 
It then updates the line capacities in the system accordingly, ensuring that the interface flow limits are also updated to reflect the new line capacities.

Derating function: 
   min(new_capacity, old_capacity)

"""
function applyLineHeatwaveDerating!(sys, resilience_folder::String)
   @info("Applying line derating to the system...\n     Folder: $(resilience_folder)")
   
   if ispath(resilience_folder)
      resil_files = readdir(resilience_folder)
   else
      @error("Resilience folder path $(resilience_folder) does not exist. Skipping line derating.")
      return sys
   end
   
   file_id_fw = findfirst(occursin.(r"line_fwcap", lowercase.(resil_files)))
   if isnothing(file_id_fw)
      @warn("No line derating file found with name containing 'line_fwcap'. Skipping line derating.")
      return sys
   end

   file_id_rv = findfirst(occursin.(r"line_rvcap", lowercase.(resil_files)))
   if isnothing(file_id_rv)
      @warn("No line derating file found with name containing 'line_rvcap'. Skipping line derating.")
      return sys
   end

   @info("Derating lines using file:\nForward:$(joinpath(resilience_folder, resil_files[file_id_fw]))\nReverse:$(joinpath(resilience_folder, resil_files[file_id_rv]))")

   l_fwcap = PRASNEM.read_timeseries_file(joinpath(resilience_folder, resil_files[file_id_fw])) # CF here is "correction factor"
   l_rvcap = PRASNEM.read_timeseries_file(joinpath(resilience_folder, resil_files[file_id_rv])) # CF here is "correction factor"
   l_fwcap_unstacked = unstack(l_fwcap, :date, :id_lin, :value)
   l_rvcap_unstacked = unstack(l_rvcap, :date, :id_lin, :value)
   line_ids = parse.(Int, names(select(l_fwcap_unstacked, Not(:date))))
   if line_ids != parse.(Int, names(select(l_rvcap_unstacked, Not(:date))))
      @warn("Line IDs in forward and reverse capacity files do not match. Check the input files.")
   end

   # Find the right time indices in the system timestamps that correspond to the derating timeseries
   diff = year(l_fwcap_unstacked.date[1]) - year(sys.timestamps[1])
   l_fwcap_unstacked.date .= l_fwcap_unstacked.date .- Year(diff) # Shift the dates to match the system timestamps
   t = findfirst(l_fwcap_unstacked.date[1] .== DateTime.(collect(sys.timestamps))):findfirst(l_fwcap_unstacked.date[end] .== DateTime.(collect(sys.timestamps)))

   # Line derating
   for id in line_ids
      # Find all the line indices in the system that correspond to this line id   
      rel_line_idxs = findall(x -> split(x, "_")[1] == "$(id)", sys.lines.names)
      if isempty(rel_line_idxs)
         continue
      end
      # For each of those line indices, update the capacity timeseries with the correction factor
      new_fwcap = round.(Int, reshape(l_fwcap_unstacked[!, "$(id)"], 1, :))
      new_rvcap = round.(Int, reshape(l_rvcap_unstacked[!, "$(id)"], 1, :))
      if any(new_fwcap .< sys.lines.forward_capacity[rel_line_idxs, t]) .|| any(new_rvcap .< sys.lines.backward_capacity[rel_line_idxs, t])
            n_timesteps = sum(new_fwcap .< sys.lines.forward_capacity[rel_line_idxs, t])
            n_timesteps_rv = sum(new_rvcap .< sys.lines.backward_capacity[rel_line_idxs, t])
            @info("Derating line $(id) for $n_timesteps timesteps forward and $n_timesteps_rv timesteps reverse.")
            sys.lines.forward_capacity[rel_line_idxs, t] .= min.(sys.lines.forward_capacity[rel_line_idxs, t], new_fwcap)
            sys.lines.backward_capacity[rel_line_idxs, t] .= min.(sys.lines.backward_capacity[rel_line_idxs, t], new_rvcap)
      end
   end

   # Now make sure that the interface flow limits are also updated accordingly
   for i in 1:length(sys.interfaces.regions_from)
      idxs = sys.interface_line_idxs[i]
      sys.interfaces.limit_forward[i, t] .= sum(sys.lines.forward_capacity[idxs, t], dims=1)[:]
      sys.interfaces.limit_backward[i, t] .= sum(sys.lines.backward_capacity[idxs, t], dims=1)[:]
   end

   return sys
end


