abstract type AbstractColumnInfo end

"""
    getsolutions(model, k)

Return a vector of information about the columns in the subproblem `k` solution.
"""
getsolutions(model::JuMP.Model, k) = getsolutions(JuMP.backend(model), k)
getsolutions(model::MOI.Utilities.CachingOptimizer, k) = getsolutions(model.optimizer, k)
getsolutions(b::MOI.Bridges.AbstractBridgeOptimizer, k) = getsolutions(b.model, k)
getsolutions(model::MOI.AbstractOptimizer, k) = error(
    "getsolutions(::$(typeof(model)), ::$(typeof(k))) not defined."
)
getsolutions(::Nothing, k) = error("No solver defined.")

"""
    value(info)

Return the value of the master column variable associated to `info`.
"""
value(info::AbstractColumnInfo) = error("value(::$(typeof(info))) not defined.")

"""
    value(info, x)

Return the coefficient of original variable `x` in the column associated to `info`.
"""
value(info::AbstractColumnInfo, x::JuMP.VariableRef) = value(info, x.index)
value(info::AbstractColumnInfo, ::MOI.VariableIndex) = error(
    "value(::$(typeof(info)), ::MOI.VariableIndex) not defined."
)
