"""
The following scores rank bordered block-diagonal structures
according to their suitability to a Dantzig-Wolfe reformulation.

white_score:
Prefer structures with a low relative border area and many blocks.

block_border_score:
Both the quality of the border area and of the block-diagonal
are taken into account. Desired characteristics of the
block-diagonal are granularity, homogeneity and isomorphism.
Score is taken from https://doi.org/10.1287/ijoc.2017.0797.

relative_border_area_score:
Prefer structures with a low relative border area.
Score is taken from https://doi.org/10.1007/s10107-014-0761-5.

inactive:
Automatic Dantzig-Wolfe decomposition is not used.
"""
@enum(AutoDwStrategy, inactive, white_score, block_border_score, relative_border_area_score)

# Decomposes the given JuMP Model automatically
function automatic_dw_decomposition!(model::JuMP.Model)
    model.ext[:decomposition_structure] = get_best_block_structure(model)
    decomposition_axis = Axis(
        1:length(model.ext[:decomposition_structure].blocks)
    )
    decomposition = decompose_leaf(
        model,
        DantzigWolfe,
        decomposition_axis
    )
    register_subproblems!(
        decomposition,
        decomposition_axis,
        DwPricingSp,
        DantzigWolfe
    )
    return nothing
end

# Finds the best decomposition structure to be used by the solver
function get_best_block_structure(model::JuMP.Model)
    @assert model.ext[:automatic_dantzig_wolfe] != inactive
    block_structures = get_all_block_structures(model)
    score_type = model.ext[:automatic_dantzig_wolfe]
    if score_type == white_score
        result = BlockDecomposition.best_white_score(block_structures)
    elseif score_type == block_border_score
        result = BlockDecomposition.best_block_border_score(block_structures)
    elseif score_type == relative_border_area_score
        result = BlockDecomposition.best_relative_border_area_score(block_structures)
    end
    return result
end

# Returns all possible block structures of the given model
function get_all_block_structures(model::JuMP.Model)
    mdesc = get_model_description(model)
    block_structures = BlockStructure[]
    axesSets = collect(powerset(collect(mdesc.axes)))
    for axes in axesSets
        block_structure0, block_structure1 = get_block_structures(axes, mdesc)
        # Only add structures that were not found already and where the set of master
        # constraints is not empty
        if !structure_exists(block_structures, block_structure0) &&
                !isempty(block_structure0.master_constraints)
            push!(block_structures, block_structure0)
        end
        if !structure_exists(block_structures, block_structure1) &&
                !isempty(block_structure1.master_constraints)
            push!(block_structures, block_structure1)
        end
    end
    return block_structures
end

# Contains all the information about the constraints and variables in a model we might need
# to compute different block structures
struct ModelDescription
    constraints::Set{JuMP.ConstraintRef}
    axes::Set{Axis}
    variables::Set{MOI.VariableIndex}
    constraints_to_axes::Dict{JuMP.ConstraintRef, Array{Axis}}
    constraints_to_variables::Dict{JuMP.ConstraintRef, Set{MOI.VariableIndex}}
end

struct BlockStructure
    # Constraints_and_axes is the same for every possible BlockStructure of a model
    model_description::ModelDescription
    master_constraints::Set{JuMP.ConstraintRef}
    master_sets::Array{Axis,1}
    # Invert linked is true iff the linking constraints are the ones not indexed
    # by any set from master_sets
    invert_linking::Bool
    blocks::Array{Set{JuMP.ConstraintRef},1}
    graph::MetaGraph
    BlockStructure(
        model_description,
        master_constraints,
        master_sets,
        invert_linking,
        graph
    ) =  new(
        model_description,
        master_constraints,
        master_sets,
        invert_linking,
        _get_connected_components!(graph),
        graph
    )
end

# Returns true if and only if block_structure already exists in block_structures
function structure_exists(
    block_structures::Array{BlockStructure,1},
    block_structure::BlockStructure
)
    for bs in block_structures
        if bs.master_constraints == block_structure.master_constraints
            return true
        end
    end
    return false
end

function best_relative_border_area_score(block_structures::Array{BlockStructure,1})
    scores = Array{Float64,1}(undef, length(block_structures))
    for i in eachindex(block_structures)
        scores[i] = _get_relative_border_area_score(block_structures[i])
    end
    result = block_structures[argmin(scores)]
    return result
end

function _get_relative_border_area_score(block_structure::BlockStructure)
    n_linking_constraints = length(block_structure.master_constraints)
    n_constraints = length(block_structure.model_description.constraints)
    score = n_linking_constraints/n_constraints
    return score
end

