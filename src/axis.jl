import Base.length
import Base.iterate
import Base.getindex
import Base.lastindex
import Base.to_index
import Base.hash
import Base.isequal
import Base.isless
import Base.==
import Base.vcat

using LightGraphs, MetaGraphs, TikzGraphs, Combinatorics, TikzPictures


struct AxisId{Name, T}
    indice::T
end

MOIU.map_indices(::Function, x::AxisId) = x

function name(i::AxisId{Name,T}) where {Name,T}
    return Name
end

function indice(i::AxisId{Name,T})::T where {Name,T}
    return i.indice
end

Base.hash(i::AxisId, h::UInt) = hash(i.indice, h)

# Permit the access to the entry of an array using an AxisId.
Base.to_index(i::AxisId) = i.indice

# Allow matching of AxisId key using the value of field indice (dict.jl:289)
# and vice-versa
Base.isequal(i::T, j::AxisId{N,T}) where {N,T} = isequal(i, j.indice)
Base.isequal(i::AxisId{N,T}, j::T) where {N,T} = isequal(i.indice, j)
Base.isless(i::T, j::AxisId{N,T}) where {N,T} = isless(i, j.indice)
Base.isless(i::AxisId{N,T}, j::T) where {N,T} = isless(i.indice, j)
Base.:(==)(i::T, j::AxisId{N,T}) where {N,T} = i == j.indice
Base.:(==)(i::AxisId{N,T}, j::T) where {N,T} = i.indice == j

iterate(i::AxisId) = (i, nothing)
iterate(i::AxisId, ::Any) = nothing
Base.show(io::IO, i::AxisId) = show(io, i.indice)

struct Axis{Name, T}
    name::Symbol
    container::Vector{AxisId{Name, T}}
end

function Axis(name::Symbol, container::A) where {T, A <: AbstractArray{T}}
    indices = AxisId{name, T}[]
    for val in container
        push!(indices, AxisId{name, T}(val))
    end
    return Axis{name, T}(name, indices)
end

Axis(container) = Axis(Symbol(), container)

name(axis::Axis) =  axis.name
iterate(axis::Axis) = iterate(axis.container)
iterate(axis::Axis, state) = iterate(axis.container, state)
length(axis::Axis) = length(axis.container)
getindex(axis::Axis, elements) = getindex(axis.container, elements)
lastindex(axis::Axis) = lastindex(axis.container)
vcat(A::BlockDecomposition.Axis, B::AbstractArray) = vcat(A.container, B)
Base.isequal(i::Axis, j::Axis) = isequal(i.container, j.container)
Base.hash(i::Axis, h::UInt) = hash(i.container, h)

function _generate_axis(name, container)
    sym_name = Meta.parse("Symbol(\"" * string(name) * "\")")
    return :(BlockDecomposition.Axis($sym_name, $container))
end

macro axis(args...)
    nbargs = length(args)
    nbargs > 2 && error("Axis declaration: too much arguments.")
    name = args[1]
    container = (nbargs == 2) ? args[2] : name
    exp = :()
    if typeof(name) != Symbol
        error("First argument of @axis is incorrect. The axis name is expected.")
    end
    exp = :($name = $(_generate_axis(name, container)))
    return esc(exp)
end




function get_best_block_structure(model::JuMP.Model)
	constraints_and_axes = get_constraints_and_axes(model)
	block_structures = Array{Block_Structure,1}()
	axesSets = collect(Combinatorics.powerset(collect(constraints_and_axes.axes)))
	for axes in axesSets
		block_structure = get_block_structure(axes, constraints_and_axes, model)
		push!(block_structures, block_structure)
	end
	return block_structures[3] #to do: find best decomposition
end

struct Block_Structure
    master_constraints::Set{JuMP.ConstraintRef}
	master_sets::Array{BlockDecomposition.Axis,1} #index sets used to determine which constraints are master constraints
	blocks::Array{Set{JuMP.ConstraintRef},1}
	graph::MetaGraphs.MetaGraph
end

mutable struct Constraints_and_Axes  #constains all the information we need to check different decompositons
	constraints::Set{JuMP.ConstraintRef}
	axes::Set{BlockDecomposition.Axis}
	variables::Set{MOI.VariableIndex} # MOI. VariableIndex can be used for reverencing variables in a model
	constraints_to_axes::Dict{JuMP.ConstraintRef, Set{BlockDecomposition.Axis}} 
	constraints_to_variables::Dict{JuMP.ConstraintRef, Set{MOI.VariableIndex}}
end

function plumple(block_structures::Array{Block_Structure,1}, constraints_and_axes::Constraints_and_Axes)
	result = nothing
	best = length(constraints_and_axes.constraints) * length(constraints_and_axes.variables) 
	for block_structure in block_structures
		plumple_value = _get_plumple_value(block_structure, constraints_and_axes)
		if plumple_value <= best
			best = plumple_value
			result = block_structure
		end
	end
	return result
end

