using BlockDecomposition

using Test
using JuMP

const BD = BlockDecomposition

include("axis.jl")
include("formulations.jl")
include("tree.jl")

axis_declarations()
test_dantzig_wolfe_different()
test_dantzig_wolfe_identical()
test_dantzig_wolfe_diffidentical()

