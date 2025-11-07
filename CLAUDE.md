# ProfilingAnalysis.jl - Guide for LLM Agents

This document provides comprehensive guidance for LLM agents (like Claude, GPT-4, etc.) to effectively use ProfilingAnalysis.jl for code optimization tasks.

## Package Overview

ProfilingAnalysis.jl is a Julia package designed to make code profiling and performance optimization accessible to both humans and automated agents. It provides structured APIs for:

- Runtime CPU profiling with automatic hotspot detection
- Memory allocation profiling
- Automatic categorization of performance bottlenecks
- Context-aware optimization recommendations
- Profile comparison for tracking improvements
- Type stability analysis

## Quick Start for Agents

### Basic Profiling Workflow

```julia
using ProfilingAnalysis

# 1. Collect runtime profile
profile = collect_profile_data() do
    # User's code to profile
    my_function(args...)
end

# 2. Query top hotspots (filter out system code)
hotspots = query_top_n(profile, 20, filter_fn=e -> !is_system_code(e))

# 3. Categorize by operation type
categorized = categorize_entries(profile.entries)

# 4. Generate recommendations
recommendations = generate_smart_recommendations(categorized, profile.total_samples)

# 5. Display results
print_categorized_summary(categorized, profile.total_samples)
for rec in recommendations
    println(rec)
end
```

### Allocation Profiling Workflow

```julia
# Profile memory allocations (10% sampling rate for speed)
allocs = collect_allocation_profile(sample_rate=0.1) do
    my_function(args...)
end

# Show allocation hotspots
summarize_allocations(allocs, top_n=20)

# Get allocation-specific recommendations
alloc_recommendations = analyze_allocation_patterns(allocs.sites)
```

## Complete API Reference

### Data Structures

#### ProfileEntry
Represents a single profiled location in code.
- `func::String` - Function name
- `file::String` - Source file path
- `line::Int` - Line number
- `samples::Int` - Number of profile samples
- `percentage::Float64` - Percentage of total runtime

#### ProfileData
Complete profile dataset.
- `timestamp::DateTime` - When profile was collected
- `total_samples::Int` - Total number of samples
- `entries::Vector{ProfileEntry}` - All profiled locations
- `metadata::Dict{String,Any}` - User-defined metadata

#### AllocationSite
Single memory allocation location.
- `func::String` - Function name
- `file::String` - Source file
- `line::Int` - Line number
- `count::Int` - Number of allocations
- `total_bytes::Int` - Total bytes allocated
- `avg_bytes::Float64` - Average bytes per allocation

#### AllocationProfile
Complete allocation profiling results.
- `timestamp::DateTime`
- `total_allocations::Int`
- `total_bytes::Int`
- `sites::Vector{AllocationSite}`
- `metadata::Dict{String,Any}`

### Collection Functions

#### `collect_profile_data(workload_fn::Function; metadata=Dict{String,Any}())`
Collect runtime CPU profile.

**Parameters:**
- `workload_fn`: Function to profile (called twice: warmup + profiling)
- `metadata`: Optional metadata to store with profile

**Returns:** `ProfileData`

**Example:**
```julia
profile = collect_profile_data(metadata=Dict("version" => "1.0")) do
    compute_expensive_operation()
end
```

#### `collect_allocation_profile(workload_fn::Function; warmup=true, sample_rate=0.1, metadata=Dict{String,Any}())`
Collect memory allocation profile.

**Parameters:**
- `workload_fn`: Function to profile
- `warmup`: Run warmup pass (default: true)
- `sample_rate`: Fraction of allocations to sample (0.1 = 10%, 1.0 = all)
- `metadata`: Optional metadata

**Returns:** `AllocationProfile`

**Note:** Use lower sample_rate (0.01-0.1) for fast profiling, 1.0 for complete data.

#### `save_profile(profile::ProfileData, filename::String)`
Save profile to JSON file.

#### `load_profile(filename::String) -> ProfileData`
Load profile from JSON file.

### Query Functions

#### `query_top_n(profile::ProfileData, n::Int; filter_fn=nothing) -> Vector{ProfileEntry}`
Get top N hotspots, optionally filtered.

