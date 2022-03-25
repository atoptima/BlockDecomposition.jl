# When you call a decomposition macro, it returns a pointer to the Decomposition
# node from where the decomposition has been performed.
# A decomposition node should contains : the master & a vector of subproblems
abstract type AbstractNode end

mutable struct Tree
    root::AbstractNode
    ann_current_uid::Int
    function Tree(D::Type{<: Decomposition}, axis::Axis)
        t = new()
        t.ann_current_uid = 0
        r = Root(t, D, axis)                  # initialize root (with node uid 1) calling the extra outer constructor
        t.root = r
        return t
    end
end

getroot(t::Tree) = t.root

MOIU.map_indices(::Function, t::Tree) = t

function generateannotationid(tree)
    tree.ann_current_uid += 1
    return tree.ann_current_uid
end

# leaves are terminals of branches
struct Leaf{V} <: AbstractNode
    tree::Tree # Keep a ref to Tree because it contains general data
    parent::AbstractNode
    problem::Annotation
    depth::Int
    # Edge id from parent
    edge_id::V
end

struct Node{N,V,T} <: AbstractNode
    tree::Tree
    parent::AbstractNode
    depth::Int
    problem::Annotation
    # Link from parent
    edge_id::T
    # Information about the decomposition
    master::Annotation
    subproblems::Dict{AxisId{N,V}, AbstractNode}
    axis::Axis{N,V}
end

struct Root{N,T} <: AbstractNode
    tree::Tree
    depth::Int
    # Current Node
    problem::Annotation
    # Children (decomposition performed on this node)
    master::Annotation
    subproblems::Dict{AxisId{N,T}, AbstractNode}
    axis::Axis{N,T}
end

annotation(n::Leaf) = n.problem
annotation(n::Root) = n.master # TODO : check if true in nested decomposition
#annotation(n::Node) = n.master # TODO : check if true in nested decomposition

subproblems(n::Leaf) = Dict{Any, AbstractNode}()
subproblems(n::Root) = n.subproblems
#subproblems(n::Node) = n.subproblems

getedgeidfromparent(node::Union{Node,Leaf}) = node.edge_id

# extra outer Root constructor
function Root(tree::Tree, D::Type{<: Decomposition}, axis::Axis{N,T}) where {N,T}
    uid = generateannotationid(tree)
    problem = OriginalAnnotation()
    master = MasterAnnotation(tree, D)
    empty_dict = Dict{AxisId{N,T}, AbstractNode}()
    return Root(tree, 0, problem, master, empty_dict, axis)
end

has_tree(model::JuMP.Model) = haskey(model.ext, :decomposition_tree)

function set_decomposition_tree!(model::JuMP.Model, D::Type{<: Decomposition}, axis::Axis)
    if !has_tree(model)
        tree = Tree(D, axis)                      # initialize tree
        model.ext[:decomposition_tree] = tree     # register tree in JuMP model
        settree!(model, tree)                     # register tree in MOI model?
    else
        error("Cannot decompose twice at the same level.")
    end
    return
end
set_decomposition_tree!(n::AbstractNode, D::Type{<: Decomposition}, axis::Axis) = return
gettree(n::AbstractNode) = n.tree
gettree(m::JuMP.Model) = get(m.ext, :decomposition_tree, nothing)
get_depth(n::AbstractNode) = n.depth
getoptimizerbuilder(n::AbstractNode) = n.master.optimizer_builder
getoptimizerbuilder(n::Leaf) = n.problem.optimizer_builder

function getnodes(tree::Tree)
    vec_nodes = Vector{AbstractNode}()
    queue = Queue{AbstractNode}()
    enqueue!(queue, tree.root)
    while length(queue) > 0
        node = dequeue!(queue)
        for (key, child) in node.subproblems
            if typeof(child) <: Leaf            # if child node is a leaf, append it to the nodes list
                push!(vec_nodes, child)
            else
                enqueue!(queue, child)          # otherwise insert the node into the queue for further node search
            end
        end
        push!(vec_nodes, node)                  # append the parent node to the nodes list
    end
    return vec_nodes
