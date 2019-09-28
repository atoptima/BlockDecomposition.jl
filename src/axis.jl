import Base.length
import Base.iterate
import Base.getindex
import Base.lastindex

struct AxisId{Name, T}
    indice::T
end

#Base.show(io::IO, i::AxisId) = show(io, i.indice)

struct Axis{Name, T}
    name::Symbol
    container::Vector{AxisId{Name, T}}
end

function Axis(name::Symbol, container::A) where {T, A <: AbstractArray{T}}
    indices = AxisId{name, T}[]
    for val in container
        push!(indices, AxisId{name, T}(val))
    end
    return Axis{name, T}(name, indices)
end

name(axis::Axis) =  axis.name
function iterate(axis::Axis)
    iter_result = iterate(axis.container)
    (iter_result === nothing) && return nothing
    (element, state) = iter_result
    return element.indice, state
end

function iterate(axis::Axis, state)
    iter_result = iterate(axis.container, state)
    (iter_result === nothing) && return nothing
    (element, state) = iter_result
    return element.indice, state
end

length(axis::Axis) = length(axis.container)
getindex(axis::Axis, elements) = getindex(axis.container, elements).indice
lastindex(axis::Axis) = lastindex(axis.container)

function _generate_axis(name, container)
    sym_name = Meta.parse("Symbol(\"" * string(name) * "\")")
    return :(BlockDecomposition.Axis($sym_name, $container))
end

macro axis(args...)
    nbargs = length(args)
    nbargs > 2 && error("Axis declaration: too much arguments.")
    name = args[1]
    container = (nbargs == 2) ? args[2] : name
    exp = :()
    if typeof(name) != Symbol
        error("First argument of @axis is incorrect. The axis name is expected.")
    end
    exp = :($name = $(_generate_axis(name, container)))
    return esc(exp)
end

