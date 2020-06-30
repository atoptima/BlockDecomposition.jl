function test_automatic_decomposition()
    @testset "Example AP automatic decomposition" begin
        model, x, cov, knp, dec, Axis = example_assignment_automatic_decomposition()
        try
            JuMP.optimize!(model)
        catch e
            @test e isa NoOptimizer
        end
        # all constraints build over the set machines are master constraints
        # (due to the result of the plumple method that scores decompotions)
        machines = 1:4
        jobs = 1:30
        
        for j in jobs
            cov_ann = BD.annotation(model, cov[j])
            test_annotation(cov_ann, BD.DwPricingSp, BD.DantzigWolfe, 0, 1)
            for m in machines
                x_ann = BD.annotation(model, x[m,j])
                test_annotation(cov_ann, BD.DwPricingSp, BD.DantzigWolfe, 0, 1)
            end
        end
        for m in machines
            knp_ann = BD.annotation(model, knp[m])
            test_annotation(knp_ann, BD.Master, BD.DantzigWolfe, 1, 1)
        end
        
        master = getmaster(dec)
        @test repr(master) == "Master formulation.\n"
        
        subproblems = getsubproblems(dec)
        @test repr(subproblems[1]) == "Subproblem formulation for  = 1 contains :\t 0.0 <= multiplicity <= 1.0\n"
        
        tree = gettree(model)
        @test gettree(model) == gettree(dec)
    end
end
