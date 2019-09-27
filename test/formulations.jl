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
    @axis(Machines, d.machines)

    model = BlockModel()
    @variable(model, x[j in d.jobs, m in Machines], Bin)

    @constraint(model, cov[j in d.jobs], sum(x[j, m] for m in Machines) >= 1)
    @constraint(model, knp[m in Machines], 
         sum(d.weights[j, m] * x[j, m] for j in d.jobs) <= d.capacities[m])

    @objective(model, Min, 
         sum(d.costs[j, m] * x[j, m] for j in d.jobs, m in Machines))

    @dantzig_wolfe_decomposition(model, decomposition, Machines)
    master = getmaster(decomposition)
    subproblems = getsubproblems(decomposition)
    specify!(subproblems, lower_multiplicity = 0, upper_multiplicity = 1)

    return model, x, cov, knp, decomposition
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

    @dantzig_wolfe_decomposition(model, decomposition, Machines)

    master = getmaster(decomposition)
    subproblems = getsubproblems(decomposition)
    for (i,m) in enumerate(Machines)
        specify!(subproblems[i], lower_multiplicity = 0, upper_multiplicity = 1)
    end
    return model, x, y, z, cov, knp, lim, decomposition
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

    @variable(mils, x[i in 1:d.nbitems, t in T] >= 0)
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
    ns = [rand(10:30) for t in 1:nbsheettypes]
    ss = [rand(8:12) for t in 1:nbsheettypes]
    d = [rand(1:5) for i in 1:nbitems]
    w = [rand(2:6) for i in 1:nbitems]
    return CsData(1:nbsheettypes, ns, ss, 1:nbitems, d, w)
end

function cutting_stock(d::CsData)
    @axis(SheetTypes, d.sheet_types)

    model = BlockModel()
    @variable(model, 0 <= x[t in SheetTypes, i in d.items] <= d.demands[i], Int)
    @variable(model, y[t in SheetTypes], Bin)

    @constraint(model, cov[i in d.items], 
        sum(x[t, i] for t in SheetTypes) >= d.demands[i])

    @constraint(model, knp[t in SheetTypes],
        sum(d.widths[i] * x[t, i] for i in d.items) <= y[t] * d.sheets_sizes[t])

    @objective(model, Min, sum(y[t] for t in SheetTypes))

    @dantzig_wolfe_decomposition(model, dec, SheetTypes)
    subproblems = getsubproblems(dec)

    specify!(subproblems, lower_multiplicity = 0, upper_multiplicity = d.nb_sheets)

    return model, x, y, cov, knp, dec
end

