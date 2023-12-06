"""
    AbstractCustomData

Left for compatibility with BlockDecomposition versions 1.14.1 and below.
One should use [AbstractCustomVarData](@ref) or [AbstractCustomConstrData](@ref) instead.
"""
abstract type AbstractCustomData end

"""
    AbstractCustomVarData

Every custom data associated to a solution passed in [PricingSolution](@ref) 
should inherit from AbstractCustomVarData.

This data is used to 
- Determine the coefficient of the corresponding column in non-robust constraints
- Store the information about pricing solution not expressed with subproblem variables
  (and thus not used in the master formulation); this information can then be retrieved 
  using [customdata(info)]@ref by the user.
- determine the branching priority of the corresponding column 
  (if [branchingpriority(::AbstractCustomVarData)] is defined for the concrete type).
"""
abstract type AbstractCustomVarData <: AbstractCustomData end

branchingpriority(::Nothing) = nothing

"""
    branchingpriority(<:AbstractCustomVarData)

This function should be redefined for a concrete type which inherits from AbstractCustomVarData
if a custom branching priority is defined for columns associated with this data type.
If this function is not redefined, the branching priority of each column equals to the 
branching priority of the pricing problem which generated it. 
"""
branchingpriority(::AbstractCustomVarData) = nothing


"""
    AbstractCustomConstrData

Every custom data associated to a non-robust constraint should inherit from AbstractCustomConstrData.

This data is used to determine the coefficient of the columns in non-robust constraints.
"""
abstract type AbstractCustomConstrData <: AbstractCustomData end

function MOI.submit(
    model, cb, con::JuMP.AbstractConstraint, custom_data::AbstractCustomConstrData
)
    return MOI.submit(JuMP.backend(model), cb, JuMP.moi_function(con.func), con.set, custom_data)
end

struct CustomVars <: MOI.AbstractModelAttribute end
struct CustomConstrs <: MOI.AbstractModelAttribute end

"""
    customvars!(model, customvar::Type{<:AbstractCustomVarData})
    customvars!(model, customvars::Vector{Type{<:AbstractCustomVarData}})

Set the possible custom data types of variables in a model.
"""
customvars!(model, customvar::Type{<:AbstractCustomData}) = MOI.set(
    model, CustomVars(), [customvar]
)
customvars!(model, customvars::Vector{DataType}) = MOI.set(
    model, CustomVars(), customvars
)

"""
    customconstrs!(model, customconstr::Type{AbstractCustomConstrData})
    customconstrs!(model, customconstrs::Vector{Type{AbstractCustomConstrData}})

Set the possible custom data types of constraints in a model.
"""
customconstrs!(model, customconstr::Type{<:AbstractCustomData}) = MOI.set(
    model, CustomConstrs(), [customconstr]
)
customconstrs!(model, customconstrs::Vector{DataType}) = MOI.set(
    model, CustomConstrs(), customconstrs
)

"""
    customvars(model)

Return the possible custom data types of variables in a model.
"""
customvars(model) = MOI.get(model, CustomVars())

"""
    customconstrs(model)

Return the custom data types of constraints in a model.
"""
customconstrs(model) = MOI.get(model, CustomConstrs())

function MOI.set(
    dest::MOIU.UniversalFallback, attribute::CustomVars, value
)
    if !haskey(dest.modattr, attribute)
        dest.modattr[attribute] = Type{<:AbstractCustomData}[]
    end
    for elem in value
        push!(dest.modattr[attribute], elem)
    end
    return
end

function MOI.set(
    dest::MOIU.UniversalFallback, attribute::CustomConstrs, value
)
    if !haskey(dest.modattr, attribute)
        dest.modattr[attribute] = Type{<:AbstractCustomData}[]
    end
    for elem in value
        push!(dest.modattr[attribute], elem)
    end
    return
end

function MOI.get(dest::MOIU.UniversalFallback, attribute::CustomVars)
    return get(dest.modattr, attribute, Type{<:AbstractCustomData}[])
end

function MOI.get(dest::MOIU.UniversalFallback, attribute::CustomConstrs)
    return get(dest.modattr, attribute, Type{<:AbstractCustomData}[])
end

struct CustomVarValue <: MOI.AbstractVariableAttribute end
struct CustomConstrValue <: MOI.AbstractConstraintAttribute end

"""
    customdata!(var, custom_data)
    customdata!(constr, custom_data)

Attach a custom data to a variable or a constraint.
"""
customdata!(x::JuMP.VariableRef, custom_data) = MOI.set(
    x.model, CustomVarValue(), x, custom_data
)
customdata!(c::JuMP.ConstraintRef, custom_data) = MOI.set(
    c.model, CustomConstrValue(), c, custom_data
)

"""
    customdata(var)
    customdata(constr)

Returns the custom data attached to a variable or a constraint; `nothing` if no custom data.
"""
customdata(x::JuMP.VariableRef) = MOI.get(x.model, CustomVarValue(), x)
customdata(c::JuMP.ConstraintRef) = MOI.get(c.model, CustomConstrValue(), c)


"""
Error thrown if you try to attach a custom data type to a variable or a constraint that has
not been registered with `customvars!` or `customconstrs!`.
"""
struct UnregisteredCustomDataFamily
    name::String
end

function MOI.set(
    dest::MOIU.UniversalFallback, attribute::CustomVarValue, vi::MOI.VariableIndex, value::CD
) where {CD<:AbstractCustomData}
    if CD ∉ MOI.get(dest, CustomVars())
        throw(UnregisteredCustomDataFamily(string(CD)))
    end
    if !haskey(dest.varattr, attribute)
        dest.varattr[attribute] = Dict{MOI.VariableIndex,Any}()
    end
    dest.varattr[attribute][vi] = value
    return
end

function MOI.get(dest::MOIU.UniversalFallback, attribute::CustomVarValue, vi::MOI.VariableIndex)
    varattr = get(dest.varattr, attribute, nothing)
    isnothing(varattr) && return nothing
    return get(varattr, vi, nothing)
end

function MOI.set(
    dest::MOIU.UniversalFallback, attribute::CustomConstrValue, ci::MOI.ConstraintIndex, value::CD
) where {CD<:AbstractCustomData}
    if CD ∉ MOI.get(dest, CustomConstrs())
        throw(UnregisteredCustomDataFamily(string(CD)))
    end
    if !haskey(dest.conattr, attribute)
        dest.conattr[attribute] = Dict{MOI.ConstraintIndex,Any}()
    end
    dest.conattr[attribute][ci] = value
    return
end

function MOI.get(dest::MOIU.UniversalFallback, attribute::CustomConstrValue, ci::MOI.ConstraintIndex)
    constrattr = get(dest.conattr, attribute, nothing)
    isnothing(constrattr) && return nothing
    return get(constrattr, ci, nothing)
end

MathOptInterface.Utilities.map_indices(
    ::MathOptInterface.Utilities.IndexMap, x::AbstractCustomData
) = x
MathOptInterface.Utilities.map_indices(
    ::MathOptInterface.Utilities.IndexMap, x::Vector{AbstractCustomData}
) = x

# added for compatibility with MathOptInterface v1.23
MathOptInterface.Utilities.map_indices(::Function, x::AbstractCustomData) = x
MathOptInterface.Utilities.map_indices(::Function, x::Vector{AbstractCustomData}) = x
