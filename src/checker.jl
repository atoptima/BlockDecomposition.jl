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

# check_annotation methods

_check_annotation(model, elem) = nothing # fallback

function _check_annotation(model, constr::JuMP.ConstraintRef)
    a = MOI.get(model, ConstraintDecomposition(), constr)
    constr_func = JuMP.constraint_object(constr).func
    _check_dec_constr(model, constr_func, constr, a)
    return
end

"""
    MasterVarInDwSp

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

# fallback
_check_dec_constr(::JuMP.Model, ::JuMP.VariableRef, ::JuMP.ConstraintRef, ::Annotation{T,F,D}) where {T,F,D} = nothing

function _check_dec_constr(model::JuMP.Model, var::JuMP.VariableRef, constr::JuMP.ConstraintRef, ::Annotation{T,F,D}) where {T,F<:DwPricingSp,D<:DantzigWolfe}
    if MOI.get(model, VariableDecomposition(), var).formulation == Master
        throw(MasterVarInDwSp(var, constr))
    end
    return
end

function _check_dec_constr(model::JuMP.Model, func::JuMP.AffExpr, constr::JuMP.ConstraintRef, a)
    for (var, _) in func.terms
        _check_dec_constr(model, var, constr, a)
    end
    return
end

function _check_dec_constr(model::JuMP.Model, funcs::Vector{A}, constr::JuMP.ConstraintRef, a) where {A<:JuMP.AbstractJuMPScalar}
    for func in funcs
        _check_dec_constr(model, func, constr, a)
    end
    return
end