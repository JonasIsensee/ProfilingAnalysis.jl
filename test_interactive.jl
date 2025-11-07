#!/usr/bin/env julia

# Test script to use ProfilingAnalysis interactively
push!(LOAD_PATH, joinpath(@__DIR__, "src"))

using ProfilingAnalysis

# Load demo workload
include("test/demo_workload.jl")

println("=" ^ 80)
println("Testing ProfilingAnalysis.jl with Demo Workload")
println("=" ^ 80)
println()

# Collect runtime profile
println("🔬 Collecting runtime profile...")
runtime = collect_profile_data() do
    run_demo_workload(duration_seconds = 2.0)
end

println()
println("✅ Profile collected: $(runtime.total_samples) samples")
println()

# Show top hotspots
println("📊 Top 15 hotspots (non-system code):")
println()
top_15 = query_top_n(runtime, 15, filter_fn = e -> !is_system_code(e))
print_entry_table(top_15)
println()

# Auto-categorize
println("🏷️  Automatic categorization:")
println()
categorized = categorize_entries(runtime.entries)
print_categorized_summary(categorized, runtime.total_samples, min_percentage = 2.0)

# Smart recommendations
println("💡 Smart Recommendations:")
println()
recs = generate_smart_recommendations(categorized, runtime.total_samples)
for rec in recs
    println(rec)
end
println()

# Test allocation profiling (lighter sampling)
println("=" ^ 80)
println("Testing Allocation Profiling")
println("=" ^ 80)
println()

println("🔬 Collecting allocation profile (10% sampling)...")
allocs = collect_allocation_profile(sample_rate = 0.1) do
    # Smaller workload for allocation profiling
    matrix_multiply(50, 10)
    solve_linear_system(50, 5)
end

println()
println("✅ Allocation profile collected")
println()

# Show allocation summary
summarize_allocations(allocs, top_n = 15)
println()

# Allocation recommendations
println("💡 Allocation Recommendations:")
println()
alloc_recs = analyze_allocation_patterns(allocs.sites)
for rec in alloc_recs
    println(rec)
end
println()

println("=" ^ 80)
println("Interactive testing complete!")
println("=" ^ 80)
