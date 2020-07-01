# Finds the best decomposition structure of to be used by the solver 
function get_best_block_structure(model::JuMP.Model)
    constraints_and_axes = get_constraints_and_axes(model)
    block_structures = Array{BlockStructure,1}()
    axesSets = collect(powerset(collect(constraints_and_axes.axes)))
    for axes in axesSets
        block_structure = get_block_structure(axes, constraints_and_axes, model)
        push!(block_structures, block_structure)
    end
    result =  plumple(block_structures, constraints_and_axes)
    return result
end

# Decomposes the given JuMP Model automatically
function decompose(model::JuMP.Model)
    model.ext[:decomposition_structure] = BlockDecomposition.get_best_block_structure(model)
    decomposition_axis = BlockDecomposition.Axis(1:length(model.ext[:decomposition_structure].blocks))
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
    return decomposition, decomposition_axis
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
    # constraints_and_axes is the same for every possible BlockStructure of a model
    constraints_and_axes::Constraints_and_Axes
    master_constraints::Set{JuMP.ConstraintRef}
    master_sets::Array{BlockDecomposition.Axis,1}
    blocks::Array{Set{JuMP.ConstraintRef},1}
    graph::MetaGraph
end

function plumple(block_structures::Array{BlockStructure,1}, constraints_and_axes::Constraints_and_Axes)
    result = nothing
    best = length(constraints_and_axes.constraints) * length(constraints_and_axes.variables)
    for block_structure in block_structures
        plumple_value = _get_plumple_value(block_structure)
        if plumple_value <= best
            best = plumple_value
            result = block_structure
        end
    end
    return result
end

function _get_plumple_value(block_structure::BlockStructure)
    n_master = length(block_structure.constraints_and_axes.variables) * length(block_structure.master_constraints)
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
    return n_master+n_blocks
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
        # Store single references to constraints in a DenseAxisArray (already done if several constraints are referenced with the same name)
        reference = typeof(model.obj_dict[k]) <: JuMP.Containers.DenseAxisArray ? model.obj_dict[k] : JuMP.Containers.DenseAxisArray([model.obj_dict[k]],1)
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

# Add anonymous constraints and axes from the model to constraints_and_axes (car)
function _add_anonymous_var_con!(car::Constraints_and_Axes, model::JuMP.Model)
    types =  JuMP.list_of_constraint_types(model)
    for t in types
        if t[1] != VariableRef
            for c in JuMP.all_constraints(model, t[1], t[2])
                if !in(c, car.constraints)
                    push!(car.constraints, c)
                    car.constraints_to_axes[c] = Set{BlockDecomposition.Axis}()
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

function _get_axes_of_constraint(reference_constraints_name::T) where T <: JuMP.Containers.DenseAxisArray
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

function get_block_structure(
    axes::Array{<:Axis,1},
    constraints_and_axes::Constraints_and_Axes,
    model::JuMP.Model,
)
    vertices = Set{JuMP.ConstraintRef}()
    master_constraints = Set{JuMP.ConstraintRef}()
    connected_components = Set{Set{JuMP.ConstraintRef}}()

    for c in keys(constraints_and_axes.constraints_to_axes)
        # Check if constraints are constructed over at least one set which is contained in axes
        # if axes is empty annotate everything as master
        if  isempty(axes) || !isempty(intersect(axes, constraints_and_axes.constraints_to_axes[c]))
            push!(master_constraints, c)
        else
            push!(vertices, c)
        end
    end

    graph = _create_graph(vertices, constraints_and_axes)
    blocks = _get_connected_components!(graph)
    block_structure = BlockStructure(constraints_and_axes, master_constraints, axes, blocks, graph)
    return block_structure
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
            isempty(intersection) ? true : add_edge!(graph, graph[v1, :constraint_ref], graph[v2, :constraint_ref])
        end
    end
    return graph
end

function draw_graph(mgraph::MetaGraph)
    sgraph = SimpleGraph(nv(mgraph))
    labels = Array{String}(undef, nv(mgraph))
    i = 1
    for v in collect(vertices(mgraph))
        labels[i] = convert(String, repr(mgraph[i, :constraint_ref]))
        i = i + 1
    end
    for e in edges(mgraph)
        add_edge!(sgraph, e)
    end
    t = plot(sgraph, labels)
    save(SVG("graph.svg"),t)
end
