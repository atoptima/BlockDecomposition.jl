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
    variables::Vector{JuMP.VariableRef},
    values::Vector{Float64}
)
    return MOI.submit(JuMP.backend(model), cb, JuMP.index.(variables), values)
end

"""
doc todo
"""
struct OracleVariableCost{OracleDataType} <: MOI.AbstractVariableAttribute
    oracle_data::OracleDataType
end

# a method symetrical to callback_value (JuMP.jl/src/callbacks.jl:19)
function oracle_cost(oracle_data, x::JuMP.VariableRef)
    return MOI.get(
        JuMP.backend(JuMP.owner_model(x), OracleVariableCost(oracle_data)),
        index(x)
    )
end

"""
doc todo
"""
struct OracleSubproblemId{OracleDataType} <: MOI.AbstractModelAttribute
    oracle_data::OracleDataType
end

function oracle_spid(oracle_data, model::JuMP.Model)
    return MOI.get(JuMP.backend(model), OracleSubproblemId(oracle_data))
end
