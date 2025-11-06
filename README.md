# ProfilingAnalysis.jl

[![CI](https://github.com/JonasIsensee/ProfilingAnalysis.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/JonasIsensee/ProfilingAnalysis.jl/actions/workflows/CI.yml)
[![codecov](https://codecov.io/gh/JonasIsensee/ProfilingAnalysis.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/JonasIsensee/ProfilingAnalysis.jl)
[![License](https://img.shields.io/github/license/JonasIsensee/ProfilingAnalysis.jl)](LICENSE)
[![Julia Version](https://img.shields.io/badge/julia-v1.10%2B-blue)](https://julialang.org/)
[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)

A comprehensive profiling analysis toolkit for Julia with support for runtime profiling, allocation tracking, automatic categorization, and smart recommendations.

## Features

### Core Capabilities
- **Runtime Profiling** - CPU hotspot detection and analysis
- **Allocation Profiling** - Memory allocation tracking with Profile.Allocs
- **Automatic Categorization** - Smart grouping by operation type
- **Context-Aware Recommendations** - Actionable optimization suggestions
- **Profile Comparison** - Track performance changes over time
- **JSON Save/Load** - Persistent profile storage
- **Type Stability Helpers** - Detect dynamic dispatch issues

## Quick Start

```julia
using ProfilingAnalysis

# Collect runtime profile
runtime = collect_profile_data() do
    # Your workload here
    my_expensive_function()
end

# Query top hotspots
top_20 = query_top_n(runtime, 20, filter_fn=e -> !is_system_code(e))
print_entry_table(top_20)

# Auto-categorize by operation type
categorized = categorize_entries(runtime.entries)
print_categorized_summary(categorized, runtime.total_samples)

# Get smart recommendations
recs = generate_smart_recommendations(categorized, runtime.total_samples)
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

## Dependencies

- Julia 1.10+
- JSON, Profile, Statistics, Dates, Printf, InteractiveUtils

## Development

### Running Tests

The package includes a comprehensive test suite covering all API functions:

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

Tests cover:
- Profile data collection and I/O
- All query functions
- Allocation profiling
- Categorization and recommendations
- Type stability checking
- CLI interface
- Edge cases and error handling

### CI/CD

Continuous Integration is set up via GitHub Actions:
- **CI.yml**: Tests on Julia 1.10, 1.11, and nightly across Linux, macOS, and Windows
- **CompatHelper.yml**: Automatic dependency compatibility updates
- **TagBot.yml**: Automatic version tagging
- **Code Coverage**: Automatically uploaded to Codecov

### For LLM Agents

If you're an LLM agent working with this package, see [CLAUDE.md](CLAUDE.md) for comprehensive API documentation and usage patterns.

### Contributing

This package is designed to be standalone and has no dependencies on other domain-specific packages. Contributions are welcome!
