struct ObjectivePrimalBound <: MOI.AbstractModelAttribute end
struct ObjectiveDualBound <: MOI.AbstractModelAttribute end

"""
    objectiveprimalbound!(model, pb)

Define a primal bound on the optimal objective value 
(upper bound for a minimisation, lower bound for a maximisation).
"""
objectiveprimalbound!(model, value::Real) = MOI.set(model, ObjectivePrimalBound(), value)

"""
    objectivedualbound!(model, db)

Define a dual bound on the optimal objective value.
(lower bound for a minimisation, upper bound for a maximisation)
"""
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