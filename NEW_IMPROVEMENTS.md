# ProfilingAnalysis.jl - New Improvements (November 2025)

This document outlines new improvements being added to the package.

## Improvements Implemented in This Session

### 1. Regex-Based Query Filtering ✅ (Implementing)
**Problem**: Current filtering only supports `contains()` matching
**Solution**: Add regex support for more powerful pattern matching

New functions:
- `query_by_regex(profile, pattern::Regex; field=:func)` - Match using regex
- `query_by_regex_file(profile, pattern::Regex)` - Regex match on file paths
- `query_by_regex_function(profile, pattern::Regex)` - Regex match on function names

Examples:
```julia
# Match functions starting with "compute_"
query_by_regex(profile, r"^compute_", field=:func)

# Match files ending with "_impl.jl"
query_by_regex_file(profile, r"_impl\.jl$")

# Case-insensitive matching
query_by_regex(profile, r"matrix"i, field=:func)
```

### 2. Export Utilities ✅ (Implementing)
**Problem**: Can only save profiles as JSON
**Solution**: Add export functions for multiple formats

New module: `src/export.jl`

Functions:
- `export_to_csv(profile, filename; filter_fn=nothing, top_n=nothing)`
- `export_to_markdown(profile, filename; filter_fn=nothing, top_n=20, include_summary=true)`
- `export_summary_markdown(profile, filename)` - Full markdown report

Examples:
```julia
# Export top 50 to CSV
export_to_csv(profile, "hotspots.csv", top_n=50)

# Export user code to markdown report
export_to_markdown(
    profile,
    "analysis.md",
    filter_fn=e -> !is_system_code(e),
    include_summary=true
)
```

### 3. Benchmark Helpers ✅ (Implementing)
**Problem**: Manual workflow for tracking optimization progress
**Solution**: Add helper functions to automate before/after profiling

New module functions in `collection.jl`:
- `benchmark_optimization(name, workload_fn; save_dir="benchmarks")`
- `compare_benchmark_results(name, save_dir="benchmarks")`

Examples:
```julia
# Collect baseline
benchmark_optimization("my_optimization_v1") do
    my_function()
end

# After changes, collect again
benchmark_optimization("my_optimization_v2") do
    my_function()
end

# Compare
compare_benchmark_results("my_optimization")
```

### 4. Advanced Profile Diffing ✅ (Implementing)
**Problem**: `compare_profiles()` shows changes but limited analysis
**Solution**: Add dedicated diff analysis

New functions in `comparison.jl`:
- `profile_diff(profile1, profile2)` - Returns detailed diff structure
- `print_diff_summary(diff)` - Print human-readable diff
- `identify_hotspot_migrations(diff)` - Show where time moved

Diff structure includes:
- Functions that disappeared
- Functions that appeared
- Functions that changed significantly
- Category migrations

Examples:
```julia
diff = profile_diff(baseline, optimized)
print_diff_summary(diff)

# Output includes:
# - Removed hotspots (appeared in baseline, gone in optimized)
# - New hotspots (appeared in optimized)
# - Migrated time (time moved from X to Y)
```

### 5. Filter Combinators ✅ (Implementing)
**Problem**: Can't easily combine multiple filters
**Solution**: Add filter combination utilities

New functions in `query.jl`:
- `combine_filters(filters...; mode=:and)` - Combine multiple filter functions
- `negate_filter(filter_fn)` - Negate a filter

Examples:
```julia
# Combine: user code AND above threshold
combined = combine_filters(
    e -> !is_system_code(e),
    e -> e.percentage > 2.0,
    mode=:and
)
results = query_by_filter(profile, combined)

# Negate: NOT system code
not_system = negate_filter(is_system_code)
user_code = query_by_filter(profile, not_system)
```

### 6. Configuration Management ✅ (Implementing)
**Problem**: Thresholds and patterns hardcoded
**Solution**: Add configuration system

New module: `src/config.jl`

Features:
- Default configuration with all thresholds
- Load from TOML file
- Override per-function

Configuration includes:
- Category thresholds
- Default sample rate for allocations
- System code patterns
- Display preferences (max_width, top_n defaults)

Examples:
```julia
# Use default config
config = load_config()

# Load from file
config = load_config("my_config.toml")

# Override specific values
config = merge_config(default_config(), Dict("top_n" => 15))

# Use in functions
categorize_entries(profile.entries, config=config)
```

## Implementation Priority

1. ✅ Regex filtering (High value, low effort)
2. ✅ Export utilities (High value, medium effort)
3. ✅ Filter combinators (Medium value, low effort)
4. ✅ Benchmark helpers (Medium value, medium effort)
5. ✅ Configuration management (Medium value, medium effort)
6. ✅ Advanced diffing (Low-medium value, medium effort)

## Testing Plan

For each new feature:
1. Add unit tests in `test/runtests.jl`
2. Add integration example in `examples/`
3. Update documentation

## Backward Compatibility

All new features are additions. No breaking changes to existing API.

## Documentation Updates Needed

- Update README.md with new features
- Add examples to LLM_GUIDE.md
- Update CLAUDE.md with new functions
- Add docstrings to all new functions

## Estimated Impact

- **LLM Agents**: Easier to perform complex queries and export results
- **Human Developers**: More flexible profiling workflows
- **Automation**: Better support for CI/CD integration with CSV/Markdown exports

## Success Criteria

- All new functions have tests
- All new functions have docstrings  
- Examples demonstrate each feature
- No regression in existing tests
- Documentation updated

