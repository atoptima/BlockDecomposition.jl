struct ObjectivePrimalBound <: MOI.AbstractModelAttribute end
struct ObjectiveDualBound <: MOI.AbstractModelAttribute end

objectiveprimalbound!(model, value::Real) = MOI.set(model, ObjectivePrimalBound(), value)
objectivedualbound!(model, value::Real) = MOI.set(model, ObjectiveDualBound(), value)

function MOI.set(
    dest::MOIU.UniversalFallback, attribute::ObjectivePrimalBound, value
)
    dest.modattr[attribute] = value
    return
end

function MOI.set(
    dest::MOIU.UniversalFallback, attribute::ObjectiveDualBound, value
)
    dest.modattr[attribute] = value
    return
end

function MOI.get(dest::MOIU.UniversalFallback, attribute::ObjectivePrimalBound)
    return get(dest.modattr, attribute, nothing)
end

function MOI.get(dest::MOIU.UniversalFallback, attribute::ObjectiveDualBound)
    return get(dest.modattr, attribute, nothing)
end