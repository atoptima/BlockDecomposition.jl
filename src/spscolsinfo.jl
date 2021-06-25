struct SpsColsInfo <: MOI.AbstractModelAttribute end
MOI.is_set_by_optimize(::SpsColsInfo) = true

abstract type AbstractColumnInfo end
struct SpColsInfo
    columns_info::Vector{AbstractColumnInfo}
end

```
    getsolutions(model, k)

Return a vector of information about the columns in the subproblem `k` solution.
```
getsolutions(model, k) = MOI.get(model, SpsColsInfo())[k].columns_info

function MOI.set(
    dest::MOIU.UniversalFallback, attribute::SpsColsInfo, value::Vector{SpColsInfo}
)
    dest.modattr[attribute] = value
    return
end

function MOI.get(dest::MOIU.UniversalFallback, attribute::SpsColsInfo)
    return get(dest.modattr, attribute, nothing)
end

MathOptInterface.Utilities.map_indices(
    ::MathOptInterface.Utilities.IndexMap, x::Vector{SpColsInfo}
) = x

value(info::AbstractColumnInfo) = error(
    "value(::$(typeof(info))) not defined."
)

value(info::AbstractColumnInfo, x::JuMP.VariableRef) = value(info, x.index)
value(info::AbstractColumnInfo, ::MOI.VariableIndex) = error(
    "value(::$(typeof(info)), ::MOI.VariableIndex) not defined."
)
