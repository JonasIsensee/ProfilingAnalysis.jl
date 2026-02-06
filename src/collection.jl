"""
collection.jl

Profile data collection and I/O operations.
"""

using Profile
using Dates
using JSON

"""
    collect_profile_data(workload_fn::Function; metadata=Dict{String,Any}())

Collect profile data by running the provided workload function.

# Arguments
- `workload_fn`: Function to profile (called twice: once for warmup, once for profiling)
- `metadata`: Optional metadata to store with the profile

# Returns
- `ProfileData`: Structured profile data
"""
function collect_profile_data(workload_fn::Function; metadata = Dict{String,Any}())
    # Clear previous profile data
    Profile.clear()

    # Warm up (compilation)
    println("Warming up (compilation)...")
    workload_fn()

    # Profile
    println("Profiling with sampling enabled...")
    Profile.clear()
    @profile workload_fn()

    # Extract data
    data = Profile.fetch()

    if isempty(data)
        @warn "No profile data collected. The workload may be too fast."
        return ProfileData(now(), 0, ProfileEntry[], metadata)
    end

    # Count samples per function
    function_counts = Dict{Tuple{String,String,Int},Int}()

    for frame_idx in data
        if frame_idx > 0  # Valid frame
            try
                frames = Profile.lookup(frame_idx)
                if !isempty(frames)
                    func_info = frames[1]
                    func_name = String(func_info.func)
                    file = String(func_info.file)
                    line = func_info.line

                    # Skip invalid entries but keep all valid ones
                    if func_name != "unknown function"
                        key = (func_name, file, line)
                        function_counts[key] = get(function_counts, key, 0) + 1
                    end
                end
            catch
                # Skip invalid frames
                continue
            end
        end
    end

    # Convert to ProfileEntry array
    total_samples = length(data)
    entries = [
        ProfileEntry(func, file, line, count, 100.0 * count / total_samples) for
        ((func, file, line), count) in function_counts
    ]

    # Sort by sample count (descending)
    sort!(entries, by = e -> e.samples, rev = true)

    return ProfileData(now(), total_samples, entries, metadata)
end

"""
    save_profile(profile::ProfileData, filename::String)

Save profile data to JSON file.
"""
function save_profile(profile::ProfileData, filename::String)
    mkpath(dirname(filename))

    # Convert to JSON-friendly format
    data = Dict(
        "timestamp" => string(profile.timestamp),
        "total_samples" => profile.total_samples,
        "entries" => [
            Dict(
                "func" => e.func,
                "file" => e.file,
                "line" => e.line,
                "samples" => e.samples,
                "percentage" => e.percentage,
            ) for e in profile.entries
        ],
        "metadata" => profile.metadata,
    )

    open(filename, "w") do io
        JSON.print(io, data, 4)  # 4-space indent for pretty printing
    end

    println("Profile data saved to: $filename")
    println("  Total samples: $(profile.total_samples)")
    println("  Unique locations: $(length(profile.entries))")
end

"""
    load_profile(filename::String) -> ProfileData

Load profile data from JSON file.
"""
function load_profile(filename::String)
    data = JSON.parse(read(filename, String))

    entries = [
        ProfileEntry(e["func"], e["file"], e["line"], e["samples"], e["percentage"]) for
        e in data["entries"]
    ]

    # Metadata is already a Dict{String,Any} from JSON.parse
    metadata = get(data, "metadata", Dict{String,Any}())

    return ProfileData(
        DateTime(data["timestamp"]),
        data["total_samples"],
        entries,
        metadata,
    )
end

"""
    benchmark_optimization(name::String, workload_fn::Function;
                          save_dir="benchmarks",
                          metadata=Dict{String,Any}())

Collect and save a profile with automatic naming for benchmark tracking.

# Arguments
- `name`: Name for this benchmark (e.g., "baseline", "optimized_v1")
- `workload_fn`: Function to profile
- `save_dir`: Directory to save benchmark profiles (default: "benchmarks")
- `metadata`: Optional metadata to include

# Returns
- `ProfileData`: The collected profile

# Example
```julia
# Collect baseline
benchmark_optimization("baseline") do
    my_function()
end

# After changes
benchmark_optimization("optimized") do
    my_function()
end

# Compare
compare_benchmark_results("baseline", "optimized")
```
"""
function benchmark_optimization(
    name::String,
    workload_fn::Function;
    save_dir = "benchmarks",
    metadata = Dict{String,Any}(),
)
    # Add benchmark info to metadata
    bench_metadata = merge(metadata, Dict("benchmark_name" => name, "benchmark_dir" => save_dir))

    # Collect profile
    println("\n=== Benchmarking: $name ===")
    profile = collect_profile_data(workload_fn, metadata = bench_metadata)

    # Save with timestamp
    mkpath(save_dir)
    filename = joinpath(save_dir, "$(name).json")
    save_profile(profile, filename)

    return profile
end

"""
    compare_benchmark_results(name1::String, name2::String;
                             save_dir="benchmarks",
                             top_n=20)

Compare two benchmark profiles by name.

# Arguments
- `name1`: First benchmark name (baseline)
- `name2`: Second benchmark name (comparison)
- `save_dir`: Directory where benchmarks are saved (default: "benchmarks")
- `top_n`: Number of top changes to display (default: 20)

# Example
```julia
# After running benchmark_optimization("baseline") and benchmark_optimization("optimized")
compare_benchmark_results("baseline", "optimized")
```
"""
function compare_benchmark_results(
    name1::String,
    name2::String;
    save_dir = "benchmarks",
    top_n = 20,
)
    file1 = joinpath(save_dir, "$(name1).json")
    file2 = joinpath(save_dir, "$(name2).json")

    if !isfile(file1)
        error("Benchmark not found: $file1")
    end
    if !isfile(file2)
        error("Benchmark not found: $file2")
    end

    profile1 = load_profile(file1)
    profile2 = load_profile(file2)

    println("\n=== Comparing Benchmarks: $name1 vs $name2 ===\n")
    compare_profiles(profile1, profile2, top_n = top_n)
end

"""
    list_benchmarks(save_dir="benchmarks") -> Vector{String}

List all available benchmarks in the specified directory.

# Returns
- Vector of benchmark names (without .json extension)

# Example
```julia
benchmarks = list_benchmarks()
println("Available benchmarks: ", join(benchmarks, ", "))
```
"""
function list_benchmarks(save_dir = "benchmarks")
    if !isdir(save_dir)
        return String[]
    end

    files = readdir(save_dir)
    json_files = filter(f -> endswith(f, ".json"), files)
    return [replace(f, ".json" => "") for f in json_files]
end
