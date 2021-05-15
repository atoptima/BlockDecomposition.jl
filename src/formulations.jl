abstract type AbstractForm end

struct MasterForm <: AbstractForm
    annotation::Annotation
end

MasterForm(n::Union{Root, Node}) = MasterForm(n.master)

"""
    getmaster(node) -> MasterForm

Return an object that wraps the annotation that describes the master formulation
of a decomposition stored at the `node` of the decomposition tree.

This method is not defined if the node is a leaf of the decomposition tree.
"""
function getmaster(decomposition::AbstractNode)
    return MasterForm(decomposition)
end

function Base.show(io::IO, m::MasterForm)
    print(io, "Master formulation.")
    print(io, "\n")
    return
end

struct SubproblemForm{T} <: AbstractForm
    axisname::Symbol
    axisval::T
    annotation::Annotation
end

#SubproblemForm(n::Node) = SubproblemForm(n.master) # TODO : nested decomposition
function SubproblemForm(n::Leaf)
    name = n.parent.axis.name
    return SubproblemForm(name, n.edge_id, n.problem)
end

"""
    getsubproblems(node) -> Vector{SubproblemForm}

Return a vector of objects that wrap the annotations that describe subproblem
formulations of a decomposition stored at `node` of the decomposition tree.

This method is not defined if the node is a leaf of the decomposition tree.
"""
function getsubproblems(decomposition::AbstractNode)
    subproblems = SubproblemForm[]
    for id in decomposition.axis
        child = decomposition.subproblems[id]
        push!(subproblems, SubproblemForm(child))
    end
    return subproblems
end

function Base.show(io::IO, m::SubproblemForm)
    ann = m.annotation
    name = m.axisname
    val = m.axisval
    lm = getlowermultiplicity(ann)
    um = getuppermultiplicity(ann)
    print(io, "Subproblem formulation for $(name) = $(val) contains :")
    print(io, "\t $(lm) <= multiplicity <= $(um)")
    print(io, "\n")
    return
end


"""
    specify!(
        subproblem, 
        lower_multiplicity = 1,
        upper_multiplicity = 1,
        solver = nothing
    )

Method that allows the user to specify additional property of the subproblems.

The multiplicity of `subproblem` is the number of times that the same independant
block shaped by the subproblem in the coefficient matrix appears in the model.
It is equivalent to the number of solutions to the subproblem that can appear in the solution 
of the original problem.

The solver of the subproblem is the way the subproblem will be optimized. It can
be either a function (pricing callback), an optimizer of MathOptInterface 
(e.g. `Gurobi.Optimizer`, `CPLEX.Optimizer`, `Glpk.Optimizer`... with attributes), 
or `nothing`. In the latter case, the solver will use a default optimizer that 
should be defined in the parameters of the main solver.

**Advanced usage** : 
The user can use several solvers to optimize a subproblem : 

    specify!(subproblem, solver = [Gurobi.Optimizer, my_callback, my_second_callback])

Coluna always uses the first solver by default. Be cautious because changes are always
buffered to all solvers. So you may degrade performances if you use a lot of solvers.
"""
function specify!(
    sp::SubproblemForm; lower_multiplicity::Real = 1, 
    upper_multiplicity::Real = 1, solver = nothing
)
    setlowermultiplicity!(sp.annotation, lower_multiplicity)
    setuppermultiplicity!(sp.annotation, upper_multiplicity)
    emptyoptimizerbuilders!(sp.annotation)
    _specify!(sp, solver)
    return
end

# Fallback
_specify!(::SubproblemForm, solver) = error("BlockDecomposition does not support solver of type $(typeof(solver)).")

_specify!(::SubproblemForm, ::Nothing) = return

function _specify!(sp::SubproblemForm, solver::Union{MOI.OptimizerWithAttributes, Type{<:MOI.AbstractOptimizer}})
    pushoptimizerbuilder!(sp.annotation, MOI._instantiate_and_check(solver))
end

function _specify!(sp::SubproblemForm, oracle::Function)
    pushoptimizerbuilder!(sp.annotation, oracle)
    return
end

function _specify!(sp::SubproblemForm, solvers::Vector)
    for solver in solvers
        _specify!(sp, solver)
    end
    return
end
