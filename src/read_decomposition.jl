# Reads the decomposition file, computes the decomposition of the model
# and stores it in model.ext[:decompositon_structure]
function read_decomposition!(model::JuMP.Model)
    decomposition_filename = model.ext[:decomp_filename]
    decomposition_structure = get_decomposition_structure(model, decomposition_filename)
    model.ext[:decomposition_structure] = decomposition_structure 
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
end

function get_decomposition_structure(model::JuMP.Model, decomposition_filename::String)
    master_names, blocks_names = _read_constraint_names(decomposition_filename)
    master_cons = Set{JuMP.ConstraintRef}() 
    blocks = Array{Set{JuMP.ConstraintRef},1}(undef, length(blocks_names))
    constraints_to_variables = Dict{JuMP.ConstraintRef, Set{MOI.VariableIndex}}()
    for cons_name in master_names
        cons = JuMP.constraint_by_name(model, cons_name)
        push!(master_cons, cons)
        constraints_to_variables[cons] = _get_variables_in_constraint(model, cons)
    end
    for block_nb in 1:length(blocks_names)
        block = Set{JuMP.ConstraintRef}()
        for cons_name in blocks_names[block_nb] 
            cons = JuMP.constraint_by_name(model, cons_name)
            push!(block, cons)
            constraints_to_variables[cons] = _get_variables_in_constraint(model, cons)
        end
        blocks[block_nb] = block
    end
    decomposition_structure = BlockStructure(master_cons, blocks, constraints_to_variables)
    return decomposition_structure
end

# Computes names of constraints in the master and blocks
function _read_constraint_names(decomp_filename::String)
    master = Set{String}() # Names of master constraints
    blocks = Array{Set{String},1}() # Names of constraints in blocks
    lines = readlines(decomp_filename)
    for index in eachindex(lines) 
        items = _line_to_items(lines[index])
        if items[1] == "NBLOCKS" # Initialize number of blocks
            index = index + 1
            nb_blocks = parse(Int, lines[index])
            blocks = Array{Set{String},1}(undef, nb_blocks)
        end
        if items[1] == "BLOCK" # Add block
            nb = parse(Int, items[2])
            constraint_names, new_index = _get_following_constraints(lines, index)
            blocks[nb] = constraint_names
        end
        if items[1] == "MASTERCONSS" # Add master constraints
            master, _ = _get_following_constraints(lines, index)
        end
    end
    return master, blocks
end

function _line_to_items(line)
    items = split(line, " "; keepempty = false)
    return String.(items)
end

# Returns all the constraint names directly following the current position
function _get_following_constraints(lines::Vector{String}, index::Int)
    constraint_names =  Set{String}()
    for new_index in index+1:length(lines)
        items = _line_to_items(lines[new_index])
        head = items[1]
        if head == "BLOCK" || head == "MASTERCONSS"
            return constraint_names, new_index
        end
        push!(constraint_names, head)
    end
    return constraint_names, length(lines)
end