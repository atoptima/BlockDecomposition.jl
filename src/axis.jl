import Base.length
import Base.iterate
import Base.getindex
import Base.lastindex

struct Axis{T, V <: AbstractArray{T}}
    name::Symbol # Name of the axis (as declared in the macro)
    id::Tuple    # id of the axis if it has been stored in an SparseAxisArray
    container::V
    identical::Bool
    function Axis(n::Symbol, id::Tuple, c::V, i::Bool) where {T, V <: AbstractArray{T}}
        return new{T, V}(n, id, c, i)
    end
end

name(axis::Axis) =  axis.name
id(axis::Axis) = axis.id
iterate(axis::Axis) = iterate(axis.container)
iterate(axis::Axis, state) = iterate(axis.container, state)
length(axis::Axis) = length(axis.container)
identical(axis::Axis) = axis.identical
getindex(axis::Axis, elements) = getindex(axis.container, elements)
lastindex(axis::Axis) = lastindex(axis.container)

macro axis(args...)
    definition = args[1]
    container = args[2]
    identical = _axis_identical_(args)
    exp = :()
    if typeof(definition) != Symbol
        exp = generate_axis_dense_array(definition, container, identical)
    else
        name = definition
        exp = :($name = $(generate_axis(name, container, identical)))
    end
    return esc(exp)
end

function generate_axis(name, id, container, i::Bool)
    sym_name = Meta.parse("Symbol(\"" * string(name) * "\")")
    return :(BlockDecomposition.Axis($sym_name, $id, $container, $i))
end

function generate_axis(name, container, i::Bool)
    return generate_axis(name, :(tuple()), container, i)
end

function _axis_identical_(args)
    if length(args) == 3
        if args[3] == :Identical
            return true
        else
            error("Third argument must be Identical but it is optional.")
        end
    end
    return false
end

function _axis_array_indices_(indexsets)
    return [indexset.args[2] for indexset in indexsets]
end

function _axis_array_sets_(indexsets)
    return [indexset.args[3] for indexset in indexsets]
end

# Returns a JuMP.Container.DenseAxisArray{Axis}
# see https://github.com/JuliaOpt/JuMP.jl/blob/master/src/Containers/DenseAxisArray.jl
function generate_axis_dense_array(definition, container, identical)
    name = definition.args[1]
    indexsets = definition.args[2:end]
    nbindexsets = length(indexsets)
    indices = _axis_array_indices_(indexsets)
    sets = _axis_array_sets_(indexsets)
    decomposition_axis = generate_axis(name, Expr(:tuple, indices...), container, identical)
    generator = Expr(:generator, decomposition_axis, [Expr(:(=), indices[i], sets[i]) for i in 1:nbindexsets]...)
    array = Expr(:comprehension, generator)
    axisarray = Expr(:call, JuMP.Containers.DenseAxisArray, array, sets...)
    return :($name = $axisarray)
end