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

- Julia 1.10+ (1.11+ recommended for CLI)
- JSON.jl
- Profile (stdlib)
- Statistics (stdlib)
- Dates (stdlib)
- Printf (stdlib)
- InteractiveUtils (stdlib)

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
