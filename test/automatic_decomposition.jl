function test_automatic_decomposition()
    @testset "Example AP automatic decomposition" begin
        model, x, cov, knp, dec, Axis = example_assignment_automatic_decomposition()
        try
            JuMP.optimize!(model)
        catch e
            @test e isa NoOptimizer
        end
        for variableref in JuMP.all_variables(model)
            x_ann = BD.annotation(model, variableref)
            test_annotation(x_ann, BD.Master, BD.DantzigWolfe, 1, 1)
        end
        for constraintref in model.ext[:decomposition_structure].master_constraints
            x_ann = BD.annotation(model, xconstraintref)
            test_annotation(x_ann, BD.Master, BD.DantzigWolfe, 0, 1)
        end
        for block in model.ext[:decomposition_structure].blocks
            for constraintref in block
                x_ann = BD.annotation(model, constraintref)
                test_annotation(x_ann, BD.DwPricingSp, BD.DantzigWolfe, 0, 1)
            end
        end
        master = getmaster(dec)
        @test repr(master) == "Master formulation.\n"
        
        subproblems = getsubproblems(dec)
        @test repr(subproblems[1]) == "Subproblem formulation for  = 1 contains :\t 0.0 <= multiplicity <= 1.0\n"
        
        tree = gettree(model)
        @test gettree(model) == gettree(dec)
        
        @test repr(dec) == "Root - Annotation(BlockDecomposition.Master, BlockDecomposition.DantzigWolfe, lm = 1.0, um = 1.0, id = 2) with 1 subproblems :\n\t 1 => Annotation(BlockDecomposition.DwPricingSp, BlockDecomposition.DantzigWolfe, lm = 0.0, um = 1.0, id = 3) \n"
    end
    
    d = GapToyData(30,10)
    @testset "GAP automatic decomposition" begin
        model, x, cov, knp, dec, Axis = generalized_assignment_automatic_decomposition(d)
        try
            JuMP.optimize!(model)
        catch e
            @test e isa NoOptimizer
        end
        for variableref in JuMP.all_variables(model)
            x_ann = BD.annotation(model, variableref)
            test_annotation(x_ann, BD.Master, BD.DantzigWolfe, 1, 1)
        end
        for constraintref in model.ext[:decomposition_structure].master_constraints
            x_ann = BD.annotation(model, xconstraintref)
            test_annotation(x_ann, BD.Master, BD.DantzigWolfe, 0, 1)
        end
        for block in model.ext[:decomposition_structure].blocks
            for constraintref in block
                x_ann = BD.annotation(model, constraintref)
                test_annotation(x_ann, BD.DwPricingSp, BD.DantzigWolfe, 0, 1)
            end
        end
        master = getmaster(dec)
        @test repr(master) == "Master formulation.\n"
    end
end
