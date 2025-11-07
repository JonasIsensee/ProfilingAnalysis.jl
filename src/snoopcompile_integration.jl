"""
SnoopCompile.jl integration for ProfilingAnalysis.

Provides AI agent-friendly interfaces to SnoopCompile.jl's compilation analysis.
"""

using SnoopCompile

"""
    analyze_compilation(workload_fn::Function;
                       check_invalidations=false,
                       check_inference=true,
                       filter_system=true,
                       top_n=20) -> CompilationAnalysis

Comprehensive compilation analysis using SnoopCompile.jl.

Analyzes type inference time and optionally invalidations during code execution.

# Arguments
- `workload_fn`: Function to profile (will be called once with warmup)
- `check_invalidations`: Include invalidation analysis (slower, for load-time issues)
- `check_inference`: Include type inference analysis (default: true)
- `filter_system`: Filter out system/stdlib code (default: true)
- `top_n`: Number of top issues to include (default: 20)

# Returns
`CompilationAnalysis` with structured results

# Example
```julia
analysis = analyze_compilation() do
    my_algorithm(test_data)
end

print_compilation_analysis(analysis)

# Show only critical issues
for issue in get_critical_compilation_issues(analysis)
    println(issue.description)
    println(issue.recommendation)
end
```
"""
function analyze_compilation(workload_fn::Function;
                            check_invalidations=false,
                            check_inference=true,
                            filter_system=true,
                            top_n=20)
    issues = CompilationIssue[]
    total_inference_time = 0.0
    metadata = Dict{String, Any}()

    # Run inference analysis
    if check_inference
        inf_issues, inf_time = analyze_inference_snoopcompile(workload_fn, filter_system, top_n)
        append!(issues, inf_issues)
        total_inference_time = inf_time
        metadata["inference_analyzed"] = true
    end

    # Run invalidation analysis
    if check_invalidations
        inv_issues = analyze_invalidations_snoopcompile(workload_fn, filter_system, top_n)
        append!(issues, inv_issues)
        metadata["invalidations_analyzed"] = true
    end

    # Build summary
    summary = Dict{Symbol, Int}()
    for issue in issues
        summary[issue.type] = get(summary, issue.type, 0) + 1
    end

    return CompilationAnalysis(
        now(),
        total_inference_time,
        issues,
        summary,
        "SnoopCompile.jl",
        metadata
    )
end

"""
    analyze_inference_snoopcompile(workload_fn::Function, filter_system::Bool, top_n::Int) -> (Vector{CompilationIssue}, Float64)

Analyze type inference using SnoopCompile's @snoopi_deep.

Returns (issues, total_inference_time).
"""
function analyze_inference_snoopcompile(workload_fn::Function, filter_system::Bool, top_n::Int)
    issues = CompilationIssue[]
    total_time = 0.0

    try
        # Warmup
        workload_fn()

        # Profile inference
        tinf = SnoopCompile.@snoopi_deep workload_fn()

        # Get total inference time
        total_time = SnoopCompile.inclusive(tinf)

        # Flatten to get all inference frames
        flat = SnoopCompile.flatten(tinf)

        # Sort by exclusive time (time spent in this function, not callees)
        sort!(flat, by=x -> SnoopCompile.exclusive(x), rev=true)

        # Process top N entries
        count = 0
        for frame in flat
            if count >= top_n
                break
            end

            # Extract information
            mi = frame.mi  # MethodInstance

            # Get method info
            method = mi.def
            if method isa Method
                func_name = string(method.name)
                file = string(method.file)
                line = method.line

                # Filter system code
                if filter_system && is_system_file(file)
                    continue
                end

                exc_time = SnoopCompile.exclusive(frame)
                inc_time = SnoopCompile.inclusive(frame)

                # Only include significant inference times
                if exc_time < 0.001  # Less than 1ms
                    continue
                end

                # Determine severity based on time
                severity = if exc_time > 0.1
                    :critical
                elseif exc_time > 0.01
                    :high
                elseif exc_time > 0.001
                    :medium
                else
                    :low
                end

                description = "Type inference took $(round(exc_time, digits=3))s (inclusive: $(round(inc_time, digits=3))s)"
                recommendation = generate_inference_recommendation(exc_time, inc_time)

                push!(issues, CompilationIssue(
                    :slow_inference,
                    severity,
                    func_name,
                    file,
                    line,
                    description,
                    exc_time,
                    0,
                    String[],
                    recommendation
                ))

                count += 1
            end
        end

        # Analyze inference triggers (runtime dispatch)
        trigger_issues = analyze_triggers_snoopcompile(tinf, filter_system, top_n)
        append!(issues, trigger_issues)

        # Check for stale instances
        stale_issues = analyze_stale_instances(tinf, filter_system)
        append!(issues, stale_issues)

    catch e
        @warn "Error during SnoopCompile inference analysis" exception=(e, catch_backtrace())
        push!(issues, CompilationIssue(
            :error,
            :high,
            "analyze_inference",
            "",
            0,
            "Error during inference analysis: $(string(e))",
            0.0,
            0,
            String[],
            "Check SnoopCompile installation and workload function"
        ))
    end

    return (issues, total_time)