**Common filters:**
```julia
# Exclude system code
query_top_n(profile, 20, filter_fn=e -> !is_system_code(e))

# Only high-sample entries
query_top_n(profile, 20, filter_fn=e -> e.samples > 100)

# Only specific file
query_top_n(profile, 20, filter_fn=e -> contains(e.file, "mycode"))
```

#### `query_by_file(profile::ProfileData, file_pattern::String) -> Vector{ProfileEntry}`
Find all entries matching file pattern.

#### `query_by_function(profile::ProfileData, func_pattern::String) -> Vector{ProfileEntry}`
Find all entries matching function name pattern.

#### `query_by_pattern(profile::ProfileData, pattern::String) -> Vector{ProfileEntry}`
Find entries where function OR file matches pattern.

#### `query_by_filter(profile::ProfileData, filter_fn::Function) -> Vector{ProfileEntry}`
Find entries matching custom filter function.

#### `is_system_code(entry::ProfileEntry) -> Bool`
Check if entry is from system/Julia base code. Useful for filtering to show only user code.

### Analysis Functions

#### `categorize_entries(entries::Vector{ProfileEntry}; categories=default_categories()) -> Dict{String, Vector{ProfileEntry}}`
Automatically categorize hotspots by operation type.

**Default categories:**
- `distance_calculation` - Distance metrics, norms, euclidean computations
- `heap_operations` - Priority queues, sorted structures
- `tree_construction` - Building spatial data structures
- `search_operations` - k-NN, range search, queries
- `point_access` - Data structure overhead
- `other` - Uncategorized

**Returns:** Dict mapping category names to matching entries.

#### `generate_smart_recommendations(categorized::Dict{String, Vector{ProfileEntry}}, total_samples::Int) -> Vector{String}`
Generate context-aware optimization recommendations based on categorized hotspots.

Returns actionable recommendations like:
- "Add @inbounds to array accesses"
- "Use @simd for vectorization"
- "Consider StaticArrays for small fixed arrays"

#### `analyze_allocation_patterns(sites::Vector{AllocationSite}) -> Vector{String}`
Analyze allocation patterns and generate recommendations.

Detects:
- Many small allocations (pooling opportunity)
- Large allocations (memory optimization opportunity)
- Package-specific allocation hotspots

### Display Functions

#### `print_entry_table(entries::Vector{ProfileEntry}; max_width=120)`
Print entries in formatted table.

#### `summarize_profile(profile::ProfileData; filter_fn=nothing, top_n=20, title="Profile Summary")`
Generate comprehensive profile summary.

#### `print_categorized_summary(categorized::Dict{String, Vector{ProfileEntry}}, total_samples::Int; min_percentage=5.0)`
Print categorized hotspot summary.

#### `summarize_allocations(profile::AllocationProfile; filter_fn=nothing, top_n=20, title="Allocation Summary")`
Generate allocation profile summary.

#### `print_allocation_table(sites::Vector{AllocationSite}; max_width=120)`
Print allocation sites in formatted table.

### Comparison Functions

#### `compare_profiles(profile1::ProfileData, profile2::ProfileData; top_n=20)`
Compare two profiles to identify performance changes.

**Use case:**
```julia
baseline = collect_profile_data(() -> my_function())
save_profile(baseline, "baseline.json")

# Make optimizations...

optimized = collect_profile_data(() -> my_function())
compare_profiles(baseline, optimized)
```

### Type Stability Functions

#### `check_type_stability_simple(f::Function, types::Tuple) -> Bool`
Quick check if function is type-stable.

**Example:**
```julia
if !check_type_stability_simple(my_function, (Int, Float64))
    println("Warning: my_function is not type-stable!")
end
```

#### `print_type_stability_guide()`
Print comprehensive guide for checking and fixing type stability issues.

### Utility Functions

#### `format_bytes(bytes::Int) -> String`
Format byte count in human-readable form (KB, MB, GB).

## Agent Workflow Examples

### Example 1: Diagnose Performance Problem

