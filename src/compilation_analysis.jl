"""
Compilation analysis structures for SnoopCompile.jl integration.

Provides AI agent-friendly interfaces for analyzing Julia compilation issues.
"""

using Dates

"""
    CompilationIssue

Represents a single compilation-related issue.

# Fields
- `type::Symbol` - Issue type: `:invalidation`, `:inference_trigger`, `:slow_inference`, `:stale_instance`
- `severity::Symbol` - Severity level: `:critical`, `:high`, `:medium`, `:low`
- `function_name::String` - Function where issue occurs
- `file::String` - Source file path
- `line::Int` - Line number
- `description::String` - Human-readable description
- `time_impact::Float64` - Time impact in seconds (or percentage for triggers)
- `count::Int` - Count of occurrences (for invalidations)
- `trigger_chain::Vector{String}` - Call chain for inference triggers
- `recommendation::String` - Suggested fix
"""
struct CompilationIssue
    type::Symbol
    severity::Symbol
    function_name::String
    file::String
    line::Int
    description::String
    time_impact::Float64
    count::Int
    trigger_chain::Vector{String}
    recommendation::String
end

"""
    CompilationAnalysis

Complete compilation analysis results.

# Fields
- `timestamp::DateTime` - When analysis was performed
- `total_inference_time::Float64` - Total type inference time in seconds
- `issues::Vector{CompilationIssue}` - All detected issues
- `summary::Dict{Symbol, Int}` - Count by issue type
- `analyzer::String` - Which analyzer was used
- `metadata::Dict{String, Any}` - Additional metadata
"""
struct CompilationAnalysis
    timestamp::DateTime
    total_inference_time::Float64
    issues::Vector{CompilationIssue}
    summary::Dict{Symbol, Int}
    analyzer::String
    metadata::Dict{String, Any}
end

"""
    Base.isempty(analysis::CompilationAnalysis) -> Bool

Check if analysis found any issues.
"""
Base.isempty(analysis::CompilationAnalysis) = isempty(analysis.issues)

"""
    Base.length(analysis::CompilationAnalysis) -> Int

Get number of issues found.
"""
Base.length(analysis::CompilationAnalysis) = length(analysis.issues)

"""
    get_critical_compilation_issues(analysis::CompilationAnalysis) -> Vector{CompilationIssue}

Filter to only critical severity issues.
"""
function get_critical_compilation_issues(analysis::CompilationAnalysis)
    filter(i -> i.severity == :critical, analysis.issues)
end

"""
    get_high_priority_compilation_issues(analysis::CompilationAnalysis) -> Vector{CompilationIssue}

Filter to critical and high severity issues.
"""
function get_high_priority_compilation_issues(analysis::CompilationAnalysis)
    filter(i -> i.severity in (:critical, :high), analysis.issues)
end

"""
    group_compilation_by_type(analysis::CompilationAnalysis) -> Dict{Symbol, Vector{CompilationIssue}}

Group issues by type.
"""
function group_compilation_by_type(analysis::CompilationAnalysis)
    result = Dict{Symbol, Vector{CompilationIssue}}()
    for issue in analysis.issues
        if !haskey(result, issue.type)
            result[issue.type] = CompilationIssue[]
        end
        push!(result[issue.type], issue)
    end
    return result
end

"""
    sort_compilation_by_impact(issues::Vector{CompilationIssue}) -> Vector{CompilationIssue}

Sort issues by time impact (highest first).
"""
function sort_compilation_by_impact(issues::Vector{CompilationIssue})
    sort(issues, by=i -> -i.time_impact)
end

"""
    print_compilation_issue(io::IO, issue::CompilationIssue; verbose=false)

Print a single compilation issue in human-readable format.
"""
function print_compilation_issue(io::IO, issue::CompilationIssue; verbose=false)
    # Severity indicator
    indicator = issue.severity == :critical ? "🔴" :
                issue.severity == :high ? "🟠" :
                issue.severity == :medium ? "🟡" : "⚪"

    println(io, "$indicator $(uppercase(String(issue.type))): $(issue.function_name)")
    println(io, "   Location: $(issue.file):$(issue.line)")
    println(io, "   Impact: $(round(issue.time_impact, digits=3))s")

    if issue.count > 0
        println(io, "   Count: $(issue.count)")
    end

    println(io, "   Issue: $(issue.description)")

    if verbose && !isempty(issue.trigger_chain)
        println(io, "   Trigger chain:")
        for (i, call) in enumerate(issue.trigger_chain)
            println(io, "     $(i). $(call)")
        end
    end

    if !isempty(issue.recommendation)
        println(io, "   💡 Fix: $(issue.recommendation)")
    end

    println(io)
end

"""
    print_compilation_analysis(io::IO, analysis::CompilationAnalysis; verbose=false, max_issues=20)

Print complete compilation analysis in human-readable format.
"""
function print_compilation_analysis(io::IO, analysis::CompilationAnalysis; verbose=false, max_issues=20)
    println(io, "\n═══ COMPILATION ANALYSIS REPORT ═══")
    println(io, "Analyzer: $(analysis.analyzer)")
    println(io, "Timestamp: $(analysis.timestamp)")
    println(io, "Total Inference Time: $(round(analysis.total_inference_time, digits=3))s")
    println(io, "\nIssues Found: $(length(analysis.issues))")

    if !isempty(analysis.summary)
        println(io, "\nBreakdown by Type:")
        for (type, count) in sort(collect(analysis.summary), by=x -> x[2], rev=true)
            println(io, "  $(type): $count")
        end
    end

    if isempty(analysis.issues)
        println(io, "\n✓ No compilation issues detected!")
        return
    end

    println(io, "\n─── Issues (showing top $max_issues by impact) ───\n")

    sorted_issues = sort_compilation_by_impact(analysis.issues)
    display_count = min(max_issues, length(sorted_issues))

    for i in 1:display_count
        print_compilation_issue(io, sorted_issues[i], verbose=verbose)
    end

    if length(sorted_issues) > max_issues
        remaining = length(sorted_issues) - max_issues
        println(io, "... and $remaining more issues (use max_issues parameter to see more)")
    end

    println(io, "\n═══════════════════════════════════")
end

# Convenience methods for printing to stdout
print_compilation_issue(issue::CompilationIssue; verbose=false) =
    print_compilation_issue(stdout, issue, verbose=verbose)
print_compilation_analysis(analysis::CompilationAnalysis; verbose=false, max_issues=20) =
    print_compilation_analysis(stdout, analysis, verbose=verbose, max_issues=max_issues)
