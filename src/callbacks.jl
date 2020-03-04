"""
    PricingOracle(oracle_data)

doc todo but it works like HeuristicSolution callback.
The user submits the solution as `variables, values` where `values[i]` gives
the value of `variables[i]`.
"""
struct PricingOracle{OracleDataType} <: MOI.AbstractSubmittable
    oracle_data::OracleDataType
end

