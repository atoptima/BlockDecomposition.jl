function axis_declarations()
    @axis(A, 3:5)
    @axis(B, ["lorem", "ipsum", "dolor"])
    Vector = [1,2,3]
    @axis(Vector)
    C = [(1,2) (4,1)]
    @axis(C)

    @testset "Axis Declaration A" begin
        @test length(A) == 3
        for (i, a) in enumerate(A)
            @test indice(a) == i + 2
        end
    end

    @testset "Axis Declaration B" begin
        @test BD.name(B) == :B
        @test indice(B[1]) == "lorem"
        @test indice(B[2]) == "ipsum"
        @test indice(B[3]) == "dolor"
    end

    @testset "Axis Declaration Vector" begin
        @test indice(Vector[1]) == 1
        @test indice(Vector[2]) == 2
        @test indice(Vector[3]) == 3
        @test typeof(Vector) <: BD.Axis 
    end

    @testset "Axis Declaration C" begin
        @test indice(C[1]) == (1,2)
        @test indice(C[end]) == (4,1)
    end
end