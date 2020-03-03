sp_pricing_oracle() = nothing

struct MokeOptimizer <: MOI.AbstractOptimizer end

function test_assignsolver()

    @testset "Assign default MOI mip solver" begin
        d = GapToyData(5, 3)
        model, x, cov, knp, dec = generalized_assignement(d)
        master = getmaster(dec)
        subproblems = getsubproblems(dec)

        specify!.(subproblems, solver = sp_pricing_oracle)
        @test BD.getpricingoracle(subproblems[1].annotation) == sp_pricing_oracle
        @test BD.getoptimizerbuilder(subproblems[2].annotation) === nothing
        specify!(subproblems[2], solver = nothing)
        @test BD.getoptimizerbuilder(subproblems[2].annotation) === nothing
        @test BD.getpricingoracle(subproblems[2].annotation) === nothing
        specify!(subproblems[3], solver = MokeOptimizer)
        @test BD.getoptimizerbuilder(subproblems[3].annotation) == MokeOptimizer()
        @test BD.getpricingoracle(subproblems[2].annotation) === nothing
    end
end