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