"""
    register_decomposition(model)

Assign to each variable and constraint an annotation indicating in 
which partition (master/subproblem) of the original formulation the variable 
or the constraint is located.
"""
function register_decomposition(model::JuMP.Model)
    # First, we retrieve the axis associtated to each JuMP object.
    # If there is no axis linked to a JuMP object, elements of the object are
    # in the master.
    obj_axes = Vector{Tuple{Symbol, Vector{Axis}}}()
    for (key, jump_obj) in model.obj_dict
        dec_axes = look_for_dec_axis(jump_obj)
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
                indices = get_indices_of_obj_in_partition(obj_ref, dec_axes, elem_axes_in_partition)
                setannotations!(model, obj_ref, indices, annotation(dec_node))
            end
            (length(dec_axes) < length(elem_axes_in_partition)) && break
        end
    end
    return
end

function look_for_dec_axis(container::JuMP.Containers.SparseAxisArray)
    error("BlockDecomposition cannot look for axes into SparseAxisArray.")   
end

function look_for_dec_axis(container::JuMP.Containers.DenseAxisArray)::Vector{Axis}
    dec_axes = Vector{Axis}()
    for axis in container.axes
        if typeof(axis) <: Axis
            push!(dec_axes, axis)
        end
    end
    return dec_axes
end

look_for_dec_axis(constr::JuMP.ConstraintRef) = Vector{Axis}()
look_for_dec_axis(var::JuMP.VariableRef) = Vector{Axis}()
look_for_dec_axis(vars::Array{<:JuMP.VariableRef, N}) where N =  Vector{Axis}()
look_for_dec_axis(constrs::Array{<:JuMP.ConstraintRef, N}) where N =  Vector{Axis}()

function get_indices_of_obj_in_partition(
    obj_ref::JuMP.Containers.DenseAxisArray, dec_axes, dec_axes_val
)
    tuple = ()
    for obj_axis in obj_ref.axes
        found_dec_axes = false
        if typeof(obj_axis) <: Axis
            for dec_axis in dec_axes 
                if obj_axis.name == dec_axis.name
                    found_dec_axes = true
                    tuple = (tuple..., dec_axes_val[dec_axis.name]...)
                end
            end
        end
        if !found_dec_axes
            tuple = (tuple..., :)
        end
    end
    return tuple
end

get_indices_of_obj_in_partition(obj_ref::JuMP.ConstraintRef, _, _) = ()
get_indices_of_obj_in_partition(obj_ref::JuMP.VariableRef, _, _) = ()
get_indices_of_obj_in_partition(obj_ref::Array{<:JuMP.VariableRef, N}, _, _) where N = ntuple(i -> Colon(), N)
get_indices_of_obj_in_partition(obj_ref::Array{<:JuMP.ConstraintRef, N}, _, _) where N = ntuple(i -> Colon(), N)

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
    return dest.conattr[attribute][ci]
end

function MOI.get(
    dest::MOIU.UniversalFallback, attribute::VariableDecomposition,
    vi::MOI.VariableIndex
)
    return dest.varattr[attribute][vi]
end

function MOI.get(dest::MOIU.UniversalFallback, attribute::DecompositionTree)
    return dest.modattr[attribute]
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
