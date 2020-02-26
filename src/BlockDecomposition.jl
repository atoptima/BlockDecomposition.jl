module BlockDecomposition

using JuMP, DataStructures, MathOptInterface
import MathOptInterface
import MathOptInterface.Utilities

const MOI = MathOptInterface
const MOIU = MOI.Utilities
const JC = JuMP.Containers

export BlockModel, annotation, specify!, gettree, getmaster, getsubproblems,
       indice, assignsolver!, objectiveprimalbound!, objectivedualbound!

export @axis, @dantzig_wolfe_decomposition, @benders_decomposition

include("axis.jl")
include("annotations.jl")
include("tree.jl")
include("formulations.jl")
include("decomposition.jl")
include("objective.jl")

function BlockModel(args...; kw...)
    m = JuMP.Model(args...; kw...)
    JuMP.set_optimize_hook(m, optimize!)
    return m
end

function optimize!(m::JuMP.Model)
    register_decomposition(m)
    return JuMP.optimize!(m, ignore_optimize_hook = true)
end

function annotation(model::JuMP.Model, objref::JuMP.ConstraintRef)
    MOI.get(model, ConstraintDecomposition(), objref)
end

function annotation(model::JuMP.Model, objref::JuMP.VariableRef)
    MOI.get(model, VariableDecomposition(), objref)
end

end # module
