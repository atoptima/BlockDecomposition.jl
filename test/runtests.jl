using BlockDecomposition

using Test
using JuMP

const BD = BlockDecomposition

function test_annotation(ann::BD.Annotation, F::Type{<:BD.Formulation}, 
        D::Type{<:BD.Decomposition}, minmult, maxmult)
    @test BD.getformulation(ann) == F
    @test BD.getdecomposition(ann) == D
    @test BD.getminmultiplicity(ann) == minmult
    @test BD.getmaxmultiplicity(ann) == maxmult
    return
end

include("axis.jl")
include("formulations.jl")
include("dantzigwolfe.jl")
include("benders.jl")

axis_declarations()
test_dantzig_wolfe_different()
test_dantzig_wolfe_identical()
test_dantzig_wolfe_diffidentical()
test_benders()

