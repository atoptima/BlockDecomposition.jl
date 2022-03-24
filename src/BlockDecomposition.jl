module BlockDecomposition

using Combinatorics: powerset
using JuMP
using Graphs: SimpleGraph, add_vertices!, nv
using MathOptInterface
using MetaGraphs: MetaGraph, add_edge!, connected_components, edges, intersect,
    set_indexing_prop!, set_prop!, vertices

import MathOptInterface
import MathOptInterface.Utilities

const MOI = MathOptInterface
const MOIU = MOI.Utilities
const JC = JuMP.Containers

export BlockModel, annotation, specify!, gettree, getmaster, getsubproblems, ×, indice,
       objectiveprimalbound!, objectivedualbound!, branchingpriority!, branchingpriority,
       customvars!, customconstrs!, customvars, customconstrs
export @axis, @dantzig_wolfe_decomposition, @benders_decomposition
export AutoDwStrategy

include("axis.jl")
include("annotations.jl")
include("tree.jl")
include("formulations.jl")
include("checker.jl")
include("decomposition.jl")
include("objective.jl")
include("callbacks.jl")
include("automatic_dantzig_wolfe.jl")
include("utils.jl")
include("branchingpriority.jl")
include("customdata.jl")
include("soldisaggregation.jl")

function model_factory(::Val{true}, optimizer; kw...)::JuMP.Model
    m = JuMP.direct_model(optimizer.optimizer_constructor())
    for (param, val) in optimizer.params
        set_optimizer_attribute(m, param, val)
    end
    for (key, val) in kw
        if key !== :direct_model
            @warn "Unsupported keyword argument $key when creating a BlockModel with direct_model=true."
        end
    end
    return m
end

function model_factory(::Val{false}, args...; kw...)::JuMP.Model
    return JuMP.Model(args...; kw...)
end

"""
    BlockModel(optimizer [, direct_model = false])

Return a JuMP model which BlockDecomposition will decompose using instructions given by the user.

If you define `direct_model = true`, the method creates the model with `JuMP.direct_model`,
otherwise it uses `JuMP.Model`.
"""
function BlockModel(args...; automatic_dantzig_wolfe::AutoDwStrategy = inactive, kw...)
    dm = haskey(kw, :direct_model) ? kw[:direct_model] : false
    m = model_factory(Val(dm), args...; kw...)
    JuMP.set_optimize_hook(m, optimize!)
    m.ext[:automatic_dantzig_wolfe] = automatic_dantzig_wolfe
    return m
end

function optimize!(m::JuMP.Model)
    if haskey(m.ext, :automatic_dantzig_wolfe) && m.ext[:automatic_dantzig_wolfe] != inactive
        automatic_dw_decomposition!(m)
    end
    register_decomposition(m)
    return JuMP.optimize!(m, ignore_optimize_hook = true)
end

"""
    annotation(node)

Return the annotation that describes the master/subproblem of a given node of
the decomposition tree.

    annotation(model, variable)
    annotation(model, constraint)

Return the subproblem to which a variable or a constraint belongs.
"""
function annotation(model::JuMP.Model, objref::JuMP.ConstraintRef)
    MOI.get(model, ConstraintDecomposition(), objref)
end

function annotation(model::JuMP.Model, objref::JuMP.VariableRef)
    MOI.get(model, VariableDecomposition(), objref)
end

end # module
