# ProfilingAnalysis.jl - LLM Agent Guide

This guide is designed for LLM agents helping developers optimize Julia code. The package provides concise, actionable profiling information without the typical bloat.

## Quick Start - The Essentials

### 1. Collect Profile (Runtime)

```julia
using ProfilingAnalysis

profile = collect_profile_data() do
    # Your code to profile
    my_function()
end
```

### 2. Get Quick Summary (Recommended First Step)

```julia
# Ultra-concise view - perfect for first glance
quick_summary(profile, filter_fn=e -> !is_system_code(e))

# Even more concise - one line
summary_text = tldr_summary(profile, filter_fn=e -> !is_system_code(e))
println(summary_text)
```

**Output example:**
```
📊 PROFILE QUICK SUMMARY

Total samples: 1247 | Unique locations: 89
Showing: 856 samples (68.6% of total)

Top 5 hotspots:
  1.  34.2% | matrix_multiply @ demo_workload.jl:16
  2.  21.5% | solve_linear_system @ demo_workload.jl:28
  3.  18.3% | compute_eigenvalues @ demo_workload.jl:50
  4.   8.7% | qr_decomposition @ demo_workload.jl:66
  5.   3.1% | vector_operations @ demo_workload.jl:82

💡 Quick actions:
   • Use print_entry_table(entries) for detailed view
   • Use categorize_entries(profile.entries) for automatic grouping
   • Use generate_smart_recommendations() for optimization tips
   • Use query_by_file() or query_by_function() to drill down
```

### 3. Get Category Breakdown

```julia
# Quick one-liner
println(quick_categorize(profile.entries, profile.total_samples))
# Output: "Main bottlenecks: Linear Algebra (45.3%), Array Operations (12.1%)"

# Compact multi-line
categorized = categorize_entries(profile.entries)
print_compact_categories(categorized, profile.total_samples)
```

### 4. Get Smart Recommendations

```julia
# Automatic recommendations based on detected patterns
recs = generate_smart_recommendations(categorized, profile.total_samples)
for rec in recs
    println(rec)
end
```

## Filtering - Hide the Bloat

### Basic Filtering

```julia
# Filter out system code (Julia base, stdlib, C libraries)
user_code = filter_user_code(profile.entries)

# Also filter out standard library
pure_user = filter_user_code(profile.entries, exclude_stdlib=true)

# Filter by percentage threshold
major_hotspots = filter_by_threshold(profile.entries, 5.0)  # Only > 5%

# Combine filters
top_user = query_top_n(profile, 10, filter_fn=e -> !is_system_code(e))
```

### Filter Helper Functions

```julia
is_system_code(entry)      # Julia internals, C libs, build artifacts
is_likely_stdlib(entry)    # Standard library (LinearAlgebra, etc.)
is_noise(entry)            # Low percentage or system code
```

## Drilling Down

### By File or Function

```julia
# Find all hotspots in a specific file
file_hotspots = query_by_file(profile, "myfile.jl")
print_entry_table(file_hotspots)

# Find hotspots by function name
func_hotspots = query_by_function(profile, "compute")

# Pattern matching (function OR file)
results = query_by_pattern(profile, "matrix")
```

### Custom Filters

```julia
# Complex custom filter
high_value = query_by_filter(profile, e ->
    e.percentage > 2.0 &&
    !is_system_code(e) &&
    contains(e.file, "mypackage")
)
```

## Allocation Profiling

### Collect Allocations

```julia
# Use sampling for speed (10% = reasonable, 1.0 = all allocations)
allocs = collect_allocation_profile(sample_rate=0.1) do
    my_function()
end

# Quick summary
summarize_allocations(allocs, top_n=10)

# Get recommendations
alloc_recs = analyze_allocation_patterns(allocs.sites)
```

## Custom Categories

### Define Your Own

```julia
# Define categories for your domain
my_categories = Dict(
    "database" => ["query", "insert", "transaction", "sql"],
    "network" => ["http", "request", "socket", "fetch"],
    "parsing" => ["parse", "json", "xml", "deserialize"]
)

categorized = categorize_with_custom(profile.entries, my_categories)
print_compact_categories(categorized, profile.total_samples)
```

### Use General Categories

```julia
# More general than the default ATRIA-specific categories
cats = categorize_entries(profile.entries, categories=general_categories())
```

## Display Formats

### Compact Display

```julia
# Single-line entries
top = query_top_n(profile, 10, filter_fn=e -> !is_system_code(e))
compact_hotspots(top)
```

