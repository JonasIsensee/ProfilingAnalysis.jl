#!/usr/bin/env julia
"""
Concise Workflow Example

This example demonstrates the LLM-friendly concise output features of ProfilingAnalysis.jl
"""

push!(LOAD_PATH, joinpath(@__DIR__, "..", "src"))
using ProfilingAnalysis

# Include demo workload
include(joinpath(@__DIR__, "..", "test", "demo_workload.jl"))

println("=" ^ 80)
println("ProfilingAnalysis.jl - Concise Workflow Example")
println("=" ^ 80)
println()

# ============================================================================
# Example 1: Simplest workflow - One function call
# ============================================================================

println("Example 1: All-in-one concise analysis")
println("-" ^ 80)
println()

profile = collect_profile_data() do
    run_demo_workload(duration_seconds=2.0)
end

# This single call gives you everything you need!
analyze_profile_concise(profile)

println()
println()

# ============================================================================
# Example 2: Ultra-concise - Just the essentials
# ============================================================================

println("Example 2: Ultra-concise (one-liners)")
println("-" ^ 80)
println()

# One-line summary
println("📝 TL;DR:")
println(tldr_summary(profile, filter_fn=e -> !is_system_code(e)))
println()

# One-line category breakdown
println("🏷️  Categories:")
user_entries = filter_user_code(profile.entries)
println(quick_categorize(user_entries, profile.total_samples))
println()

# Compact top 5
println("🔥 Top 5:")
compact_hotspots(user_entries, max_display=5)
println()

println()
println()

# ============================================================================
# Example 3: Progressive detail - Start small, drill down
# ============================================================================

println("Example 3: Progressive drilling")
println("-" ^ 80)
println()

# Start with quick summary
println("Step 1: Quick summary")
quick_summary(profile, top_n=3, filter_fn=e -> !is_system_code(e))
println()

# Drill into specific file
println("Step 2: Focus on a specific file")
workload_entries = query_by_file(profile, "demo_workload.jl")
if !isempty(workload_entries)
    println("Hotspots in demo_workload.jl:")
    compact_hotspots(workload_entries, max_display=5)
end
println()

# Get detailed table for specific function
println("Step 3: Detailed view of matrix operations")
matrix_entries = query_by_pattern(profile, "matrix")
if !isempty(matrix_entries)
    print_entry_table(matrix_entries)
end
println()

println()
println()

# ============================================================================
# Example 4: Custom filtering
# ============================================================================

println("Example 4: Custom filtering")
println("-" ^ 80)
println()

# Major hotspots only (>5%)
major = filter_by_threshold(user_entries, 5.0)
println("Hotspots above 5%:")
compact_hotspots(major)
println()

# Custom filter - complex conditions
critical = query_by_filter(profile, e ->
    e.percentage > 2.0 &&
    !is_system_code(e) &&
    contains(e.file, ".jl")
)
println("Critical user code hotspots (>2%):")
compact_hotspots(critical)
println()

println()
println()

# ============================================================================
# Example 5: Custom categories
# ============================================================================

println("Example 5: Custom categorization")
println("-" ^ 80)
println()

# Define custom categories for this workload
custom_cats = Dict(
    "matrix_ops" => ["matrix", "gemm", "mul"],
    "linear_solve" => ["solve", "factorization", "lu", "qr"],
    "eigenvalue" => ["eigen", "eig"],
    "vector_ops" => ["vector", "dot", "norm"]
)

categorized = categorize_with_custom(user_entries, custom_cats)
print_compact_categories(categorized, profile.total_samples, min_percentage=2.0)
println()

println()
println()

# ============================================================================
# Example 6: Allocation profiling (concise)
# ============================================================================

println("Example 6: Allocation profiling")
println("-" ^ 80)
println()

println("Collecting allocation profile (10% sampling)...")
allocs = collect_allocation_profile(sample_rate=0.1) do
    matrix_multiply(50, 10)
    solve_linear_system(50, 5)
end

println()
summarize_allocations(allocs, top_n=8)
println()

# Get recommendations
println("Allocation recommendations:")
alloc_recs = analyze_allocation_patterns(allocs.sites)
for rec in alloc_recs
    println(rec)
end
println()

println()
println()

# ============================================================================
# Summary
# ============================================================================

println("=" ^ 80)
println("SUMMARY")
println("=" ^ 80)
println()
println("Key takeaways for LLM agents:")
println()
println("✅ Start with: analyze_profile_concise(profile)")
println("   → Gets you 80% of what you need in one call")
println()
println("✅ For ultra-short: tldr_summary() + quick_categorize()")
println("   → Perfect for token-limited contexts")
println()
println("✅ Use filter_user_code() to hide noise")
println("   → Focus on actionable items")
println()
println("✅ Use compact_hotspots() for lists")
println("   → Space-efficient display")
println()
println("✅ Drill down progressively")
println("   → query_by_file() → query_by_function() → print_entry_table()")
println()
println("📚 See LLM_GUIDE.md for comprehensive documentation")
println("=" ^ 80)