function _get_plumple_value(block_structure::Block_Structure, constraints_and_axes::Constraints_and_Axes)
	n_master = length(constraints_and_axes.variables) * length(block_structure.master_constraints) 
	n_blocks = 0
	for block in block_structure.blocks
		for constraint in block
			n_blocks = n_blocks + length(constraints_and_axes.constraints_to_variables[constraint])
		end
	end
	return n_master+n_blocks
end



function get_constraints_and_axes(model::JuMP.Model) #returns an instance of the struct Constraints_and_axes
	constraints = Set{JuMP.ConstraintRef}()
	axes = Set{BlockDecomposition.Axis}()
	variables = Set{JuMP.MOI.VariableIndex}()
	constraints_to_axes = Dict{JuMP.ConstraintRef, Set{BlockDecomposition.Axis}}()
	constraints_to_variables = Dict{JuMP.ConstraintRef, Set{MOI.VariableIndex}}()
	constraints_and_axes = Constraints_and_Axes(constraints, axes, variables, constraints_to_axes, constraints_to_variables)
	
	for k in keys(model.obj_dict)  #check all names in the model
		# store single references to constraints in a DenseAxisArray (already done if several constraints are referenced with the same name)
		reference = typeof(model.obj_dict[k]) <: JuMP.Containers.DenseAxisArray ? model.obj_dict[k] : JuMP.Containers.DenseAxisArray([model.obj_dict[k]],1) 
		if typeof(reference[1]) <: JuMP.ConstraintRef #constraint  
			for c in reference
				_add_constraint!(constraints_and_axes, c, model, reference)
			end
		elseif typeof(reference[1]) <: JuMP.VariableRef
			for v in reference
				push!(variables, JuMP.index(v))
			end
		end
	end
	constraints_and_axes = Constraints_and_Axes(constraints, axes, variables, constraints_to_axes, constraints_to_variables)
	add_anonymous_var_and_con!(constraints_and_axes, model)
	return constraints_and_axes
end

function add_anonymous_var_and_con!(car::Constraints_and_Axes, model::JuMP.Model) #adds anonymous constraints and axes from the model to constraints_and_axes (car)
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

function _add_constraint!(o::Constraints_and_Axes, c::JuMP.ConstraintRef, model::JuMP.Model, reference_constraints_name::T) where T <: JuMP.Containers.DenseAxisArray
	push!(o.constraints, c)
	axes_of_constraint = _get_axes_of_constraint(reference_constraints_name)
	for r in axes_of_constraint
		push!(o.axes, r)
	end
	o.constraints_to_axes[c] = axes_of_constraint
	o.constraints_to_variables[c] = _get_variables_in_constraint(model, c)	
end	

function _get_axes_of_constraint(reference_constraints_name::T) where T <: JuMP.Containers.DenseAxisArray
	axes_of_constraint = Set{BlockDecomposition.Axis}()
	for a in reference_constraints_name.axes
		if a != 1   #axes of the form 1:1 do not matter (single constraints)
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

function get_block_structure(axes::Array{<:Axis,1}, constraints_and_axes::Constraints_and_Axes, model::JuMP.Model) 
	vertices = Set{JuMP.ConstraintRef}()
	master_constraints = Set{JuMP.ConstraintRef}()
	connected_components = Set{Set{JuMP.ConstraintRef}}()
	
	for c in keys(constraints_and_axes.constraints_to_axes)
		if !isempty(intersect(axes, constraints_and_axes.constraints_to_axes[c]))  #which constraints are build over at least one set that is contained in axes?
			push!(master_constraints, c)
		else
			push!(vertices, c)
		end
	end

	graph = _create_graph(vertices, constraints_and_axes)
	blocks = _get_connected_components!(graph)
	block_structure = Block_Structure(master_constraints, axes, blocks, graph)
	return block_structure
end

function _get_connected_components!(graph::MetaGraphs.MetaGraph)
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

function _create_graph(vertices::Set{JuMP.ConstraintRef}, constraints_and_axes::Constraints_and_Axes)
	graph = LightGraphs.SimpleGraph(0)
	graph = MetaGraphs.MetaGraph(graph)
	n_vertices = LightGraphs.add_vertices!(graph, length(vertices))
	MetaGraphs.set_indexing_prop!(graph, :constraint_ref)
	i = 1
	#set values for indexing property :constraint_ref
	for ver in vertices  
		MetaGraphs.set_prop!(graph, i, :constraint_ref, ver)
		i = i+1
	end
	#build edges
    for v1 in vertices, v2 in vertices 
		 if v1 != v2
			intersection = LightGraphs.intersect(constraints_and_axes.constraints_to_variables[v1], constraints_and_axes.constraints_to_variables[v2])
			isempty(intersection) ? true : LightGraphs.add_edge!(graph, graph[v1, :constraint_ref], graph[v2, :constraint_ref])
		end
	end 	
	return graph
end

function draw_graph(mgraph::MetaGraphs.MetaGraph)
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
	t = TikzGraphs.plot(sgraph, labels)
	save(SVG("graph.svg"),t)
end