import Base.length
import Base.iterate
import Base.getindex
import Base.lastindex

struct Axis{T, V <: AbstractArray{T}}
    name::Symbol # Name of the axis (as declared in the macro)
    container::V
end

name(axis::Axis) =  axis.name
iterate(axis::Axis) = iterate(axis.container)
iterate(axis::Axis, state) = iterate(axis.container, state)
length(axis::Axis) = length(axis.container)
getindex(axis::Axis, elements) = getindex(axis.container, elements)
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

