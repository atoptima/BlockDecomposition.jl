abstract type AbstractForm end

struct MasterForm <: AbstractForm
    annotation::Annotation
end

MasterForm(n::Union{Root, Node}) = MasterForm(n.master)

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

function _specify!(sp::SubproblemForm, lm::Real, um::Real, opt::Type{<:MOI.AbstractOptimizer})
    setlowermultiplicity!(sp.annotation, lm)
    setuppermultiplicity!(sp.annotation, um)
    setoptimizerbuilder!(sp.annotation, opt())
    setpricingoracle!(sp.annotation, nothing)
end

function _specify!(sp::SubproblemForm, lm::Real, um::Real, oracle::Union{Nothing,Function})
    setlowermultiplicity!(sp.annotation, lm)
    setuppermultiplicity!(sp.annotation, um)
    setpricingoracle!(sp.annotation, oracle)
    setoptimizerbuilder!(sp.annotation, nothing)
    return
end

function specify!(
    sp::SubproblemForm; lower_multiplicity::Real = 1, 
    upper_multiplicity::Real = 1, solver::Union{Nothing, Function, Type{<:MOI.AbstractOptimizer}} = nothing
)
    _specify!(sp, lower_multiplicity, upper_multiplicity, solver)
    return
end