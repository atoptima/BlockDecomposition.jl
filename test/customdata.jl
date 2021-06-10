struct MyCustomVarData1 <: BlockDecomposition.AbstractCustomData
    nb_items::Int
end

struct MyCustomVarData2 <: BlockDecomposition.AbstractCustomData
    nb_items::Float64
end

struct MyCustomCutData1 <: BlockDecomposition.AbstractCustomData
    min_items::Int
end

struct MyCustomCutData2 <: BlockDecomposition.AbstractCustomData
    min_items::Float64
end

function test_custom_data()
    model = Model()
    addcustomvars!(model, [MyCustomVarData1, MyCustomVarData2])
    addcustomconstrs!(model, [MyCustomCutData1, MyCustomCutData2])

    @testset "Custom data" begin
        @test customvars(model)[1] == MyCustomVarData1
        @test customvars(model)[2] == MyCustomVarData2
        @test customconstrs(model)[1] == MyCustomCutData1
        @test customconstrs(model)[2] == MyCustomCutData2
    end

    return
end
