"""
    PricingSolution(oracle_data)

doc todo but it works like HeuristicSolution callback.
The user submits the solution as `variables, values` where `values[i]` gives
the value of `variables[i]`.
"""
struct PricingSolution{OracleDataType} <: MOI.AbstractSubmittable
    oracle_data::OracleDataType
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
struct OracleVariableCost{OracleDataType} <: MOI.AbstractVariableAttribute
    oracle_data::OracleDataType
end
MOI.is_set_by_optimize(::OracleVariableCost) = true

# a method symetrical to callback_value (JuMP.jl/src/callbacks.jl:19)
function oracle_cost(oracle_data, x::JuMP.VariableRef)
    return MOI.get(
        JuMP.backend(JuMP.owner_model(x)), OracleVariableCost(oracle_data),
        index(x)
    )
end

"""
doc todo
"""
struct OracleSubproblemId{OracleDataType} <: MOI.AbstractModelAttribute
    oracle_data::OracleDataType
end
MOI.is_set_by_optimize(::OracleSubproblemId) = true

function oracle_spid(oracle_data, model::JuMP.Model)
    return MOI.get(JuMP.backend(model), OracleSubproblemId(oracle_data))
end

"""
doc todo
"""
struct OracleVariableLowerBound{OracleDataType} <: MOI.AbstractVariableAttribute
    oracle_data::OracleDataType
end
MOI.is_set_by_optimize(::OracleVariableLowerBound) = true

function oracle_lb(oracle_data, x::JuMP.VariableRef)
    return MOI.get(
        JuMP.backend(JuMP.owner_model(x)), 
        OracleVariableLowerBound(oracle_data), index(x)
    )
end

"""
doc todo
"""
struct OracleVariableUpperBound{OracleDataType} <: MOI.AbstractVariableAttribute
    oracle_data::OracleDataType
end
MOI.is_set_by_optimize(::OracleVariableUpperBound) = true

function oracle_ub(oracle_data, x::JuMP.VariableRef)
    return MOI.get(
        JuMP.backend(JuMP.owner_model(x)), 
        OracleVariableUpperBound(oracle_data), index(x)
    )
end