function best_block_border_score(block_structures::Array{BlockStructure,1})
    scores = Array{Float64,1}(undef, length(block_structures))
    for i in eachindex(block_structures)
        scores[i] = _get_block_border_score(block_structures[i])
    end
    result = block_structures[argmax(scores)]
    return result
end

function _get_block_border_score(block_structure::BlockStructure)
    # m describes the total number of nonzero entries in the blocks,
    # e gives the numberof nonzero entries for each block
    e =  Int64[]
    m = 0
    lambda = 5
    for block in block_structure.blocks
        n = _get_nb_nonzero_entries(block, block_structure.model_description)
        push!(e, n)
        m += n
    end
    q_a = 0
    for i in 1:length(block_structure.blocks)
        q_a += (e[i] / m) * (1 - (e[i] / m))
    end
    n_master_constraints =  length(block_structure.master_constraints)
    n_constraints = length(block_structure.model_description.constraints)
    p_a = MathConstants.e^(-1 * lambda * (n_master_constraints / n_constraints))
    gamma = q_a*p_a
    return gamma
end

# Computes the number of nonzero entries in the given constraints
function _get_nb_nonzero_entries(
    constraints::Set{JuMP.ConstraintRef},
    mdesc::ModelDescription
)
    result = 0
    for c in constraints
        result = result + length(mdesc.constraints_to_variables[c])
    end
    return result
end

function best_white_score(block_structures::Array{BlockStructure,1})
    scores = Array{Float64,1}(undef, length(block_structures))
    for i in eachindex(block_structures)
        scores[i] = _get_white_score(block_structures[i])
    end
    result = block_structures[argmax(scores)]
    return result
end

function _get_white_score(block_structure::BlockStructure)
    n_master = length(block_structure.model_description.variables) *
        length(block_structure.master_constraints)
    n_blocks = 0
    variables_in_block = Set{MOI.VariableIndex}()
    for block in block_structure.blocks
        empty!(variables_in_block)
        for constraint in block
            union!(
                variables_in_block,
                block_structure.model_description.constraints_to_variables[constraint]
            )
        end
        n_blocks = n_blocks + length(variables_in_block) * length(block)
    end
    coefficient_matrix_size = length(block_structure.model_description.constraints) *
        length(block_structure.model_description.variables)
    black_score = (n_master + n_blocks) / coefficient_matrix_size
    white_score = 1-black_score
    return white_score
end

# Add anonymous constraints and axes from the model to model_description (mdesc)
function _add_anonymous_var_con!(
    constraints::Set{JuMP.ConstraintRef},
    constraints_to_axes::Dict{JuMP.ConstraintRef, Array{Axis}},
    constraints_to_variables::Dict{JuMP.ConstraintRef, Set{MOI.VariableIndex}},
    variables::Set{MOI.VariableIndex},
    model::JuMP.Model
)
    types = JuMP.list_of_constraint_types(model)
    for t in types
        if t[1] != VariableRef
            for c in JuMP.all_constraints(model, t[1], t[2])
                if !in(c, constraints)
                    push!(constraints, c)
                    constraints_to_axes[c] = Axis[]
                    constraints_to_variables[c] = _get_variables_in_constraint(model, c)
                end
            end
        end
    end
    for v in JuMP.all_variables(model)
        push!(variables, JuMP.index(v))
    end
    return nothing
end

# Returns an instance of the struct ModelDescription
function get_model_description(model::JuMP.Model)
    constraints = Set{JuMP.ConstraintRef}()
    axes = Set{Axis}()
    variables = Set{MOI.VariableIndex}()
    constraints_to_axes = Dict{JuMP.ConstraintRef, Array{Axis}}()
    constraints_to_variables = Dict{JuMP.ConstraintRef, Set{MOI.VariableIndex}}()
    for k in keys(model.obj_dict)  # Check all names in the model
        reference = model.obj_dict[k]
        index_sets = _get_constraint_axes(reference)
        if eltype(reference) <: JuMP.ConstraintRef # Add constraint
            for c in reference
                _add_constraint!(
                    constraints,
                    constraints_to_axes,
                    constraints_to_variables,
                    axes,
                    c,
                    model,
                    index_sets
                )
            end
        elseif eltype(reference) <: JuMP.VariableRef # Add variable
            for v in reference
                push!(variables, JuMP.index(v))
            end
        end
    end
    _add_anonymous_var_con!(
        constraints,
        constraints_to_axes,
        constraints_to_variables,
        variables,
        model
    )
    mdesc = ModelDescription(
        constraints,
        axes,
        variables,
        constraints_to_axes,
        constraints_to_variables
    )
    return mdesc