```julia
using ProfilingAnalysis

# Profile the code
profile = collect_profile_data() do
    user_code()
end

# Get user code only (filter system code)
user_entries = query_by_filter(profile, e -> !is_system_code(e))

# Categorize bottlenecks
categorized = categorize_entries(user_entries)

# Generate recommendations
recs = generate_smart_recommendations(categorized, profile.total_samples)

# Display analysis
println("\n=== PERFORMANCE ANALYSIS ===\n")
print_categorized_summary(categorized, profile.total_samples)

println("\n=== RECOMMENDATIONS ===\n")
for rec in recs
    println(rec)
end
```

### Example 2: Track Optimization Progress

```julia
# Before optimization
baseline = collect_profile_data(() -> my_algorithm(data))
save_profile(baseline, "baseline.json")

# After optimization
optimized = collect_profile_data(() -> my_algorithm(data))
save_profile(optimized, "optimized.json")

# Compare
compare_profiles(baseline, optimized, top_n=15)
```

### Example 3: Focus on Specific Code

```julia
profile = collect_profile_data(() -> run_workload())

# Query specific package code
my_code = query_by_file(profile, "MyPackage")

# Find specific function bottlenecks
matrix_ops = query_by_function(profile, "matrix_multiply")

# Show top hotspots in my code only
print_entry_table(my_code[1:min(10, length(my_code))])
```

### Example 4: Memory Allocation Analysis

```julia
# Profile allocations (1% sampling for speed)
allocs = collect_allocation_profile(sample_rate=0.01) do
    my_algorithm(large_data)
end

# Focus on user code allocations
user_allocs = filter(allocs.sites) do site
    !contains(site.file, "julia/") && !contains(site.file, "stdlib/")
end

# Show top allocation sites
print_allocation_table(user_allocs[1:min(20, length(user_allocs))])

# Get recommendations
recs = analyze_allocation_patterns(user_allocs)
for rec in recs
    println(rec)
end
```

### Example 5: Type Stability Check

```julia
# Check if key functions are type-stable
functions_to_check = [
    (my_distance, (Vector{Float64}, Vector{Float64})),
    (my_search, (MyTree, Vector{Float64}, Int)),
]

println("Type Stability Analysis:")
for (func, types) in functions_to_check
    is_stable = check_type_stability_simple(func, types)
    status = is_stable ? "✓" : "✗"
    println("  $status $(func) with $types")
end

# Show guide for fixing issues
print_type_stability_guide()
```

## Best Practices for Agents

### 1. Always Filter System Code
System code creates noise. Use `is_system_code()` to focus on user code:
```julia
user_hotspots = query_by_filter(profile, e -> !is_system_code(e))
```

### 2. Use Categorization for Context
Automatic categorization provides context for better recommendations:
```julia
categorized = categorize_entries(profile.entries)
recs = generate_smart_recommendations(categorized, profile.total_samples)
```

### 3. Sample Allocations for Speed
Full allocation profiling can be slow. Use sampling:
```julia
# Fast: 1-10% sampling
allocs = collect_allocation_profile(sample_rate=0.01) do
    workload()
end
```

### 4. Save Profiles for Comparison
Always save before/after profiles to track improvements:
```julia
save_profile(baseline, "before.json")
# ... make changes ...
save_profile(optimized, "after.json")
compare_profiles(baseline, optimized)
```

### 5. Check Type Stability Early
Type instabilities can cause 10-100x slowdowns:
```julia
is_stable = check_type_stability_simple(critical_function, (ArgType1, ArgType2))
if !is_stable
    println("Warning: Type instability detected!")
end
```

### 6. Use Metadata for Tracking
Add metadata to profiles for better organization:
```julia
profile = collect_profile_data(
    metadata=Dict(
        "version" => "1.0",
        "optimization" => "baseline",
        "commit" => "abc123"
    )
) do
    workload()
end
```

## Common Optimization Patterns

Based on categorization results, apply these optimizations:

### Distance Calculations Hotspot
- Add `@inbounds` to array accesses (after verifying bounds)
- Use `@simd` for vectorization
- Implement early termination in partial distance calculation
- Ensure `@inline` on small distance functions

