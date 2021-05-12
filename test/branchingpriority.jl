function test_branching_priority()
    model = Model()
    @variable(model, x)
    @variable(model, y[1:5])
    
    @testset "Branching priority of a single variable" begin
        @test BD.branchingpriority(model, x) == 1
        BD.branchingpriority!(model, x, 2)
        @test BD.branchingpriority(model, x) == 2
    end

    @testset "Branching priority of a collection of variables" begin
        @test BD.branchingpriority(model, y) == 1
        BD.branchingpriority!(model, y, 2)
        @test BD.branchingpriority(model, y) == 2
    end 
end