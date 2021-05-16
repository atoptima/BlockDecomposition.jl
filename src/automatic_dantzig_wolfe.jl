
# Available scores that can be used in an automatic Dantzig-Wolfe decomposition
# inaktive means that automatic Dantzig-Wolfe is not used
@enum(AutoDwStrategy, inaktive, white_score, block_border_score, relative_border_area_score)

# Decomposes the given JuMP Model automatically
function automatic_dw_decomposition!(model::JuMP.Model)
    model.ext[:decomposition_structure] = BlockDecomposition.get_best_block_structure(model)
    decomposition_axis = BlockDecomposition.Axis(
        1:length(model.ext[:decomposition_structure].blocks)
    )
    decomposition = BlockDecomposition.decompose_leaf(
        model,
        BlockDecomposition.DantzigWolfe,
        decomposition_axis
    )
    BlockDecomposition.register_subproblems!(
        decomposition,
        decomposition_axis,
        BlockDecomposition.DwPricingSp,
        BlockDecomposition.DantzigWolfe
    )
    return
end

# Finds the best decomposition structure to be used by the solver
function get_best_block_structure(model::JuMP.Model)
    @assert(model.ext[:automatic_dantzig_wolfe] != inaktive)
    block_structures = get_all_block_structures(model)
    score_type = model.ext[:automatic_dantzig_wolfe]
    if score_type == white_score
        white_scores =  BlockDecomposition.white_scores(block_structures)
        result = block_structures[argmax(white_scores)]
    elseif score_type == block_border_score
        block_border_scores = BlockDecomposition.block_border_scores(block_structures)
        result = block_structures[argmax(block_border_scores)]
    elseif score_type == relative_border_area_score
        relative_border_area_scores = BlockDecomposition.relative_border_area_scores(block_structures)
        result = block_structures[argmin(relative_border_area_scores)]
    end
    return result
end

# Returns all possible block structures of the given model
function get_all_block_structures(model::JuMP.Model)
    constraints_and_axes = get_constraints_and_axes(model)
    block_structures = Array{BlockStructure,1}()
    axesSets = collect(powerset(collect(constraints_and_axes.axes)))
    for axes in axesSets
        block_structure0, block_structure1 = get_block_structure(axes, constraints_and_axes, model)
        # Only add structures that were not found already and were the set of master
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
mutable struct Constraints_and_Axes
    constraints::Set{JuMP.ConstraintRef}
    axes::Set{BlockDecomposition.Axis}
    variables::Set{MOI.VariableIndex}
    constraints_to_axes::Dict{JuMP.ConstraintRef, Array{BlockDecomposition.Axis}}
    constraints_to_variables::Dict{JuMP.ConstraintRef, Set{MOI.VariableIndex}}
end

struct BlockStructure
    # Constraints_and_axes is the same for every possible BlockStructure of a model
    constraints_and_axes::Constraints_and_Axes
    master_constraints::Set{JuMP.ConstraintRef}
    master_sets::Array{BlockDecomposition.Axis,1}
    # Invert linked is true iff the linking constraints are the ones not indexed
    # by any set from master_sets
    invert_linking::Bool
    blocks::Array{Set{JuMP.ConstraintRef},1}
    graph::MetaGraph
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

# This score is described in: Bergner, Martin, et al. 
# "Automatic Dantzig–Wolfe reformulation of mixed integer programs."
# Mathematical Programming 149.1-2 (2015): 391-424.
function relative_border_area_scores(block_structures::Array{BlockStructure,1})
    scores = Array{Float64,1}(undef, length(block_structures))
    for i in eachindex(block_structures)
        scores[i] = _get_relative_border_area_score(block_structures[i])
    end
    return scores
end

function _get_relative_border_area_score(block_structure::BlockStructure)
    n_linking_constraints = length(block_structure.master_constraints)
    n_constraints = length(block_structure.constraints_and_axes.constraints)
    score = n_linking_constraints/n_constraints
end

