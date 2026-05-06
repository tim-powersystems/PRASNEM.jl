"""
    get_added_lines_per_year(;scenario::Int=2)

Function to get the lines to be added per year based on the actionable and anticipated projects per the ISP.

"""
function get_added_lines_per_year(;scenario::Int=2)

    if scenario == 2
        # Define lines to be added per year based on scenario assumptions
        added_lines_per_year = Dict(
            2025 => [],
            2026 => [],
            2027 => ["NL_86_INV30"], # HumeLink
            2028 => ["NL_86_INV30"], 
            2029 => ["NL_86_INV30", "NL_67_INV19", "NL_23_INV3"], # Sydney Ring North, Gladstone Grid Reinforcement
            2030 => ["NL_86_INV30", "NL_67_INV19", "NL_23_INV3", "VNI North", "VNI South", "NL_98_INV34"], #  VNI + VNI West
            2031 => ["NL_86_INV30", "NL_67_INV19", "NL_23_INV3", "VNI North", "VNI South", "NL_98_INV34", "NL_109_INV35"], #  Marinus Link Stage 1
            2032 => ["NL_86_INV30", "NL_67_INV19", "NL_23_INV3", "VNI North", "VNI South", "NL_98_INV34", "NL_109_INV35", "NL_42_INV8"], # QLD SuperGrid South 
            2033 => ["NL_86_INV30", "NL_67_INV19", "NL_23_INV3", "VNI North", "VNI South", "NL_98_INV34", "NL_109_INV35", "NL_42_INV8", "NL_109_INV36", "NL_54_INV10"], # Marinus Link Stage 2, QNI Connect
            2034 => ["NL_86_INV30", "NL_67_INV19", "NL_23_INV3", "VNI North", "VNI South", "NL_98_INV34", "NL_109_INV35", "NL_42_INV8", "NL_109_INV36", "NL_54_INV10"],
            2035 => ["NL_86_INV30", "NL_67_INV19", "NL_23_INV3", "VNI North", "VNI South", "NL_98_INV34", "NL_109_INV35", "NL_42_INV8", "NL_109_INV36", "NL_54_INV10"],
            2036 => ["NL_86_INV30", "NL_67_INV19", "NL_23_INV3", "VNI North", "VNI South", "NL_98_INV34", "NL_109_INV35", "NL_42_INV8", "NL_109_INV36", "NL_54_INV10"],
            2037 => ["NL_86_INV30", "NL_67_INV19", "NL_23_INV3", "VNI North", "VNI South", "NL_98_INV34", "NL_109_INV35", "NL_42_INV8", "NL_109_INV36", "NL_54_INV10"],
            2038 => ["NL_86_INV30", "NL_67_INV19", "NL_23_INV3", "VNI North", "VNI South", "NL_98_INV34", "NL_109_INV35", "NL_42_INV8", "NL_109_INV36", "NL_54_INV10"],
            2039 => ["NL_86_INV30", "NL_67_INV19", "NL_23_INV3", "VNI North", "VNI South", "NL_98_INV34", "NL_109_INV35", "NL_42_INV8", "NL_109_INV36", "NL_54_INV10"],
            2040 => ["NL_86_INV30", "NL_67_INV19", "NL_23_INV3", "VNI North", "VNI South", "NL_98_INV34", "NL_109_INV35", "NL_42_INV8", "NL_109_INV36", "NL_54_INV10"],
            2041 => ["NL_86_INV30", "NL_67_INV19", "NL_23_INV3", "VNI North", "VNI South", "NL_98_INV34", "NL_109_INV35", "NL_42_INV8", "NL_109_INV36", "NL_54_INV10"],
            2042 => ["NL_86_INV30", "NL_67_INV19", "NL_23_INV3", "VNI North", "VNI South", "NL_98_INV34", "NL_109_INV35", "NL_42_INV8", "NL_109_INV36", "NL_54_INV10"],
            2043 => ["NL_86_INV30", "NL_67_INV19", "NL_23_INV3", "VNI North", "VNI South", "NL_98_INV34", "NL_109_INV35", "NL_42_INV8", "NL_109_INV36", "NL_54_INV10"],
            2044 => ["NL_86_INV30", "NL_67_INV19", "NL_23_INV3", "VNI North", "VNI South", "NL_98_INV34", "NL_109_INV35", "NL_42_INV8", "NL_109_INV36", "NL_54_INV10"],
            2045 => ["NL_86_INV30", "NL_67_INV19", "NL_23_INV3", "VNI North", "VNI South", "NL_98_INV34", "NL_109_INV35", "NL_42_INV8", "NL_109_INV36", "NL_54_INV10"],
            2046 => ["NL_86_INV30", "NL_67_INV19", "NL_23_INV3", "VNI North", "VNI South", "NL_98_INV34", "NL_109_INV35", "NL_42_INV8", "NL_109_INV36", "NL_54_INV10"],
            2047 => ["NL_86_INV30", "NL_67_INV19", "NL_23_INV3", "VNI North", "VNI South", "NL_98_INV34", "NL_109_INV35", "NL_42_INV8", "NL_109_INV36", "NL_54_INV10"],
            2048 => ["NL_86_INV30", "NL_67_INV19", "NL_23_INV3", "VNI North", "VNI South", "NL_98_INV34", "NL_109_INV35", "NL_42_INV8", "NL_109_INV36", "NL_54_INV10"],
            2049 => ["NL_86_INV30", "NL_67_INV19", "NL_23_INV3", "VNI North", "VNI South", "NL_98_INV34", "NL_109_INV35", "NL_42_INV8", "NL_109_INV36", "NL_54_INV10"],
            2050 => ["NL_86_INV30", "NL_67_INV19", "NL_23_INV3", "VNI North", "VNI South", "NL_98_INV34", "NL_109_INV35", "NL_42_INV8", "NL_109_INV36", "NL_54_INV10"])
    else
        @error("Line addition assumptions for scenario $scenario not defined.")
    end

    return added_lines_per_year
