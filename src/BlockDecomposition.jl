module BlockDecomposition

using JuMP, MathOptInterface
import MathOptInterface
import MathOptInterface.Utilities

const MOI = MathOptInterface
const MOIU = MOI.Utilities
const JC = JuMP.Containers

export BlockModel, annotation, specify!, gettree, getmaster, getsubproblems, ×, indice,
       objectiveprimalbound!, objectivedualbound!, branchingpriority!, branchingpriority,
       addcustomvars!, addcustomconstrs!, customvars, customconstrs

export @axis, @dantzig_wolfe_decomposition, @benders_decomposition

include("axis.jl")
include("annotations.jl")
include("tree.jl")
include("formulations.jl")
include("decomposition.jl")
include("objective.jl")
include("callbacks.jl")
include("utils.jl")
include("branchingpriority.jl")
include("customdata.jl")

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

function BlockModel(args...; kw...)
    dm = haskey(kw, :direct_model) ? kw[:direct_model] : false
    m = model_factory(Val(dm), args...; kw...)
    JuMP.set_optimize_hook(m, optimize!)
    return m
end

function optimize!(m::JuMP.Model)
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
