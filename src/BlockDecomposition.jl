module BlockDecomposition

using JuMP, DataStructures, MathOptInterface
import MathOptInterface
import MathOptInterface.Utilities

const MOI = MathOptInterface
const MOIU = MOI.Utilities

export BlockModel, @axis, @dantzig_wolfe_decomposition

include("axis.jl")
include("annotations.jl")
include("tree.jl")
include("decomposition.jl")

function BlockModel(args...; kw...)
    m = JuMP.Model(args...; kw...)
    JuMP.set_optimize_hook(m, optimize!)
    return m
end

function optimize!(m::JuMP.Model)
    register_decomposition(m)
    if JuMP.mode(m) != JuMP.DIRECT && MOIU.state(JuMP.backend(m)) == MOIU.NO_OPTIMIZER
        throw(JuMP.NoOptimizer())
    end
    MOI.optimize!(JuMP.backend(m))
    return
end

end # module