end

"""
    get_DER_parameters(; case="base")

Function to get predefined DER parameters for different cases, as outlined in the final report.

"""
function get_DER_parameters(; case="base")

    if case == "base"
        return Dict(
            "RoofPV"=>true, # For PRASNEM (if false, RoofPV generation units are excluded)
            "DSP_flexibility"=>false, # For PRASNEM and SchedNEM
                "DSP_interest"=>-1.0,  # default value
                "DSP_payback_before_borrowing"=>false, # Only relevant for SchedNEM
                "DSP_limit_energy_per_window"=>Dict("enabled" => true,
                    "max_energy_time_window" => 24, 
                    "max_energy_per_window_per_capacity" => 3.0, 
                    "limits_on_price_bands" => [0] # Price band 0 is for the reliability response, other prices are (300, 500, 1000, 7500)
                    ),
            "EV_charge_flexibility"=>false, # For PRASNEM and SchedNEM
                "EV_payback_window"=>10, 
                "EV_interest"=>0.0, # default value
                "EV_max_energy_factor"=>100.0, # This is to define the capacity of the DSP in each time step (e.g. the "storage energy capacity" of the EV)
                "EV_payback_before_borrowing"=>false, # Only relevant for SchedNEM
                "EV_limit_energy_per_window"=>Dict("enabled" => false,
                    "max_energy_time_window" => 24, 
                    "max_energy_per_window_per_capacity" => 24.0
                    ),
            "VPP_flexibility"=>false, # For PRASNEM and SchedNEM (if false, VPP storage units are disabled by setting their capacities to zero) 
            )
    elseif case == "demand_response"
        return Dict(
            "RoofPV"=>true, # For PRASNEM (if false, RoofPV generation units are excluded)
            "DSP_flexibility"=>true, # For PRASNEM and SchedNEM
                "DSP_interest"=>-1.0,  # default value
                "DSP_payback_before_borrowing"=>false, # Only relevant for SchedNEM
                "DSP_limit_energy_per_window"=>Dict("enabled" => true,
                    "max_energy_time_window" => 24, 
                    "max_energy_per_window_per_capacity" => 3.0, 
                    "limits_on_price_bands" => [0] # Price band 0 is for the reliability response, other prices are (300, 500, 1000, 7500)
                    ),
            "EV_charge_flexibility"=>false, # For PRASNEM and SchedNEM
                "EV_payback_window"=>10, 
                "EV_interest"=>0.0, # default value
                "EV_max_energy_factor"=>100.0, # This is to define the capacity of the DSP in each time step (e.g. the "storage energy capacity" of the EV)
                "EV_payback_before_borrowing"=>false, # Only relevant for SchedNEM
                "EV_limit_energy_per_window"=>Dict("enabled" => false,
                    "max_energy_time_window" => 24, 
                    "max_energy_per_window_per_capacity" => 24.0
                    ),
            "VPP_flexibility"=>false, # For PRASNEM and SchedNEM (if false, VPP storage units are disabled by setting their capacities to zero) 
            )
    elseif case == "coordination"
        return Dict(
            "RoofPV"=>true, # For PRASNEM (if false, RoofPV generation units are excluded)
            "DSP_flexibility"=>true, # For PRASNEM and SchedNEM
                "DSP_payback_window"=>24, 
                "DSP_interest"=>-1.0, 
                "DSP_max_energy_factor"=>2.0, # This is to define the capacity of the DSP in each time step (e.g. the "storage energy capacity" of the DSP)
                "DSP_payback_before_borrowing"=>false, # Only relevant for SchedNEM
                "DSP_limit_energy_per_window"=>Dict("enabled" => false,
                    "max_energy_time_window" => 24, 
                    "max_energy_per_window_per_capacity" => 3.0, 
                    "limits_on_price_bands" => [0] # Price band 0 is for the reliability response, other prices are (300, 500, 1000, 7500)
                    ),
            "EV_charge_flexibility"=>true, # For PRASNEM and SchedNEM
                "EV_payback_window"=>10, 
                "EV_interest"=>0.0, 
                "EV_max_energy_factor"=>100.0, # This is to define the capacity of the DSP in each time step (e.g. the "storage energy capacity" of the EV)
                "EV_payback_before_borrowing"=>false, # Only relevant for SchedNEM
                "EV_limit_energy_per_window"=>Dict("enabled" => false,
                    "max_energy_time_window" => 24, 
                    "max_energy_per_window_per_capacity" => 24.0
                    ),
            "VPP_flexibility"=>true # For PRASNEM and SchedNEM (if false, VPP storage units are disabled by setting their capacities to zero) 
            )
    else
        error("DER parameter case not recognised.")
    end
