"""
query.jl

Query functions for filtering and analyzing profile data.
"""

"""
    query_top_n(profile::ProfileData, n::Int; filter_fn=nothing) -> Vector{ProfileEntry}

Get top N hotspots.

# Arguments
- `profile`: Profile data to query
- `n`: Number of top entries to return
- `filter_fn`: Optional function to filter entries (e.g., `e -> !is_system_code(e)`)

# Returns
- Vector of top N ProfileEntry objects
"""
function query_top_n(profile::ProfileData, n::Int; filter_fn = nothing)
    entries = profile.entries

    if filter_fn !== nothing
        entries = filter(filter_fn, entries)
    end

    return entries[1:min(n, length(entries))]
end

"""
    query_by_file(profile::ProfileData, file_pattern::String) -> Vector{ProfileEntry}

Get all entries matching a file pattern.
"""
function query_by_file(profile::ProfileData, file_pattern::String)
    return filter(e -> contains(e.file, file_pattern), profile.entries)
end

"""
    query_by_function(profile::ProfileData, func_pattern::String) -> Vector{ProfileEntry}

Get all entries matching a function name pattern.
"""
function query_by_function(profile::ProfileData, func_pattern::String)
    return filter(e -> contains(e.func, func_pattern), profile.entries)
end

"""
    query_by_pattern(profile::ProfileData, pattern::String) -> Vector{ProfileEntry}

Get all entries where function OR file matches pattern.
"""
function query_by_pattern(profile::ProfileData, pattern::String)
    return filter(
        e -> contains(e.func, pattern) || contains(e.file, pattern),
        profile.entries,
    )
end

"""
    query_by_filter(profile::ProfileData, filter_fn::Function) -> Vector{ProfileEntry}

Get all entries matching a custom filter function.

# Example
```julia
# Find all entries with more than 100 samples
results = query_by_filter(profile, e -> e.samples > 100)
```
"""
function query_by_filter(profile::ProfileData, filter_fn::Function)
    return filter(filter_fn, profile.entries)
end

"""
    is_system_code(entry::ProfileEntry;
                   system_patterns=default_system_patterns()) -> Bool

Check if entry is from system/base Julia code.

You can provide custom system patterns to filter different types of code.

# Example
```julia
# Filter out system code
user_entries = filter(e -> !is_system_code(e), profile.entries)

# Custom patterns
is_system_code(entry, system_patterns=["MyInternalLib", "libc"])
```
"""
function is_system_code(entry::ProfileEntry; system_patterns = default_system_patterns())
    return any(contains(entry.file, p) || contains(entry.func, p) for p in system_patterns)
end

"""
    default_system_patterns() -> Vector{String}

Return default patterns for identifying system/library code.
"""
function default_system_patterns()
    return [
        # Julia internals
        "libc",
        "libopenlibm",
        "jl_",
        "julia-release",
        "/Base.jl",
        "/client.jl",
        "/loading.jl",
        "/boot.jl",
        "/compiler/",
        "/reflection.jl",

        # Build artifacts
        "/cache/build/",
        "/workspace/srcdir/",

        # System libraries
        "glibc",
        "libm.so",
        "libpthread",

        # Common bloat patterns
        "inference.jl",
        "essentials.jl",
        "promotion.jl",
        "abstractarray.jl",
        "broadcast.jl",
        "reducedim.jl",

        # LLVM/compiler
        "llvm",
        "codegen",
    ]
end

"""
    is_likely_stdlib(entry::ProfileEntry) -> Bool

Check if entry is likely from Julia standard library.
More aggressive than is_system_code - filters out common stdlib modules.
"""
function is_likely_stdlib(entry::ProfileEntry)
    stdlib_patterns = [
        "/LinearAlgebra/",
        "/Statistics/",
        "/Random/",
        "/SparseArrays/",
        "/Distributed/",
        "/Profile/",
        "/REPL/",
        "/Pkg/",
        "/Test/",
        "/Dates/",
        "stdlib/",
        "share/julia/stdlib",
    ]
    return is_system_code(entry) || any(contains(entry.file, p) for p in stdlib_patterns)
end

"""
    is_noise(entry::ProfileEntry; min_percentage=0.5) -> Bool

Check if entry is likely noise (very low sample count or system code).

# Arguments
- `entry`: Profile entry to check
- `min_percentage`: Minimum percentage threshold (default 0.5%)
"""
function is_noise(entry::ProfileEntry; min_percentage = 0.5)
    return entry.percentage < min_percentage || is_system_code(entry)
end

