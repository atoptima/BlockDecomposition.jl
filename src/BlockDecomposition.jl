module BlockDecomposition

using Combinatorics: powerset
using JuMP
using LightGraphs: SimpleGraph, add_vertices!, nv
using MathOptInterface
using MetaGraphs: MetaGraph, add_edge!, connected_components, edges, intersect,
    set_indexing_prop!, set_prop!, vertices

import MathOptInterface
import MathOptInterface.Utilities

const MOI = MathOptInterface
const MOIU = MOI.Utilities
const JC = JuMP.Containers

export BlockModel, annotation, specify!, decompose,gettree,
    getmaster, getsubproblems, indice, objectiveprimalbound!, objectivedualbound!

export @axis, @dantzig_wolfe_decomposition, @benders_decomposition

include("axis.jl")
include("annotations.jl")
include("tree.jl")
include("formulations.jl")
include("decomposition.jl")
include("objective.jl")
include("callbacks.jl")
include("automatic_decomposition.jl")
include("utils.jl")

function BlockModel(args...; automatic_decomposition = false, automatic_decomposition_score_type = 0, kw...)
    m = JuMP.Model(args...; kw...)
    JuMP.set_optimize_hook(m, optimize!)
    m.ext[:automatic_decomposition] = automatic_decomposition
    m.ext[:automatic_decomposition_score_type] = automatic_decomposition_score_type
    return m
end

function optimize!(m::JuMP.Model)
    if m.ext[:automatic_decomposition]
        decompose(m)
    end
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
