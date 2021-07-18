struct CustomVars <: MOI.AbstractModelAttribute end
struct CustomConstrs <: MOI.AbstractModelAttribute end

"""
    customvars!(model, customvars::DataType)
    customvars!(model, customvars::Vector{DataType})

Set the possible custom data types of variables in a model.
"""
customvars!(model, customvars::DataType) = MOI.set(
    model, CustomVars(), [customvars]
)
customvars!(model, customvars::Vector{DataType}) = MOI.set(
    model, CustomVars(), customvars
)

"""
    customconstrs!(model, customconstrs::DataType)
    customconstrs!(model, customconstrs::Vector{DataType})

Set the possible custom data types of constraints in a model.
"""
customconstrs!(model, customconstrs::DataType) = MOI.set(
    model, CustomConstrs(), [customconstrs]
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