end

# Adds a constraint to the ModelDescription object o
function _add_constraint!(
    constraints::Set{JuMP.ConstraintRef},
    constraints_to_axes::Dict{JuMP.ConstraintRef, Array{Axis}},
    constraints_to_variables::Dict{JuMP.ConstraintRef, Set{MOI.VariableIndex}},
    axes::Set{Axis},
    c::JuMP.ConstraintRef,
    model::JuMP.Model,
    index_sets::Array{Axis,1}
)
    push!(constraints, c)
    for r in index_sets
        push!(axes, r)
    end
    constraints_to_axes[c] = index_sets
    constraints_to_variables[c] = _get_variables_in_constraint(model, c)
    return nothing
end

# Computes the index sets of the constraint reference
function _get_constraint_axes(constraint_ref::AbstractArray)
    axs = axes(constraint_ref)
    ds = JC.DenseAxisArray(constraint_ref, axs...)
    return _get_constraint_axes(ds)
end

function _get_constraint_axes(constraint_ref::JC.DenseAxisArray)
    axes_of_constraint = Axis[]
    for a in constraint_ref.axes
        if a != 1   # Axes of the form 1:1 do not matter (single constraints)
            push!(axes_of_constraint, Axis(a))
        end
    end
    return axes_of_constraint
end

function _get_constraint_axes(constraint_ref::JC.SparseAxisArray)
    indices = eachindex(constraint_ref)
    axes = Array{Set{Any}}(undef, 1)
    for index in indices
        for j in 1:length(index)
            if length(axes) < length(index)
                resize!(axes, length(index))
            end
            if !isassigned(axes, j)
                axes[j] = Set()
            end
            push!(axes[j], index[j])
        end
    end
    result = Array{Axis,1}()
    for a in axes
        push!(result, Axis(a))
    end
    return result
end

function _get_variables_in_constraint(model::JuMP.Model, constraint::JuMP.ConstraintRef)
    f = MOI.get(model, MathOptInterface.ConstraintFunction(), constraint)
    variables = Set{MOI.VariableIndex}()
    for term in f.terms
        push!(variables, term.variable)
    end
    return variables
end

# Computes for the given axes two decomposition structures:
# In the first one (bs0) all constraints *not indexed by any* axis from
# axes are in the master, in the second one (bs1), all constraints *indexed
# by at least one* axis from axes are in the master
function get_block_structures(
    axes::Vector,
    mdesc::ModelDescription
)
    block_constraints = Set{JuMP.ConstraintRef}()
    master_constraints = Set{JuMP.ConstraintRef}()
    for c in keys(mdesc.constraints_to_axes)
        if  isempty(intersect(axes, mdesc.constraints_to_axes[c]))
            push!(master_constraints, c)
        else
            push!(block_constraints, c)
        end
    end
    # Create first block structure
    graph = _create_graph(block_constraints, mdesc)
    blocks = _get_connected_components!(graph)
    bs0 = BlockStructure(
        mdesc, master_constraints, axes, false, graph
    )
    # Create second block structure (the roles of master constraints and block
    # constraints are switched)
    graph = _create_graph(master_constraints, mdesc)
    blocks = _get_connected_components!(graph)
    bs1 = BlockStructure(
        mdesc, block_constraints, axes, true, graph
    )
    return bs0, bs1
end

function _get_connected_components!(graph::MetaGraph)
    connected_components_int = connected_components(graph)
    blocks = Set{JuMP.ConstraintRef}[]
    for component_int in connected_components_int
            component_constraintref = Set{JuMP.ConstraintRef}()
            for vertex_int in component_int
                push!(component_constraintref, graph[vertex_int, :constraint_ref])
            end
            push!(blocks, component_constraintref)
    end
    return blocks
end

function _create_graph(
    vertices::Set{JuMP.ConstraintRef},
    mdesc::ModelDescription,
)
    graph = SimpleGraph(0)
    graph = MetaGraph(graph)
    n_vertices = add_vertices!(graph, length(vertices))
    set_indexing_prop!(graph, :constraint_ref)
    i = 1
    # Set values for indexing property :constraint_ref
    for ver in vertices
        set_prop!(graph, i, :constraint_ref, ver)
        i = i+1
    end
    # Build edges
    for v1 in vertices, v2 in vertices
         if v1 != v2
            intersection = intersect(
                mdesc.constraints_to_variables[v1],
                mdesc.constraints_to_variables[v2],
            )
            if !isempty(intersection)
                add_edge!(graph, graph[v1, :constraint_ref], graph[v2, :constraint_ref])
            end
        end
    end
    return graph
end