# This score is described in: Khaniyev, Taghi, Samir Elhedhli, and Fatih Safa Erenay.
# "Structure detection in mixed-integer programs." INFORMS Journal on Computing 30.3 (2018): 570-587.
function block_border_scores(block_structures::Array{BlockStructure,1})
    scores = Array{Float64,1}(undef, length(block_structures))
    for i in eachindex(block_structures)
        scores[i] = _get_block_border_score(block_structures[i])
    end
    return scores
end

function _get_block_border_score(block_structure::BlockStructure)
    # m describes the total number of nonzero entries in the blocks,
    # e gives the numberof nonzero entries for each block
    e =  Int64[]
    m = 0
    lambda = 5
    for block in block_structure.blocks
        n = _get_nb_nonzero_entries(block, block_structure.constraints_and_axes)
        push!(e, n)
        m += n
    end
    q_a = 0
    for i in 1:length(block_structure.blocks)
        q_a += (e[i] / m) * (1 - (e[i] / m))
    end
    n_master_constraints =  length(block_structure.master_constraints)
    n_constraints = length(block_structure.constraints_and_axes.constraints)
    p_a = MathConstants.e^(-1 * lambda * (n_master_constraints / n_constraints))
    gamma = q_a*p_a
    return gamma
end

# Computes the number of nonzero entries in the given constraints
function _get_nb_nonzero_entries(
    constraints::Set{JuMP.ConstraintRef},
    constraints_and_axes::Constraints_and_Axes
)
    result = 0
    for c in constraints
        result = result + length(constraints_and_axes.constraints_to_variables[c])
    end
    return result
end

# Returns the relative amount of "white" in the matrix
function white_scores(block_structures::Array{BlockStructure,1})
    scores = Array{Float64,1}(undef, length(block_structures))
    for i in eachindex(block_structures)
        scores[i] = _get_white_score(block_structures[i])
    end
    return scores
end

function _get_white_score(block_structure::BlockStructure)
    n_master = length(block_structure.constraints_and_axes.variables) *
        length(block_structure.master_constraints)
    n_blocks = 0
    variables_in_block = Set{MOI.VariableIndex}()
    for block in block_structure.blocks
        empty!(variables_in_block)
        for constraint in block
            union!(
                variables_in_block,
                block_structure.constraints_and_axes.constraints_to_variables[constraint]
            )
        end
        n_blocks = n_blocks + length(variables_in_block)*length(block)
    end
    coefficient_matrix_size = length(block_structure.constraints_and_axes.constraints) *
        length(block_structure.constraints_and_axes.variables)
    black_score = (n_master+n_blocks)/coefficient_matrix_size
    white_score = 1-black_score
    return white_score
end

# Returns an instance of the struct Constraints_and_Axes
function get_constraints_and_axes(model::JuMP.Model)
    constraints = Set{JuMP.ConstraintRef}()
    axes = Set{BlockDecomposition.Axis}()
    variables = Set{MOI.VariableIndex}()
    constraints_to_axes = Dict{JuMP.ConstraintRef, Array{BlockDecomposition.Axis}}()
    constraints_to_variables = Dict{JuMP.ConstraintRef, Set{MOI.VariableIndex}}()
    constraints_and_axes = Constraints_and_Axes(
                               constraints,
                               axes,
                               variables,
                               constraints_to_axes,
                               constraints_to_variables
                            )
    for k in keys(model.obj_dict)  # Check all names in the model
        reference = _get_constraint_reference(model, k)
        if eltype(reference) <: JuMP.ConstraintRef
            for c in reference
                _add_constraint!(constraints_and_axes, c, model, reference)
            end
        elseif eltype(reference) <: JuMP.VariableRef
            for v in reference
                push!(variables, JuMP.index(v))
            end
        end
    end
    constraints_and_axes.variables = variables
    _add_anonymous_var_con!(constraints_and_axes, model)
    return constraints_and_axes
end

# Convert the constraint reference to a DenseAxisArrays
function _get_constraint_reference(model::JuMP.Model, k)
    if typeof(model.obj_dict[k]) <: JuMP.Containers.DenseAxisArray
        return model.obj_dict[k]
    elseif typeof(model.obj_dict[k]) <: Array
        axs = axes(model.obj_dict[k])
        return JuMP.Containers.DenseAxisArray(model.obj_dict[k], axs...)
    else
        # Can this case happen?
        return error("Type of constraint reference can not be handled.")
    end
