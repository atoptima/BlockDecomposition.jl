struct ColumnInfo <: BlockDecomposition.AbstractColumnInfo end

function test_sol_disagg()
    @testset "Disaggregate solution" begin
        model = direct_model(MockOptimizer())
        @test_throws ErrorException(
            "getsolutions(::MockOptimizer, ::Int64) not defined."
        ) BlockDecomposition.getsolutions(model, 1)

        model = Model()
        @test_throws ErrorException(
            "No solver defined."
        ) BlockDecomposition.getsolutions(model, 1)

        model = Model(MockOptimizer)
        @test_throws ErrorException(
            "getsolutions(::MockOptimizer, ::Int64) not defined."
        ) BlockDecomposition.getsolutions(model, 1)

        @variable(model, x, Bin)
        @test_throws ErrorException(
            "value(::ColumnInfo) not defined."
        ) BlockDecomposition.value(ColumnInfo())
        @test_throws ErrorException(
            "value(::ColumnInfo, ::MOI.VariableIndex) not defined."
        ) BlockDecomposition.value(ColumnInfo(), x)
    end
end
