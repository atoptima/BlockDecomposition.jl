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
    specify!.(subproblems, lower_multiplicity = 0, upper_multiplicity = 1)
    return model, x, cov, knp, decomposition
end

function example_assignment_automatic_decomposition()
    nb_machines = 4
    nb_jobs = 30
    c = [12.7 22.5 8.9 20.8 13.6 12.4 24.8 19.1 11.5 17.4 24.7 6.8 21.7 14.3 10.5 15.2 14.3 12.6 9.2 20.8 11.7 17.3 9.2 20.3 11.4 6.2 13.8 10.0 20.9 20.6;  19.1 24.8 24.4 23.6 16.1 20.6 15.0 9.5 7.9 11.3 22.6 8.0 21.5 14.7 23.2 19.7 19.5 7.2 6.4 23.2 8.1 13.6 24.6 15.6 22.3 8.8 19.1 18.4 22.9 8.0;  18.6 14.1 22.7 9.9 24.2 24.5 20.8 12.9 17.7 11.9 18.7 10.1 9.1 8.9 7.7 16.6 8.3 15.9 24.3 18.6 21.1 7.5 16.8 20.9 8.9 15.2 15.7 12.7 20.8 10.4;  13.1 16.2 16.8 16.7 9.0 16.9 17.9 12.1 17.5 22.0 19.9 14.6 18.2 19.6 24.2 12.9 11.3 7.5 6.5 11.3 7.8 13.8 20.7 16.8 23.6 19.1 16.8 19.3 12.5 11.0]
    w = [61 70 57 82 51 74 98 64 86 80 69 79 60 76 78 71 50 99 92 83 53 91 68 61 63 97 91 77 68 80; 50 57 61 83 81 79 63 99 82 59 83 91 59 99 91 75 66 100 69 60 87 98 78 62 90 89 67 87 65 100; 91 81 66 63 59 81 87 90 65 55 57 68 92 91 86 74 80 89 95 57 55 96 77 60 55 57 56 67 81 52;  62 79 73 60 75 66 68 99 69 60 56 100 67 68 54 66 50 56 70 56 72 62 85 70 100 57 96 69 65 50]
    Q = [1020 1460 1530 1190]
    M = 1:nb_machines
    J = 1:nb_jobs
    model = BlockModel(automatic_decomposition = true)
    @variable(model, x[m in M, j in J], Bin)
    @constraint(model, cov[j in J], sum(x[m, j] for m in M) >= 1)
    @constraint(model, knp[m in M], sum(w[m, j] * x[m, j] for j in J) <= Q[m])
    @objective(model, Min, sum(c[m, j] * x[m, j] for m in M, j in J))

    return model, x, cov, knp
end

function generalized_assignment_automatic_decomposition(d::GapData)
    model = BlockModel(automatic_decomposition = true)
    
    @variable(model, x[j in d.jobs, m in d.machines], Bin)

    @constraint(model, cov[j in d.jobs], sum(x[j, m] for m in d.machines) >= 1)
    @constraint(model, knp[m in d.machines], 
         sum(d.weights[j, m] * x[j, m] for j in d.jobs) <= d.capacities[m])

    @objective(model, Min, 
         sum(d.costs[j, m] * x[j, m] for j in d.jobs, m in d.machines))

    return model, x, cov, knp
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

function generalized_assignement_conditional_constraint(d::GapData)
    BD.@axis(Machines, d.machines)

    model = BlockModel()
    @variable(model, x[j in d.jobs, m in Machines], Bin)
    @variable(model, y[j in d.jobs], Bin)
    @variable(model, z, Int)

    @constraint(model, cov[j in d.jobs], sum(x[j, m] for m in Machines) + y[j] >= 1)
    @constraint(model, lim, sum(y[j] for j in d.jobs)  <= 3 + z)

    @constraint(model, knp[m in Machines], 
        sum(d.weights[j, m] * x[j, m] for j in d.jobs) <= d.capacities[m])

    @constraint(model, cond1[m in Machines; m < 3],
        sum(d.weights[j, m] * x[j, m] for j in d.jobs) >= 0.3 * d.capacities[m])

    @constraint(model, cond2[m in Machines; m in [2,4]],
        sum(d.weights[j, m] * x[j, m] for j in d.jobs) >= 0.35 * d.capacities[m])

    @constraint(model, cond3[m in Machines; m > 3],
        sum(d.weights[j, m] * x[j, m] for j in d.jobs) >= 0.4 * d.capacities[m])

    @objective(model, Min, 
        sum(d.costs[j, m] * x[j, m] for j in d.jobs, m in Machines) + 1000 * z)

    @dantzig_wolfe_decomposition(model, decomposition, Machines)

    master = getmaster(decomposition)
    subproblems = getsubproblems(decomposition)
    for (i,m) in enumerate(Machines)
        specify!(subproblems[i], lower_multiplicity = 0, upper_multiplicity = 1)
    end
    return model, x, y, z, cov, knp, lim, cond1, cond2, cond3, decomposition
end

# test pure master variables, constraint without id, variables without id, & decomposition over only subsets of decomposition axes
function generalized_assignment_centralized_machines(d::GapData)
    BD.@axis(DecMachines, d.machines[1:5])
    CenMachines = d.machines[6:10]
    Machines = vcat(DecMachines.container, CenMachines)

    model = BlockModel()
    @variable(model, x[j in d.jobs, m in Machines], Bin)
    @variable(model, y[j in d.jobs], Bin) # variables without id
    @variable(model, z, Int) # pure master variable

    @constraint(model, cov[j in d.jobs], sum(x[j, m] for m in Machines) + y[j] >= 1)
    @constraint(model, lim, sum(y[j] for j in d.jobs)  <= 3 + z) # constraint without id

    @constraint(model, knp[m in Machines], 
        sum(d.weights[j, m] * x[j, m] for j in d.jobs) <= d.capacities[m])

    @constraint(model, cond1[m in Machines; m < 3],
        sum(d.weights[j, m] * x[j, m] for j in d.jobs) >= 0.3 * d.capacities[m])

    @constraint(model, cond2[m in Machines; m in [2,4]],
        sum(d.weights[j, m] * x[j, m] for j in d.jobs) >= 0.35 * d.capacities[m])

    @constraint(model, cond3[m in Machines; m > 3],
        sum(d.weights[j, m] * x[j, m] for j in d.jobs) >= 0.4 * d.capacities[m])

    @objective(model, Min, 
        sum(d.costs[j, m] * x[j, m] for j in d.jobs, m in Machines) + 1000 * z)

    @dantzig_wolfe_decomposition(model, decomposition, DecMachines)

    master = getmaster(decomposition)
    subproblems = getsubproblems(decomposition)
    for (i,m) in enumerate(DecMachines)
        specify!(subproblems[i], lower_multiplicity = 0, upper_multiplicity = 1)
    end
    return model, x, y, z, cov, knp, lim, cond1, cond2, cond3, decomposition
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

    for s in SheetTypes
        specify!(subproblems[s], lower_multiplicity = 0, upper_multiplicity = d.nb_sheets[s])
    end

    return model, x, y, cov, knp, dec
end

