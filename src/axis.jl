import Base.length
import Base.iterate
import Base.getindex
import Base.lastindex

struct Axis{T, V <: AbstractArray{T}}
    name::Symbol # Name of the axis (as declared in the macro)
    id::Tuple    # id of the axis if it has been stored in an SparseAxisArray
    container::V
    identical::Bool
    lb::Int
    function Axis(n::Symbol, id::Tuple, c::V, i::Bool, lb::Int) where {T, V <: AbstractArray{T}}
        return new{T, V}(n, id, c, i, lb)
    end
end

name(axis::Axis) =  axis.name
id(axis::Axis) = axis.id
iterate(axis::Axis) = iterate(axis.container)
iterate(axis::Axis, state) = iterate(axis.container, state)
length(axis::Axis) = length(axis.container)
identical(axis::Axis) = axis.identical
lowermultiplicity(axis::Axis) = axis.lb
getindex(axis::Axis, elements) = getindex(axis.container, elements)
lastindex(axis::Axis) = lastindex(axis.container)

function _axis_extra_args(args)
    identical = false
    lb_mult = 1
    if length(args) >= 3
        identical, lb_mult = _axis_extra_arg!(args[3], identical, lb_mult)
    end
    if length(args) >= 4
        identical, lb_mult = _axis_extra_arg!(args[4], identical, lb_mult)
    end
    if length(args) >= 5 
        error("Axis declaration has too many arguments.")
    end
    return identical, lb_mult
end

function _axis_extra_arg!(arg::Symbol, identical, lb_mult)
    if arg == :Identical
        identical = true
    else
        error("Unknown argument $arg in axis declaration.")
    end
    return identical, lb_mult
end

function _axis_extra_arg!(arg::Expr, identical, lb_mult)
    if arg.head == :(=) && arg.args[1] == :lb
        lb_mult = Int(arg.args[2])
    else
        error("Unknown argument $arg in axis declaration.")
    end
    return identical, lb_mult
end

function _axis_array_indices(indexsets)
    return [indexset.args[2] for indexset in indexsets]
end

function _axis_array_sets(indexsets)
    return [indexset.args[3] for indexset in indexsets]
end

function _generate_axis(name, id, container, i::Bool, lb_mult::Int)
    sym_name = Meta.parse("Symbol(\"" * string(name) * "\")")
    return :(BlockDecomposition.Axis($sym_name, $id, $container, $i, $lb_mult))
end

function _generate_axis(name, container, i::Bool, lb_mult::Int)
    return _generate_axis(name, :(tuple()), container, i, lb_mult)
end

# Returns a JuMP.Container.DenseAxisArray{Axis}
# see https://github.com/JuliaOpt/JuMP.jl/blob/master/src/Containers/DenseAxisArray.jl
function _generate_axis_dense_array(definition, container, identical, lb_mult)
    name = definition.args[1]
    indexsets = definition.args[2:end]
    nbindexsets = length(indexsets)
    indices = _axis_array_indices(indexsets)
    sets = _axis_array_sets(indexsets)
    decomposition_axis = _generate_axis(name, Expr(:tuple, indices...), container, identical, lb_mult)
    generator = Expr(:generator, decomposition_axis, [Expr(:(=), indices[i], sets[i]) for i in 1:nbindexsets]...)
    array = Expr(:comprehension, generator)
    axisarray = Expr(:call, JuMP.Containers.DenseAxisArray, array, sets...)
    return :($name = $axisarray)
end

macro axis(args...)
    definition = args[1]
    container = args[2]
    identical, lb_mult = _axis_extra_args(args)
    exp = :()
    if typeof(definition) != Symbol
        exp = _generate_axis_dense_array(definition, container, identical, lb_mult)
    else
        name = definition
        exp = :($name = $(_generate_axis(name, container, identical, lb_mult)))
    end
    return esc(exp)
end

