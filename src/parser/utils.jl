

function get_unit_region_assignment(regions_selected, bus_id_list)
    """
    Given a list of selected regions and a list of bus IDs for each unit (generator, storage, genstorage),
    this function returns a vector of ranges, where each inner vector contains the indices of units in that region.

        Note: regions_selected and bus_id_list must both be in ascending order!
    """
    # This function takes in a list of regions selected and a list of bus IDs for each unit
    unit_region_attribution = repeat([1:0], length(regions_selected))
    data = DataFrame(id_bus=bus_id_list, id_ascending=1:length(bus_id_list))
    counter = 1
    for i in 1:length(regions_selected)
        region_id = regions_selected[i]
        group = data[findall(data.id_bus .== region_id), [:id_ascending]]
        if isempty(group) && counter == 1
            unit_region_attribution[i] = 1:0 # If first region doesnt have any unit, set to empty
        elseif isempty(group)
            unit_region_attribution[i] = last(unit_region_attribution[i-1])+1:last(unit_region_attribution[i-1]) # If region doesnt have any unit, set to last index of previous region
        else
            unit_region_attribution[i] = first(group.id_ascending):last(group.id_ascending)
        end
        counter += 1
    end

    return unit_region_attribution
end


# ====================================================

function read_timeseries_file(file_path::String)
    if isfile(file_path)
        # If the file exists, read it
        timeseries_data = CSV.read(file_path, DataFrame)

        if typeof(timeseries_data.date[1]) != DateTime
            # Convert the date column to DateTime format
            timeseries_data.date = DateTime.(timeseries_data.date, dateformat"yyyy-mm-dd HH:MM:SS")
        end
        return timeseries_data
    else
        # If the file does not exist, return an error
        error("The timeseries file $file_path does not exist.")
    end
end

# ====================================================
function check_parameters(regions_selected, weather_folder, start_dt, end_dt)
    """
    Function to check if optional parameters provided are valid.
    """
    # ============= CHECKS DUE TO PRAS FUNCTIONALITY LIMITATIONS
    # Check if regions_selected is not empty
    if !isempty(regions_selected)
        # Check if regions_selected contains only integers
        if !all(x -> x isa Int, regions_selected)
            error("regions_selected must be an array of integers.")
        end
        # Check the regions_selected values are in ascending order
        if !issorted(regions_selected)
            error("regions_selected must be in ascending order.")
        end
    end


    # ============= CHECKS BECAUSE FUNCTIONALITY IS NOT IMPLEMENTED YET
    # If weather_folder is specified, check if start_dt and end_dt are in the same year (else there would be problems for now)
    if weather_folder != ""
        if year(start_dt) != year(end_dt)
            error("If weather_folder is specified, start_dt and end_dt must be in the same year.")
        end
    end

end

# ====================================================

function update_dates(df, year::Int)
    """
    Function to update the year in the date column of a DataFrame.
    """
    if isleapyear(df.date[1]) && !isleapyear(year)
        # If the original year is a leap year and the new year is not, remove Feb 29
        df = filter(row -> !(month(row.date) == 2 && day(row.date) == 29), df)
    elseif !isleapyear(df.date[1]) && isleapyear(year)
        println("INFO: Original data is not a leap year, but the target year is a leap year. Adding Feb 29 as duplicate of Feb 28.")
        # Add Feb 29 as the same as Feb 28
        feb28_rows = filter(row -> month(row.date) == 2 && day(row.date) == 28, df)
        feb29_rows = deepcopy(feb28_rows)
        feb29_rows.date .= DateTime.(year, 2, 29, hour.(feb28_rows.date), minute.(feb28_rows.date), second.(feb28_rows.date))
        df = vcat(df, feb29_rows)
        sort!(df, :date)
    end
    df.date = DateTime.(year, month.(df.date), day.(df.date), hour.(df.date), minute.(df.date), second.(df.date))
    return df
end

function update_with_weather_year(df_filtered, df_filtered_weather; timeseries_name="")

    # Check if the number of rows match
    if nrow(df_filtered) != nrow(df_filtered_weather)
        error("The number of rows in the original and weather year timeseries do not match. Please check timeseries folder selection.")
    end

    # Update the original filtered dataframe with the weather year data
    for col in names(df_filtered)
        if col == "date"
            continue
        elseif col in names(df_filtered_weather)
            df_filtered[!, col] = df_filtered_weather[!, col]
        else
            println("WARNING: Column $col in original data $timeseries_name not found in weather year data. Skipping this column.")
        end
    end

    return df_filtered
end