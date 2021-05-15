sp_pricing_oracle() = nothing

struct MockOptimizer <: MOI.AbstractOptimizer end

MOI.is_empty(model::MockOptimizer) = true

function test_assignsolver()

    @testset "Assign default MOI mip solver" begin
        d = GapToyData(5, 3)
        model, x, cov, knp, dec = generalized_assignement(d)
        master = getmaster(dec)
        subproblems = getsubproblems(dec)

        specify!.(subproblems, solver = sp_pricing_oracle)
        @test BD.getoptimizerbuilders(subproblems[1].annotation) == [sp_pricing_oracle]
        specify!(subproblems[2], solver = nothing)
        @test BD.getoptimizerbuilders(subproblems[2].annotation) == []
        specify!(subproblems[3], solver = MockOptimizer)
        @test BD.getoptimizerbuilders(subproblems[3].annotation) == [MockOptimizer()]
        specify!(subproblems[1], solver = [sp_pricing_oracle, MockOptimizer])
        @test BD.getoptimizerbuilders(subproblems[1].annotation) == [sp_pricing_oracle, MockOptimizer()]
    end
end