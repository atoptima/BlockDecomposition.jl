struct ColumnInfo <: BlockDecomposition.AbstractColumnInfo end

function test_sol_disagg()
    @testset "Disaggregate solution" begin
        model = Model()
        @variable(model, x, Bin)

        @test_throws MethodError BlockDecomposition.getsolutions(model, 1)
        @test_throws ErrorException(
            "value(::ColumnInfo) not defined."
        ) BlockDecomposition.value(ColumnInfo())
        @test_throws ErrorException(
            "value(::ColumnInfo, ::MOI.VariableIndex) not defined."
        ) BlockDecomposition.value(ColumnInfo(), x)
    end
end
