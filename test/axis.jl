function axis_declarations()
    BD.@axis(A, 3:5)
    BD.@axis(B, 3:5, Identical)
    BD.@axis(C[a in A], 1:6)
    BD.@axis(D[i in 1:3], 1:A[i])
    BD.@axis(E[a in A], 1:a)
    BD.@axis(F[i in 1:5, j in 1:2], 1:i*j, Identical)
    BD.@axis(G, ["lorem", "ipsum", "dolor"])
    BD.@axis(H, 1:3, lb = 0)

    @testset "Axis Declaration A" begin
        @test length(A) == 3
        for (i, a) in enumerate(A)
            @test a == i + 2
        end
        @test BD.identical(A) == false
    end

    @testset "Axis Declaration B" begin
        @test B[end] == 5
        @test BD.identical(B) == true
    end

    @testset "Axis Declaration C" begin
        for a in A
            @test length(C[a]) == 6
            for i in 1:6
                @test C[a][i] == i
                @test BD.identical(C[a]) == false
            end
        end
    end

    @testset "Axis Declaration D" begin
        for i in 1:3
            @test D[i][end] == A[i]
        end
    end

    @testset "Axis Declaration E" begin
        for a in A
            @test E[a][end] == a
        end
    end

    @testset "Axis Declaration F" begin
        for i in 1:5, j in 1:2
            @test F[i, j][end] == i * j
            @test BD.identical(F[i, j]) == true
        end
    end

    @testset "Axis Declaration G" begin
        @test G[1] == "lorem"
        @test G[2] == "ipsum"
        @test G[3] == "dolor"
    end

    @testset "Axis Declaration H" begin
        @test BD.lowermultiplicity(H) == 0
    end
end