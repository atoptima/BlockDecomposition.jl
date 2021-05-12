struct VarBranchingPriority <: MOI.AbstractVariableAttribute end

branchingpriority!(model, x::JuMP.VariableRef, branching_priority::Int) = MOI.set(
    model, VarBranchingPriority(), x, branching_priority
)

branchingpriority!(model, x::Array{JuMP.VariableRef}, branching_priority::Int) =
branchingpriority!.(model, x, branching_priority)

branchingpriority(model, x::JuMP.VariableRef) = MOI.get(model, VarBranchingPriority(), x)

branchingpriority(model, x::Array{JuMP.VariableRef}) = branchingpriority(model, x[1])

function MOI.set(
    dest::MOIU.UniversalFallback, attribute::VarBranchingPriority, vi::MOI.VariableIndex, value
)
    if !haskey(dest.varattr, attribute)
        dest.varattr[attribute] = Dict{MOI.VariableIndex, Tuple}()
    end
    dest.varattr[attribute][vi] = value
    return
end

function MOI.get(dest::MOIU.UniversalFallback, attribute::VarBranchingPriority, vi::MOI.VariableIndex)
    varattr = get(dest.varattr, attribute, nothing)
    varattr === nothing && return 1
    return get(varattr, vi, 1)
end