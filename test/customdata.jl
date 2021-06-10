struct MyCustomVarData <: BlockDecomposition.AbstractCustomData
    nb_items::Int
end

struct MyCustomCutData <: BlockDecomposition.AbstractCustomData
    min_items::Int
end

function test_custom_data()
    model = Model()
    addcustomvars!(model, MyCustomVarData)
    addcustomconstrs!(model, MyCustomCutData)

    @testset "Custom data" begin
        @test customvars(model) == MyCustomVarData
        @test customconstrs(model) == MyCustomCutData
    end

    return
end