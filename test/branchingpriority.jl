function test_branching_priority()
    model = Model()
    @variable(model, x)
    @variable(model, y[1:5])
    @variable(model, z[['a', 'b', 'd', 'e'], 1:5])
    @variable(model, w[i in 1:10, j in 1:i])
    
    @testset "Branching priority of a single variable" begin
        @test BD.branchingpriority(model, x) == 1
        BD.branchingpriority!(model, x, 2)
        @test BD.branchingpriority(model, x) == 2
    end

    @testset "Branching priority of a collection of variables" begin
        for v in BD.branchingpriority.(model, y)
            @test v == 1
        end
        BD.branchingpriority!.(model, y, 2)
        for v in BD.branchingpriority.(model, y)
            @test v == 2
        end
    end

    @testset "Branching priority of a dense axis array of variables" begin
        for v in BD.branchingpriority.(model, z)
            @test v == 1
        end
        BD.branchingpriority!.(model, z, 2)
        for v in BD.branchingpriority.(model, z)
            @test v == 2
        end
    end

    @testset "Branching priority of a sparse axis array of variables" begin
        for v in BD.branchingpriority.(model, w)
            @test v == 1
        end
        BD.branchingpriority!.(model, w, 2)
        for v in BD.branchingpriority.(model, w)
            @test v == 2
        end
    end
end