### Heap Operations Hotspot
- Consider `StaticArrays` for small fixed k values
- Reduce allocations in priority queue operations
- Profile insert/remove operations specifically

### Search Operations Hotspot
- Optimize priority queue operations
- Use `@inbounds` for index access
- Minimize allocations in search loop
- Cache frequently accessed data

### Tree Construction Hotspot
- Pre-allocate temporary arrays
- Optimize partition algorithms
- Improve memory access patterns for cache efficiency

### Allocation Issues
- Many small allocations → Use object pooling or pre-allocation
- Large allocations → Consider in-place operations
- Loop allocations → Move allocations outside loops

### Type Instability
- Add type annotations to function arguments
- Use type assertions for return values
- Avoid changing variable types
- Use typed containers (e.g., `Float64[]` instead of `[]`)

## CLI Usage (Optional)

The package also provides a CLI for batch processing:

```bash
# Generate profile summary
julia -m ProfilingAnalysis summary --input profile.json --top 20

# Query specific functions
julia -m ProfilingAnalysis query --input profile.json --function matrix_multiply

# Compare profiles
julia -m ProfilingAnalysis compare baseline.json optimized.json
```

Note: Requires Julia 1.11+ for `-m` flag. For Julia 1.10, use:
```julia
using ProfilingAnalysis
run_cli(["summary", "--input", "profile.json"])
```

## Advanced Analysis (Optional Dependencies)

ProfilingAnalysis.jl integrates with two powerful Julia tools for deeper analysis:
- **JET.jl** - Static type analysis and error detection
- **SnoopCompile.jl** - Compilation latency and inference analysis

These are **optional dependencies** - ProfilingAnalysis works without them, but they provide additional capabilities for AI agents.

### Installation

```julia
# Install JET.jl
using Pkg

# For Julia 1.12+
Pkg.add("JET")

# For Julia 1.11
Pkg.add(name="JET", version="0.9")

# Install SnoopCompile.jl (any Julia version)
Pkg.add("SnoopCompile")
```

### JET.jl Integration - Type Analysis

JET.jl provides advanced static type analysis to detect type instabilities and potential runtime errors.

#### Key Functions

**`check_jet_available() -> Bool`**
Check if JET.jl is installed and available.

**`check_jet_version() -> (Bool, String)`**
Verify JET.jl version compatibility with current Julia version.

**`analyze_types_with_jet(func::Function, args::Tuple; filter_system=true) -> TypeAnalysis`**
Comprehensive type analysis using JET.jl. Runs both type stability and type error checks.

**`is_type_stable_jet(func::Function, args::Tuple) -> Bool`**
Quick check if function is type-stable using JET.jl.

**`quick_type_check(func::Function, args::Tuple) -> String`**
Returns user-friendly message about type issues.

#### TypeAnalysis Structure

```julia
TypeAnalysis
├── timestamp::DateTime
├── issues::Vector{TypeIssue}
├── summary::Dict{Symbol, Int}
├── type_stable::Bool
├── analyzer::String
└── metadata::Dict{String, Any}

TypeIssue
├── type::Symbol  # :instability, :type_error, :dispatch, :no_method_error, :undefined_method
├── severity::Symbol  # :critical, :high, :medium, :low
├── function_name::String
├── file::String
├── line::Int
├── description::String
├── inferred_type::String
├── expected_type::String
├── call_chain::Vector{String}
└── recommendation::String
```

#### Type Analysis Example

```julia
using ProfilingAnalysis

# Check if JET is available
if !check_jet_available()
    println("JET.jl not installed. Install with: Pkg.add(\"JET\")")
    # Fall back to basic type stability check
    is_stable = check_type_stability_simple(my_function, (Int, Float64))
else
    # Use advanced JET analysis
    analysis = analyze_types_with_jet(my_function, (1, 2.0))

    if !analysis.type_stable
        println("Type issues found:")

        # Get high-priority issues
        high_priority = get_high_priority_issues(analysis)

        for issue in high_priority
            println("\n$(issue.severity): $(issue.function_name)")
            println("  Location: $(issue.file):$(issue.line)")
            println("  Issue: $(issue.description)")
            println("  Fix: $(issue.recommendation)")
        end

        # Group by type
        by_type = group_by_type(analysis)
        for (type, issues) in by_type
            println("\n$(type): $(length(issues)) issues")
        end
    else
        println("✓ Code is type-stable!")
    end

    # Or use quick check for simple pass/fail
    msg = quick_type_check(my_function, (1, 2.0))
    println(msg)
end
```