"""
    filter_user_code(entries::Vector{ProfileEntry};
                     exclude_stdlib=false) -> Vector{ProfileEntry}

Convenience function to filter entries to user code only.

# Arguments
- `entries`: Profile entries to filter
- `exclude_stdlib`: Also filter out standard library code (default: false)

# Example
```julia
# Get only user code
user_hotspots = filter_user_code(profile.entries)

# Exclude stdlib too
pure_user = filter_user_code(profile.entries, exclude_stdlib=true)
```
"""
function filter_user_code(entries::Vector{ProfileEntry}; exclude_stdlib = false)
    if exclude_stdlib
        return filter(e -> !is_likely_stdlib(e), entries)
    else
        return filter(e -> !is_system_code(e), entries)
    end
end

"""
    filter_by_threshold(entries::Vector{ProfileEntry},
                       min_percentage::Float64) -> Vector{ProfileEntry}

Filter entries to only those above a percentage threshold.

# Example
```julia
# Get only hotspots above 5%
major_hotspots = filter_by_threshold(profile.entries, 5.0)
```
"""
function filter_by_threshold(entries::Vector{ProfileEntry}, min_percentage::Float64)
    return filter(e -> e.percentage >= min_percentage, entries)
end

"""
    query_by_regex(profile::ProfileData, pattern::Regex; field=:func) -> Vector{ProfileEntry}

Query entries using regular expression matching.

# Arguments
- `profile`: Profile data to query
- `pattern`: Regular expression pattern
- `field`: Which field to match against (`:func`, `:file`, or `:both`)

# Examples
```julia
# Match functions starting with "compute_"
results = query_by_regex(profile, r"^compute_")

# Match files ending with "_impl.jl"
results = query_by_regex(profile, r"_impl\\.jl\$", field=:file)

# Case-insensitive matching
results = query_by_regex(profile, r"matrix"i)

# Match both function and file
results = query_by_regex(profile, r"optimization", field=:both)
```
"""
function query_by_regex(profile::ProfileData, pattern::Regex; field = :func)
    return filter(profile.entries) do e
        if field == :func
            occursin(pattern, e.func)
        elseif field == :file
            occursin(pattern, e.file)
        elseif field == :both
            occursin(pattern, e.func) || occursin(pattern, e.file)
        else
            error("field must be :func, :file, or :both")
        end
    end
end

"""
    query_by_regex_function(profile::ProfileData, pattern::Regex) -> Vector{ProfileEntry}

Query entries by matching function names with regex.
Convenience wrapper for `query_by_regex(profile, pattern, field=:func)`.

# Example
```julia
# Find all functions starting with "test_"
test_funcs = query_by_regex_function(profile, r"^test_")
```
"""
function query_by_regex_function(profile::ProfileData, pattern::Regex)
    return query_by_regex(profile, pattern, field = :func)
end

"""
    query_by_regex_file(profile::ProfileData, pattern::Regex) -> Vector{ProfileEntry}

Query entries by matching file paths with regex.
Convenience wrapper for `query_by_regex(profile, pattern, field=:file)`.

# Example
```julia
# Find all entries from test files
test_files = query_by_regex_file(profile, r"test.*\\.jl\$")
```
"""
function query_by_regex_file(profile::ProfileData, pattern::Regex)
    return query_by_regex(profile, pattern, field = :file)
end

"""
    combine_filters(filters...; mode=:and) -> Function

Combine multiple filter functions into a single filter.

# Arguments
- `filters`: Variable number of filter functions
- `mode`: How to combine - `:and` (all must match) or `:or` (any must match)

# Examples
```julia
# Combine: user code AND above threshold
combined = combine_filters(
    e -> !is_system_code(e),
    e -> e.percentage > 2.0,
    mode=:and
)
results = query_by_filter(profile, combined)

# Any match (OR)
combined = combine_filters(
    e -> contains(e.file, "important.jl"),
    e -> e.percentage > 10.0,
    mode=:or
)
high_priority = query_by_filter(profile, combined)
```
"""
function combine_filters(filters...; mode = :and)
    if mode == :and
        return function (entry)
            all(f(entry) for f in filters)
        end
    elseif mode == :or
        return function (entry)
            any(f(entry) for f in filters)
        end
    else
        error("mode must be :and or :or")
    end
end

"""
    negate_filter(filter_fn::Function) -> Function

Negate a filter function (logical NOT).

# Example
```julia
# Get all entries that are NOT system code
not_system = negate_filter(is_system_code)
user_entries = query_by_filter(profile, not_system)

# Equivalent to:
user_entries = query_by_filter(profile, e -> !is_system_code(e))
```
"""
function negate_filter(filter_fn::Function)
    return function (entry)
        !filter_fn(entry)
    end
end
