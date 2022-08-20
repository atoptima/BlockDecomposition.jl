function test_errors()
    master_var_in_subproblem()
    master_var_in_subproblem2()
    vars_of_same_sp_in_master()
    vars_of_same_sp_in_master2()
    vars_of_same_sp_in_master3()
    decomposition_not_on_axis()
    not_representative_of_sp()
    different_dw_sp_vars_in_same_dw_sp()
end

function master_var_in_subproblem()
    model = BlockModel(MockOptimizer)
    I = 1:5
    @axis(J, 1:10)
    @variable(model, x[i in I, j in J]) # subproblem variable
    @variable(model, y[i in I]) # master variable
    @constraint(model, c1[i in I], sum(x[i,j] for j in J) + y[i] >= 1) # master constraint
    @constraint(model, c2[j in J], sum(x[i,j] for i in I) <= 2) # subproblem constraint
    @constraint(model, c3[j in J, i in I], x[i,j] <= 1) # subproblem constraint

     # errored constraint (in subproblem but contains master variables)
    @constraint(model, c4[j in J, i in I], x[i,j] + y[i] <= 2)
    @dantzig_wolfe_decomposition(model, dec, J)

    @test_throws BlockDecomposition.MasterVarInDwSp JuMP.optimize!(model)
end

function master_var_in_subproblem2()
    model = BlockModel(MockOptimizer)
    I = 1:5
    @axis(J, 1:10)
    @variable(model, x[i in I, j in J]) # subproblem variable
    @variable(model, y[i in I]) # master variable
    @constraint(model, c1[i in I], sum(x[i,j] for j in J) + y[i] >= 1) # master constraint
    @constraint(model, c2[j in J], sum(x[i,j] for i in I) <= 2) # subproblem constraint
    @constraint(model, c3[j in J, i in I], x[i,j] <= 1) # subproblem constraint

     # errored constraint (in subproblem but contains master variables)
    @constraint(model, c4[J[1]], x[2,J[1]] + y[2] <= 2)
    @dantzig_wolfe_decomposition(model, dec, J)

    @test_throws BlockDecomposition.MasterVarInDwSp JuMP.optimize!(model)
end

function vars_of_same_sp_in_master()
    model = BlockModel(MockOptimizer)
    I = 1:5
    @axis(J, 1:10)
    @variable(model, x[i in I, j in J]) # subproblem variable
    @variable(model, y[i in I]) # master variable
    @constraint(model, c1[i in I], sum(x[i,j] for j in J) + y[i] >= 1) # master constraint
    @constraint(model, c2[j in J], sum(x[i,j] for i in I) <= 2) # subproblem constraint
    @constraint(model, c3, sum(x[i,2] for i in 2:4) <= 1)

    @dantzig_wolfe_decomposition(model, dec, J)

    @static if VERSION >= v"1.7"
        check_warn(msg) = occursin("BlockDecomposition.VarsOfSameDwSpInMaster(c3", msg)
        @test_warn check_warn JuMP.optimize!(model)
    end
    return
end

function vars_of_same_sp_in_master2()
    model = BlockModel(MockOptimizer)
    I = 1:5
    @axis(J, 1:10)
    @variable(model, x[i in I, j in J]) # subproblem variable
    @variable(model, y[i in I]) # master variable
    @constraint(model, c1[i in I], sum(x[i,j] for j in J) + y[i] >= 1) # master constraint
    @constraint(model, c2[j in J], sum(x[i,j] for i in I) <= 2) # subproblem constraint
    @constraint(model, c3[j in 3:4], sum(x[i,j] for i in 2:4) <= 1)

    @dantzig_wolfe_decomposition(model, dec, J)

    @static if VERSION >= v"1.7"
        check_warn(msg) = occursin("BlockDecomposition.VarsOfSameDwSpInMaster(c3[3]", msg)
        @test_warn check_warn JuMP.optimize!(model)
    end
    return
end

function vars_of_same_sp_in_master3()
    model = BlockModel(MockOptimizer)
    I = 1:5
    @axis(J, 1:10)
    @variable(model, x[i in I, j in J]) # subproblem variable
    @variable(model, y[i in I]) # master variable
    @constraint(model, c1[i in I], sum(x[i,j] for j in J) + y[i] >= 1) # master constraint
    @constraint(model, c2[j in J], sum(x[i,j] for i in I) <= 2) # subproblem constraint
    @constraint(model, c3[j in 3:4], sum(x[i,j] for i in 2:4) <= 1)

    @dantzig_wolfe_decomposition(model, dec, J)
    specify!.(getsubproblems(dec), upper_multiplicity = 2)

    @test_nowarn JuMP.optimize!(model) # no warn because upper multiplicity != 1
    return
end

function decomposition_not_on_axis()
    model = BlockModel(MockOptimizer)
    I = [1,2,3,4,5]
    @variable(model, x[I])
    @test_throws BlockDecomposition.DecompositionNotOverAxis{Vector{Int}} @dantzig_wolfe_decomposition(model, dec, I)
    return
end

function not_representative_of_sp()
    model = BlockModel(MockOptimizer)
    I = 1:5
    @axis(J, 1:3)
    @variable(model, x[i in I])
    @constraint(model, cov, sum(x[i] for i in I) >= 1)
    @constraint(model, sp1[j in J[1:2]], sum(x[i] for i in I) <= 3)
    @constraint(model, sp2[J[3]], sum(x[i] for i in I) >= 4) # error because of A
    
    @dantzig_wolfe_decomposition(model, dec, J)
    subproblemrepresentative.(x, Ref(getsubproblems(dec)[1:2])) # A

    @test_throws BlockDecomposition.NotRepresentativeOfDwSp JuMP.optimize!(model)
    return
end

function different_dw_sp_vars_in_same_dw_sp()
    model = BlockModel(MockOptimizer)
    @axis(I, 1:3)
    @variable(model, x[i in I])
    @constraint(model, sp[I[1]], x[1] + x[2] >= 1) # error
    @dantzig_wolfe_decomposition(model, dec, I)
    @test_throws BlockDecomposition.DwSpVarNotInGoodDwSp JuMP.optimize!(model)
    return
end