#### Common Type Issues Detected

1. **Type Instability** (`:instability`)
   - Functions returning `Union` types
   - Variables changing type in loops
   - Container type instability
   - Recommendation: Add type annotations

2. **Runtime Dispatch** (`:dispatch`)
   - Dynamic dispatch in hot paths
   - Unclear types in function calls
   - Recommendation: Add type annotations, use function barriers

3. **Type Errors** (`:type_error`, `:no_method_error`)
   - No matching method for types
   - Undefined methods
   - Recommendation: Fix method signatures, check package imports

### SnoopCompile.jl Integration - Compilation Analysis

SnoopCompile.jl analyzes Julia's compilation process to identify inference bottlenecks and invalidations.

#### Key Functions

**`check_snoopcompile_available() -> Bool`**
Check if SnoopCompile.jl is installed.

**`analyze_compilation(workload_fn::Function; check_invalidations=false, check_inference=true, filter_system=true, top_n=20) -> CompilationAnalysis`**
Comprehensive compilation analysis. Analyzes type inference time and optionally method invalidations.

**`quick_compilation_check(workload_fn::Function) -> String`**
Returns user-friendly message about compilation issues.

#### CompilationAnalysis Structure

```julia
CompilationAnalysis
├── timestamp::DateTime
├── total_inference_time::Float64
├── issues::Vector{CompilationIssue}
├── summary::Dict{Symbol, Int}
├── analyzer::String
└── metadata::Dict{String, Any}

CompilationIssue
├── type::Symbol  # :invalidation, :inference_trigger, :slow_inference, :stale_instance
├── severity::Symbol  # :critical, :high, :medium, :low
├── function_name::String
├── file::String
├── line::Int
├── description::String
├── time_impact::Float64  # seconds
├── count::Int
├── trigger_chain::Vector{String}
└── recommendation::String
```

#### Compilation Analysis Example

```julia
using ProfilingAnalysis

# Check if SnoopCompile is available
if !check_snoopcompile_available()
    println("SnoopCompile.jl not installed. Install with: Pkg.add(\"SnoopCompile\")")
else
    # Analyze compilation
    analysis = analyze_compilation(
        check_invalidations=false,  # Set true for load-time issues
        check_inference=true,
        top_n=20
    ) do
        my_algorithm(test_data)
    end

    println("Total inference time: $(round(analysis.total_inference_time, digits=3))s")
    println("Issues found: $(length(analysis.issues))")

    # Get critical issues
    critical = get_critical_compilation_issues(analysis)
    if !isempty(critical)
        println("\nCritical compilation issues:")
        for issue in critical
            print_compilation_issue(issue)
        end
    end

    # Group by type
    by_type = group_compilation_by_type(analysis)
    for (type, issues) in by_type
        total_time = sum(i.time_impact for i in issues)
        println("$(type): $(length(issues)) issues, $(round(total_time, digits=3))s")
    end

    # Or use quick check
    msg = quick_compilation_check(() -> my_algorithm(test_data))
    println(msg)
end
```

#### Common Compilation Issues Detected

1. **Slow Inference** (`:slow_inference`)
   - Type inference taking significant time (>10ms)
   - Complex type calculations
   - Recommendation: Add type annotations to reduce inference work

2. **Inference Triggers** (`:inference_trigger`)
   - Runtime dispatch causing fresh type inference
   - Hot paths triggering compilation
   - Recommendation: Eliminate runtime dispatch, use function barriers

