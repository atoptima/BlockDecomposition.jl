MOI.is_set_by_optimize(::BlockDecomposition.SpsColsInfo) = false

struct ColumnInfo <: BlockDecomposition.AbstractColumnInfo
    id::Int
end

function test_sps_cols_info()
    @testset "Subproblems columns info" begin
        model = Model()
        @variable(model, x, Bin)
        sps_cols_info = [
            BlockDecomposition.SpColsInfo([ColumnInfo(1), ColumnInfo(2)]),
            BlockDecomposition.SpColsInfo([ColumnInfo(3), ColumnInfo(4)])
        ]
        MOI.set(model, BlockDecomposition.SpsColsInfo(), sps_cols_info)
        
        for i in 1:2
            # i-th element of first subproblem columns info
            col = BlockDecomposition.getsolutions(model, 1)[i]
            @test col.id == i
            
            # i-th element of second subproblem columns info
            col = BlockDecomposition.getsolutions(model, 2)[i]
            @test col.id == i + 2

            @test_throws ErrorException(
                "value(::ColumnInfo) not defined."
            ) BlockDecomposition.value(col)

            @test_throws ErrorException(
                "value(::ColumnInfo, ::MOI.VariableIndex) not defined."
            ) BlockDecomposition.value(col, x)
        end
    end
end