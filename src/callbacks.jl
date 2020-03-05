"""
    PricingSolution(cbdata)

doc todo but it works like HeuristicSolution callback.
The user submits the solution as `variables, values` where `values[i]` gives
the value of `variables[i]`.
"""
struct PricingSolution{CbDataType} <: MOI.AbstractSubmittable
    callback_data::CbDataType
end

function MOI.submit(
    model::Model,
    cb::PricingSolution,
    cost::Float64,
    variables::Vector{JuMP.VariableRef},
    values::Vector{Float64}
)
    return MOI.submit(
        JuMP.backend(model), cb, cost, JuMP.index.(variables), values
    )
end

"""
doc todo
"""
struct PricingVariableCost{CbDataType} <: MOI.AbstractVariableAttribute
    callback_data::CbDataType
end
MOI.is_set_by_optimize(::PricingVariableCost) = true

# a method symetrical to callback_value (JuMP.jl/src/callbacks.jl:19)
function callback_reduced_cost(cbdata, x::JuMP.VariableRef)
    return MOI.get(
        JuMP.backend(JuMP.owner_model(x)), PricingVariableCost(cbdata),
        index(x)
    )
end

"""
doc todo
"""
struct PricingSubproblemId{CbDataType} <: MOI.AbstractModelAttribute
    callback_data::CbDataType
end
MOI.is_set_by_optimize(::PricingSubproblemId) = true

function callback_spid(cbdata, model::JuMP.Model)
    return MOI.get(JuMP.backend(model), PricingSubproblemId(cbdata))
end

"""
doc todo
"""
struct PricingVariableLowerBound{CbDataType} <: MOI.AbstractVariableAttribute
    callback_data::CbDataType
end
MOI.is_set_by_optimize(::PricingVariableLowerBound) = true

function callback_lb(cbdata, x::JuMP.VariableRef)
    return MOI.get(
        JuMP.backend(JuMP.owner_model(x)), 
        PricingVariableLowerBound(cbdata), index(x)
    )
end

"""
doc todo
"""
struct PricingVariableUpperBound{CbDataType} <: MOI.AbstractVariableAttribute
    callback_data::CbDataType
end
MOI.is_set_by_optimize(::PricingVariableUpperBound) = true

function callback_ub(cbdata, x::JuMP.VariableRef)
    return MOI.get(
        JuMP.backend(JuMP.owner_model(x)), 
        PricingVariableUpperBound(cbdata), index(x)
    )
end
