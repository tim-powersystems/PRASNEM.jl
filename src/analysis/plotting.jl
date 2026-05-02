"""
   plot_PRAS_dispatch(sys, samples=100, selected_sample, idx_start, idx_end; seed::Int=1, regions=[], filename="./_temp.png")

Runs a PRAS assessment for the given system and samples, and then plots the dispatch for the selected sample and regions. The plot is saved to the specified filename.
"""
function plot_PRAS_dispatch(sys, samples, selected_sample, idx_start, idx_end; seed::Int=1, regions=[], filename="")
   if isempty(regions)
      regions = collect(1:length(sys.regions.names))
   end

   # Run pras for the selected seed and sample
   simspecs = SequentialMonteCarlo(samples=samples, seed=seed)
   resspecs = (ShortfallSamples(),StorageEnergySamples(), GeneratorStorageEnergySamples(), GeneratorAvailability(), FlowSamples(), DemandResponseEnergySamples(), SurplusSamples())
   sf, se, gse, genAv, f, drborrow, sp = assess(sys, simspecs, resspecs...)

   sample = selected_sample
   plt = plot_PRAS_results(sys, sf, se, gse, genAv,  f, drborrow, sp, sample, idx_start, idx_end; regions=regions, filename=filename)
   return plt
end

"""
   plot_PRAS_results(sys, sf, se, gse, genAv,f, drborrow, sp, sample, idx_start, idx_end; regions=[], filename="")

Plots the PRAS dispatch from the given system and results for the selected sample and regions. The plot is saved to the specified filename.
"""
function plot_PRAS_results(sys, sf, se, gse, genAv, f, dre, sp, sample, idx_start, idx_end; regions=[], filename="")
   if isempty(regions)
      regions = collect(1:length(sys.regions.names))
   end

   # Get all the relevant indices for the selected regions
   idxs_genstors = vcat(sys.region_genstor_idxs[regions]...)
   idxs_stors = vcat(sys.region_stor_idxs[regions]...)
   idxs_interfaces_to = findall(x -> x in regions, sys.interfaces.regions_to)
   idxs_interfaces_from = findall(x -> x in regions, sys.interfaces.regions_from)
   idxs_interfaces_within = intersect(idxs_interfaces_to, idxs_interfaces_from)
   idxs_interfaces_to = setdiff(idxs_interfaces_to, idxs_interfaces_within)
   idxs_interfaces_from = setdiff(idxs_interfaces_from, idxs_interfaces_within)
   idxs_gens = vcat(sys.region_gen_idxs[regions]...)
   idxs_drs = vcat(sys.region_dr_idxs[regions]...)

   # Calculate all the relevant capacities
   gen_cap = sum(genAv.available[idxs_gens,idx_start:idx_end, sample] .* sys.generators.capacity[idxs_gens,idx_start:idx_end], dims=1)[:]
   genstor_cap = sum(min.((gse.energy[idxs_genstors,idx_start-1:idx_end-1, sample] .+ sys.generatorstorages.inflow[idxs_genstors,idx_start:idx_end]) .* sys.generatorstorages.discharge_efficiency[idxs_genstors,idx_start:idx_end], sys.generatorstorages.discharge_capacity[idxs_genstors,idx_start:idx_end]), dims=1)[:]
   stor_cap = sum(min.(se.energy[idxs_stors,idx_start-1:idx_end-1, sample], sys.storages.discharge_capacity[idxs_stors,idx_start:idx_end]), dims=1)[:]
   genstor_disch = sum(round.(Int,(gse.energy[idxs_genstors,idx_start-1:idx_end-1, sample] .- gse.energy[idxs_genstors,idx_start:idx_end, sample] .+ sys.generatorstorages.inflow[idxs_genstors,idx_start:idx_end]) .* sys.generatorstorages.discharge_efficiency[idxs_genstors,idx_start:idx_end]), dims=1)[:]
   stor_disch = sum(round.(Int,(se.energy[idxs_stors,idx_start-1:idx_end-1, sample] .- se.energy[idxs_stors,idx_start:idx_end, sample]) .* sys.storages.discharge_efficiency[idxs_stors,idx_start:idx_end]), dims=1)[:]
   inflows = sum(f.flow[idxs_interfaces_to, idx_start:idx_end, sample], dims=1)[:] .- sum(f.flow[idxs_interfaces_from, idx_start:idx_end, sample], dims=1)[:]
   shortfl = sum(sf.shortfall[regions,idx_start:idx_end, sample], dims=1)[:]
   dr = sum(round.(Int,(dre.energy[idxs_drs,idx_start:idx_end, sample] .- dre.energy[idxs_drs,idx_start-1:idx_end-1, sample] .* (1 .+ sys.demandresponses.borrowed_energy_interest[idxs_drs,idx_start:idx_end])) .* sys.demandresponses.borrow_efficiency[idxs_drs,idx_start:idx_end]), dims=1)[:]
   dem = sum(sys.regions.load[regions,idx_start:idx_end], dims=1)[:]

   # Need to calculate the actual generator dispatch based on the "suplus"
   sp_actual = sum(sp.surplus[regions,idx_start:idx_end, sample], dims=1)[:]
   sp_remaining = sp_actual .- genstor_cap .- stor_cap .+ max.(0, genstor_disch) .+ max.(0, stor_disch)

   # Create the stack
   stack = [(gen_cap .- sp_remaining) genstor_disch stor_disch inflows shortfl dr]
   stack_pos = copy(stack); stack_pos[stack .< 0.0] .= 0.0
   stack_neg = copy(stack); stack_neg[stack .> 0.0] .= 0.0
   labs = ["Generation" "Hydro" "Battery" "Import/Exports" "Shortfall" "DR"]

   x = vcat(repeat(0.5:1.0:length(idx_start:idx_end), inner=2)[2:end], length(idx_start:idx_end) + 0.5)
   y_pos = hcat([repeat(stack_pos[:,i], inner=2) for i in 1:size(stack,2)]...)
   y_neg = hcat([repeat(stack_neg[:,i], inner=2) for i in 1:size(stack,2)]...)
   y_dem = repeat(dem, inner=2)
   y_dem_net = repeat(dem .- dr, inner=2)

   plt = Plots.areaplot(x, y_pos ./ 1e3, label=labs, color=[:grey 10 11 3 :red :orange], fillalpha=0.8, lw=0, palette=:Spectral_11)
   Plots.areaplot!(plt, x, y_neg ./ 1e3, label="", color=[:grey 10 11 3 :red :orange], fillalpha=0.8, lw=0, palette=:Spectral_11)
   Plots.plot!(x, y_dem ./ 1e3, label="Demand", color=:black, linewidth=3, legend=:bottomleft, linestyle=:dot)
   Plots.plot!(x, y_dem_net ./ 1e3, label="Net Demand", color=:black, linewidth=3)  
   Plots.xticks!(plt, 1:length(idx_start:idx_end), string.(idx_start:idx_end))
   Plots.xlabel!(plt, "Timestep")
   Plots.ylabel!(plt, "Power [GW]")
   Plots.title!(plt, "Sample $sample, Regions $(regions), PRAS dispatch")

   if filename != ""
      Plots.savefig(filename)
   end

   return plt
end

