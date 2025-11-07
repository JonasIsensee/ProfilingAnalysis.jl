"""
JET.jl integration for ProfilingAnalysis.

Provides AI agent-friendly interfaces to JET.jl's static type analysis capabilities.

**Note:** JET.jl is an optional dependency. The functions in this module will only
work if JET.jl is installed. Use `check_jet_available()` to verify availability.

# Version Compatibility
- Julia 1.12: Requires JET v0.11
- Julia 1.11: Requires JET v0.9
- Julia 1.10: May not be fully supported

Call `check_jet_version()` to verify compatibility.
"""

const JET_AVAILABLE = Ref(false)
const JET_VERSION_OK = Ref(false)

"""
    check_jet_available() -> Bool

Check if JET.jl is available in the current environment.
"""
function check_jet_available()
    if !JET_AVAILABLE[]
        try
            # Try to load JET
            @eval Main begin
                if !isdefined(Main, :JET)
                    using JET
                end
            end
            JET_AVAILABLE[] = true
        catch
            JET_AVAILABLE[] = false
        end
    end
    return JET_AVAILABLE[]
end

"""
    check_jet_version() -> (Bool, String)

Check if JET.jl version is compatible with current Julia version.

Returns `(is_compatible, message)`.
"""
function check_jet_version()
    if !check_jet_available()
        return (false, "JET.jl is not installed. Install with: Pkg.add(\"JET\")")
    end

    julia_version = VERSION

    # Get JET version if available
    try
        jet_module = Main.JET
        # JET version checking - this is approximate since we can't easily get package version
        # In practice, users should ensure they have the right version

        if julia_version >= v"1.12"
            msg = "Julia 1.12+ detected. Ensure JET v0.11+ is installed."
            return (true, msg)
        elseif julia_version >= v"1.11"
            msg = "Julia 1.11 detected. Ensure JET v0.9.x is installed."
            return (true, msg)
        else
            msg = "Julia $(VERSION). JET may not be fully supported. Recommended: Julia 1.11+"
            return (false, msg)
        end
    catch e
        return (false, "Error checking JET version: $e")
    end
end

"""
    require_jet()

Throw an error with helpful message if JET is not available.
"""
function require_jet()
    if !check_jet_available()
        error("""
        JET.jl is not available. To use type analysis features, install JET:

        Julia 1.12+:
            using Pkg
            Pkg.add("JET")

        Julia 1.11:
            using Pkg
            Pkg.add(name="JET", version="0.9")

        Then restart your Julia session.
        """)
    end

    is_ok, msg = check_jet_version()
    if !is_ok
        @warn msg
    end
end

"""
    analyze_types_with_jet(func::Function, args::Tuple; filter_system=true) -> TypeAnalysis

Analyze type stability and potential type errors using JET.jl.

Automatically runs both `@report_opt` (type stability) and `@report_call` (type errors).

# Arguments
- `func`: Function to analyze
- `args`: Tuple of argument types or values
- `filter_system`: If true, filter out issues in system/stdlib code

# Returns
`TypeAnalysis` with structured results

# Example
```julia
function my_function(x::Int, y::Float64)
    z = x + y  # Type unstable - returns Union{Int, Float64}
    return z * 2
end

analysis = analyze_types_with_jet(my_function, (1, 2.0))
print_type_analysis(analysis)
```
"""
function analyze_types_with_jet(func::Function, args::Tuple; filter_system=true)
    require_jet()

    issues = TypeIssue[]
    metadata = Dict{String, Any}(
        "function" => string(func),
        "args" => string(typeof(args))
    )

    # Run type stability check (@report_opt)
    stability_issues = analyze_stability_jet(func, args, filter_system)
    append!(issues, stability_issues)

    # Run type error check (@report_call)
    error_issues = analyze_type_errors_jet(func, args, filter_system)
    append!(issues, error_issues)

    # Build summary
    summary = Dict{Symbol, Int}()
    for issue in issues
        summary[issue.type] = get(summary, issue.type, 0) + 1
    end

    # Determine if type stable (no instability or dispatch issues)
    type_stable = !any(i -> i.type in (:instability, :dispatch), issues)

    return TypeAnalysis(
        now(),
        issues,
        summary,
        type_stable,
        "JET.jl",
        metadata
    )
end

"""
    analyze_stability_jet(func::Function, args::Tuple, filter_system::Bool) -> Vector{TypeIssue}

Run JET's @report_opt to detect type instabilities.
"""
function analyze_stability_jet(func::Function, args::Tuple, filter_system::Bool)
    issues = TypeIssue[]

    try
        # Capture output from JET
        io = IOBuffer()

        # Run @report_opt
        result = @eval Main begin
            JET.@report_opt $(func)($(args)...)
        end

        # Parse result
        # JET returns a JET.JETCallResult object with reports
        if isdefined(Main.JET, :get_reports)
            reports = Main.JET.get_reports(result)

            for report in reports
                issue = parse_jet_report(report, :instability, filter_system)
                if !isnothing(issue)
                    push!(issues, issue)
                end
            end
        else
            # Fallback: try to extract information from result directly
            # This is version-dependent, so we're being defensive
            @warn "Could not extract structured reports from JET. Analysis may be incomplete."
        end

    catch e
        @warn "Error during JET type stability analysis" exception=(e, catch_backtrace())
        # Create a generic issue
        push!(issues, TypeIssue(
            :error,
            :high,
            string(func),
            "",
            0,
            "Error during type stability analysis: $(string(e))",
            "",
            "",
            String[],
            "Review the function manually or check JET installation"
        ))
    end

    return issues
