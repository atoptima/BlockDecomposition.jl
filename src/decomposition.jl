# For debug purpose : must be improved
function print_annotations(model::JuMP.Model)
    for (key, obj_ref) in model.obj_dict
        if applicable(iterate, obj_ref)
            for obj in obj_ref
                a = nothing
                if typeof(obj) <: JuMP.ConstraintRef
                    a = MOI.get(model, ConstraintDecomposition(), obj)
                else
                    a = MOI.get(model, VariableDecomposition(), obj)
                end
                println("$obj = $a")
            end
        else
            a = nothing
            obj = obj_ref
            if typeof(obj) <: JuMP.ConstraintRef
                a = MOI.get(model, ConstraintDecomposition(), obj)
            else
                a = MOI.get(model, VariableDecomposition(), obj)
            end
            println("$obj = $a")
        end
    end
    return
end

function register_decomposition(model::JuMP.Model)
    obj_axes = Vector{Tuple{Symbol, Vector{Axis}}}()
    for (key, jump_obj) in model.obj_dict
        dec_axes = look_for_dec_axis(jump_obj)
        push!(obj_axes, (key, dec_axes))
    end
    sort!(obj_axes, by = e -> length(e[2]), rev = true)

    dec_nodes = get_nodes(get_tree(model))
    sort!(dec_nodes, by = n -> get_depth(n), rev = true)
    
    for dec_node in dec_nodes 
        dec_axes_val = value_of_axes(dec_node)
        for (key, dec_axes) in obj_axes
            if length(dec_axes) == length(dec_axes_val)
                obj_ref = model.obj_dict[key]
                indices = compute_indices_of_decomposition(obj_ref, dec_axes, dec_axes_val)
                set_annotations!(model, obj_ref, indices, annotation(dec_node))
            end
            (length(dec_axes) < length(dec_axes_val)) && break
        end
    end
    print_annotations(model::JuMP.Model)
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

function compute_indices_of_decomposition(obj_ref, dec_axes, dec_axes_val)
    tuple = ()
    for obj_axis in obj_ref.axes
        found_dec_axes = false
        if typeof(obj_axis) <: Axis
            for dec_axis in dec_axes 
                if obj_axis.name == dec_axis.name
                    found_dec_axes = true
                    tuple = (tuple..., dec_axes_val[dec_axis.name])
                end
            end
        end
        if !found_dec_axes
            tuple = (tuple..., :)
        end
    end
    return tuple
end

struct ConstraintDecomposition <: MOI.AbstractConstraintAttribute end

set_annotation(model, obj::JuMP.ConstraintRef, a) = MOI.set(model, ConstraintDecomposition(), obj, a)
set_annotation(model, obj::JuMP.VariableRef, a) = MOI.set(model, VariableDecomposition(), obj, a)

function MOI.set(dest::MOIU.UniversalFallback, attribute::ConstraintDecomposition, 
        ci::MOI.ConstraintIndex, annotation::Annotation)
    if !haskey(dest.conattr, attribute)
        dest.conattr[attribute] = Dict{MOI.ConstraintIndex, Tuple}()
    end
    dest.conattr[attribute][ci] = moi_format(annotation)
    return
end

struct VariableDecomposition <: MOI.AbstractVariableAttribute end

function MOI.set(dest::MOIU.UniversalFallback, attribute::VariableDecomposition, 
        vi::MOI.VariableIndex, annotation::Annotation)
    if !haskey(dest.varattr, attribute)
        dest.varattr[attribute] = Dict{MOI.VariableIndex, Tuple}()
    end
    dest.varattr[attribute][vi] = moi_format(annotation)
    return
end

function set_annotations!(model::JuMP.Model, obj_ref, indices::Tuple, annotation::Annotation)
    if applicable(iterate, obj_ref[indices...])
        for obj in obj_ref[indices...]
            set_annotation(model, obj, annotation)
        end
    else
        obj = obj_ref[indices...]
        set_annotation(model, obj, annotation)
    end
end