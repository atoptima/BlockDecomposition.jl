function test_JuMP_containers()
    @testset "DenseAxisArray usage" begin
        test_DenseAxisArray_usage()
    end
    return
end

function test_DenseAxisArray_usage()
    model = Model()

    cA = 1:10
    @axis(aA, cA)

    cB = 5:10
    @axis(aB, cB)

    cC = 10:15
    @axis(aC, cC) 

    # Make sure we can use either the axis or the container to get a variable
    @variable(model, x1[aA, aB, aC])
    @test x1 isa JuMP.Containers.DenseAxisArray
    @test x1[cA[1], cB[1], cC[1]] == x1[aA[1], aB[1], aC[1]]

    @variable(model, x2[aA, aB, cC])
    @test x2[cA[1], cB[1], cC[1]] == x2[aA[1], aB[1], aC[1]]

    @variable(model, x3[aA, cB, cC])
    @test x3[cA[1], cB[1], cC[1]] == x3[aA[1], aB[1], aC[1]]

    @variable(model, x4[aA, cB, aC])
    @test x4[cA[1], cB[1], cC[1]] == x4[aA[1], aB[1], aC[1]]

    @variable(model, x5[cA, cB, cC])
    @test x5[cA[1], cB[1], cC[1]] == x5[aA[1], aB[1], aC[1]]

    cD = ['a', 'd', 'k']
    @axis(aD, cD)

    cE = ["yes", "no"]
    @axis(aE, cE)

    @variable(model, x6[cC, cD])
    @test x6[cC[1], cD[1]] == x6[aC[1], aD[1]]

    @variable(model, x7[aC, aD])
    @test x7[cC[1], cD[1]] == x7[aC[1], aD[1]]

    @variable(model, x8[aE, aD])
    @test x8[cE[1], cD[1]] == x8[aE[1], aD[1]]

    cF = [(1,1), (1,2), (3,4)]
    @axis(aF, cF)

    @variable(model, x9[aF, aA])
    @test x9[aF[1], aA[1]] == x9[cF[1], cA[1]]

    @variable(model, x10[cF, cA])
    @test x10[aF[1], aA[1]] == x10[cF[1], cA[1]]
    return
end