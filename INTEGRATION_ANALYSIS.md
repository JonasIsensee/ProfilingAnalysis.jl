# Integration Analysis: SnoopCompile.jl & JET.jl

## Library Overview

### SnoopCompile.jl - Compilation Latency Analysis

**Problems Solved:**
- TTFX (Time To First X) - compilation latency issues
- Method invalidation detection
- Type inference performance bottlenecks
- Excessive specialization detection
- Precompilation effectiveness

**Key Features:**
1. `@snoop_invalidations` - Detect method cache invalidations
2. `@snoop_inference` - Profile type inference time
3. `invalidation_trees()` - Parse invalidation data into trees
4. `flatten()` - Convert nested timing to flat lists
5. `inference_triggers()` - Find runtime dispatch points causing inference
6. `staleinstances()` - Find invalidated code instances
7. Precompilation analysis and directive generation

### JET.jl - Static Type Analysis

**Problems Solved:**
- Type stability detection
- Type error detection (potential runtime errors)
- Package-wide static analysis
- Runtime dispatch identification

**Key Features:**
1. `@report_opt` - Type instability analysis (like enhanced @code_warntype)
2. `@report_call` - Type error detection on actual calls
3. `report_package()` - Whole package analysis

**Version Requirements:**
- Julia 1.12: JET v0.11
- Julia 1.11: JET v0.9
- Critical compatibility issue for agents!

## AI Agent Challenges

### SnoopCompile.jl Challenges

1. **Complex Data Structures**
   - Returns nested trees of MethodInstances
   - Requires multiple processing steps to extract insights
   - No unified "just analyze this" function

2. **Workflow Complexity**
   - Different workflows for load-time vs runtime issues
   - Need to understand Julia compilation pipeline
   - Results require manual interpretation

3. **Raw Output**
   - Returns low-level data structures
   - Need domain knowledge to prioritize issues
   - No automatic severity ranking

4. **Multi-Step Process**
   - Collect data with macro
   - Process with various functions
   - Interpret results manually
   - Generate fixes

### JET.jl Challenges

1. **Version Compatibility**
   - Critical version matching with Julia
   - Agents must check and handle compatibility
   - Dependency conflicts possible

2. **Text-Based Output**
   - Results are printed text, not structured data
   - Need to capture and parse output
   - Hard to process programmatically

3. **False Negatives**
   - "No errors" doesn't guarantee safety
   - Type instability breaks analysis chain
   - Missing dynamic dispatch paths

4. **Noise Filtering**
   - External library errors clutter results
   - Need to filter to user code
   - Hard to distinguish critical vs minor issues

5. **Workflow Dependencies**
   - Should run @report_opt before @report_call
   - Need type-stable code for best results
   - Iterative refinement required

## Agent-Friendly Interface Design

### Design Principles

1. **Structured Output** - Always return structured data, never raw text
2. **Automatic Ranking** - Sort issues by severity/impact
3. **Actionable Recommendations** - Each issue includes fix suggestions
4. **Filter Noise** - Automatically filter system/library code
5. **Unified API** - Single function for common workflows
6. **Error Handling** - Graceful degradation on version issues

### Proposed APIs

#### SnoopCompile Integration

```julia
# Unified compilation analysis
struct CompilationIssue
    type::Symbol  # :invalidation, :inference_trigger, :slow_inference
    severity::Symbol  # :critical, :high, :medium, :low
    function_name::String
    file::String
    line::Int
    description::String
    time_impact::Float64  # seconds or percentage
    recommendation::String
end

struct CompilationAnalysis
    timestamp::DateTime
    total_inference_time::Float64
    issues::Vector{CompilationIssue}
    summary::Dict{Symbol, Int}  # count by type
    metadata::Dict{String, Any}
end

# Main function - analyzes everything
function analyze_compilation(workload_fn::Function;
                             check_invalidations=true,
                             check_inference=true,
                             filter_system=true,
                             top_n=20)
    -> CompilationAnalysis
end

# Focused analyses
function analyze_invalidations(workload_fn::Function) -> Vector{CompilationIssue}
function analyze_inference_triggers(workload_fn::Function) -> Vector{CompilationIssue}
function analyze_slow_inference(workload_fn::Function) -> Vector{CompilationIssue}
```

#### JET Integration

```julia
# Unified type analysis
struct TypeIssue
    type::Symbol  # :instability, :type_error, :dispatch
    severity::Symbol  # :critical, :high, :medium, :low
    function_name::String
    file::String
    line::Int
    description::String
    inferred_type::String  # for instabilities
    call_chain::Vector{String}  # backtrace to issue
    recommendation::String
end

struct TypeAnalysis
    timestamp::DateTime
    issues::Vector{TypeIssue}
    summary::Dict{Symbol, Int}
    type_stable::Bool
    metadata::Dict{String, Any}
end

# Main function - automatic version checking
function analyze_types(func::Function, args::Tuple;
                       check_stability=true,
                       check_errors=true,
                       filter_system=true)
    -> TypeAnalysis
end

# Package-wide analysis
function analyze_package_types(package_name::String;
                               target_modules=nothing,
                               filter_external=true)
    -> TypeAnalysis
end

# Quick checks
function is_type_stable(func::Function, args::Tuple) -> Bool
function find_type_errors(func::Function, args::Tuple) -> Vector{TypeIssue}
```

