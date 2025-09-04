function run_pras_study(sys_input, sample_number::Int=1000)
    
    println("Using $(Threads.nthreads()) threads")

    if typeof(sys_input) == String
        println("Loading system... $(sys_input)")
        sys = SystemModel(sys_input)
    else
        sys = sys_input
    end

    #%% 
    println("Evaluating system...")
    sf,  = assess(sys, SequentialMonteCarlo(samples=sample_number), Shortfall())

    #%%
    println("Calculating metrics...")
    println(LOLE(sf))
    println(EUE(sf))
    println(NEUE(sf))

end