# When you call a decomposition macro, it returns a pointer to the Decomposition
# node from where the decomposition has been performed.
# A decomposition node should contains : the master & a vector of subproblems
const AxisContainer = Union{Axis, JuMP.Containers.DenseAxisArray{<: Axis}}

abstract type AbstractNode end

mutable struct Tree
    root::AbstractNode
    nb_masters::Int
    nb_subproblems::Int
    current_uid::Int
    function Tree(D::Type{<: Decomposition}, axis::A) where {A <: AxisContainer}
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
    # Edge id from parent
    edge_id::Any
end

struct Node{A} <: AbstractNode where {A <: AxisContainer}
    tree::Tree
    parent::AbstractNode
    depth::Int
    problem::Annotation
    # Edge id from parent
    edge_id::Any
    # Information about the decomposition
    master::Annotation
    subproblems::Dict{Any, AbstractNode}
    axis::A
end

struct Root{A} <: AbstractNode where {A <: AxisContainer}
    tree::Tree
    depth::Int
    # Current Node
    problem::Annotation
    # Children (decomposition performed on this node)
    master::Annotation
    subproblems::Dict{Any, AbstractNode}
    axis::A
end

annotation(n::Leaf) = n.problem
annotation(n::Root) = n.master # TODO : check if true in nested decomposition
annotation(n::Node) = n.master # TODO : check if true in nested decomposition

function Root(t::Tree, D::Type{<: Decomposition}, axis::A) where {A <: AxisContainer}
    uid = generateannotationid(t)
    problem = OriginalAnnotation()
    master = MasterAnnotation(uid, D)
    empty_dict = Dict{Any, AbstractNode}()
    return Root(t, 0, problem, master, empty_dict, axis)
end

hasTree(model::JuMP.Model) = haskey(model.ext, :decomposition_tree)

function set_decomposition_tree!(model::JuMP.Model, D::Type{<: Decomposition}, axis::A) where {A <: AxisContainer}
    if !hasTree(model)
        model.ext[:decomposition_tree] = Tree(D, axis)
    else
        error("Cannot decompose twice at the same level.")
    end
    return
end
set_decomposition_tree!(n::AbstractNode, D::Type{<: Decomposition}, axis::A) where {A <: AxisContainer} = return
gettree(n::AbstractNode) = n.tree
gettree(m::JuMP.Model) = m.ext[:decomposition_tree]
get_depth(n::AbstractNode) = n.depth

function getnodes(tree::Tree)
    vec_nodes = Vector{AbstractNode}()
    queue = Queue{AbstractNode}()
    enqueue!(queue, tree.root)
    while length(queue) > 0
        node = dequeue!(queue)
        for (key, child) in node.subproblems
            if typeof(child) <: Leaf
                push!(vec_nodes, child)
            else
                enqueue!(queue, child)
            end
        end
        push!(vec_nodes, node)
    end
    return vec_nodes
end

function axes_value(n::AbstractNode)
    axes_names_values = Dict{Symbol, Any}()
    current_node = n
    while !(typeof(current_node) <: Root)
        # some modification to do for decomposition with 2 indices
        axes_names_values[current_node.parent.axis.name] = current_node.edge_id
        current_node = current_node.parent
    end
    return axes_names_values
end

function create_leaf!(n::AbstractNode, id, a::Annotation)
    edge_val = id
    if identical(n.axis)
        edge_val = n.axis.container
    end
    leaf = Leaf(gettree(n), n, a, get_depth(n) + 1, edge_val)
    get!(n.subproblems, id, leaf)
end

function decompose_leaf(m::JuMP.Model, D::Type{<: Decomposition}, axis::A) where {A <: AxisContainer}
    set_decomposition_tree!(m, D, axis)
    return gettree(m).root
end

function decompose_leaf(n::AbstractNode, D::Type{<: Decomposition}, axis::A) where {A <: AxisContainer}
    error("BlockDecomposition does not support nested decomposition yet.") 
    return
end

function register_subproblem!(n::AbstractNode, id, P::Type{<: Subproblem}, D::Type{<: Decomposition}, min_mult::Int, max_mult::Int)
    tree = gettree(n)
    uid = generateannotationid(tree)
    annotation = Annotation(uid, 0, P, D, id, min_mult, max_mult)
    create_leaf!(n, id, annotation)
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
        BlockDecomposition.register_subproblems!($name, $axis, BlockDecomposition.DwPricingSp, BlockDecomposition.DantzigWolfe)
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
    print(io, getformulation(a))
    print(io, ", ")
    print(io, getdecomposition(a))
    print(io, ", ")
    print(io, getminmultiplicity(a))
    print(io, " <= multiplicity <= ")
    print(io, getmaxmultiplicity(a))
    print(io, ", ")
    print(io, getid(a))
    print(io, ")")
    return
end
