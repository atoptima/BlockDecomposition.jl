struct GapData
    jobs
    machines
    weights
    capacities
    costs
end

function GapToyData(nbjobs::Int, nbmachines::Int)
    w = [rand(1:10) for j in 1:nbjobs, m in 1:nbmachines]
    ca = [rand(7:15) for m in 1:nbmachines]
    co = [rand(1:5) for j in 1:nbjobs, m in 1:nbmachines]
    return GapData(1:nbjobs, 1:nbmachines, w, ca, co)
end

function generalized_assignement(d::GapData)
    BD.@axis(Machines, d.machines)

    model = BlockModel()
    @variable(model, x[j in d.jobs, m in Machines], Bin)

    @constraint(model, cov[j in d.jobs], sum(x[j, m] for m in Machines) >= 1)
    @constraint(model, knp[m in Machines], 
        sum(d.weights[j, m] * x[j, m] for j in d.jobs) <= d.capacities[m])

    @objective(model, Min, 
        sum(d.costs[j, m] * x[j, m] for j in d.jobs, m in Machines))

    BD.@dantzig_wolfe_decomposition(model, dwd, Machines)

    # dwd = BlockDecomposition.decompose_leaf(model, BlockDecomposition.DantzigWolfe)
    # for m in Machines
    #     BlockDecomposition.register_subproblem!(dwd, m, BlockDecomposition.DwPricingSp, BlockDecomposition.DantzigWolfe, 1, 1)
    # end
    return model, x, cov, knp, dwd
end

# Test pure master variables, constraint without id & variables without id
function generalized_assignement_penalties(d::GapData)
    BD.@axis(Machines, d.machines)

    model = BlockModel()
    @variable(model, x[j in d.jobs, m in Machines], Bin)
    @variable(model, y[j in d.jobs], Bin)
    @variable(model, z, Int)

    @constraint(model, cov[j in d.jobs], sum(x[j, m] for m in Machines) + y[j] >= 1)
    @constraint(model, lim, sum(y[j] for j in d.jobs)  <= 3 + z)

    @constraint(model, knp[m in Machines], 
        sum(d.weights[j, m] * x[j, m] for j in d.jobs) <= d.capacities[m])

    @objective(model, Min, 
        sum(d.costs[j, m] * x[j, m] for j in d.jobs, m in Machines) + 1000 * z)

    BD.@dantzig_wolfe_decomposition(model, dwd, Machines)

    return model, x, y, z, cov, knp, lim, dwd
end

struct LsData
    nbitems
    nbperiods
    demand
    prodcost
    setupcost
end

function LsToyData(nbitems::Int, nbperiods::Int)
    demand = [rand(0:10) for i in 1:nbitems, t in 1:nbperiods]
    prodcost = [rand(0:5) for i in 1:nbitems, t in 1:nbperiods]
    setupcost = [rand(0:5) for i in 1:nbitems, t in 1:nbperiods]
    return LsData(nbitems, nbperiods, demand, prodcost, setupcost)
end

function single_mode_multi_item_lot_sizing(d::LsData)
    mils = BlockModel()

    @axis(I, 1:d.nbitems)
    T = 1:d.nbperiods

    @variable(mils, x[i in 1:d.nbitems, t in T] >= 0) #no axis -> master
    @variable(mils, y[i in I, t in T] >= 0)

    @constraint(mils, singlemode[t in T], sum(y[i, t] for i in I) <= 1)

    @constraint(mils, setup[i in I, t in T], x[i, t] - sum(d.demand) * y[i, t] <= 0)

    @constraint(mils, cov[i in I, t in T], 
        sum(x[i, τ] for τ in 1:t) >= sum(d.demand[i, τ] for τ in 1:t)
    )

    @objective(mils, Min, 
        sum(d.prodcost[i, t] * x[i, t] for i in I, t in T) +
        sum(d.setupcost[i, t] * y[i, t] for i in I, t in T)
    )

    @benders_decomposition(mils, dec, I)

    return mils, x, y, singlemode, setup, cov, dec
end

struct CsData
    sheet_types
    nb_sheets
    sheets_sizes
    items
    demands
    widths
end

function CsToyData(nbsheettypes::Int, nbitems::Int)
    ns = [rand(6:8) for t in 1:nbsheettypes]
    ss = [rand(8:12) for t in 1:nbsheettypes]
    d = [rand(1:5) for i in 1:nbitems]
    w = [rand(2:6) for i in 1:nbitems]
    return CsData(1:nbsheettypes, ns, ss, 1:nbitems, d, w)
end

function cutting_stock(d::CsData)
    @assert length(d.sheet_types) == 1

    BD.@axis(Sheets, 1:7, Identical)

    model = BlockModel()
    @variable(model, 0 <= x[i in d.items, s in Sheets] <= d.demands[i], Int)
    @variable(model, y[s in Sheets], Bin)

    @constraint(model, cov[i in d.items], 
        sum(x[i, s] for s in Sheets) >= d.demands[i])
    @constraint(model, knp[s in Sheets], 
        sum(d.widths[i] * x[i, s] for i in d.items) <= d.sheets_sizes[1] * y[s])

    @objective(model, Min, sum(y[s] for s in Sheets))

    BD.@dantzig_wolfe_decomposition(model, dwd, Sheets)

    #dwd = BlockDecomposition.decompose_leaf(model, BlockDecomposition.DantzigWolfe)
    #BlockDecomposition.register_subproblem!(dwd, 1, BlockDecomposition.DwPricingSp, BlockDecomposition.DantzigWolfe, 1, Sheets[end])
    return model
end

function cutting_stock_different_sizes(d::CsData)
    @assert length(d.sheet_types) > 1
    BD.@axis(Sheets[t in d.sheet_types], 1:d.nb_sheets[t], Identical)

    model = BlockModel()
    @variable(model, 0 <= x[t in d.sheet_types, s in Sheets[t], i in d.items] <= d.demands[i], Int)
    @variable(model, y[t in d.sheet_types, s in Sheets[t]], Bin)

    @constraint(model, cov[i in d.items], 
        sum(x[t, s, i] for t in d.sheet_types, s in Sheets[t]) >= d.demands[i])

    @constraint(model, knp[t in d.sheet_types, s in Sheets[t]],
        sum(d.widths[i] * x[t, s, i] for i in d.items) <= y[t, s] * d.sheets_sizes[t])

    @objective(model, Min, sum(y[t, s] for t in d.sheet_types, s in Sheets[t]))

    #BD.@dantzig_wolfe_decomposition(model, dwd, Sheets)

    #dwd = BlockDecomposition.decompose_leaf(model, BlockDecomposition.DantzigWolfe)
    #for t in SheetTypes
    #    BlockDecomposition.register_subproblem!(dwd, (t, 1), BlockDecomposition.DwPricingSp, BlockDecomposition.DantzigWolfe, 1, NbSheets[t])
    #end
    return model
end