end

"""

    get_default_hydro_parameters(;case="base")

Function to get the default hydro parameters for hydro generators and genstorages, which can be updated based on scenario assumptions.
"""
function get_hydro_parameters(;case="base")

    if case == "base"
        hydro_parameters = Dict{String, Any}()
        # Reservoirs sizes
        hydro_parameters["reservoir_discharge_time_units"] = Dict{String, Any}("GORDON" => 10000, "POAT110" => 20000, 
                            "MURRAY1" => 2100, "UPPTUMUT" => 2100, "MCKAY1" => 300) # This is the amount of timesteps that the reservoir can discharge at full capacity. 
        hydro_parameters["reservoir_discharge_time_states"] = Dict{Int, Any}(3 => 200, 4 => 2000) # 3 - VIC, 4 - TAS
        hydro_parameters["reservoir_discharge_time_other"] = 200 # Default assumption for all other reservoirs
        hydro_parameters["reservoir_initial_soc_units"] = Dict{String, Any}("GORDON" => 0.4, "POAT110" => 0.3, 
                    "MURRAY1" => 0.5, "UPPTUMUT" => 0.5, "MCKAY1" => 0.5) # As a factor of the maximum energy capacity (e.g. 0.5 means 50% initial SOC)
        hydro_parameters["reservoir_initial_soc_states"] = Dict{Int, Any}(3 => 0.5, 4 => 0.6) # As a factor of the maximum energy capacity (e.g. 0.5 means 50% initial SOC)
        hydro_parameters["reservoir_initial_soc_other"] = 0.5 # As a factor of the maximum energy capacity (e.g. 0.5 means 50% initial SOC)
        # Pumped Hydro assumptions
        hydro_parameters["pumped_hydro_initial_soc"] = 0.5 # As a factor of the maximum energy capacity (e.g. 0.5 means 50% initial SOC)
        # Run-of-river assumptions
        hydro_parameters["run_of_river_discharge_time"] = 0 # This is the amount of timesteps that the run-of-river can discharge at full capacity (e.g. 0 = no storage)
        hydro_parameters["run_of_river_discharge_efficiency"] = 1.0
        hydro_parameters["run_of_river_carryover_efficiency"] = 1.0 # Irrelevant when discharge time is zero anyway
        # Further reservoir assumptions
        hydro_parameters["reservoir_discharge_efficiency"] = 1.0
        hydro_parameters["reservoir_carryover_efficiency"] = 1.0
        # Default inflow assumptions
        hydro_parameters["default_static_inflow"] = 0.0 # As a factor of grid injection power capacity

        # Additional parameters for SchedNEM
        hydro_parameters["hydro_discharging_cost"] = 8.58 # $/MWh
        hydro_parameters["final_soc_constraint"] = ["Reservoir"] # Whether to include a final SOC constraint for each type of hydro category (e.g. "Reservoir", "Pumped Hydro", "Run-of-River")

    else
        error("Hydro parameter case not recognised.")
    end
    
    return hydro_parameters
