sp_pricing_oracle() = nothing

function test_assignsolver()

    @testset "Assign default MOI mip solver" begin
        d = GapToyData(5, 2)
        model, x, cov, knp, dec = generalized_assignement(d)
        master = getmaster(dec)
        subproblems = getsubproblems(dec)

        specify!.(subproblems, solver = sp_pricing_oracle)
        @test BD.getoptimizerbuilder(subproblems[1].annotation) == sp_pricing_oracle
        specify!(subproblems[2], solver = nothing)
        @test BD.getoptimizerbuilder(subproblems[2].annotation) === nothing
    end
end