3. **Method Invalidations** (`:invalidation`)
   - Methods invalidated during load (TTFX issues)
   - Method redefinitions causing cache invalidation
   - Recommendation: Check load order, add precompile directives

4. **Stale Instances** (`:stale_instance`)
   - Code invalidated during profiling
   - Indicates active invalidation issues
   - Recommendation: Investigate method redefinitions

### Complete AI Agent Workflow with Advanced Analysis

```julia
using ProfilingAnalysis

function optimize_code(user_function, test_args)
    println("=== COMPREHENSIVE PERFORMANCE ANALYSIS ===\n")

    # 1. Runtime profiling
    println("1. Collecting runtime profile...")
    profile = collect_profile_data() do
        user_function(test_args...)
    end

    user_hotspots = query_top_n(profile, 20, filter_fn=e -> !is_system_code(e))
    println("   Found $(length(user_hotspots)) user code hotspots")

    categorized = categorize_entries(user_hotspots)
    runtime_recs = generate_smart_recommendations(categorized, profile.total_samples)

    # 2. Type analysis (if JET available)
    type_issues = TypeIssue[]
    if check_jet_available()
        println("\n2. Running type analysis with JET.jl...")
        try
            type_analysis = analyze_types_with_jet(user_function, test_args)
            println("   Type stable: $(type_analysis.type_stable)")
            println("   Type issues: $(length(type_analysis.issues))")
            type_issues = get_high_priority_issues(type_analysis)
        catch e
            @warn "JET analysis failed" exception=e
        end
    else
        println("\n2. Type analysis skipped (JET.jl not installed)")
        # Fall back to basic check
        is_stable = check_type_stability_simple(user_function, typeof(test_args))
        println("   Basic type check: $(is_stable ? "stable" : "unstable")")
    end

    # 3. Compilation analysis (if SnoopCompile available)
    comp_issues = CompilationIssue[]
    if check_snoopcompile_available()
        println("\n3. Running compilation analysis with SnoopCompile.jl...")
        try
            comp_analysis = analyze_compilation(
                () -> user_function(test_args...),
                check_inference=true,
                check_invalidations=false,
                top_n=10
            )
            println("   Inference time: $(round(comp_analysis.total_inference_time, digits=3))s")
            println("   Compilation issues: $(length(comp_analysis.issues))")
            comp_issues = get_high_priority_compilation_issues(comp_analysis)
        catch e
            @warn "SnoopCompile analysis failed" exception=e
        end
    else
        println("\n3. Compilation analysis skipped (SnoopCompile.jl not installed)")
    end

    # 4. Memory allocation analysis
    println("\n4. Analyzing memory allocations...")
    allocs = collect_allocation_profile(sample_rate=0.01) do
        user_function(test_args...)
    end
    println("   Total allocations: $(allocs.total_allocations)")
    println("   Total bytes: $(format_bytes(allocs.total_bytes))")

    alloc_recs = analyze_allocation_patterns(allocs.sites)

    # 5. Generate comprehensive recommendations
    println("\n=== RECOMMENDATIONS ===\n")

    # Prioritize by severity
    all_recommendations = String[]

    # Critical type issues first
    if !isempty(type_issues)
        println("🔴 Critical Type Issues:")
        for issue in type_issues
            if issue.severity == :critical
                println("  - $(issue.description)")
                println("    Fix: $(issue.recommendation)")
                push!(all_recommendations, issue.recommendation)
            end
        end
    end

    # Compilation issues
    if !isempty(comp_issues)
        println("\n🟠 Compilation Performance:")
        for issue in comp_issues
            println("  - $(issue.description)")
            println("    Fix: $(issue.recommendation)")
            push!(all_recommendations, issue.recommendation)
        end
    end

    # Runtime hotspots
    println("\n🟡 Runtime Hotspots:")
    for rec in runtime_recs
        println("  - $rec")
        push!(all_recommendations, rec)
    end

    # Allocation issues
    if !isempty(alloc_recs)
        println("\n🟡 Memory Allocations:")
        for rec in alloc_recs
            println("  - $rec")
            push!(all_recommendations, rec)
        end
    end

    println("\n=== ANALYSIS COMPLETE ===")

    return Dict(
        "profile" => profile,
        "type_issues" => type_issues,
        "compilation_issues" => comp_issues,
        "recommendations" => all_recommendations
    )
end

# Usage
results = optimize_code(my_algorithm, (test_data,))
```