end

function get_min_units_per_area(;scenario=2)

    if scenario in [1,2]
        return Dict(
            2025 => Dict("coal" => Dict(1 => 11, 2 => 7, 3 => 5), "gas" => Dict(5 => 1)),
            2026 => Dict("coal" => Dict(1 => 8, 2 => 5, 3 => 3), "gas" => Dict(5 => 1)),
            2027 => Dict("coal" => Dict(1 => 6, 2 => 3, 3 => 2), "gas" => Dict(0 => 0)),
            2028 => Dict("coal" => Dict(1 => 4, 2 => 2, 3 => 2), "gas" => Dict(0 => 0)),
            2029 => Dict("coal" => Dict(1 => 3, 2 => 2, 3 => 1), "gas" => Dict(0 => 0)),
            2030 => Dict("coal" => Dict(1 => 2, 2 => 1, 3 => 1), "gas" => Dict(0 => 0)),
            2031 => Dict("coal" => Dict(1 => 1, 2 => 1), "gas" => Dict(0 => 0)),
            2032 => Dict("coal" => Dict(1 => 1), "gas" => Dict(0 => 0)),
            2033 => Dict("coal" => Dict(1 => 1), "gas" => Dict(0 => 0)),
            2034 => Dict("coal" => Dict(0 => 0), "gas" =>  Dict(0 => 0)),
            2035 => Dict("coal" => Dict(0 => 0), "gas" =>  Dict(0 => 0)),
            2036 => Dict("coal" => Dict(0 => 0), "gas" =>  Dict(0 => 0)),
            2037 => Dict("coal" => Dict(0 => 0), "gas" =>  Dict(0 => 0)),
            2038 => Dict("coal" => Dict(0 => 0), "gas" =>  Dict(0 => 0)),
            2039 => Dict("coal" => Dict(0 => 0), "gas" =>  Dict(0 => 0)),
            2040 => Dict("coal" => Dict(0 => 0), "gas" =>  Dict(0 => 0)),
            2041 => Dict("coal" => Dict(0 => 0), "gas" =>  Dict(0 => 0)),
            2042 => Dict("coal" => Dict(0 => 0), "gas" =>  Dict(0 => 0)),
            2043 => Dict("coal" => Dict(0 => 0), "gas" =>  Dict(0 => 0)),
            2044 => Dict("coal" => Dict(0 => 0), "gas" =>  Dict(0 => 0)),
            2045 => Dict("coal" => Dict(0 => 0), "gas" =>  Dict(0 => 0)),
            2046 => Dict("coal" => Dict(0 => 0), "gas" =>  Dict(0 => 0)),
            2047 => Dict("coal" => Dict(0 => 0), "gas" =>  Dict(0 => 0)),
            2048 => Dict("coal" => Dict(0 => 0), "gas" =>  Dict(0 => 0)),
            2049 => Dict("coal" => Dict(0 => 0), "gas" =>  Dict(0 => 0)),
            2050 => Dict("coal" => Dict(0 => 0), "gas" =>  Dict(0 => 0))
            )
    elseif scenario == 3
        return Dict(
            2025 => Dict("coal" => Dict(1 => 11, 2 => 7, 3 => 5), "gas" => Dict(5 => 1)),
            2026 => Dict("coal" => Dict(1 => 5, 2 => 3, 3 => 2), "gas" => Dict(5 => 1)),
            2027 => Dict("coal" => Dict(1 => 2, 2 => 1, 3 => 1), "gas" => Dict(0 => 0)),
            2028 => Dict("coal" => Dict(1 => 1), "gas" => Dict(0 => 0)),
            2029 => Dict("coal" => Dict(0 => 0), "gas" => Dict(0 => 0)),
            2030 => Dict("coal" => Dict(0 => 0), "gas" => Dict(0 => 0)),
            2031 => Dict("coal" => Dict(0 => 0), "gas" => Dict(0 => 0)),
            2032 => Dict("coal" => Dict(0 => 0), "gas" => Dict(0 => 0)),
            2033 => Dict("coal" => Dict(0 => 0), "gas" => Dict(0 => 0)),
            2034 => Dict("coal" => Dict(0 => 0), "gas" =>  Dict(0 => 0)),
            2035 => Dict("coal" => Dict(0 => 0), "gas" =>  Dict(0 => 0)),
            2036 => Dict("coal" => Dict(0 => 0), "gas" =>  Dict(0 => 0)),
            2037 => Dict("coal" => Dict(0 => 0), "gas" =>  Dict(0 => 0)),
            2038 => Dict("coal" => Dict(0 => 0), "gas" =>  Dict(0 => 0)),
            2039 => Dict("coal" => Dict(0 => 0), "gas" =>  Dict(0 => 0)),
            2040 => Dict("coal" => Dict(0 => 0), "gas" =>  Dict(0 => 0)),
            2041 => Dict("coal" => Dict(0 => 0), "gas" =>  Dict(0 => 0)),
            2042 => Dict("coal" => Dict(0 => 0), "gas" =>  Dict(0 => 0)),
            2043 => Dict("coal" => Dict(0 => 0), "gas" =>  Dict(0 => 0)),
            2044 => Dict("coal" => Dict(0 => 0), "gas" =>  Dict(0 => 0)),
            2045 => Dict("coal" => Dict(0 => 0), "gas" =>  Dict(0 => 0)),
            2046 => Dict("coal" => Dict(0 => 0), "gas" =>  Dict(0 => 0)),
            2047 => Dict("coal" => Dict(0 => 0), "gas" =>  Dict(0 => 0)),
            2048 => Dict("coal" => Dict(0 => 0), "gas" =>  Dict(0 => 0)),
            2049 => Dict("coal" => Dict(0 => 0), "gas" =>  Dict(0 => 0)),
            2050 => Dict("coal" => Dict(0 => 0), "gas" =>  Dict(0 => 0))
            )
    else
        error("Minimum units per area case not recognised.")
    end
end