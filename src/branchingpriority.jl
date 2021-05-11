struct VarBranchingPriority <: MOI.AbstractVariableAttribute end

branchingpriority!(model, x::JuMP.VariableRef, branching_priority::Int) = MOI.set(
    model, VarBranchingPriority(), x, branching_priority
)

branchingpriority(model, x::JuMP.VariableRef) = MOI.get(model, VarBranchingPriority(), x)

function MOI.set(
    dest::MOIU.UniversalFallback, attribute::VarBranchingPriority, value
)
    dest.modattr[attribute] = value
    return
end

function MOI.get(dest::MOIU.UniversalFallback, attribute::VarBranchingPriority)
    return get(dest.modattr, attribute, nothing)
end