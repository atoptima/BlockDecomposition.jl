struct CustomVars <: MOI.AbstractModelAttribute end
struct CustomConstrs <: MOI.AbstractModelAttribute end

addcustomvars!(model, customvars::Vector{DataType}) = MOI.set(
    model, CustomVars(), customvars
)

addcustomconstrs!(model, customconstrs::Vector{DataType}) = MOI.set(
    model, CustomConstrs(), customconstrs
)

customvars(model) = MOI.get(model, CustomVars())

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
    return get(dest.modattr, attribute, nothing)
end

function MOI.get(dest::MOIU.UniversalFallback, attribute::CustomConstrs)
    return get(dest.modattr, attribute, nothing)
end
