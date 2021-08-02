function test_branching_priority()
    model = Model()
    @variable(model, x)
    @variable(model, y[1:5])
    @variable(model, z[['a', 'b', 'd', 'e'], 1:5])
    @variable(model, w[i in 1:10, j in 1:i])
    
    @testset "Branching priority of a single variable" begin
        @test BD.branchingpriority(x) == 1.0
        BD.branchingpriority!(x, 2.0)
        @test BD.branchingpriority(x) == 2.0
    end

    @testset "Branching priority of a collection of variables" begin
        for v in BD.branchingpriority.(y)
            @test v == 1.0
        end
        BD.branchingpriority!.(y, 2.0)
        for v in BD.branchingpriority.(y)
            @test v == 2.0
        end
    end

    @testset "Branching priority of a dense axis array of variables" begin
        for v in BD.branchingpriority.(z)
            @test v == 1.0
        end
        BD.branchingpriority!.(z, 2.0)
        for v in BD.branchingpriority.(z)
            @test v == 2.0
        end
    end

    @testset "Branching priority of a sparse axis array of variables" begin
        for v in BD.branchingpriority.(w)
            @test v == 1.0
        end
        BD.branchingpriority!.(w, 2.5)
        for v in BD.branchingpriority.(w)
            @test v == 2.5
        end
    end
    return
end