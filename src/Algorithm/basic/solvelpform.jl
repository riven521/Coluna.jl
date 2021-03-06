"""
    Coluna.Algorithm.SolveLpForm(
        get_dual_solution = false,
        relax_integrality = false,
        set_dual_bound = false,
        silent = true
    )

Solve a linear program.
"""
@with_kw struct SolveLpForm <: AbstractOptimizationAlgorithm 
    get_ip_primal_solution = false
    get_dual_solution = false
    relax_integrality = false
    set_dual_bound = false
    silent = true
    log_level = 0
end

# SolveLpForm does not have child algorithms, therefore get_child_algorithms() is not defined

function get_storages_usage(
    algo::SolveLpForm, form::Formulation{Duty}
) where {Duty<:MathProg.AbstractFormDuty}
    # we use storages in the read only mode, as relaxing integrality
    # is reverted before the end of the algorithm, 
    # so the state of the formulation remains the same 
    storages_usage = Tuple{AbstractModel, StorageTypePair, StorageAccessMode}[] 
    push!(storages_usage, (form, StaticVarConstrStoragePair, READ_ONLY))
    if Duty <: MathProg.AbstractMasterDuty
        push!(storages_usage, (form, MasterColumnsStoragePair, READ_ONLY))
        push!(storages_usage, (form, MasterBranchConstrsStoragePair, READ_ONLY))
        push!(storages_usage, (form, MasterCutsStoragePair, READ_ONLY))
    end
    return storages_usage
end

function optimize_lp_form!(algo::SolveLpForm, optimizer, form::Formulation) # fallback
    error("Cannot optimize LP formulation with optimizer of type ", typeof(optimizer), ".")
end

function optimize_lp_form!(algo::SolveLpForm, optimizer::MoiOptimizer, form::Formulation)
    MOI.set(form.optimizer.inner, MOI.Silent(), algo.silent)
    return optimize!(form)
end

function run!(algo::SolveLpForm, data::ModelData, input::OptimizationInput)::OptimizationOutput
    form = getmodel(data)
    optstate = OptimizationState(form)

    TO.@timeit Coluna._to "SolveLpForm" begin

    if algo.relax_integrality
        relax_integrality!(form)
    end

    optimizer_result = optimize_lp_form!(algo, getoptimizer(form), form)

    setfeasibilitystatus!(optstate, getfeasibilitystatus(optimizer_result))    
    setterminationstatus!(optstate, getterminationstatus(optimizer_result))   

    lp_primal_sol = getbestprimalsol(optimizer_result)
    if lp_primal_sol !== nothing
        add_lp_primal_sol!(optstate, lp_primal_sol)
        if algo.get_ip_primal_solution && isinteger(lp_primal_sol) && 
            !contains(lp_primal_sol, varid -> isanArtificialDuty(getduty(varid)))
            add_ip_primal_sol!(optstate, lp_primal_sol)
        end
    end

    if algo.get_dual_solution
        lp_dual_sol = getbestdualsol(optimizer_result)
        if lp_dual_sol !== nothing
            if algo.set_dual_bound
                update_lp_dual_sol!(optstate, lp_dual_sol)
            else
                set_lp_dual_sol!(optstate, lp_dual_sol)
            end
        end
    end

    end 
    return OptimizationOutput(optstate)
end
