using Coluna, BlockDecomposition, JuMP, GLPK
coluna = optimizer_with_attributes(
    Coluna.Optimizer,
    "params" => Coluna.Params(
        solver = Coluna.Algorithm.TreeSearchAlgorithm() # default BCP
    ),
    "default_optimizer" => GLPK.Optimizer # GLPK for the master & the subproblems
)

model = BlockModel(
    coluna,
    read_decomposition = true,
    model_filename = "./bpp_20_0.mps", # From: https://striplib.or.rwth-aachen.de/
    decomp_filename = "./bpp_20_0.dec"
)
optimize!(model)
return model
