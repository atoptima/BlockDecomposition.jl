struct MasterForm
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

struct SubproblemForm
    annotation::Annotation
end

SubproblemForm(n::Node) = SubproblemForm(n.master)
SubproblemForm(n::Leaf) = SubproblemForm(n.problem)

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
    lm = getlowermultiplicity(ann)
    um = getuppermultiplicity(ann)
    print(io, "Subproblem formulation contains :")
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
