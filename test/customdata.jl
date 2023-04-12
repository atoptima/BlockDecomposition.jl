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
    customvars!(model, [MyCustomVarData1, MyCustomVarData2])
    customconstrs!(model, [MyCustomCutData1, MyCustomCutData2])

    @testset "Add custom data vector" begin
        @test customvars(model)[1] == MyCustomVarData1
        @test customvars(model)[2] == MyCustomVarData2
        @test customconstrs(model)[1] == MyCustomCutData1
        @test customconstrs(model)[2] == MyCustomCutData2
    end

    customvars!(model, MyCustomVarData2)
    customconstrs!(model, MyCustomCutData2)

    @testset "Add single custom data" begin
        @test length(customvars(model)) == 1
        @test customvars(model)[1] == MyCustomVarData2
        @test length(customconstrs(model)) == 1
        @test customconstrs(model)[1] == MyCustomCutData2
    end

    return
end

function test_attach_custom_data()
    model = Model()
    @variable(model, x[1:2])
    @constraint(model, con, x[1] + x[2] <= 1)

    @testset "attach custom data to variable from unregistered custom data family" begin
        @test_throws UnregisteredCustomDataFamily customdata!(x[1], MyCustomVarData1(1))
    end

    @testset "attach custom data to a variable" begin
        customvars!(model, MyCustomVarData1)
        customdata!(x[1], MyCustomVarData1(1))
        @test customdata(x[1]) == MyCustomVarData1(1)
    end

    @testset "attach custom data to a constraint" begin
        customconstrs!(model, MyCustomCutData1)
        customdata!(con, MyCustomCutData1(1))
        @test customdata(con) == MyCustomCutData1(1)
    end
end
