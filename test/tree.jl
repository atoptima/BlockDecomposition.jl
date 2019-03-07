function test_dantzig_wolfe_different()
    d = GapToyData(5, 2)
    m = generalized_assignement(d)
    @show BD.get_tree(m)
end

function test_dantzig_wolfe_identical()
    d = CsToyData(1, 10)
    m = cutting_stock(d)
    @show BD.get_tree(m)
end

function test_dantzig_wolfe_diffidentical()
    d = CsToyData(3, 15)
    m = cutting_stock_different_sizes(d)
    @show BD.get_tree(m)
end