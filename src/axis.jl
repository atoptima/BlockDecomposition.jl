import Base.length
import Base.iterate
import Base.getindex
import Base.lastindex
import Base.to_index
import Base.hash
import Base.isequal
import Base.isless
import Base.==
import Base.vcat

struct AxisId{Name, T}
    indice::T
end

MOIU.map_indices(::Function, x::AxisId) = x

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
Base.isless(i::T, j::AxisId{N,T}) where {N,T} = isless(i, j.indice)
Base.isless(i::AxisId{N,T}, j::T) where {N,T} = isless(i.indice, j)
Base.:(==)(i::T, j::AxisId{N,T}) where {N,T} = i == j.indice
Base.:(==)(i::AxisId{N,T}, j::T) where {N,T} = i.indice == j

# Allow matching of AxisId key in the DenseAxisArray
Base.getindex(
    ax::JuMP.Containers._AxisLookup{<:Base.OneTo}, 
    k::AxisId{Name, T}
) where {Name,T<:Integer} = getindex(ax, k.indice)

Base.getindex(
    x::JuMP.Containers._AxisLookup{Tuple{T,T}},
    key::AxisId{Name,T},
) where {Name, T} = getindex(x, key.indice)

Base.getindex(
    x::JuMP.Containers._AxisLookup{Dict{K,Int}}, 
    key::AxisId{Name,K}
) where {Name,K} = getindex(x, key.indice)

# Iterate over the AxisId
iterate(i::AxisId) = (i, nothing)
iterate(i::AxisId, ::Any) = nothing

Base.show(io::IO, i::AxisId) = show(io, i.indice)
Base.length(i::AxisId) = 1

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
vcat(A::BlockDecomposition.Axis, B::AbstractArray) = vcat(A.container, B)

×(args...) = Iterators.product(args...)

function _generate_axis(name, container)
    sym_name = Meta.parse("Symbol(\"" * string(name) * "\")")
    return :(BlockDecomposition.Axis($sym_name, $container))
end

"""
    @axis(name, collection)

Declare `collection` as an index-set of subproblems. 
You can access the axis using the variable `name`.

# Examples
```julia-repl
julia> @axis(K, 1:5)
BlockDecomposition.Axis{:K, Int64}(:K, BlockDecomposition.AxisId{:K, Int64}[1, 2, 3, 4, 5])
```

In this example, we declare an axis named `K` that contains 5 entries. 
The index-set of the subproblems is `[1, 2, 3, 4, 5]`.

```julia-repl
julia> K[1]
1

julia> typeof(K[1])
BlockDecomposition.AxisId{:K, Int64}
```

The elements of the axis are `AxisId`. The user must use `AxisId` in the indices
of the variables and the constraints because BlockDecomposition use them to 
decompose the MIP.
"""
macro axis(args...)
    nbargs = length(args)
    nbargs > 2 && error("Axis declaration: too much arguments.")
    name = args[1]
    container = (nbargs == 2) ? args[2] : name
    exp = :()
    if typeof(name) != Symbol
        error("First argument of @axis is incorrect. The axis name is expected.")
    end

    container_exp = :()
    if container isa Expr && container.head == :call
        container_exp = :(collect($container))
    else
        container_exp = :($container)
    end

    exp = :($name = $(_generate_axis(name, container_exp)))
    return esc(exp)
end

