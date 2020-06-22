function test_automatic_decomposition()
    @testset "Example GAP automatic decomposition with Coluna" begin
        model, x, cov, knp, dec, Axis = automatic_decomposition_coluna()
        JuMP.optimize!(model)
    end
end
