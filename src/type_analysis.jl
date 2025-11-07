"""
Type analysis structures and utilities for JET.jl integration.

Provides AI agent-friendly interfaces for type stability and type error analysis.
"""

using Dates

"""
    TypeIssue

Represents a single type-related issue found during analysis.

# Fields
- `type::Symbol` - Issue type: `:instability`, `:type_error`, `:dispatch`, `:undefined_method`, `:no_method_error`
- `severity::Symbol` - Severity level: `:critical`, `:high`, `:medium`, `:low`
- `function_name::String` - Function where issue occurs
- `file::String` - Source file path
- `line::Int` - Line number
- `description::String` - Human-readable description
- `inferred_type::String` - Inferred type (for instabilities)
- `expected_type::String` - Expected type (for errors)
- `call_chain::Vector{String}` - Call stack leading to issue
- `recommendation::String` - Suggested fix
"""
struct TypeIssue
    type::Symbol
    severity::Symbol
    function_name::String
    file::String
    line::Int
    description::String
    inferred_type::String
    expected_type::String
    call_chain::Vector{String}
    recommendation::String
end

"""
    TypeAnalysis

Complete type analysis results.

# Fields
- `timestamp::DateTime` - When analysis was performed
- `issues::Vector{TypeIssue}` - All detected issues
- `summary::Dict{Symbol, Int}` - Count by issue type
- `type_stable::Bool` - Whether code is type-stable
- `analyzer::String` - Which analyzer was used ("JET", "InteractiveUtils", etc.)
- `metadata::Dict{String, Any}` - Additional metadata
"""
struct TypeAnalysis
    timestamp::DateTime
    issues::Vector{TypeIssue}
    summary::Dict{Symbol, Int}
    type_stable::Bool
    analyzer::String
    metadata::Dict{String, Any}
end

"""
    Base.isempty(analysis::TypeAnalysis) -> Bool

Check if analysis found any issues.
"""
Base.isempty(analysis::TypeAnalysis) = isempty(analysis.issues)

"""
    Base.length(analysis::TypeAnalysis) -> Int

Get number of issues found.
"""
Base.length(analysis::TypeAnalysis) = length(analysis.issues)

"""
    get_critical_issues(analysis::TypeAnalysis) -> Vector{TypeIssue}

Filter to only critical severity issues.
"""
function get_critical_issues(analysis::TypeAnalysis)
    filter(i -> i.severity == :critical, analysis.issues)
end

"""
    get_high_priority_issues(analysis::TypeAnalysis) -> Vector{TypeIssue}

Filter to critical and high severity issues.
"""
function get_high_priority_issues(analysis::TypeAnalysis)
    filter(i -> i.severity in (:critical, :high), analysis.issues)
end

"""
    group_by_type(analysis::TypeAnalysis) -> Dict{Symbol, Vector{TypeIssue}}

Group issues by type.
"""
function group_by_type(analysis::TypeAnalysis)
    result = Dict{Symbol, Vector{TypeIssue}}()
    for issue in analysis.issues
        if !haskey(result, issue.type)
            result[issue.type] = TypeIssue[]
        end
        push!(result[issue.type], issue)
    end
    return result
end

"""
    group_by_file(analysis::TypeAnalysis) -> Dict{String, Vector{TypeIssue}}

Group issues by file.
"""
function group_by_file(analysis::TypeAnalysis)
    result = Dict{String, Vector{TypeIssue}}()
    for issue in analysis.issues
        if !haskey(result, issue.file)
            result[issue.file] = TypeIssue[]
        end
        push!(result[issue.file], issue)
    end
    return result
end

"""
    severity_rank(severity::Symbol) -> Int

Get numeric rank for severity (lower is more severe).
"""
function severity_rank(severity::Symbol)
    severity == :critical && return 0
    severity == :high && return 1
    severity == :medium && return 2
    return 3
end

"""
    sort_by_severity(issues::Vector{TypeIssue}) -> Vector{TypeIssue}

Sort issues by severity (most severe first).
"""
function sort_by_severity(issues::Vector{TypeIssue})
    sort(issues, by=i -> severity_rank(i.severity))
end

"""
    print_type_issue(io::IO, issue::TypeIssue; verbose=false)

Print a single type issue in human-readable format.
"""
function print_type_issue(io::IO, issue::TypeIssue; verbose=false)
    # Severity indicator
    indicator = issue.severity == :critical ? "🔴" :
                issue.severity == :high ? "🟠" :
                issue.severity == :medium ? "🟡" : "⚪"

    println(io, "$indicator $(uppercase(String(issue.type))): $(issue.function_name)")
    println(io, "   Location: $(issue.file):$(issue.line)")
    println(io, "   Issue: $(issue.description)")

    if !isempty(issue.inferred_type)
        println(io, "   Inferred type: $(issue.inferred_type)")
    end

    if !isempty(issue.expected_type)
        println(io, "   Expected type: $(issue.expected_type)")
    end

    if verbose && !isempty(issue.call_chain)
        println(io, "   Call chain:")
        for (i, call) in enumerate(issue.call_chain)
            println(io, "     $(i). $(call)")
        end
    end

    if !isempty(issue.recommendation)
        println(io, "   💡 Fix: $(issue.recommendation)")
    end

    println(io)
end

"""
    print_type_analysis(io::IO, analysis::TypeAnalysis; verbose=false, max_issues=20)

Print complete type analysis in human-readable format.
"""
function print_type_analysis(io::IO, analysis::TypeAnalysis; verbose=false, max_issues=20)
    println(io, "\n═══ TYPE ANALYSIS REPORT ═══")
    println(io, "Analyzer: $(analysis.analyzer)")
    println(io, "Timestamp: $(analysis.timestamp)")
    println(io, "Type Stable: $(analysis.type_stable ? "✓ Yes" : "✗ No")")
    println(io, "\nIssues Found: $(length(analysis.issues))")

    if !isempty(analysis.summary)
        println(io, "\nBreakdown by Type:")
        for (type, count) in sort(collect(analysis.summary), by=x -> x[2], rev=true)
            println(io, "  $(type): $count")
        end
    end

    if isempty(analysis.issues)
        println(io, "\n✓ No type issues detected!")
        return
    end

    println(io, "\n─── Issues (showing top $max_issues) ───\n")

    sorted_issues = sort_by_severity(analysis.issues)
    display_count = min(max_issues, length(sorted_issues))

    for i in 1:display_count
        print_type_issue(io, sorted_issues[i], verbose=verbose)
    end

    if length(sorted_issues) > max_issues
        remaining = length(sorted_issues) - max_issues
        println(io, "... and $remaining more issues (use max_issues parameter to see more)")
    end

    println(io, "\n═══════════════════════════")
end

# Convenience methods for printing to stdout
print_type_issue(issue::TypeIssue; verbose=false) = print_type_issue(stdout, issue, verbose=verbose)
print_type_analysis(analysis::TypeAnalysis; verbose=false, max_issues=20) =
    print_type_analysis(stdout, analysis, verbose=verbose, max_issues=max_issues)
