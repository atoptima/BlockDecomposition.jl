# When you call a decomposition macro, it returns a pointer to the Decomposition
# node from where the decomposition has been performed.
# A decomposition node should contains : the master & a vector of subproblems
abstract type AbstractNode end

mutable struct Tree
    root::AbstractNode
    nb_masters::Int
    nb_subproblems::Int
    current_uid::Int
    function Tree(D::Type{<: Decomposition}, axis::Axis)
        t = new()
        t.nb_masters = 0
        t.nb_subproblems = 0
        t.current_uid = 0
        r = Root(t, D, axis)
        t.root = r
        return t
    end
end

function generateannotationid(tree)
    tree.current_uid += 1
    return tree.current_uid
end

struct Leaf <: AbstractNode
    tree::Tree # Keep a ref to Tree because it contains general data
    parent::AbstractNode
    problem::Annotation
    depth::Int
end

struct Node <: AbstractNode
    tree::Tree
    parent::AbstractNode
    depth::Int
    problem::Annotation
    # Information about the decomposition
    master::Annotation
    subproblems::Dict{Any, AbstractNode}
    axis::Axis
end

struct Root <: AbstractNode
    tree::Tree
    # Current Node
    problem::Annotation
    # Children (decomposition performed on this node)
    master::Annotation
    subproblems::Dict{Any, AbstractNode}
    axis::Axis
end

annotation(n::AbstractNode) = n.problem

function Root(t::Tree, D::Type{<: Decomposition}, axis::Axis)
    uid = generateannotationid(t)
    problem = OriginalAnnotation()
    master = MasterAnnotation(uid, D)
    empty_dict = Dict{Any, AbstractNode}()
    return Root(t, problem, master, empty_dict, axis)
end

hasTree(model::JuMP.Model) = haskey(model.ext, :decomposition_tree)

function set_decomposition_tree!(model::JuMP.Model, D::Type{<: Decomposition}, axis::Axis)
    if !hasTree(model)
        model.ext[:decomposition_tree] = Tree(D, axis)
    else
        error("Cannot decompose twice at the same level.")
    end
    return
end
set_decomposition_tree!(n::AbstractNode, D::Type{<: Decomposition}, axis::Axis) = return
get_tree(n::AbstractNode) = n.tree
get_tree(m::JuMP.Model) = m.ext[:decomposition_tree]

function decompose_leaf(m::JuMP.Model, D::Type{<: Decomposition}, axis::Axis)
    set_decomposition_tree!(m, D, axis)
    return get_tree(m).root
end

function decompose_leaf(n::AbstractNode, D::Type{<: Decomposition}, axis::Axis)
    error("BlockDecomposition does not support nested decomposition yet.") 
    return
end

function register_subproblem!(n::AbstractNode, id, P::Type{<: Subproblem}, D::Type{<: Decomposition}, min_mult::Int, max_mult::Int)
    tree = get_tree(n)
    uid = generateannotationid(tree)
    annotation = Annotation(uid, P, D, id, min_mult, max_mult)
    leaf = Leaf(tree, n, annotation, 1)
    get!(n.subproblems, id, leaf)
end


function register_subproblems!(n::AbstractNode, axis::Axis, P::Type{<: Subproblem}, D::Type{<: Decomposition})
    if identical(axis)
        register_subproblem!(n, 1, P, D, 0, length(axis))
    else
        for a in axis
            register_subproblem!(n, a, P, D, 1, 1)
        end
    end
end

function register_subproblems!(n::AbstractNode, axis::JuMP.Containers.DenseAxisArray, P::Type{<: Subproblem}, D::Type{<: Decomposition})
    for multi_index in Base.product(axis.axes...)
        register_multi_index_subproblems!(n, multi_index, axis[multi_index...], P, D)
    end
end

function register_multi_index_subproblems!(n::AbstractNode, multi_index::Tuple, axis::Axis, P::Type{<: Subproblem}, D::Type{<: Decomposition})
    if identical(axis)
        register_subproblem!(n, (multi_index..., 1), P, D, 0, length(axis))
    else
        for a in axis
            register_subproblem!(n, (multi_index..., a), P, D, 1, 1)
        end
    end
end

macro dantzig_wolfe_decomposition(args...)
    if length(args) != 3
        error("Three arguments expected. Model, Decomposition name, Axis")
    end
    node, name, axis = args
    dw_exp = quote 
        $name = BlockDecomposition.decompose_leaf($node, BlockDecomposition.DantzigWolfe, $axis)
        BlockDecomposition.register_subproblems!($name, $axis, BlockDecomposition.Pricing, BlockDecomposition.DantzigWolfe)
    end
    return esc(dw_exp)
end

function Base.show(io::IO, r::Root)
    print(io, "Root - ")
    show(io, r.master)
    print(io,  " with ")
    print(io, length(r.subproblems))
    println(io, " subproblems :")
    for (key, node) in r.subproblems
        print(io, "\t ")
        print(io, key)
        print(io, " => ")
        show(io, annotation(node))
        println(io, " ")
    end
    return
end

function Base.show(io::IO, a::Annotation)
    print(io, "Annotation(")
    print(io, a.problem)
    print(io, ", ")
    print(io, a.decomposition)
    print(io, ", ")
    print(io, a.min_multiplicity)
    print(io, " <= multiplicity <= ")
    print(io, a.max_multiplicity)
    print(io, ", ")
    print(io, a.unique_id)
    print(io, ")")
    return
end
