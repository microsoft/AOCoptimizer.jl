function MOI.get(optimizer::Optimizer, pm::MOI.PrimalStatus)
    if 1 <= pm.result_index <= MOI.get(optimizer, MOI.ResultCount())
        # Unconstrained problems are always feasible :)
        return MOI.FEASIBLE_POINT
    else
        return MOI.NO_SOLUTION
    end
end

function MOI.get(::Optimizer, ::MOI.DualStatus)
    # No constraints, no duals :(
    return MOI.NO_SOLUTION
end

function MOI.get(::Optimizer, ::MOI.RawStatusString)
    return ""
end

function MOI.get(optimizer::Optimizer, ::MOI.ResultCount)
    if isnothing(optimizer.output)
        return 0
    else
        return 1
    end
end

function MOI.get(optimizer::Optimizer, ::MOI.TerminationStatus)
    if isnothing(optimizer.output)
        return MOI.OPTIMIZE_NOT_CALLED
    else
        # This is everything we can say about the termination status
        # as in every other optimization heuristic method.
        return MOI.LOCALLY_SOLVED
    end
end

MOI.supports(::Optimizer, ::MOI.VariablePrimal, ::VI) = true
function MOI.get(optimizer::Optimizer, vp::MOI.VariablePrimal, vi::VI)
    @assert 1 <= vp.result_index <= MOI.get(optimizer, MOI.ResultCount())

    if haskey(optimizer.fixed, vi)
        return optimizer.fixed[vi]
    end

    yi = optimizer.output["Assignment"][optimizer.variable_map[vi]]

    if optimizer.variable_info[vi].type === :binary
        return yi
    else # optimizer.variable_info[vi].type === continuous
        li = optimizer.variable_info[vi].lower
        ui = optimizer.variable_info[vi].upper

        return li + (yi + 1) * (ui - li) / 2
    end
end

MOI.supports(::Optimizer, ::MOI.ObjectiveValue) = true
function MOI.get(optimizer::Optimizer, ov::MOI.ObjectiveValue)
    @assert 1 <= ov.result_index <= MOI.get(optimizer, MOI.ResultCount())

    return optimizer.output["Objective"] + optimizer.offset
end
