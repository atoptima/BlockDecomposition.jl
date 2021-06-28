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

export BlockModel, annotation, specify!, decompose, gettree,
    getmaster, getsubproblems, indice, objectiveprimalbound!, objectivedualbound!,
    read_decomposition!
export @axis, @dantzig_wolfe_decomposition, @benders_decomposition
export AutoDwStrategy

include("axis.jl")
include("annotations.jl")
include("tree.jl")
include("formulations.jl")
include("decomposition.jl")
include("objective.jl")
include("callbacks.jl")
include("automatic_dantzig_wolfe.jl")
include("read_decomposition.jl")
include("utils.jl")

function BlockModel(
    args...;
    automatic_dantzig_wolfe::AutoDwStrategy = inaktive,
    read_decomposition::Bool = false,
    model_filename::String = "",
    decomp_filename::String = "",
    kw...
)
    if read_decomposition
        src = MOI.FileFormats.Model(format = MOI.FileFormats.FORMAT_MPS, filename = model_filename)
        MathOptInterface.read_from_file(src, model_filename)
        m = JuMP.Model(args...; kw...)
        MathOptInterface.copy_to(m, src)
        m.ext[:model_filename] = model_filename
        m.ext[:decomp_filename] = decomp_filename
    else
        m = JuMP.Model(args...; kw...)
    end
    JuMP.set_optimize_hook(m, optimize!)
    m.ext[:read_decomposition] = read_decomposition
    m.ext[:automatic_dantzig_wolfe] = automatic_dantzig_wolfe
    return m
end

function optimize!(m::JuMP.Model)
    if m.ext[:automatic_dantzig_wolfe] != inaktive
        automatic_dw_decomposition!(m)
    end
    if m.ext[:read_decomposition]
        read_decomposition!(m)
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
