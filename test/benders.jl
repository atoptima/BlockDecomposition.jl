function test_benders()
    d = LsToyData(3, 10)
    @testset "Single Mode Multi Item Lot Sizing" begin
        model, x, y, singlemode, setup, cov = single_mode_multi_item_lot_sizing(d)
        #@show BD.gettree(model)
        try
             JuMP.optimize!(model)
        catch e
             @test e isa NoOptimizer
        end
        x_ann = BD.annotation(model, x[1, 1])
        test_annotation(x_ann, BD.Master, BD.Benders, 1, 1)
        y_ann = BD.annotation(model, y[2, 5])
        test_annotation(y_ann, BD.BendersSepSp, BD.Benders, 1, 1)
        singlemode_ann = BD.annotation(model, singlemode[2])
        test_annotation(singlemode_ann, BD.Master, BD.Benders, 1, 1)
        cov_ann = BD.annotation(model, cov[1, 1])
        test_annotation(cov_ann, BD.BendersSepSp, BD.Benders, 1, 1)
        setup_ann = BD.annotation(model, setup[1, 1])
        test_annotation(setup_ann, BD.BendersSepSp, BD.Benders, 1, 1)
    end
end