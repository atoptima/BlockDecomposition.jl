"""
    register_decomposition(model)

Assign to each variable and constraint an annotation indicating in
which partition (master/subproblem) of the original formulation the variable
or the constraint is located.

This method is called by the `JuMP.optimize!` hook.
"""
function register_decomposition(model::JuMP.Model)
    if model.ext[:automatic_dantzig_wolfe] != inactive
        register_automatic_dantzig_wolfe(model)
    else
        tree = gettree(model)
        tree === nothing && return
        for (_, jump_obj) in model.obj_dict
            _annotate_elements!(model, jump_obj, tree)
        end
    end
    return
end

function register_automatic_dantzig_wolfe(model::JuMP.Model)
    tree = gettree(model)
    # Annotate master constraints
    decomposition_structure = model.ext[:decomposition_structure]
    _annotate_elements!(model, collect(decomposition_structure.master_constraints), tree)
    # Annotate variables in blocks
    variables_in_block = Set{MOI.VariableIndex}()
    annotated_variables = Set{MOI.VariableIndex}()
    axisids = Vector{AxisId}()
    virtual_axis = BlockDecomposition.Axis(1:length(decomposition_structure.blocks))
    for i in virtual_axis
        empty!(variables_in_block)
        empty!(axisids)
        push!(axisids, i)
        # Annotate constraints in one block (and variables contained in these)  with the same annotation
        ann = _getannotation(tree, axisids)
        for constraintref in decomposition_structure.blocks[i]
            setannotation!(model, constraintref, ann)
            union!(
                variables_in_block,
                model.ext[:decomposition_structure].model_description.constraints_to_variables[constraintref]
            )
        end
        for v in variables_in_block
            setannotation!(model, JuMP.VariableRef(model, v), ann)
        end
        union!(annotated_variables, variables_in_block)
    end
    # Annotate all other variables
    all_variables = MathOptInterface.get(model, MathOptInterface.ListOfVariableIndices())
    not_annotated_vars = [JuMP.VariableRef(model, v) for v in collect(setdiff(all_variables, annotated_variables))]
    _annotate_elements!(model, not_annotated_vars, tree)
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
    tree = MOI.get(dest, DecompositionTree())
    tree === nothing && return nothing

    conattr = get(dest.conattr, attribute, nothing)
    conattr === nothing && return nothing # anonymous constraint
    return get(conattr, ci, tree.root.master)
end

function MOI.get(
    dest::MOIU.UniversalFallback, attribute::VariableDecomposition,
    vi::MOI.VariableIndex
)
    tree = MOI.get(dest, DecompositionTree())
    tree === nothing && return nothing

    varattr = get(dest.varattr, attribute, nothing)
    varattr === nothing && return nothing # anonymous variable
    return get(varattr, vi, tree.root.master)
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