### Best Practices for Advanced Analysis

1. **Check Availability First**
   Always check if optional dependencies are available before using them:
   ```julia
   jet_available = check_jet_available()
   sc_available = check_snoopcompile_available()
   ```

2. **Use Appropriate Tools for Problem Type**
   - **JET.jl** → Type stability, type errors (correctness issues)
   - **SnoopCompile.jl** → Compilation time, TTFX (latency issues)
   - **Runtime profiling** → Hot loops, algorithm bottlenecks (throughput)
   - **Allocation profiling** → Memory pressure, GC overhead

3. **Filter System Code**
   Always filter system/stdlib code to focus on user code:
   ```julia
   analyze_types_with_jet(func, args, filter_system=true)
   analyze_compilation(workload, filter_system=true)
   ```

4. **Handle Version Compatibility**
   JET.jl has strict version requirements. Handle gracefully:
   ```julia
   if check_jet_available()
       is_ok, msg = check_jet_version()
       if !is_ok
           @warn msg
       end
   end
   ```

5. **Progressive Analysis**
   Start with quick checks, dive deeper if needed:
   ```julia
   # Quick pass
   msg = quick_type_check(func, args)

   # If issues found, do detailed analysis
   if contains(msg, "issues")
       analysis = analyze_types_with_jet(func, args)
       # Detailed investigation...
   end
   ```

6. **Combine Multiple Analyses**
   Use all available tools for comprehensive understanding:
   - Runtime profiling shows WHERE time is spent
   - Type analysis shows WHY it's slow (runtime dispatch)
   - Compilation analysis shows WHEN slowness occurs (first call)
   - Allocation profiling shows WHAT causes memory pressure

## Integration Tips

### Working with Existing Code
```julia
# If code is in a module
using MyPackage
profile = collect_profile_data() do
    MyPackage.my_function(args...)
end

# Filter to show only MyPackage code
my_code = query_by_file(profile, "MyPackage")
```

### Automated Optimization Pipeline
```julia
# 1. Profile
profile = collect_profile_data(() -> workload())

# 2. Categorize
categorized = categorize_entries(profile.entries)

# 3. Generate recommendations
recs = generate_smart_recommendations(categorized, profile.total_samples)

# 4. Apply optimizations (agent implements recommendations)
# 5. Re-profile and compare
optimized = collect_profile_data(() -> workload())
compare_profiles(profile, optimized)
```

## Dependencies

### Core Dependencies (Required)
- Julia 1.10+ (1.11+ recommended for CLI)
- JSON.jl
- Profile (stdlib)
- Statistics (stdlib)
- Dates (stdlib)
- Printf (stdlib)
- InteractiveUtils (stdlib)

### Optional Dependencies (Advanced Analysis)
- **JET.jl** - For advanced type analysis and error detection
  - Julia 1.12+: JET v0.11+
  - Julia 1.11: JET v0.9.x
  - Install: `Pkg.add("JET")`
- **SnoopCompile.jl** - For compilation analysis and inference profiling
  - Any Julia version (1.10+)
  - Install: `Pkg.add("SnoopCompile")`

The package works fully without optional dependencies, but they enable additional AI agent capabilities.

## Package Status

- Version: 0.1.0
- Status: Active development
- License: Check repository
- Testing: Comprehensive test suite included

## Support and Issues

For bugs or questions:
1. Check test suite at `test/runtests.jl` for usage examples
2. Review `README.md` for human-readable documentation
3. Consult this file for complete API reference

## Version History

- 0.1.0: Initial release with core profiling, categorization, and recommendation features
  - Core runtime profiling with automatic categorization
  - Allocation profiling with pattern analysis
  - Type stability checking
  - JET.jl integration for advanced type analysis
  - SnoopCompile.jl integration for compilation analysis
  - AI agent-friendly structured output for all analyses