end

"""
    analyze_triggers_snoopcompile(tinf, filter_system::Bool, top_n::Int) -> Vector{CompilationIssue}

Analyze inference triggers (runtime dispatch points).
"""
function analyze_triggers_snoopcompile(tinf, filter_system::Bool, top_n::Int)
    issues = CompilationIssue[]

    try
        # Get inference triggers
        triggers = SnoopCompile.inference_triggers(tinf)

        count = 0
        for trigger in triggers
            if count >= top_n
                break
            end

            # Extract trigger info
            caller = SnoopCompile.callerinstance(trigger)

            if caller isa Core.MethodInstance
                method = caller.def
                if method isa Method
                    func_name = string(method.name)
                    file = string(method.file)
                    line = method.line

                    # Filter system code
                    if filter_system && is_system_file(file)
                        continue
                    end

                    # Get backtrace
                    chain = String[]
                    current = trigger
                    for _ in 1:5  # Limit depth
                        try
                            frame = SnoopCompile.callingframe(current)
                            if !isnothing(frame)
                                push!(chain, string(frame))
                                current = frame
                            else
                                break
                            end
                        catch
                            break
                        end
                    end

                    description = "Runtime dispatch causes type inference"
                    recommendation = "Add type annotations to eliminate runtime dispatch, or use a function barrier"

                    push!(issues, CompilationIssue(
                        :inference_trigger,
                        :high,
                        func_name,
                        file,
                        line,
                        description,
                        0.0,  # Can't easily get time for triggers
                        1,
                        chain,
                        recommendation
                    ))

                    count += 1
                end
            end
        end

    catch e
        @warn "Error analyzing inference triggers" exception=(e, catch_backtrace())
    end

    return issues
end

"""
    analyze_stale_instances(tinf, filter_system::Bool) -> Vector{CompilationIssue}

Analyze stale code instances (invalidated during profiling).
"""
function analyze_stale_instances(tinf, filter_system::Bool)
    issues = CompilationIssue[]

    try
        stale = SnoopCompile.staleinstances(tinf)

        for node in stale
            mi = node.mi

            if mi isa Core.MethodInstance
                method = mi.def
                if method isa Method
                    func_name = string(method.name)
                    file = string(method.file)
                    line = method.line

                    # Filter system code
                    if filter_system && is_system_file(file)
                        continue
                    end

                    description = "Code was invalidated during profiling - indicates invalidation issue"
                    recommendation = "Check for method redefinitions or type piracy that might cause invalidations"

                    push!(issues, CompilationIssue(
                        :stale_instance,
                        :high,
                        func_name,
                        file,
                        line,
                        description,
                        0.0,
                        1,
                        String[],
                        recommendation
                    ))
                end
            end
        end

    catch e
        # staleinstances might not be available in all versions
        @debug "Could not analyze stale instances" exception=(e, catch_backtrace())
    end

    return issues
