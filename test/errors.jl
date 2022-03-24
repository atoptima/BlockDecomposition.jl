function test_errors()
    master_var_in_subproblem()
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

