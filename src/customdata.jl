struct CustomVars <: MOI.AbstractModelAttribute end
struct CustomConstrs <: MOI.AbstractModelAttribute end

"""
    customvars!(model, customvar::DataType)
    customvars!(model, customvars::Vector{DataType})

Set the possible custom data types of variables in a model.
"""
customvars!(model, customvar::DataType) = MOI.set(
    model, CustomVars(), [customvar]
)
customvars!(model, customvars::Vector{DataType}) = MOI.set(
    model, CustomVars(), customvars
)

"""
    customconstrs!(model, customconstr::DataType)
    customconstrs!(model, customconstrs::Vector{DataType})

Set the possible custom data types of constraints in a model.
"""
customconstrs!(model, customconstr::DataType) = MOI.set(
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
    dest.modattr[attribute] = value
    return
end

function MOI.set(
    dest::MOIU.UniversalFallback, attribute::CustomConstrs, value
)
    dest.modattr[attribute] = value
    return
end

function MOI.get(dest::MOIU.UniversalFallback, attribute::CustomVars)
    return get(dest.modattr, attribute, [])
end

function MOI.get(dest::MOIU.UniversalFallback, attribute::CustomConstrs)
    return get(dest.modattr, attribute, [])
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
) where CD
    if CD ∉ MOI.get(dest, CustomVars())
        throw(UnregisteredCustomDataFamily(string(CD)))
    end
    if !haskey(dest.varattr, attribute)
        dest.varattr[attribute] = Dict{MOI.VariableIndex, Any}()
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
) where CD
    if CD ∉ MOI.get(dest, CustomConstrs())
        throw(UnregisteredCustomDataFamily(string(CD)))
    end
    if !haskey(dest.conattr, attribute)
        dest.conattr[attribute] = Dict{MOI.ConstraintIndex, Any}()
    end
    dest.conattr[attribute][ci] = value
    return
end

function MOI.get(dest::MOIU.UniversalFallback, attribute::CustomConstrValue, ci::MOI.ConstraintIndex)
    constrattr = get(dest.conattr, attribute, nothing)
    isnothing(constrattr) && return nothing
    return get(constrattr, ci, nothing)
end