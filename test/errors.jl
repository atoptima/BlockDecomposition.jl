function test_errors()
    master_var_in_subproblem()
    master_var_in_subproblem2()
    vars_of_same_sp_in_master()
    vars_of_same_sp_in_master2()
end

function master_var_in_subproblem()
    model = BlockModel()
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
    model = BlockModel()
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
    model = BlockModel()
    I = 1:5
    @axis(J, 1:10)
    @variable(model, x[i in I, j in J]) # subproblem variable
    @variable(model, y[i in I]) # master variable
    @constraint(model, c1[i in I], sum(x[i,j] for j in J) + y[i] >= 1) # master constraint
    @constraint(model, c2[j in J], sum(x[i,j] for i in I) <= 2) # subproblem constraint
    @constraint(model, c3, sum(x[i,2] for i in 2:4) <= 1)

    @dantzig_wolfe_decomposition(model, dec, J)

    try
        @test_warn "BlockDecomposition.VarsOfSameDwSpInMaster(c3 : x[2,2] + x[3,2] + x[4,2] ≤ 1.0)" JuMP.optimize!(model)
    catch e
        @test e isa NoOptimizer
    end
end

function vars_of_same_sp_in_master2()
    model = BlockModel()
    I = 1:5
    @axis(J, 1:10)
    @variable(model, x[i in I, j in J]) # subproblem variable
    @variable(model, y[i in I]) # master variable
    @constraint(model, c1[i in I], sum(x[i,j] for j in J) + y[i] >= 1) # master constraint
    @constraint(model, c2[j in J], sum(x[i,j] for i in I) <= 2) # subproblem constraint
    @constraint(model, c3[j in 3:4], sum(x[i,j] for i in 2:4) <= 1)

    @dantzig_wolfe_decomposition(model, dec, J)

    try
        @test_warn "BlockDecomposition.VarsOfSameDwSpInMaster(c3 : x[2,3] + x[3,3] + x[4,3] ≤ 1.0)" JuMP.optimize!(model)
    catch e
        @test e isa NoOptimizer
    end
end

function decomposition_not_on_axis()
    model = BlockModel()
    I = [1,2,3,4,5]
    @variable(model, x[I])
    @test_throws BlockDecomposition.DecompositionNotOverAxis{Vector{Int}} @dantzig_wolfe_decomposition(model, dec, I)
end