### Display Functions

```julia
# Unified display for all analyses
function print_compilation_analysis(analysis::CompilationAnalysis)
function print_type_analysis(analysis::TypeAnalysis)

# Tables for issues
function print_issue_table(issues::Vector{Union{CompilationIssue, TypeIssue}})

# Comparison
function compare_compilation(before::CompilationAnalysis, after::CompilationAnalysis)
```

## Implementation Strategy

### Phase 1: JET.jl Integration (Simpler)
1. Add JET.jl as optional dependency
2. Implement version compatibility check
3. Capture and parse @report_opt output
4. Capture and parse @report_call output
5. Structure results into TypeIssue/TypeAnalysis
6. Generate recommendations based on issue patterns
7. Add display functions

### Phase 2: SnoopCompile.jl Integration (More Complex)
1. Add SnoopCompile.jl as optional dependency
2. Implement invalidation analysis wrapper
3. Implement inference timing analysis wrapper
4. Flatten and rank results
5. Structure into CompilationIssue/CompilationAnalysis
6. Generate recommendations
7. Add display functions

### Phase 3: Integration & Testing
1. Add comprehensive tests
2. Update CLAUDE.md with new APIs
3. Add examples to README
4. Test with real-world code

## Most Useful Features for Agents

### Priority 1 (Implement First)
1. **JET @report_opt** - Type stability is the #1 performance issue
2. **SnoopCompile inference_triggers** - Find runtime dispatch hotspots
3. **Unified analysis functions** - One call to get comprehensive results

### Priority 2 (High Value)
4. **JET @report_call** - Type error detection
5. **SnoopCompile invalidations** - Load-time performance
6. **Automatic ranking** - Sort by severity/impact

### Priority 3 (Nice to Have)
7. **Package-wide analysis** - Full codebase scan
8. **Comparison functions** - Track improvements
9. **Precompilation directives** - Generate precompile statements

## Recommendations Generation

Based on issue patterns, generate specific recommendations:

### Type Instability Patterns
- `Union{T, Nothing}` → Add type assertion or use @something
- `Any` return type → Add type annotation
- Container type instability → Use typed containers
- Loop variable changes type → Pre-allocate with correct type

### Inference Trigger Patterns
- Runtime dispatch in hot loop → Add type annotation or @inline
- Higher-order function with unclear types → Use function barriers
- Dynamic dispatch on container elements → Use typed containers

### Invalidation Patterns
- Method redefinition invalidates code → Check load order
- Type piracy causing invalidations → Add precompile directives
- Extension method invalidations → Consider package structure

## Example Workflows

### For Agents: Quick Type Check
```julia
using ProfilingAnalysis

# Check if function is type-stable
analysis = analyze_types(my_function, (Int, Float64))

if !analysis.type_stable
    println("Type issues found:")
    for issue in analysis.issues
        println("  $(issue.severity): $(issue.description)")
        println("  Fix: $(issue.recommendation)")
    end
end
```

### For Agents: Comprehensive Analysis
```julia
# Full compilation + type analysis
comp_analysis = analyze_compilation() do
    my_algorithm(test_data)
end

type_analysis = analyze_types(my_algorithm, (typeof(test_data),))

# Show all issues sorted by severity
all_issues = vcat(comp_analysis.issues, type_analysis.issues)
sort!(all_issues, by=i -> (i.severity == :critical ? 0 :
                           i.severity == :high ? 1 : 2))

print_issue_table(all_issues)
```

### For Agents: Optimization Loop
```julia
# 1. Profile runtime
profile = collect_profile_data(() -> workload())

# 2. Analyze compilation
comp = analyze_compilation(() -> workload())

# 3. Analyze types for hot functions
hot_functions = query_top_n(profile, 5, filter_fn=e -> !is_system_code(e))
for entry in hot_functions
    # Agent would need to look up function and call with appropriate types
    println("Analyzing $(entry.func)...")
end

# 4. Generate combined recommendations
# 5. Apply fixes
# 6. Re-run and compare
```

## Implementation Notes

### Optional Dependencies
Use Julia's weak dependencies (extensions) to avoid forcing installation:
- SnoopCompile.jl → ProfilingAnalysisCompileExt
- JET.jl → ProfilingAnalysisJETExt

### Error Handling
- Check package availability before calling
- Handle version incompatibilities gracefully
- Provide helpful error messages

### Testing Strategy
- Mock JET/SnoopCompile output for unit tests
- Integration tests with actual packages (if available)
- Test version compatibility detection
- Test filtering and ranking logic
