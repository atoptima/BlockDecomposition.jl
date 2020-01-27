"""
    register_decomposition(model)

Assign to each variable and constraint an annotation indicating in 
which partition (master/subproblem) of the original formulation the variable 
or the constraint is located.
"""
function register_decomposition(model::JuMP.Model)
    # Link to the tree
    tree = gettree(model)
    for (key, jump_obj) in model.obj_dict
        _annotate_elements!(model, jump_obj, tree)
    end
    return
end

_getrootmasterannotation(tree) = tree.root.master

# Should return the annotation corresponding to the vector of AxisId.
# Example :
# if axisids = [], the element goes in the master
# if axisids = [AxisIds(1)], the element goes in the subproblem with index 1
# todo : support nesting decomposition
function _getannotation(tree, axisids::Vector{AxisId})
    length(axisids) == 0 && return _getrootmasterannotation(tree)
    length(axisids) > 1 && error("BlockDecomposition does not support nested decomposition yet.")
    return tree.root.subproblems[axisids[1]].problem
end

function _annotate_elements!(model::JuMP.Model, container::JC.DenseAxisArray, tree)
    axisids = Vector{AxisId}()
    indice_sets = collect(Iterators.product(container.axes...))

    for indice_set in indice_sets # iterate over all the indice sets of the JuMP object
        for indice in indice_set # iterate over all indices of the current indice set
            if indice isa AxisId
                push!(axisids, indice)
            end
        end
        ann = _getannotation(tree, axisids)
        setannotation!(model, container[indice_set...], ann)
        empty!(axisids)
    end
    return
end

function _annotate_elements!(model::JuMP.Model, container::JC.SparseAxisArray, tree)
    axisids = Vector{AxisId}()
    container_keys = collect(keys(container.data))
    for key in container_keys # iterate over all indices of the container
        for indice in key
            if indice isa AxisId
                push!(axisids, indice)
            end
        end
        ann = _getannotation(tree, axisids)
        setannotation!(model, container[key...], ann)
        empty!(axisids)
    end
    return
end

function _annotate_elements!(model::JuMP.Model, container::JuMP.ConstraintRef, tree)
    setannotation!(model, container, _getrootmasterannotation(tree))
    return
end

function _annotate_elements!(model::JuMP.Model, container::JuMP.VariableRef, tree)
    setannotation!(model, container, _getrootmasterannotation(tree))
    return
end

function _annotate_elements!(model::JuMP.Model, container::AbstractArray, tree)
    for element in container
        setannotation!(model, element, _getrootmasterannotation(tree))
    end
    return
end

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
    conattr === nothing && return nothing
    val = get(conattr, ci, nothing)
    return val
end

function MOI.get(
    dest::MOIU.UniversalFallback, attribute::VariableDecomposition,
    vi::MOI.VariableIndex
)
    varattr = get(dest.varattr, attribute, nothing)
    varattr === nothing && return nothing
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
