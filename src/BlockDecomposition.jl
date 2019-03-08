module BlockDecomposition

using JuMP, DataStructures, MathOptInterface
import MathOptInterface
import MathOptInterface.Utilities

const MOI = MathOptInterface
const MOIU = MOI.Utilities

export BlockModel

include("axis.jl")
include("annotations.jl")
include("tree.jl")
include("decomposition.jl")

function BlockModel(args...; kw...)
    m = JuMP.Model(args...; kw...)
    JuMP.set_optimize_hook(m, register_decomposition)

    return m
end


end # module
