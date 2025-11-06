# ProfilingAnalysis.jl

A comprehensive profiling analysis toolkit for Julia designed to make performance optimization accessible to LLM agents. Provides concise, actionable insights without the typical profiling bloat.

## Features

### Core Capabilities
- **Runtime Profiling** - CPU hotspot detection and analysis
- **Allocation Profiling** - Memory allocation tracking with Profile.Allocs
- **Automatic Categorization** - Smart grouping by operation type
- **Context-Aware Recommendations** - Actionable optimization suggestions
- **Profile Comparison** - Track performance changes over time
- **JSON Save/Load** - Persistent profile storage
- **Type Stability Helpers** - Detect dynamic dispatch issues

### LLM-Friendly Features
- **Ultra-Concise Output** - Hide noise, show only what matters
- **Smart Filtering** - Automatically exclude system/stdlib bloat
- **Quick Summaries** - One-line to 5-line summaries
- **Contextual Hints** - Always show how to get more detail
- **Compact Formats** - Space-efficient displays for multiple results

## Quick Start

### Simplest Workflow (Recommended for LLMs)

```julia
using ProfilingAnalysis

# 1. Collect profile
profile = collect_profile_data() do
    my_expensive_function()
end

# 2. Get concise analysis (all-in-one)
analyze_profile_concise(profile)
```

This gives you:
- One-line summary of the profile
- Top 5 hotspots (compact format)
- Category breakdown
- Smart optimization recommendations
- Hints for drilling deeper

### Manual Step-by-Step

```julia
# Collect runtime profile
profile = collect_profile_data() do
    my_expensive_function()
end

# Quick summary (5 top hotspots with hints)
quick_summary(profile, filter_fn=e -> !is_system_code(e))

# Or ultra-concise (one-line summary)
println(tldr_summary(profile, filter_fn=e -> !is_system_code(e)))

# Category breakdown
categorized = categorize_entries(profile.entries)
print_compact_categories(categorized, profile.total_samples)

# Get smart recommendations
recs = generate_smart_recommendations(categorized, profile.total_samples)
for rec in recs
    println(rec)
end
```

## Allocation Profiling

```julia
# Profile allocations (10% sampling for speed)
allocs = collect_allocation_profile(sample_rate=0.1) do
    my_expensive_function()
end

# Show allocation hotspots
summarize_allocations(allocs, top_n=20)

# Get allocation-specific recommendations
alloc_recs = analyze_allocation_patterns(allocs.sites)
```

## Automatic Categorization

The tool automatically categorizes hotspots into:
- **Distance calculations** - Metric computations, norms
- **Heap operations** - Priority queues, sorted structures  
- **Tree construction** - Building spatial data structures
- **Search operations** - k-NN, range search, queries
- **Point access** - Data structure overhead

Each category gets specific optimization recommendations based on thresholds.

## Type Stability Checking

```julia
# Quick check
is_stable = check_type_stability_simple(my_function, (Int, Float64))

# Show detailed guide
print_type_stability_guide()
```

## Profile Comparison

```julia
baseline = collect_profile_data(() -> my_function())
save_profile(baseline, "baseline.json")

# Make optimizations...

optimized = collect_profile_data(() -> my_function())
compare_profiles(baseline, optimized, top_n=20)
```

## LLM Agent Guide

**For LLM agents**: See [LLM_GUIDE.md](LLM_GUIDE.md) for a comprehensive guide on using this package effectively, including:
- Recommended workflows
- Best practices for concise output
- Filtering strategies
- Custom categorization
- Advanced features

## Dependencies

- Julia 1.10+
- JSON, Profile, Statistics, Dates, Printf, InteractiveUtils

## Development

This package is designed to be standalone with minimal dependencies.
