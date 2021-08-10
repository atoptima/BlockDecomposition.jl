sp_pricing_oracle() = nothing

struct MockOptimizer <: MOI.AbstractOptimizer end

MOI.is_empty(model::MockOptimizer) = true

const SupportedObjFunc = Union{MOI.ScalarAffineFunction{Float64}, MOI.SingleVariable}

const SupportedVarSets = Union{
    MOI.ZeroOne, MOI.Integer, MOI.LessThan{Float64}, MOI.EqualTo{Float64}, 
    MOI.GreaterThan{Float64}
}

const SupportedConstrFunc = Union{MOI.ScalarAffineFunction{Float64}}

const SupportedConstrSets = Union{
    MOI.EqualTo{Float64}, MOI.GreaterThan{Float64}, MOI.LessThan{Float64}
}

MOI.supports(::MockOptimizer, ::MOI.VariableName, ::Type{MOI.VariableIndex}) = true
MOI.supports(::MockOptimizer, ::MOI.ConstraintName, ::Type{<:MOI.ConstraintIndex}) = true
MOI.supports_constraint(::MockOptimizer, ::Type{<:SupportedConstrFunc}, ::Type{<:SupportedConstrSets}) = true
MOI.supports_constraint(::MockOptimizer, ::Type{MOI.SingleVariable}, ::Type{<: SupportedVarSets}) = true
MOI.supports(::MockOptimizer, ::MOI.ObjectiveFunction{<:SupportedObjFunc}) = true
MOI.supports(::MockOptimizer, ::MOI.ObjectiveSense) = true

function test_assignsolver()

    @testset "Assign default MOI mip solver" begin
        d = GapToyData(5, 3)
        model, x, cov, knp, dec = generalized_assignement(d)
        master = getmaster(dec)
        subproblems = getsubproblems(dec)

        specify!.(subproblems, solver = sp_pricing_oracle)
        @test BD.getoptimizerbuilders(subproblems[1].annotation) == [sp_pricing_oracle]
        specify!(subproblems[2], solver = nothing)
        @test BD.getoptimizerbuilders(subproblems[2].annotation) == []
        specify!(subproblems[3], solver = MockOptimizer)
        @test BD.getoptimizerbuilders(subproblems[3].annotation) == [MockOptimizer()]
        specify!(subproblems[1], solver = [sp_pricing_oracle, MockOptimizer])
        @test BD.getoptimizerbuilders(subproblems[1].annotation) == [sp_pricing_oracle, MockOptimizer()]
    end
end