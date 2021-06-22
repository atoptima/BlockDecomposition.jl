struct SpsInfo <: MOI.AbstractModelAttribute end
MOI.is_set_by_optimize(::SpsInfo) = true

abstract type AbstractColumnInfo end
struct SpInfo
    columns_info::Vector{AbstractColumnInfo}
end

getsolutions(model, k) = MOI.get(model, SpsInfo())[k].columns_info

function MOI.set(
    dest::MOIU.UniversalFallback, attribute::SpsInfo, value::Vector{SpInfo}
)
    dest.modattr[attribute] = value
    return
end

function MOI.get(dest::MOIU.UniversalFallback, attribute::SpsInfo)
    return get(dest.modattr, attribute, nothing)
end

MathOptInterface.Utilities.map_indices(
    ::MathOptInterface.Utilities.IndexMap, x::Vector{SpInfo}
) = x
