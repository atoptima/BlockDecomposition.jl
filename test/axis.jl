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

    # Cartesian product
    E = 1:3
    F = ['a', 'b', 'c']
    @axis(G, E × F)

    @testset "Cartesian product axis" begin
        @test indice(G[1]) == (1, 'a')
        @test indice(G[2]) == (2, 'a')
        @test indice(G[3]) == (3, 'a')
        @test indice(G[4]) == (1, 'b')
        @test indice(G[5]) == (2, 'b')
        @test indice(G[6]) == (3, 'b')
        @test indice(G[7]) == (1, 'c')
        @test indice(G[8]) == (2, 'c')
        @test indice(G[9]) == (3, 'c')
    end
end