# Errors or warnings

"""
Error thrown when a master variable is in a constraint that belongs to a Dantzig-Wolfe
subproblem.

You can retrieve the JuMP variable and the JuMP constraint where the error occurs:
```julia
error.variable
error.constraint
```
"""
struct MasterVarInDwSp 
    variable::JuMP.VariableRef
    constraint::JuMP.ConstraintRef
end

"""
Warning when a master constraint involves variables that belong to the same Dantzig-Wolfe
subproblem. It means you can move the constraint in a subproblem.
"""
struct VarsOfSameDwSpInMaster
    constraint::JuMP.ConstraintRef
end

"""
Error thrown when a variable representative of a set of subproblems is involved in a
constraint that belongs to a subproblem which is to in the set.

For example, consider a variable `x` representative of subproblems `A` and `B`.
Assume that a constraint of subproblem `C` involves variable `x`.
BlockDecomposition with throw `NotRepresentativeOfDwSp` error.
"""
struct NotRepresentativeOfDwSp
    variable::JuMP.VariableRef
    constraint::JuMP.ConstraintRef
end

"""
Error thrown when a Dantzig-Wolfe subproblem variable is involed in another Dantzig-Wolfe
subproblem.
"""
struct DwSpVarNotInGoodDwSp
    variable::JuMP.VariableRef
    constraint::JuMP.ConstraintRef
end

# Methods to check constraints and variables.

function _check_annotations(model::JuMP.Model, container::JC.DenseAxisArray)
    for indice_set in Iterators.product(container.axes...)
        _check_annotations(model, container[indice_set...])
    end
    return
end

function _check_annotations(model::JuMP.Model, container::JC.SparseAxisArray)
    for key in keys(container.data)
        _check_annotations(model, container[key...])
    end
    return
end

function _check_annotations(model::JuMP.Model, container::JuMP.ConstraintRef)
    _check_annotation(model, container)
    return
end

function _check_annotations(model::JuMP.Model, container::JuMP.VariableRef)
    _check_annotation(model, container)
    return
end

function _check_annotations(model::JuMP.Model, container::AbstractArray)
    for element in container
        _check_annotation(model, element)
    end
    return
end

_check_annotations(model::JuMP.Model, container::JuMP.AffExpr) = nothing

# Type of checks
abstract type DecompositionCheck end

# when the verfication consists in checking the annotation of an element in another one 
# without caring about the previous verifications
abstract type IndepDecompositionCheck <: DecompositionCheck end

# when the verfication consists in checking the annotation of an element in another one 
# with caring about the previous verifications (=> accumulator)
abstract type AccDecompositionCheck <: DecompositionCheck end

"""
Checks:
- master variable in dantzig-wolfe subproblem
- dantzig-wolfe variable not in good subproblem
- representative variable not in good subproblem

"""
struct VarInDwSpCheck <: IndepDecompositionCheck end

struct VarsOfSameDwSpInMasterCheck <: AccDecompositionCheck end


# check_annotation methods

_check_annotation(model, elem) = nothing # fallback

function _check_annotation(model, constr::JuMP.ConstraintRef)
    a = MOI.get(model, ConstraintDecomposition(), constr)
    constr_func = JuMP.constraint_object(constr).func
    _check_dec_constr(model, constr_func, constr, a)
    return
end

# fallback
_check_dec_constr(
    ::IndepDecompositionCheck,
    ::JuMP.Model,
    ::JuMP.VariableRef,
    ::JuMP.ConstraintRef,
    ::Annotation{T,F,D}
) where {T,F,D} = nothing

_acc_check_dec_constr(
    ::AccDecompositionCheck,
    ::JuMP.Model,
    ::JuMP.AffExpr,
    ::JuMP.ConstraintRef,
    ::Annotation{T,F,D}
) where {T,F,D} = nothing

function _check_varindwsepcheck(annotation::Annotation, var, constr, sp)
    if getformulation(annotation) == Master
        throw(MasterVarInDwSp(var, constr))
    elseif annotation.axis_index_value !== sp.axis_index_value
        throw(DwSpVarNotInGoodDwSp(var, constr))
    end
    return
end

function _check_varindwsepcheck(annotations::Vector{<:Annotation}, var, constr, sp)
    axis_index_values = getfield.(annotations, :axis_index_value)
    if sp.axis_index_value ∉ axis_index_values
        throw(NotRepresentativeOfDwSp(var, constr))
    end
    return
end

function _check_dec_constr(
    ::VarInDwSpCheck,
    model::JuMP.Model,
    var::JuMP.VariableRef,
    constr::JuMP.ConstraintRef,
    sp::Annotation{T,F,D}
) where {T,F<:DwPricingSp,D<:DantzigWolfe}
    ann = MOI.get(model, VariableDecomposition(), var)
    _check_varindwsepcheck(ann, var, constr, sp)
    return
end

_isrepresentative(::Annotation) = false
_isrepresentative(::Vector{<:Annotation}) = true

function _acc_check_dec_constr(
    ::VarsOfSameDwSpInMasterCheck,
    model::JuMP.Model,
    func::JuMP.AffExpr,
    constr::JuMP.ConstraintRef,
    ::Annotation{T,F,D}
) where {T,F<:Master,D<:DantzigWolfe}
    prev_ann = nothing
    annotations = Iterators.map(((var, _),) -> MOI.get(model, VariableDecomposition(), var), func.terms)
    for annotation in annotations
        if _isrepresentative(annotation) || annotation.formulation != DwPricingSp || annotation.upper_multiplicity > 1 ||
            (!isnothing(prev_ann) && getid(prev_ann) != getid(annotation))
            return
        end
        prev_ann = annotation
    end
    @warn(VarsOfSameDwSpInMaster(constr))
    return
end

function _check_dec_constr(model::JuMP.Model, func::JuMP.AffExpr, constr::JuMP.ConstraintRef, annotation)
    for (var, _) in func.terms
        _check_dec_constr(VarInDwSpCheck(), model, var, constr, annotation)
    end
    _acc_check_dec_constr(VarsOfSameDwSpInMasterCheck(), model, func, constr, annotation)
    return
end

function _check_dec_constr(model::JuMP.Model, funcs::Vector{A}, constr::JuMP.ConstraintRef, a) where {A<:JuMP.AbstractJuMPScalar}
    for func in funcs
        _check_dec_constr(model, func, constr, a)
    end
    return
end
