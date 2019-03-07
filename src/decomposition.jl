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
        @show value_of_axes(dec_node)
    end
    # example of annotation : MOI.set(model, Coluna.ConstraintDantzigWolfeAnnotation(), constr_ref, block)
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