end

function get_elems_of_axes_in_node(n::AbstractNode)
    axes_names_values = Dict{Symbol, Any}()
    current_node = n
    while !(typeof(current_node) <: Root)
        axes_names_values[current_node.parent.axis.name] = getedgeidfromparent(current_node)
        current_node = current_node.parent
    end
    return axes_names_values
end

function create_leaf!(n::AbstractNode, id, a::Annotation)
    leaf = Leaf(gettree(n), n, a, get_depth(n) + 1, id)
    n.subproblems[id] = leaf
    return
end

function decompose_leaf(m::JuMP.Model, D::Type{<:Decomposition}, axis::Axis)
    set_decomposition_tree!(m, D, axis)     # register the tree in the model
    return gettree(m).root                  # return the root node of the new tree
end

"""
    DecompositionNotOverAxis{T}

Decomposition must be done over an axis.
Getting started guide available at https://atoptima.github.io/Coluna.jl/stable/start/start/

The container on which you try to decompose is of type `T` and available at `error.container`.
"""
struct DecompositionNotOverAxis{T}
    message::String
    container::T
end

function decompose_leaf(::JuMP.Model, D::Type{<:Decomposition}, axis)
    err_msg = """Decomposition must be done over an axis.
    Getting started guide available at https://atoptima.github.io/Coluna.jl/stable/start/start/
    """
    throw(DecompositionNotOverAxis(err_msg, axis))
end

function decompose_leaf(n::AbstractNode, D::Type{<:Decomposition}, axis::Axis)
    error("BlockDecomposition does not support nested decomposition yet.")
    return
end

function register_subproblems!(n::AbstractNode, axis::Axis, P::Type{<:Subproblem}, D::Type{<:Decomposition})
    tree = gettree(n)
    for a in axis                                       # iterate over AxisIds i.e. subproblems
        create_leaf!(n, a, Annotation(tree, P, D, a))
    end
    return
end

function register_multi_index_subproblems!(n::AbstractNode, multi_index::Tuple, axis::Axis, P::Type{<:Subproblem}, D::Type{<:Decomposition})
    for a in axis
        register_subproblem!(n, (multi_index..., a), P, D, 1, 1)
    end
end

"""
    @dantzig_wolfe_decomposition(model, name, axis)

Register a Dantzig-Wolfe decomposition on the JuMP model `model` where the index-set
of the subproblems is defined by the axis `axis`.

Create a variable `name` from which the user can access the decomposition tree.
"""
macro dantzig_wolfe_decomposition(args...)
    if length(args) != 3
        error("Three arguments expected: model, decomposition name, and axis")
    end
    node, name, axis = args
    dw_exp = quote
        $name = BlockDecomposition.decompose_leaf($node, BlockDecomposition.DantzigWolfe, $axis)                                # initialize a tree for the current root node
        BlockDecomposition.register_subproblems!($name, $axis, BlockDecomposition.DwPricingSp, BlockDecomposition.DantzigWolfe)
    end
    return esc(dw_exp)
end

"""
    @benders_decomposition(model, name, axis)

Register a Benders decomposition on the JuMP model `model` where the index-set
of the subproblems is defined by the axis `axis`.

Create a variable `name` from which the user can access decomposition tree.
"""
macro benders_decomposition(args...)
    if length(args) != 3
        error("Three arguments expected: model, decomposition name, and axis")
    end
    node, name, axis = args
    b_exp = quote
        $name = BlockDecomposition.decompose_leaf($node, BlockDecomposition.Benders, $axis)
        BlockDecomposition.register_subproblems!($name, $axis, BlockDecomposition.BendersSepSp, BlockDecomposition.Benders)
    end
    return esc(b_exp)
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
