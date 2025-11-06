# Improvements for LLM-Friendly Profiling

This document summarizes the improvements made to ProfilingAnalysis.jl to make it more accessible to LLM agents.

## Core Philosophy

**Goal**: Provide the most relevant profiling information concisely, hide bloat, and always provide hints for deeper analysis.

## New Features

### 1. Concise Summary Functions

#### `analyze_profile_concise(profile)`
All-in-one function that provides:
- One-line TL;DR summary
- Top N hotspots (compact format)
- Category breakdown
- Smart recommendations
- Hints for deeper analysis

**Use case**: First call for any profiling task. Gets you 80% of what you need.

#### `quick_summary(profile; top_n=5, filter_fn=...)`
Formatted quick summary showing:
- Total samples and locations
- Top N hotspots with percentages
- Contextual hints for next steps

**Use case**: When you want slightly more detail than TL;DR but still concise.

#### `tldr_summary(profile; filter_fn=...)` → String
Ultra-concise one-paragraph summary.

**Use case**: Token-limited contexts, or when you need a summary as a string.

#### `compact_hotspots(entries; max_display=10)`
One-line-per-hotspot display format.

**Use case**: Displaying multiple hotspots space-efficiently.

### 2. Enhanced Filtering

#### `filter_user_code(entries; exclude_stdlib=false)`
Convenience function to get only user code.

#### `is_likely_stdlib(entry)`
More aggressive filtering than `is_system_code` - also excludes standard library.

#### `is_noise(entry; min_percentage=0.5)`
Identifies low-impact or system code.

#### `filter_by_threshold(entries, min_percentage)`
Only keep hotspots above a threshold.

#### Improved `is_system_code()`
- Now uses `default_system_patterns()` which can be customized
- Expanded pattern list to catch more bloat
- Better documentation

**Impact**: Makes it much easier to focus on actionable code and hide noise.

### 3. Enhanced Categorization

#### `quick_categorize(entries, total_samples)` → String
One-line category breakdown.

**Example output**: `"Main bottlenecks: Linear Algebra (45.3%), Array Operations (12.1%)"`

#### `print_compact_categories(categorized, total_samples)`
Compact multi-line category display showing top function per category.

#### `general_categories()`
More general categorization patterns suitable for any Julia code:
- linear_algebra
- array_operations
- memory_allocation
- io_operations
- string_operations
- math_functions
- iteration
- compilation

#### `categorize_with_custom(entries, custom_categories)`
Use your own categorization patterns.

**Impact**: Makes category analysis much more concise and flexible.

### 4. Documentation

#### LLM_GUIDE.md
Comprehensive guide specifically for LLM agents including:
- Quick start workflows
- Filtering strategies
- Display formats
- Custom categories
- Best practices
- Example session
- Function reference table

#### examples/concise_workflow.jl
Complete working example demonstrating:
- All-in-one analysis
- Ultra-concise workflows
- Progressive drilling
- Custom filtering
- Custom categorization
- Allocation profiling

#### Updated README.md
- Highlighted LLM-friendly features
- Simplified quick start
- Referenced LLM guide

## Key Improvements by Use Case

### For Initial Analysis
**Before**: Manual filtering, verbose output
```julia
entries = filter(e -> !is_system_code(e), profile.entries)
top = entries[1:min(20, length(entries))]
print_entry_table(top)  # Long table output
```

**After**: One function call
```julia
analyze_profile_concise(profile)  # Concise, complete analysis
```

### For Token-Limited Contexts
**Before**: No built-in ultra-concise option
```julia
# Had to manually format
```

**After**: One-liner
```julia
println(tldr_summary(profile, filter_fn=e -> !is_system_code(e)))
# "Profile has 1523 samples across 67 locations. Top 3 hotspots account for 68.2%: ..."
```

### For Category Analysis
**Before**: Verbose multi-line output
```julia
categorized = categorize_entries(profile.entries)
print_categorized_summary(categorized, profile.total_samples)
# Shows all categories with details
```

**After**: One-liner option
```julia
println(quick_categorize(profile.entries, profile.total_samples))
# "Main bottlenecks: Distance Calculation (23.5%), Search Operations (15.2%)"
```

### For Listing Hotspots
**Before**: Full table
```julia
print_entry_table(entries)
# Rank  Samples    % Total  Function @ File:Line
# ---------------------------------------------------------
# 1     234        34.2     matrix_multiply @ demo_workload.jl:16
```

**After**: Compact format
```julia
compact_hotspots(entries)
#  1.  34.2% matrix_multiply                       demo_workload.jl:16
```

## Backward Compatibility

All existing functions remain unchanged. New functions are additions, not replacements.

## Function Exports Added

### summary.jl
- `quick_summary`
- `tldr_summary`
- `compact_hotspots`
- `analyze_profile_concise`

### query.jl
- `is_likely_stdlib`
- `is_noise`
- `filter_user_code`
- `filter_by_threshold`
- `default_system_patterns`

### categorization.jl
- `quick_categorize`
- `print_compact_categories`
- `general_categories`
- `categorize_with_custom`

## Design Principles Applied

1. **Conciseness First**: Every new function prioritizes brevity
2. **Progressive Disclosure**: Start with summary, provide hints for details
3. **Smart Defaults**: Filter system code by default, show top N only
4. **Consistent Format**: All compact functions use similar formatting
5. **Actionable Output**: Always include recommendations when relevant
6. **Hints Included**: Show how to get more information

## Metrics

- **New functions**: 12
- **Enhanced functions**: 1 (`is_system_code`)
- **New documentation**: 2 files (LLM_GUIDE.md, IMPROVEMENTS.md)
- **Examples**: 1 comprehensive example
- **Lines of documentation**: ~500+

## Next Steps / Future Improvements

Potential future enhancements:
1. JSON output format for programmatic consumption
2. Flamegraph-style text visualization
3. Performance regression detection
4. Automated benchmarking integration
5. More specialized categorization presets
6. Interactive REPL mode with progressive queries
7. Integration with profiling visualization tools

## Testing Recommendations

To test the new features:
```julia
using ProfilingAnalysis

# Run demo workload
include("test/demo_workload.jl")
profile = collect_profile_data(() -> run_demo_workload(duration_seconds=2.0))

# Test all new concise functions
analyze_profile_concise(profile)
quick_summary(profile)
println(tldr_summary(profile, filter_fn=e -> !is_system_code(e)))

# Test filtering
user_code = filter_user_code(profile.entries)
compact_hotspots(user_code)

# Test categorization
println(quick_categorize(user_code, profile.total_samples))
```

Or run the example:
```bash
julia examples/concise_workflow.jl
```
