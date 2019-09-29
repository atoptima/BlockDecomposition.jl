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

function _specify!(sp::SubproblemForm, lm::Real, um::Real)
    setlowermultiplicity!(sp.annotation, lm)
    setuppermultiplicity!(sp.annotation, um)
    return
end

function specify!(
    sp::SubproblemForm; lower_multiplicity::Real = 1, 
    upper_multiplicity::Real = 1
)
    _specify!(sp, lower_multiplicity, upper_multiplicity)
    return
end

# No broadcast over keyword arguments.
function specify!(
    sp::Vector{SubproblemForm}; lower_multiplicity = 1, 
    upper_multiplicity = 1
)
    _specify!.(sp, lower_multiplicity, upper_multiplicity)
    return
end

function assignsolver!(form::AbstractForm, func::Function)
    setoptimizerbuilder!(form.annotation, func)
    return
end