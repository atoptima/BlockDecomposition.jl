abstract type AbstractColumnInfo end
struct SpInfos <: MOI.AbstractModelAttribute end
struct SpInfo
    columns_infos::Vector{AbstractColumnInfo}
end

getsolutions(model, k) = MOI.get(model, SpInfos())[k].columns_infos

function MOI.set(
    dest::MOIU.UniversalFallback, attribute::SpInfos, value::Vector{SpInfo}
)
    dest.modattr[attribute] = value
    return
end

function MOI.get(dest::MOIU.UniversalFallback, attribute::SpInfos)
    return get(dest.modattr, attribute, nothing)
end
