struct MyCustomVarData1 <: BlockDecomposition.AbstractCustomVarData
    nb_items::Int
    branching_priority::Float64
end

BD.branchingpriority(data::MyCustomVarData1) = data.branching_priority

struct MyCustomVarData2 <: BlockDecomposition.AbstractCustomVarData
    nb_items::Float64
end

struct MyCustomCutData1 <: BlockDecomposition.AbstractCustomConstrData
    min_items::Int
end

struct MyCustomCutData2 <: BlockDecomposition.AbstractCustomConstrData
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

    model = Model()
    customvars!(model, MyCustomVarData2)
    customconstrs!(model, MyCustomCutData2)

    @testset "Add single custom data" begin
        @test length(customvars(model)) == 1
        @test customvars(model)[1] == MyCustomVarData2
        @test length(customconstrs(model)) == 1
        @test customconstrs(model)[1] == MyCustomCutData2
    end

    model = Model()
    customvars!(model, MyCustomVarData1)
    customvars!(model, MyCustomVarData2)
    customconstrs!(model, MyCustomCutData1)
    customconstrs!(model, MyCustomCutData2)

    @testset "Successive declaration of custom data" begin
        @test customvars(model)[1] == MyCustomVarData1
        @test customvars(model)[2] == MyCustomVarData2
        @test customconstrs(model)[1] == MyCustomCutData1
        @test customconstrs(model)[2] == MyCustomCutData2
    end

    return
end

function test_attach_custom_data()
    model = Model()
    @variable(model, x[1:2])
    @constraint(model, con, x[1] + x[2] <= 1)

    @testset "attach custom data to variable from unregistered custom data family" begin
        @test_throws UnregisteredCustomDataFamily customdata!(x[1], MyCustomVarData1(1, 2.0))
    end

    @testset "attach custom data to a variable" begin
        customvars!(model, MyCustomVarData1)
        customvars!(model, MyCustomVarData2)
        customdata!(x[1], MyCustomVarData1(1, 2.0))
        @test customdata(x[1]) == MyCustomVarData1(1, 2.0)
        @test branchingpriority(customdata(x[1])) == 2.0
        customdata!(x[2], MyCustomVarData2(2))
        @test customdata(x[2]) == MyCustomVarData2(2)
        @test branchingpriority(customdata(x[2])) === nothing
    end

    @testset "attach custom data to a constraint" begin
        customconstrs!(model, MyCustomCutData1)
        customdata!(con, MyCustomCutData1(1))
        @test customdata(con) == MyCustomCutData1(1)
    end
end