end

"""
    analyze_type_errors_jet(func::Function, args::Tuple, filter_system::Bool) -> Vector{TypeIssue}

Run JET's @report_call to detect potential type errors.
"""
function analyze_type_errors_jet(func::Function, args::Tuple, filter_system::Bool)
    issues = TypeIssue[]

    try
        # Run @report_call
        result = @eval Main begin
            JET.@report_call $(func)($(args)...)
        end

        # Parse result
        if isdefined(Main.JET, :get_reports)
            reports = Main.JET.get_reports(result)

            for report in reports
                issue = parse_jet_report(report, :type_error, filter_system)
                if !isnothing(issue)
                    push!(issues, issue)
                end
            end
        end

    catch e
        @warn "Error during JET type error analysis" exception=(e, catch_backtrace())
    end

    return issues
end

"""
    parse_jet_report(report, default_type::Symbol, filter_system::Bool) -> Union{TypeIssue, Nothing}

Parse a JET report object into a TypeIssue.

Returns `nothing` if the report should be filtered out.
"""
function parse_jet_report(report, default_type::Symbol, filter_system::Bool)
    try
        # Extract information from report
        # JET report structure varies by version, so we're being defensive

        # Get file and line
        file = ""
        line = 0
        func_name = ""

        if hasfield(typeof(report), :sig)
            sig = report.sig
            func_name = string(sig)
        end

        if hasfield(typeof(report), :file)
            file = string(report.file)
        end

        if hasfield(typeof(report), :line)
            line = report.line
        end

        # Filter system code if requested
        if filter_system && !isempty(file)
            if contains(file, "julia/stdlib") ||
               contains(file, "julia/base") ||
               contains(file, "@stdlib") ||
               startswith(file, "Base.") ||
               startswith(file, "Core.")
                return nothing
            end
        end

        # Determine issue type and severity
        issue_type = default_type
        severity = :medium

        # Get description
        description = string(report)

        # Check for specific patterns to categorize better
        if contains(description, "runtime dispatch")
            issue_type = :dispatch
            severity = :high
        elseif contains(description, "no matching method")
            issue_type = :no_method_error
            severity = :critical
        elseif contains(description, "undefined")
            issue_type = :undefined_method
            severity = :critical
        elseif contains(description, "Union")
            issue_type = :instability
            severity = :high
        end

        # Extract inferred type if available
        inferred_type = ""
        if hasfield(typeof(report), :rt)
            inferred_type = string(report.rt)
        end

        # Generate recommendation
        recommendation = generate_recommendation_for_issue(issue_type, description, inferred_type)

        return TypeIssue(
            issue_type,
            severity,
            func_name,
            file,
            line,
            description,
            inferred_type,
            "",
            String[],  # Call chain - would need more parsing
            recommendation
        )

    catch e
        @warn "Error parsing JET report" exception=(e, catch_backtrace())
        return nothing
    end
end

"""
    generate_recommendation_for_issue(issue_type::Symbol, description::String, inferred_type::String) -> String

Generate actionable recommendation for a type issue.
"""
function generate_recommendation_for_issue(issue_type::Symbol, description::String, inferred_type::String)
    if issue_type == :instability
        if contains(inferred_type, "Union")
            if contains(inferred_type, "Nothing")
                return "Add type assertion or use @something macro to handle Nothing case"
            else
                return "Add type annotation to ensure consistent return type, or use type assertion"
            end
        elseif contains(inferred_type, "Any")
            return "Add type annotations to function signature and return values"
        else
            return "Ensure function returns consistent type across all code paths"
        end

    elseif issue_type == :dispatch
        return "Add type annotations to eliminate runtime dispatch, or use function barrier"

    elseif issue_type == :no_method_error
        return "Ensure method exists for these argument types, or add appropriate methods"

    elseif issue_type == :undefined_method
        return "Check for typos or ensure required packages are loaded"

    else
        return "Review code for type-related issues"
    end
end

"""
    is_type_stable_jet(func::Function, args::Tuple) -> Bool

Quick check if function is type-stable using JET.

Returns `true` if no type instabilities detected, `false` otherwise.

# Example
```julia
if !is_type_stable_jet(my_function, (1, 2.0))
    println("Warning: Type instability detected!")
end
```
"""
function is_type_stable_jet(func::Function, args::Tuple)
    if !check_jet_available()
        @warn "JET not available, falling back to basic type stability check"
        return check_type_stability_simple(func, args)
    end

    analysis = analyze_types_with_jet(func, args, filter_system=true)
    return analysis.type_stable
end

"""
    quick_type_check(func::Function, args::Tuple) -> String

Quick type check with simple pass/fail message.

Returns a user-friendly message about type stability.
"""
function quick_type_check(func::Function, args::Tuple)
    if !check_jet_available()
        return "JET not available. Install with: Pkg.add(\"JET\")"
    end

    analysis = analyze_types_with_jet(func, args)

    if isempty(analysis.issues)
        return "✓ No type issues detected - code looks good!"
    end

    critical = length(get_critical_issues(analysis))
    high = length(filter(i -> i.severity == :high, analysis.issues))

    if critical > 0
        return "✗ Found $critical critical issues - needs immediate attention!"
    elseif high > 0
        return "⚠ Found $high high-priority issues - should be addressed"
    else
        return "⚠ Found minor type issues - consider addressing for better performance"
    end
end
