function axis_declarations()
    BD.@axis(A, 3:5)
    BD.@axis(B, ["lorem", "ipsum", "dolor"])
    Vector = [1,2,3]
    BD.@axis(Vector)
    C = [(1,2) (4,1)]
    BD.@axis(C)

    @testset "Axis Declaration A" begin
        @test length(A) == 3
        for (i, a) in enumerate(A)
            @test a == i + 2
        end
    end

    @testset "Axis Declaration B" begin
        @test G[1] == "lorem"
        @test G[2] == "ipsum"
        @test G[3] == "dolor"
    end

    @testset "Axis Declaration Vector" begin
        @test Vector[1] == 1
        @test Vector[2] == 2
        @test Vector[3] == 3
        @test typeof(Vector) <: BD.Axis 
    end

    @testset "Axis Declaration C" begin
        @test C[1] == (1,2)
        @test C[end] == (4,1)
    end
end