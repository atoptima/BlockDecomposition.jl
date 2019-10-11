"""
    register_decomposition(model)

Assign to each variable and constraint an annotation indicating in 
which partition (master/subproblem) of the original formulation the variable 
or the constraint is located.
"""
function register_decomposition(model::JuMP.Model)
    # Link to the tree
    tree = gettree(model)
    # First, we retrieve the axes associtated to each JuMP object.
    # If there is no axis linked to a JuMP object, elements of the object are
    # in the master.
    obj_axes = Vector{Tuple{Symbol, Vector{Axis}}}()
    for (key, jump_obj) in model.obj_dict
        dec_axes = look_for_dec_axis(tree, jump_obj)
        push!(obj_axes, (key, dec_axes))
    end
    
    # We sort JuMP objects according to the number of decomposition performed
    # over them.
    sort!(obj_axes, by = e -> length(e[2]), rev = true)

    dec_nodes = getnodes(gettree(model))
    sort!(dec_nodes, by = n -> get_depth(n), rev = true)

    for dec_node in dec_nodes 
        elem_axes_in_partition = get_elems_of_axes_in_node(dec_node)
        for (key, dec_axes) in obj_axes
            if length(dec_axes) == length(elem_axes_in_partition)
                obj_ref = model.obj_dict[key]
                indices = get_indices_of_obj_in_partition(obj_ref, elem_axes_in_partition)
                setannotations!(model, obj_ref, indices, annotation(dec_node))
            end
            (length(dec_axes) < length(elem_axes_in_partition)) && break
        end
    end
    return
end

# look_for_dec_axis checks if some indices of the JuMP object are defined on
# axes.
function look_for_dec_axis(tree::Tree, container::JC.DenseAxisArray)::Vector{Axis}
    dec_axes = Vector{Axis}()
    for axis in container.axes
        if typeof(axis) <: Axis
            push!(dec_axes, axis)
        end
    end
    return dec_axes
end

function look_for_dec_axis(tree::Tree, container::JC.SparseAxisArray)::Vector{Axis}
    dec_axes = Vector{Axis}()
    container_keys = collect(keys(container.data))
    length(container_keys) == 0 && error("Unsupported : Open an issue at https://github.com/atoptima/BlockDecomposition.jl")
    for indice in container_keys[1]
        if indice isa AxisId
            push!(dec_axes, tree.decomposition_axes[name(indice)])
        end
    end
    return dec_axes
end

look_for_dec_axis(tree, constr::JuMP.ConstraintRef) = Vector{Axis}()
look_for_dec_axis(tree, var::JuMP.VariableRef) = Vector{Axis}()
look_for_dec_axis(tree, vars::Array{<:JuMP.VariableRef, N}) where N =  Vector{Axis}()
look_for_dec_axis(tree, constrs::Array{<:JuMP.ConstraintRef, N}) where N =  Vector{Axis}()

# get_indices_of_obj_in_partition returns the indices of the elements of the
# JuMP object that are in the parition defined by dec_axes_val.
# Consider an axis named :A with AxisId values [1,2,3,4]. 
# Assume we want the indices of the variable x[a in A, b in 1:5] that are in the
# partition defined by dec_axes_val = Dict(:A => 4) 
# get_indices_of_obj_in_partition returns the tuple (4,:) meaning that variables
# x[4,:] are in the subproblem with indice 4.
function get_indices_of_obj_in_partition(obj_ref::JC.DenseAxisArray, dec_axes_val)
    tuple = ()
    for obj_axis in obj_ref.axes
        found_dec_axes = false
        if typeof(obj_axis) <: Axis
            for (axis_name, value) in dec_axes_val
                if obj_axis.name == axis_name
                    found_dec_axes = true
                    tuple = (tuple..., value...)
                end
            end
        end
        if !found_dec_axes
            tuple = (tuple..., :)
        end
    end
    return tuple
end

