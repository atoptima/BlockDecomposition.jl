# For debug purpose : must be improved
# function print_annotations(model::JuMP.Model)
#     for (key, obj_ref) in model.obj_dict
#         if applicable(iterate, obj_ref)
#             for obj in obj_ref
#                 a = nothing
#                 if typeof(obj) <: JuMP.ConstraintRef
#                     a = MOI.get(model, ConstraintDecomposition(), obj)
#                 else
#                     a = MOI.get(model, VariableDecomposition(), obj)
#                 end
#                 println("$obj = $a")
#             end
#         else
#             a = nothing
#             obj = obj_ref
#             if typeof(obj) <: JuMP.ConstraintRef
#                 a = MOI.get(model, ConstraintDecomposition(), obj)
#             else
#                 a = MOI.get(model, VariableDecomposition(), obj)
#             end
#             println("$obj = $a")
#         end
#     end
#     return
# end

function register_decomposition(model::JuMP.Model)
    obj_axes = Vector{Tuple{Symbol, Vector{Axis}}}()
    for (key, jump_obj) in model.obj_dict
        dec_axes = look_for_dec_axis(jump_obj)
        push!(obj_axes, (key, dec_axes))
    end
    sort!(obj_axes, by = e -> length(e[2]), rev = true)

    dec_nodes = getnodes(gettree(model))
    sort!(dec_nodes, by = n -> get_depth(n), rev = true)
    
    for dec_node in dec_nodes 
        dec_axes_val = axes_value(dec_node)
        for (key, dec_axes) in obj_axes
            
            if length(dec_axes) == length(dec_axes_val)
                obj_ref = model.obj_dict[key]
                indices = compute_indices_of_decomposition(obj_ref, dec_axes, dec_axes_val)
                setannotations!(model, obj_ref, indices, annotation(dec_node))
            end
            (length(dec_axes) < length(dec_axes_val)) && break
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

compute_indices_of_decomposition(obj_ref::JuMP.ConstraintRef, _, _) = ()
compute_indices_of_decomposition(obj_ref::JuMP.VariableRef, _, _) = ()

struct ConstraintDecomposition <: MOI.AbstractConstraintAttribute end
struct VariableDecomposition <: MOI.AbstractVariableAttribute end

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

function MOI.set(dest::MOIU.UniversalFallback, attribute::VariableDecomposition, 
        vi::MOI.VariableIndex, annotation::Annotation)
    if !haskey(dest.varattr, attribute)
        dest.varattr[attribute] = Dict{MOI.VariableIndex, Tuple}()
    end
    dest.varattr[attribute][vi] = annotation
    return
end

function MOI.get(dest::MOIU.UniversalFallback, attribute::ConstraintDecomposition,
        ci::MOI.ConstraintIndex)
    return dest.conattr[attribute][ci]
end

function MOI.get(dest::MOIU.UniversalFallback, attribute::VariableDecomposition,
        vi::MOI.VariableIndex)
    return dest.varattr[attribute][vi]
end

function setannotations!(model::JuMP.Model, objref::AbstractArray, indices::Tuple, 
        annotation::Annotation)
    if applicable(iterate, objref[indices...])
        for obj in objref[indices...]
            setannotation!(model, obj, annotation)
        end
    else
        obj = objref[indices...]
        setannotation!(model, obj, annotation)
    end
end

function setannotations!(model::JuMP.Model, objref::JuMP.ConstraintRef, _, 
        annotation::Annotation)
    setannotation!(model, objref, annotation)
end

function setannotations!(model::JuMP.Model, objref::JuMP.VariableRef, _, 
        annotation::Annotation)
    setannotation!(model, objref, annotation)
end