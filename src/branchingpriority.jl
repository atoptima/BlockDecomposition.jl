struct VarBranchingPriority <: MOI.AbstractVariableAttribute end

"""
    branchingpriority!(x, value::Float64)

Set the branching priority of variable `x` to `value`.

You can use fractional branching priorities. 
The idea is to have both "soft" and "hard" branching priorities. For instance :
- if the number of branching candidates with priority 4.0 is less than the maximum number of candidates considered, no branching candidates with priority 3.0 will be considered
- if the number of branching candidates with priority 3.5 is less than the maximum number of candidates considered, then some branching candidates with priority 3.0 will be considered (to bring the total number to the maximum)
- if the number of branching candidates with priority 3.5 is not less than the maximum number, then no branching candidates with priority 3.0 will be considered

Branching priority is also used in rounding and diving heuristics to determine which variables should be fixed first. 
"""
branchingpriority!(x::JuMP.VariableRef, priority) = MOI.set(
    x.model, VarBranchingPriority(), x, priority
)
@deprecate branchingpriority!(model, x::JuMP.VariableRef, priority) branchingpriority!(x, priority)

"""
    branchingpriority(x)

Return the branching priority of variable `x`.
"""
branchingpriority(x::JuMP.VariableRef) = MOI.get(x.model, VarBranchingPriority(), x)
@deprecate branchingpriority(model, x::JuMP.VariableRef) branchingpriority(x)

function MOI.set(
    dest::MOIU.UniversalFallback, attribute::VarBranchingPriority, vi::MOI.VariableIndex, value
)
    if !haskey(dest.varattr, attribute)
        dest.varattr[attribute] = Dict{MOI.VariableIndex, Float64}()
    end
    dest.varattr[attribute][vi] = value
    return
end

function MOI.get(dest::MOIU.UniversalFallback, attribute::VarBranchingPriority, vi::MOI.VariableIndex)
    varattr = get(dest.varattr, attribute, nothing)
    isnothing(varattr) && return 1.0
    return get(varattr, vi, 1.0)
end
