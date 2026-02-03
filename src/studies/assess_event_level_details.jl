function assess_event_level_details(sys; simspec=SequentialMonteCarlo(samples=100, seed=1), include_storage::Bool=true)


    if include_storage
        resultspecs = (ShortfallSamples(), StorageEnergySamples(),);
        sfsamples, sesamples, = assess(sys, simspec, resultspecs...)
        df_res = get_all_event_details(sfsamples; sesamples=sesamples, sys=sys)
    else
        resultspecs = (ShortfallSamples(),);
        sfsamples,  = assess(sys, simspec, resultspecs...)
        df_res = get_all_event_details(sfsamples; sys=sys)
    end    

    return df_res

    
end