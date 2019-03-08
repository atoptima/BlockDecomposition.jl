function test_dantzig_wolfe_different()
    d = GapToyData(5, 2)
    m = generalized_assignement(d)
    @show BD.get_tree(m)
    JuMP.optimize!(m)
end

function test_dantzig_wolfe_identical()
    #d = CsToyData(1, 10)
    #m = cutting_stock(d) # Not working yet : identical subproblems
    #@show BD.get_tree(m)
    #JuMP.optimize!(m)
end

function test_dantzig_wolfe_diffidentical()
    #d = CsToyData(3, 15)
    #m = cutting_stock_different_sizes(d)
    #@show BD.get_tree(m)
    #JuMP.optimize!(m) # Does not work yet because JuMP creates SparseArray to store cstrs & vars
end