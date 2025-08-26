struct FilterSortTimestepData
    input_file::String
    df::DataFrame
    function FilterSortTimestepData(input_file::String)
        """
        Initializes the FilterSortTimestepData struct with an input file.
        
        Parameters:
        - input_file (str): Path to the input CSV file.
        """
        df = CSV.read(input_file, DataFrame)
        # Ensure :date column is DateTime
        if "date" in names(df)
            df.date = DateTime.(df.date, dateformat"yyyy-mm-dd HH:MM:SS")
        end
        new(input_file, df)
    end
end

function execute(
        filter_obj::FilterSortTimestepData;
        output_file::Union{Nothing, String}=nothing,
        scenarios::Union{Nothing, Vector{Int}}=nothing,
        dem_ids::Union{Nothing, Vector{Any}, Vector{Int}}=nothing,
        gen_ids::Union{Nothing, Vector{Any}, Vector{Int}}=nothing,
        start_dt::Union{Nothing, DateTime}=nothing,
        end_dt::Union{Nothing, DateTime}=nothing
    )

    df_filtered = copy(filter_obj.df)
    #println(df_filtered)

    if scenarios !== nothing && "scenario" in names(df_filtered)
        df_filtered = filter(row -> row.scenario in scenarios, df_filtered)
    end
    if dem_ids !== nothing && "dem_id" in names(df_filtered) && !isempty(dem_ids)
        df_filtered = filter(row -> row.dem_id in dem_ids, df_filtered)
    end
    if gen_ids !== nothing && "gen_id" in names(df_filtered) && !isempty(gen_ids)
        df_filtered = filter(row -> row.gen_id in gen_ids, df_filtered)
    end
    if start_dt !== nothing && "date" in names(df_filtered)
        df_filtered = filter(row -> row.date >= start_dt, df_filtered)
    end
    if end_dt !== nothing && "date" in names(df_filtered)
        df_filtered = filter(row -> row.date <= end_dt, df_filtered)
    end

    # Sorting
    if dem_ids !== nothing && "dem_id" in names(df_filtered)
        sort!(df_filtered, [:dem_id, :date])
    elseif gen_ids !== nothing && "gen_id" in names(df_filtered)
        sort!(df_filtered, [:gen_id, :date])
    end

    if output_file !== nothing
        CSV.write(output_file, df_filtered)
        println("Filtered and sorted CSV saved as $output_file")
    end
    return df_filtered
end

# Example usage:
# filter_obj = FilterSortTimestepData("Demand_load_sched.csv")
# filtered = execute(filter_obj; output_file="filtered_timestep_load.csv", scenarios=[2], dem_ids=[1,2], start_dt=DateTime("2025-07-01 00:00:00", dateformat"yyyy-mm-dd HH:MM:SS"), end_dt=DateTime("2026-06-30 23:00:00", dateformat"yyyy-mm-dd HH:MM:SS"))