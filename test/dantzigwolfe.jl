function test_dantzig_wolfe_different()
    d = GapToyData(5, 2)
    @testset "Classic GAP" begin
        model, x, cov, knp, dwd = generalized_assignement(d)
        @show BD.gettree(model)
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
end

function test_dantzig_wolfe_identical()
    #d = CsToyData(1, 10)
    #m = cutting_stock(d) # Not working yet : identical subproblems
    #@show BD.gettree(m)
    #JuMP.optimize!(m)
end

function test_dantzig_wolfe_diffidentical()
    #d = CsToyData(3, 15)
    #m = cutting_stock_different_sizes(d)
    #@show BD.gettree(m)
    #JuMP.optimize!(m) # Does not work yet because JuMP creates SparseArray to store cstrs & vars
end