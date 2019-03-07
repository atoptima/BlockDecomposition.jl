using BlockDecomposition

using Test
using JuMP

const BD = BlockDecomposition

include("axis.jl")
#include("formulations.jl")
#include("decompositiontree.jl")

axis_declarations()