end

# Add anonymous constraints and axes from the model to constraints_and_axes (car)
function _add_anonymous_var_con!(car::Constraints_and_Axes, model::JuMP.Model)
    types =  JuMP.list_of_constraint_types(model)
    for t in types
        if t[1] != VariableRef
            for c in JuMP.all_constraints(model, t[1], t[2])
                if !in(c, car.constraints)
                    push!(car.constraints, c)
                    car.constraints_to_axes[c] = Array{BlockDecomposition.Axis,1}()
                    car.constraints_to_variables[c] = _get_variables_in_constraint(model, c)
                end
            end
        end
    end
    for v in JuMP.all_variables(model)
        push!(car.variables, JuMP.index(v))
    end
end

function _add_constraint!(
    o::Constraints_and_Axes,
    c::JuMP.ConstraintRef,
    model::JuMP.Model,
    reference_constraints_name::T,
) where T <: JuMP.Containers.DenseAxisArray
    push!(o.constraints, c)
    axes_of_constraint = _get_axes_of_constraint(reference_constraints_name)
    for r in axes_of_constraint
        push!(o.axes, r)
    end
    o.constraints_to_axes[c] = axes_of_constraint
    o.constraints_to_variables[c] = _get_variables_in_constraint(model, c)
end

function _get_axes_of_constraint(
    reference_constraints_name::T
) where T <: JuMP.Containers.DenseAxisArray
    axes_of_constraint = Array{BlockDecomposition.Axis,1}()
    for a in reference_constraints_name.axes
        if a != 1   # Axes of the form 1:1 do not matter (single constraints)
            push!(axes_of_constraint, Axis(a))
        end
    end
    return axes_of_constraint
end

function _get_variables_in_constraint(model::JuMP.Model, constraint::JuMP.ConstraintRef)
    f = MOI.get(model, MathOptInterface.ConstraintFunction(), constraint)
    variables = Set{MOI.VariableIndex}()
    for term in f.terms
        push!(variables, term.variable_index)
    end
    return variables
end

# Computes for the given axes two decomposition structures:
# In the first one (bs0) all constraints *not indexed by any* axis from
# axes are in the master, in the second one (bs1), all constraints *indexed
# by at least one* axis from axes are in the master
function get_block_structure(
    axes::Array{<:Axis,1},
    constraints_and_axes::Constraints_and_Axes,
    model::JuMP.Model,
)
    block_constraints = Set{JuMP.ConstraintRef}()
    master_constraints = Set{JuMP.ConstraintRef}()
    for c in keys(constraints_and_axes.constraints_to_axes)
        if  isempty(intersect(axes, constraints_and_axes.constraints_to_axes[c]))
            push!(master_constraints, c)
        else
            push!(block_constraints, c)
        end
    end
    # Create first block structure
    graph = _create_graph(block_constraints, constraints_and_axes)
    blocks = _get_connected_components!(graph)
    bs0 = BlockStructure(
        constraints_and_axes, master_constraints, axes, false, blocks, graph
    )
    # Create second block structure (the roles of master constraints and block
    # constraints are switched)
    graph = _create_graph(master_constraints, constraints_and_axes)
    blocks = _get_connected_components!(graph)
    bs1 = BlockStructure(
        constraints_and_axes, block_constraints, axes, true, blocks, graph
    )
    return bs0, bs1
end

function _get_connected_components!(graph::MetaGraph)
    connected_components_int = connected_components(graph)
    blocks = Array{Set{JuMP.ConstraintRef},1}()
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
    constraints_and_axes::Constraints_and_Axes,
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
                constraints_and_axes.constraints_to_variables[v1],
                constraints_and_axes.constraints_to_variables[v2],
            )
            if !isempty(intersection)
                add_edge!(graph, graph[v1, :constraint_ref], graph[v2, :constraint_ref])
            end
        end
    end
    return graph
end

