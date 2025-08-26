using Test
using PRASNEM
using PRAS

@testset "Create System Tests" begin
    data_dir = "../src/sample_data/nem12"
    generator_input_file = joinpath(data_dir, "Generator.csv")
    timeseries_folder = joinpath(data_dir, "schedule-24h")

    
    start_dt = DateTime("2025-01-07 00:00:00", dateformat"yyyy-mm-dd HH:MM:SS")
    end_dt = DateTime("2025-01-07 02:00:00", dateformat"yyyy-mm-dd HH:MM:SS")
    units = (N = 3, L = 1, T = Hour, P = MW, E=MWh)
    regions_selected = []
    gens, gen_region_attribution = createGenerators(generator_input_file, timeseries_folder, units, regions_selected, start_dt, end_dt)


    @test size(gens.capacity)[2] == units.N
    @test typeof(gens) == Generators{units.N, units.L, units.T, units.P}
end