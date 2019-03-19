abstract type Decomposition end
struct NoDecomposition <: Decomposition end
struct DantzigWolfe <: Decomposition end
struct Benders <: Decomposition end
struct CombinedBendersDanztigWolfe <: Decomposition end

abstract type Problem end
struct Original <: Problem end
struct Master <: Problem end
abstract type Subproblem <: Problem end
struct Pricing <: Subproblem end
struct Separation <: Subproblem end


struct Annotation{T, P <: Problem, D <: Decomposition}
    unique_id::Int
    problem::Type{P}
    decomposition::Type{D}
    axis_index_value::T
    min_multiplicity::Int
    max_multiplicity::Int
end

OriginalAnnotation() = Annotation(0, Original, NoDecomposition, 0, 1, 1)

function MasterAnnotation(uid::Int, D::Type{<: Decomposition})
    return Annotation(uid, Master, D, 0, 1, 1)
end

function Annotation(uid::Int, P::Type{<: Problem}, D::Type{<: Decomposition}, v)
    return Annotation(uid, P, D, v, 1, 1)
end

