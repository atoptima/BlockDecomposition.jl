# When you call a decomposition macro, it returns a pointer to the Decomposition
# node from where the decomposition has been performed.
# A decomposition node should contains : the master & a vector of subproblems
abstract type AbstractNode end

mutable struct Tree
    root::AbstractNode
    nb_masters::Int
    nb_subproblems::Int
    ann_current_uid::Int
    decomposition_axes::Dict{Symbol, Axis}
    function Tree(D::Type{<: Decomposition}, axis::Axis)
        t = new()
        t.nb_masters = 0
        t.nb_subproblems = 0
        t.ann_current_uid = 0
        r = Root(t, D, axis)
        t.root = r
        t.decomposition_axes = Dict{Symbol, Axis}(name(axis) => axis)
        return t
    end
end

getroot(t::Tree) = t.root

function generateannotationid(tree)
    tree.ann_current_uid += 1
    return tree.ann_current_uid
end

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
        tree = Tree(D, axis)
        model.ext[:decomposition_tree] = tree
        settree!(model, tree)
    else
        error("Cannot decompose twice at the same level.")
    end
    return
end
set_decomposition_tree!(n::AbstractNode, D::Type{<: Decomposition}, axis::Axis) = return
gettree(n::AbstractNode) = n.tree
gettree(m::JuMP.Model) = m.ext[:decomposition_tree]
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

function decompose_leaf(m::JuMP.Model, D::Type{<: Decomposition}, axis::Axis)
    set_decomposition_tree!(m, D, axis)
    return gettree(m).root
end

function decompose_leaf(n::AbstractNode, D::Type{<: Decomposition}, axis::Axis)
    error("BlockDecomposition does not support nested decomposition yet.") 
    return
end

function register_subproblems!(n::AbstractNode, axis::Axis, P::Type{<: Subproblem}, D::Type{<: Decomposition})
    tree = gettree(n)
    for a in axis
        create_leaf!(n, a, Annotation(tree, P, D, a))
    end
    return
end

function register_multi_index_subproblems!(n::AbstractNode, multi_index::Tuple, axis::Axis, P::Type{<: Subproblem}, D::Type{<: Decomposition})
    for a in axis
        register_subproblem!(n, (multi_index..., a), P, D, 1, 1)
    end
end

macro dantzig_wolfe_decomposition(args...)
    if length(args) != 3
        error("Three arguments expected: model, decomposition name, and axis")
    end
    node, name, axis = args
    dw_exp = quote 
        $name = BlockDecomposition.decompose_leaf($node, BlockDecomposition.DantzigWolfe, $axis)
        BlockDecomposition.register_subproblems!($name, $axis, BlockDecomposition.DwPricingSp, BlockDecomposition.DantzigWolfe)
    end
    return esc(dw_exp)
end

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