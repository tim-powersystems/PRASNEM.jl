function get_added_lines_per_year(scenario::Int)

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