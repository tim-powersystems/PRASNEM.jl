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
            2030 => ["NL_86_INV30", "NL_67_INV19", "NL_23_INV3", "NL_109_INV35", "VNI North", "VNI South", "NL_98_INV34"], # Marinus Link Stage 1, VNI + VNI West
            2031 => ["NL_86_INV30", "NL_67_INV19", "NL_23_INV3", "NL_109_INV35", "VNI North", "VNI South", "NL_98_INV34"],
            2032 => ["NL_86_INV30", "NL_67_INV19", "NL_23_INV3", "NL_109_INV35", "VNI North", "VNI South", "NL_98_INV34", "NL_42_INV8"], # QLD SuperGrid South
            2033 => ["NL_86_INV30", "NL_67_INV19", "NL_23_INV3", "NL_109_INV35", "VNI North", "VNI South", "NL_98_INV34", "NL_42_INV8", "NL_109_INV36"], # Marinus Link Stage 2
            2034 => ["NL_86_INV30", "NL_67_INV19", "NL_23_INV3", "NL_109_INV35", "VNI North", "VNI South", "NL_98_INV34", "NL_42_INV8", "NL_109_INV36", "NL_54_INV10"], # QNI Connect
            2035 => ["NL_86_INV30", "NL_67_INV19", "NL_23_INV3", "NL_109_INV35", "VNI North", "VNI South", "NL_98_INV34", "NL_42_INV8", "NL_109_INV36", "NL_54_INV10"]
            )
    else
        error("Line addition assumptions for scenario $scenario not defined.")
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
            "DSP_flexibility"=>true, # For PRASNEM and SchedNEM
                "DSP_payback_window"=>24, 
                "DSP_interest"=>-1.0, 
                "DSP_max_energy_factor"=>2.0, # This is to define the capacity of the DSP in each time step (e.g. the "storage energy capacity" of the DSP)
                "DSP_payback_before_borrowing"=>false, # Only relevant for SchedNEM
                "DSP_limit_energy_per_window"=>Dict("enabled" => true,
                    "max_energy_time_window" => 24, 
                    "max_energy_per_window_per_capacity" => 3.0, 
                    "limits_on_price_bands" => [0] # Price band 0 is for the reliability response, other prices are (300, 500, 1000, 7500)
                    ),
            "EV_charge_flexibility"=>false, # For PRASNEM and SchedNEM
                "EV_payback_window"=>10, 
                "EV_interest"=>0.0, 
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