**Output:**
```
 1.  34.2% matrix_multiply                       demo_workload.jl:16
 2.  21.5% solve_linear_system                   demo_workload.jl:28
 3.  18.3% compute_eigenvalues                   demo_workload.jl:50
```

### Detailed Table

```julia
# Full table with columns
print_entry_table(top)
```

## Comparison (Before/After Optimization)

```julia
# Collect baseline
baseline = collect_profile_data(() -> my_function())
save_profile(baseline, "baseline.json")

# ... make optimizations ...

# Collect optimized version
optimized = collect_profile_data(() -> my_function())

# Compare
compare_profiles(baseline, optimized, top_n=15)
```

## Recommended Workflow for LLMs

### Step 1: Quick Assessment
```julia
profile = collect_profile_data(() -> target_function())
println(tldr_summary(profile, filter_fn=e -> !is_system_code(e)))
```

### Step 2: Identify Categories
```julia
println(quick_categorize(profile.entries, profile.total_samples))
```

### Step 3: Get Details on Top Issues
```julia
top_5 = query_top_n(profile, 5, filter_fn=e -> !is_system_code(e))
compact_hotspots(top_5)
```

### Step 4: Get Actionable Advice
```julia
categorized = categorize_entries(profile.entries)
recs = generate_smart_recommendations(categorized, profile.total_samples)
for rec in recs
    println(rec)
end
```

### Step 5: Drill Down If Needed
```julia
# Focus on specific file
hotspots = query_by_file(profile, "problematic_file.jl")
print_entry_table(hotspots)
```

## Tips for LLM Agents

### ✅ DO:
- Start with `quick_summary()` or `tldr_summary()` for overview
- Use `filter_user_code()` to focus on actionable code
- Use `quick_categorize()` for high-level bottleneck identification
- Combine filters for precise targeting
- Use `compact_hotspots()` for space-efficient output

### ❌ DON'T:
- Show raw profile dumps with hundreds of entries
- Include system/stdlib code in initial analysis
- Display entries with < 1% impact (unless specifically debugging)
- Overwhelm user with full table when compact view suffices

## Key Functions Summary

| Function | Use Case | Output |
|----------|----------|--------|
| `quick_summary()` | First look at profile | Concise formatted summary |
| `tldr_summary()` | One-line summary | Single string |
| `compact_hotspots()` | List top issues | One line per hotspot |
| `quick_categorize()` | Identify bottleneck types | Single line category breakdown |
| `filter_user_code()` | Focus on user code | Filtered entries |
| `generate_smart_recommendations()` | Get optimization tips | List of actionable advice |

## Example Session

```julia
using ProfilingAnalysis

# Profile some code
profile = collect_profile_data() do
    my_expensive_computation()
end

# Quick look
println(tldr_summary(profile, filter_fn=e -> !is_system_code(e)))
# "Profile has 1523 samples across 67 locations. Top 3 hotspots account for 68.2%:
#  1) matrix_multiply (34.2%) @ workload.jl:16
#  2) solve_system (21.5%) @ workload.jl:28
#  3) eigenvalues (12.5%) @ workload.jl:50"

# Categories
println(quick_categorize(profile.entries, profile.total_samples))
# "Main bottlenecks: Linear Algebra (68.2%), Array Operations (8.3%)"

# Details
top = filter_user_code(profile.entries)
compact_hotspots(top[1:5])

# Recommendations
categorized = categorize_entries(filter_user_code(profile.entries))
recs = generate_smart_recommendations(categorized, profile.total_samples)
for rec in recs
    println(rec)
end
```

## Allocation Profiling Quick Reference

```julia
# Collect
allocs = collect_allocation_profile(sample_rate=0.1) do
    code_to_profile()
end

# Quick view
summarize_allocations(allocs, top_n=10)

# Recommendations
recs = analyze_allocation_patterns(
    allocs.sites,
    package_patterns=["MyPackage", "myfile.jl"]
)
```

## Advanced: Type Stability

```julia
# Quick check if function has type instability
is_stable = check_type_stability_simple(my_function, (Int, Float64))

# Get guide for fixing type issues
print_type_stability_guide()
```

## Remember

**The goal is to provide the most relevant information concisely.**
- Filter aggressively (hide system/stdlib/noise)
- Start with summaries, drill down only when needed
- Provide actionable recommendations
- Use compact formats when listing multiple items
