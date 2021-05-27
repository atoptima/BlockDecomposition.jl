abstract type Decomposition end
struct NoDecomposition <: Decomposition end
struct DantzigWolfe <: Decomposition end
struct Benders <: Decomposition end
struct CombinedBendersDanztigWolfe <: Decomposition end

abstract type Formulation end
struct Original <: Formulation end
struct Master <: Formulation end
abstract type Subproblem <: Formulation end
struct DwPricingSp <: Subproblem end
struct BendersSepSp <: Subproblem end

abstract type AbstractCustomOptimizer end
mutable struct Annotation{T, F<:Formulation, D<:Decomposition}
    unique_id::Int
    parent_id::Int # 0 if original formulation
    formulation::Type{F}
    decomposition::Type{D}
    axis_index_value::T
    lower_multiplicity::Float64
    upper_multiplicity::Float64
    optimizer_builders::Vector
end

getid(a::Annotation) = a.unique_id
getparent(a::Annotation) = a.parent_id
getformulation(a::Annotation) = a.formulation
getdecomposition(a::Annotation) = a.decomposition
getlowermultiplicity(a::Annotation) = a.lower_multiplicity
getuppermultiplicity(a::Annotation) = a.upper_multiplicity
getoptimizerbuilders(a::Annotation) = a.optimizer_builders

setlowermultiplicity!(a::Annotation, lm::Real) = a.lower_multiplicity = lm 
setuppermultiplicity!(a::Annotation, um::Real) = a.upper_multiplicity = um
emptyoptimizerbuilders!(a::Annotation) = empty!(a.optimizer_builders)
pushoptimizerbuilder!(a::Annotation, f::MOI.AbstractOptimizer) = push!(a.optimizer_builders, f)
pushoptimizerbuilder!(a::Annotation, f::Function) = push!(a.optimizer_builders, f)
pushoptimizerbuilder!(a::Annotation, f::AbstractCustomOptimizer) = push!(a.optimizer_builders, f)

OriginalAnnotation() = Annotation(0, 0, Original, NoDecomposition, 0, 1.0, 1.0, [])

function MasterAnnotation(tree, D::Type{<:Decomposition})
    uid = generateannotationid(tree)
    return Annotation(uid, 0, Master, D, 0, 1.0, 1.0, [])
end

function Annotation(tree, F::Type{<:Formulation}, D::Type{<:Decomposition}, v)
    uid = generateannotationid(tree)
    return Annotation(uid, 0, F, D, v, 1.0, 1.0, [])
end

function Base.show(io::IO, a::Annotation)
    print(io, "Annotation(")
    print(io, getformulation(a))
    print(io, ", ")
    print(io, getdecomposition(a))
    print(io, ", lm = ")
    print(io, getlowermultiplicity(a))
    print(io, ", um = ")
    print(io, getuppermultiplicity(a))
    print(io, ", id = ")
    print(io, getid(a))
    print(io, ")")
    return
end