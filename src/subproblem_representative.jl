struct ListOfRepresentatives <: MOI.AbstractModelAttribute end
struct RepresentativeVar <: MOI.AbstractVariableAttribute end

"""
    subproblemrepresentative(x, [subproblem1, subproblem2])

Indicate that variable `x` will belongs to many subproblem (`subproblem1` and `subproblem2`
in the example).

Variable `x` should not contain any axis id in this indices otherwise BlockDecomposition
will throw a [RepresentativeAlreadyInDwSp](@ref) error.
"""
function subproblemrepresentative(x::JuMP.VariableRef, subproblems::Vector{SubproblemForm})
    @assert x.model == subproblems[1].model
    MOI.set(x.model, RepresentativeVar(), x, getfield.(subproblems, :annotation))
    return nothing
end

function MOI.set(
    dest::MOIU.UniversalFallback, attribute::RepresentativeVar, vi::MOI.VariableIndex, sp_annotations
)
    if !haskey(dest.varattr, attribute)
        dest.varattr[attribute] = Dict{MOI.VariableIndex,Vector{Annotation}}()
    end
    dest.varattr[attribute][vi] = sp_annotations
    return
end

function MOI.get(dest::MOIU.UniversalFallback, attribute::RepresentativeVar, vi::MOI.VariableIndex)
    varattr = get(dest.varattr, attribute, nothing)
    isnothing(varattr) && return nothing
    return get(varattr, vi, nothing)
end

MOI.get(dest::MOIU.UniversalFallback, ::ListOfRepresentatives) =
    get(dest.varattr, RepresentativeVar(), nothing)
