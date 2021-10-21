function test_automatic_dantzig_wolfe()
    d = GapToyData(30, 4)
    @testset "Classic GAP automatic Dantzig-Wolfe (white score)" begin
        model, x, cov, knp = generalized_assignment_automatic_dantzig_wolfe(
            d,
            BlockDecomposition.white_score
        )
        try
            JuMP.optimize!(model)
        catch e
            @test e isa NoOptimizer
        end
        machines = 1:4
        jobs = 1:30
        # master constraints are the ones built of the set of machines
        for j in jobs
            cov_ann = BD.annotation(model, cov[j])
            test_annotation(cov_ann, BD.DwPricingSp, BD.DantzigWolfe, 1, 1)
            for m in machines
                x_ann = BD.annotation(model, x[m, j])
                test_annotation(cov_ann, BD.DwPricingSp, BD.DantzigWolfe, 1, 1)
            end
        end
        for m in machines
            knp_ann = BD.annotation(model, knp[m])
            test_annotation(knp_ann, BD.Master, BD.DantzigWolfe, 1, 1)
        end
    end

    @testset "Classic GAP automatic Dantzig-Wolfe (block-border score)" begin
        model, x, cov, knp = generalized_assignment_automatic_dantzig_wolfe(
            d,
            BlockDecomposition.block_border_score
        )
        try
            JuMP.optimize!(model)
        catch e
            @test e isa NoOptimizer
        end
        machines = 1:4
        jobs = 1:30
        # master constraints are the ones built of the set of machines
        for j in jobs
            cov_ann = BD.annotation(model, cov[j])
            test_annotation(cov_ann, BD.DwPricingSp, BD.DantzigWolfe, 1, 1)
            for m in machines
                x_ann = BD.annotation(model, x[m, j])
                test_annotation(cov_ann, BD.DwPricingSp, BD.DantzigWolfe, 1, 1)
            end
        end
        for m in machines
            knp_ann = BD.annotation(model, knp[m])
            test_annotation(knp_ann, BD.Master, BD.DantzigWolfe, 1, 1)
        end
    end
end
