@hl type MasterColumn <: Variable
    solution::Solution

    # ```
    # Determines whether this column was generated by a subproblem with the
    # "enumerated" status. This flag may have an impact on the column
    # coefficients in master cuts.
    # ```
    enumerated_flag::Bool

    # ```
    # Flag telling whether or not the column is part of the convexity constraint.
    # ```
    belongs_to_convexity_constraint::Bool
end

function MasterColumnBuilder(problem::P, sp_sol::Solution,
                             name::String) where P
    return tuplejoin(VariableBuilder(problem,
            string(name, problem.counter.value), 0.0, 'P', sp_sol.type, 'd', -1, 
            0.0, Inf), sp_sol, 0, 0 #= enumeration not supported =#, true)
end