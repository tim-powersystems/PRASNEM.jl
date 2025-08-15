module PRASNEM

using PRAS
import Base.Threads

# Write your package code here.
    function run_pras_study(file_name::String, sample_number::Int=1000)
        
        println("Using $(Threads.nthreads()) threads")
        println("Loading system... $(file_name)")

        sys = SystemModel(file_name)

        #%% 
        println("Evaluating system...")
        sf,  = assess(sys, SequentialMonteCarlo(samples=sample_number), Shortfall())

        #%%
        println("Calculating LOLE and EUE...")
        println(LOLE(sf))
        println(EUE(sf))
        println(NEUE(sf))

    end

end
