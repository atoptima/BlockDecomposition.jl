build_master_moi_optimizer() = nothing
build_sp_moi_optimizer() = nothing

function test_assignsolver()

    @testset "Assign default MOI mip solver" begin
        d = GapToyData(5, 2)
        model, x, cov, knp, dwd = generalized_assignement(d)
        BD.assignsolver(dwd, build_master_moi_optimizer)
        BD.assignsolver(dwd[1:2], build_sp_moi_optimizer)
        @test BD.getoptimizerbuilder(dwd) == build_master_moi_optimizer
        @test BD.getoptimizerbuilder(dwd[1]) == build_sp_moi_optimizer
        @test BD.getoptimizerbuilder(dwd[2]) == build_sp_moi_optimizer
    end

    # @testset "Assign ad-hoc callback" begin
    #     d = GapToyData(5, 2)
    #     model, x, cov, knp, dwd = generalized_assignement(d)
    #     DB.assignsolver(dwd, )

    # end

end