include("./assess_event_level_details.jl")


function run_pras_study(sys_input; sample_number::Int=100)
    
    println("Using $(Threads.nthreads()) threads")

    if typeof(sys_input) == String
        println("Loading system... $(sys_input)")
        sys = SystemModel(sys_input)
    else
        sys = sys_input
    end

    #%% 
    println("Assessing system...")
    sf,  = assess(sys, SequentialMonteCarlo(samples=sample_number), Shortfall())

    #%%
    println("Calculating metrics...")
    println(LOLE(sf))
    println(EUE(sf))
    println(NEUE(sf))

    return sf

end