end

"""
    analyze_invalidations_snoopcompile(workload_fn::Function, filter_system::Bool, top_n::Int) -> Vector{CompilationIssue}

Analyze method invalidations using SnoopCompile's @snoop_invalidations.
"""
function analyze_invalidations_snoopcompile(workload_fn::Function, filter_system::Bool, top_n::Int)
    issues = CompilationIssue[]

    try
        # Run @snoop_invalidations
        invalidations = SnoopCompile.@snoop_invalidations workload_fn()

        # Parse invalidations into trees
        trees = SnoopCompile.invalidation_trees(invalidations)

        # Extract unique invalidated instances
        uinv = SnoopCompile.uinvalidated(invalidations)

        # Sort by frequency (if available)
        # Process top N
        count = 0
        for mi in uinv
            if count >= top_n
                break
            end

            if mi isa Core.MethodInstance
                method = mi.def
                if method isa Method
                    func_name = string(method.name)
                    file = string(method.file)
                    line = method.line

                    # Filter system code
                    if filter_system && is_system_file(file)
                        continue
                    end

                    description = "Method was invalidated - causes recompilation on next use"
                    recommendation = "Check what triggers invalidation (method redefinition, type changes). Consider precompile directives."

                    push!(issues, CompilationIssue(
                        :invalidation,
                        :medium,
                        func_name,
                        file,
                        line,
                        description,
                        0.0,
                        1,
                        String[],
                        recommendation
                    ))

                    count += 1
                end
            end
        end

    catch e
        @warn "Error during SnoopCompile invalidation analysis" exception=(e, catch_backtrace())
    end

    return issues
end

"""
    is_system_file(file::String) -> Bool

Check if file is from Julia system/stdlib.
"""
function is_system_file(file::String)
    return contains(file, "julia/stdlib") ||
           contains(file, "julia/base") ||
           contains(file, "@stdlib") ||
           startswith(file, "Base.") ||
           startswith(file, "Core.") ||
           contains(file, "boot.jl") ||
           contains(file, "sysimg.jl")
end

"""
    generate_inference_recommendation(exc_time::Float64, inc_time::Float64) -> String

Generate recommendation based on inference timing characteristics.
"""
function generate_inference_recommendation(exc_time::Float64, inc_time::Float64)
    ratio = inc_time / max(exc_time, 0.0001)

    if ratio > 10
        # Most time in callees
        return "Inference time dominated by callees. Add type annotations to callees or use function barriers."
    elseif exc_time > 0.1
        # Expensive inference in this function
        return "Expensive type inference. Add type annotations to function signature and local variables."
    else
        return "Consider adding type annotations to improve inference time."
    end
end

"""
    quick_compilation_check(workload_fn::Function) -> String

Quick compilation check with simple pass/fail message.

Returns a user-friendly message about compilation issues.
"""
function quick_compilation_check(workload_fn::Function)
    analysis = analyze_compilation(workload_fn, check_inference=true, check_invalidations=false)

    if isempty(analysis.issues)
        return "✓ No significant compilation issues detected!"
    end

    critical = length(get_critical_compilation_issues(analysis))
    high = length(filter(i -> i.severity == :high, analysis.issues))
    total_time = analysis.total_inference_time

    if critical > 0
        return "✗ Found $critical critical compilation issues ($(round(total_time, digits=2))s inference time) - needs attention!"
    elseif high > 0
        return "⚠ Found $high high-priority issues ($(round(total_time, digits=2))s inference time) - consider addressing"
    elseif total_time > 1.0
        return "⚠ High inference time ($(round(total_time, digits=2))s) - review type stability"
    else
        return "✓ Minor compilation issues ($(round(total_time, digits=2))s inference time)"
    end
end
