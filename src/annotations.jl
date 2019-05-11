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


struct Annotation{T, F<:Formulation, D<:Decomposition}
    unique_id::Int
    parent_id::Int # 0 if original formulation
    formulation::Type{F}
    decomposition::Type{D}
    axis_index_value::T
    min_multiplicity::Int
    max_multiplicity::Int
end

getid(a::Annotation) = a.unique_id
getparent(a::Annotation) = a.parent_id
getformulation(a::Annotation) = a.formulation
getdecomposition(a::Annotation) = a.decomposition
getminmultiplicity(a::Annotation) = a.min_multiplicity
getmaxmultiplicity(a::Annotation) = a.max_multiplicity

OriginalAnnotation() = Annotation(0, 0, Original, NoDecomposition, 0, 1, 1)

function MasterAnnotation(uid::Int, D::Type{<:Decomposition})
    return Annotation(uid, 0, Master, D, 0, 1, 1)
end

function Annotation(uid::Int, F::Type{<:Formulation}, D::Type{<:Decomposition}, v)
    return Annotation(uid, 0, F, D, v, 1, 1)
end

