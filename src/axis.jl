import Base.length
import Base.iterate
import Base.getindex
import Base.lastindex
import Base.to_index
import Base.hash
import Base.isequal

struct AxisId{Name, T}
    indice::T
end

function name(i::AxisId{Name,T}) where {Name,T}
    return Name
end

function indice(i::AxisId{Name,T})::T where {Name,T}
    return i.indice
end

Base.hash(i::AxisId, h::UInt) = hash(i.indice, h)

# Permit the access to the entry of an array using an AxisId.
Base.to_index(i::AxisId) = i.indice

# Allow matching of AxisId key using the value of field indice (dict.jl:289)
# and vice-versa
Base.isequal(i::T, j::AxisId{N,T}) where {N,T} = isequal(i, j.indice)
Base.isequal(i::AxisId{N,T}, j::T) where {N,T} = isequal(i.indice, j)

iterate(i::AxisId) = (i, nothing)
iterate(i::AxisId, ::Any) = nothing
Base.show(io::IO, i::AxisId) = show(io, i.indice)

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

