function test_dantzig_wolfe_different()
    d = GapToyData(5, 2)
    @testset "Classic GAP" begin
        model, x, cov, knp, dec = generalized_assignement(d)
        try
            JuMP.optimize!(model)
        catch e
            @test e isa NoOptimizer
        end
        cov_ann = BD.annotation(model, cov[1])
        test_annotation(cov_ann, BD.Master, BD.DantzigWolfe, 1, 1)
        x_ann = BD.annotation(model, x[1,1])
        test_annotation(x_ann, BD.DwPricingSp, BD.DantzigWolfe, 0, 1)
        knp_ann = BD.annotation(model, knp[1])
        test_annotation(knp_ann, BD.DwPricingSp, BD.DantzigWolfe, 0, 1)

        master = getmaster(dec)
        @test repr(master) == "Master formulation.\n"

        subproblems = getsubproblems(dec)
        @test repr(subproblems[1]) == "Subproblem formulation for Machines = 1 contains :\t 0.0 <= multiplicity <= 1.0\n"

        tree = gettree(model)
        @test gettree(model) == gettree(dec)

        @test repr(dec) == "Root - Annotation(BlockDecomposition.Master, BlockDecomposition.DantzigWolfe, lm = 1.0, um = 1.0, id = 2) with 2 subproblems :\n\t 2 => Annotation(BlockDecomposition.DwPricingSp, BlockDecomposition.DantzigWolfe, lm = 0.0, um = 1.0, id = 4) \n\t 1 => Annotation(BlockDecomposition.DwPricingSp, BlockDecomposition.DantzigWolfe, lm = 0.0, um = 1.0, id = 3) \n"
    end

    @testset "GAP + Pure master vars + Constr & Var without index" begin
        model, x, y, z, cov, knp, lim, dwd = generalized_assignement_penalties(d)
        try
            JuMP.optimize!(model)
        catch e
            @test e isa NoOptimizer
        end
        y_ann = BD.annotation(model, y[1])
        test_annotation(y_ann, BD.Master, BD.DantzigWolfe, 1, 1)
        z_ann = BD.annotation(model, z)
        test_annotation(z_ann, BD.Master, BD.DantzigWolfe, 1, 1)
        lim_ann = BD.annotation(model, lim)
        test_annotation(lim_ann, BD.Master, BD.DantzigWolfe, 1, 1) 
    end
    return
end

function test_dantzig_wolfe_identical()
    @testset "CS" begin
        d = CsToyData(3, 10)
        model, x, y, cov, knp, dec = cutting_stock(d)
        try
            JuMP.optimize!(model)
        catch e
            @test e isa NoOptimizer
        end
        y_ann1 = BD.annotation(model, y[1])
        test_annotation(y_ann1, BD.DwPricingSp, BD.DantzigWolfe, 0, d.nb_sheets[1])
        knp_ann = BD.annotation(model, knp[1])
        @test knp_ann == y_ann1
        x_ann = BD.annotation(model, x[1,5])
        @test x_ann == y_ann1
    end
    return
end

function dummymodel1()
    model = BD.BlockModel()
    BD.@axis(A, 1:5)
    @variable(model, y[1:5] >= 0)
    @variable(model, z[A, 1:10], Int)
    @constraint(model, fix[i in 1:5], y[i] == 1)
    @constraint(model, cov, sum(z[a, i] for a in A, i in 1:10) == 5)
    @constraint(model, knp[a in A], sum(z[a, i] for i in 1:10) <= 3)
    BD.@dantzig_wolfe_decomposition(model, dec, A)
    return model, y, z, fix, cov, knp, dec
end

function dummymodel2()
    model = BD.BlockModel()
    BD.@axis(A, 1:5)
    B = 1:4
    C = [2:(b+5) for b in B]
    @variable(model, x[a in A, b in B, c in C[b]], Int)
    @constraint(model, sp[a in A, b in B], sum(x[a,b,c] for c in C[b]) >= 1)
    @constraint(model, mast, sum(x[a,b,c] for a in A, b in B, c in C[b]) == 2)
    @objective(model, Min, sum(x[a,b,c] for a in A, b in B, c in C[b]))
    @dantzig_wolfe_decomposition(model, dec, A)
    return model, x, sp, mast, dec
end

function test_dummy_model_decompositions()
    @testset "Model with Arrays" begin
        model, y, z, fix, cov, knp, dec = dummymodel1()
        try 
            JuMP.optimize!(model)
        catch e
            @test e isa NoOptimizer
        end
        fix_ann = BD.annotation(model, fix[1])
        test_annotation(fix_ann, BD.Master, BD.DantzigWolfe, 1, 1)
        y_ann = BD.annotation(model, y[1])
        test_annotation(y_ann, BD.Master, BD.DantzigWolfe, 1, 1)
    end

    @testset "Model with SparseAxis" begin
        model, x, sp, mast, dec = dummymodel2()
        try 
            JuMP.optimize!(model)
        catch e
            @test e isa NoOptimizer
        end
        x1_ann = BD.annotation(model, x[1,1,3])
        test_annotation(x1_ann, BD.DwPricingSp, BD.DantzigWolfe, 1, 1)
        x2_ann = BD.annotation(model, x[2,3,4])
        test_annotation(x2_ann, BD.DwPricingSp, BD.DantzigWolfe, 1, 1)
        @test BD.getid(x1_ann) != BD.getid(x2_ann)
    end
    return
end
