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
    model_filename = "./gap.mps",
    decomp_filename = "./gap.dec"
)
optimize!(model)
return model
