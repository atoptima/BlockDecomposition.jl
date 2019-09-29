build_master_moi_optimizer() = nothing
build_sp_moi_optimizer() = nothing

function test_assignsolver()

    @testset "Assign default MOI mip solver" begin
        d = GapToyData(5, 2)
        model, x, cov, knp, dec = generalized_assignement(d)
        master = getmaster(dec)
        subproblems = getsubproblems(dec)
        assignsolver!(master, build_master_moi_optimizer)
        for sp in subproblems
            assignsolver!(sp, build_sp_moi_optimizer)
        end
        @test BD.getoptimizerbuilder(master.annotation) == build_master_moi_optimizer
        @test BD.getoptimizerbuilder(subproblems[1].annotation) == build_sp_moi_optimizer
    end
end