function get_indices_of_obj_in_partition(
    obj_ref::JC.SparseAxisArray, dec_axes_val
)
    indices = Tuple[]
    container_keys = collect(keys(obj_ref.data))
    for key in container_keys
        keep = true
        axis_found = 0
        for indice in key
            if indice isa AxisId
                for (axis_name, value) in dec_axes_val
                    if name(indice) == axis_name && indice != value
                        keep = false
                    else
                        axis_found += 1
                    end
                end
            end
            if keep && axis_found == length(dec_axes_val)
                push!(indices, key)
            end
        end
    end
    return indices
end

get_indices_of_obj_in_partition(obj_ref::JuMP.ConstraintRef, _) = ()
get_indices_of_obj_in_partition(obj_ref::JuMP.VariableRef, _) = ()
get_indices_of_obj_in_partition(obj_ref::Array{<:JuMP.VariableRef, N}, _) where N = ntuple(i -> Colon(), N)
get_indices_of_obj_in_partition(obj_ref::Array{<:JuMP.ConstraintRef, N}, _) where N = ntuple(i -> Colon(), N)

struct ConstraintDecomposition <: MOI.AbstractConstraintAttribute end
struct VariableDecomposition <: MOI.AbstractVariableAttribute end
struct DecompositionTree <: MOI.AbstractModelAttribute end

setannotation!(model, obj::JuMP.ConstraintRef, a) = MOI.set(model, ConstraintDecomposition(), obj, a)
setannotation!(model, obj::JuMP.VariableRef, a) = MOI.set(model, VariableDecomposition(), obj, a)

function MOI.set(dest::MOIU.UniversalFallback, attribute::ConstraintDecomposition, 
        ci::MOI.ConstraintIndex, annotation::Annotation)
    if !haskey(dest.conattr, attribute)
        dest.conattr[attribute] = Dict{MOI.ConstraintIndex, Tuple}()
    end
    dest.conattr[attribute][ci] = annotation
    return
end

function MOI.set(
    dest::MOIU.UniversalFallback, attribute::VariableDecomposition, 
    vi::MOI.VariableIndex, ann::Annotation
)
    if !haskey(dest.varattr, attribute)
        dest.varattr[attribute] = Dict{MOI.VariableIndex, Tuple}()
    end
    dest.varattr[attribute][vi] = ann
    return
end

function MOI.set(
    dest::MOIU.UniversalFallback, attribute::DecompositionTree, tree::Tree
)
    dest.modattr[attribute] = tree
    return
end

function MOI.get(
    dest::MOIU.UniversalFallback, attribute::ConstraintDecomposition,
    ci::MOI.ConstraintIndex
)
    conattr = get(dest.conattr, attribute, nothing)
    conattr == nothing && return nothing
    val = get(conattr, ci, nothing)
    return val
end

function MOI.get(
    dest::MOIU.UniversalFallback, attribute::VariableDecomposition,
    vi::MOI.VariableIndex
)
    varattr = get(dest.varattr, attribute, nothing)
    varattr == nothing && return nothing
    val = get(varattr, vi, nothing)
    return val
end

function MOI.get(dest::MOIU.UniversalFallback, attribute::DecompositionTree)
    modattr = get(dest.modattr, attribute, nothing)
    return modattr
end

function setannotations!(
    model::JuMP.Model, objref::AbstractArray, indices::Tuple, ann::Annotation
)
    if applicable(iterate, objref[indices...])
        for obj in objref[indices...]
            setannotation!(model, obj, ann)
        end
    else
        obj = objref[indices...]
        setannotation!(model, obj, ann)
    end
    return
end

function setannotations!(
    model::JuMP.Model, objref::AbstractArray, indices_set::Vector{Tuple}, 
    ann::Annotation
)
    for indices in indices_set
        obj = objref[indices...]
        setannotation!(model, obj, ann)
    end
    return
end

function setannotations!(
    model::JuMP.Model, objref::JuMP.ConstraintRef, _, ann::Annotation
)
    setannotation!(model, objref, ann)
    return
end

function setannotations!(
    model::JuMP.Model, objref::JuMP.VariableRef, _, ann::Annotation
)
    setannotation!(model, objref, ann)
    return
end

settree!(model::JuMP.Model, tree) = MOI.set(model, DecompositionTree(), tree)
