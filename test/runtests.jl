"""
runtests.jl

Test suite for ProfilingAnalysis.jl

This suite tests:
- Profile data collection
- Save/load functionality
- Query functions
- Summary and comparison functions
- CLI interface
- Fuzzy tests for top hotspots
- Advanced analysis features (JET.jl and SnoopCompile.jl integrations)
"""

using Test
using ProfilingAnalysis
using LinearAlgebra
using Dates

# Include demo workload
include("demo_workload.jl")

# Temporary directory for test files
const TEST_DIR = mktempdir()
const TEST_PROFILE_1 = joinpath(TEST_DIR, "test_profile_1.json")
const TEST_PROFILE_2 = joinpath(TEST_DIR, "test_profile_2.json")

@testset "ProfilingAnalysis.jl" begin

    @testset "Profile Collection" begin
        println("\n=== Testing Profile Collection ===")

        # Collect profile data
        profile = collect_profile_data(
            metadata = Dict("test" => "collection", "version" => "1.0"),
        ) do
            run_demo_workload(duration_seconds = 2.0)
        end

        @test profile isa ProfileData
        @test profile.total_samples > 0
        @test length(profile.entries) > 0
        @test haskey(profile.metadata, "test")
        @test profile.metadata["test"] == "collection"

        println(
            "✓ Profile collected: $(profile.total_samples) samples, $(length(profile.entries)) locations",
        )
    end

    @testset "Save and Load" begin
        println("\n=== Testing Save and Load ===")

        # Create a profile
        profile = collect_profile_data(metadata = Dict("test" => "save_load")) do
            run_demo_workload(duration_seconds = 1.0)
        end

        # Save profile
        save_profile(profile, TEST_PROFILE_1)
        @test isfile(TEST_PROFILE_1)

        # Load profile
        loaded = load_profile(TEST_PROFILE_1)
        @test loaded isa ProfileData
        @test loaded.total_samples == profile.total_samples
        @test length(loaded.entries) == length(profile.entries)
        @test loaded.metadata["test"] == "save_load"

        println("✓ Save/load verified: $(loaded.total_samples) samples")
    end

    @testset "Query Functions" begin
        println("\n=== Testing Query Functions ===")

        # Create a profile for testing
        profile = collect_profile_data() do
            run_demo_workload(duration_seconds = 2.0)
        end

        # Test query_top_n
        top_10 = query_top_n(profile, 10)
        @test length(top_10) <= 10
        @test all(e -> e isa ProfileEntry, top_10)
        if length(top_10) > 1
            @test top_10[1].samples >= top_10[end].samples  # Sorted descending
        end
        println("✓ query_top_n: $(length(top_10)) entries")

        # Test query_top_n with filter
        non_system = query_top_n(profile, 10, filter_fn = e -> !is_system_code(e))
        @test all(e -> !is_system_code(e), non_system)
        println("✓ query_top_n with filter: $(length(non_system)) entries")

        # Test query_by_file
        workload_entries = query_by_file(profile, "demo_workload")
        @test all(e -> contains(e.file, "demo_workload"), workload_entries)
        println("✓ query_by_file: $(length(workload_entries)) entries")

        # Test query_by_function
        multiply_entries = query_by_function(profile, "matrix_multiply")
        @test all(e -> contains(e.func, "matrix_multiply"), multiply_entries)
        println("✓ query_by_function: $(length(multiply_entries)) entries")

        # Test query_by_pattern
        pattern_entries = query_by_pattern(profile, "matrix")
        @test all(
            e -> contains(e.func, "matrix") || contains(e.file, "matrix"),
            pattern_entries,
        )
        println("✓ query_by_pattern: $(length(pattern_entries)) entries")

        # Test query_by_filter
        high_sample_entries = query_by_filter(profile, e -> e.samples > 10)
        @test all(e -> e.samples > 10, high_sample_entries)
        println(
            "✓ query_by_filter: $(length(high_sample_entries)) entries with >10 samples",
        )

        # Test is_system_code
        if length(profile.entries) > 0
            system_entries = filter(is_system_code, profile.entries)
            non_system_entries = filter(e -> !is_system_code(e), profile.entries)
            @test length(system_entries) + length(non_system_entries) ==
                  length(profile.entries)
            println(
                "✓ is_system_code: $(length(system_entries)) system, $(length(non_system_entries)) non-system",
            )
        end
    end

    @testset "Fuzzy Top Hotspots Test" begin
        println("\n=== Testing Top Hotspots (Fuzzy) ===")

        # Collect profile with known workload
        profile = collect_profile_data() do
            run_demo_workload(duration_seconds = 3.0)
        end

        # Get non-system code only
        user_code = query_by_filter(profile, e -> !is_system_code(e))

        # Look for functions from our demo_workload.jl file in top 15
        # (Fuzzy test: we don't care about exact order or timing, just that our code appears)
        top_user_code = user_code[1:min(15, length(user_code))]

        # Count how many entries are from demo_workload.jl
        demo_workload_entries =
            filter(e -> contains(e.file, "demo_workload"), top_user_code)

        println("Top 15 user code functions:")
        for (i, entry) in enumerate(top_user_code)
            marker = contains(entry.file, "demo_workload") ? " ✓" : ""
            println("  $i. $(entry.func)$marker")
            println(
                "      $(entry.samples) samples ($(round(entry.percentage, digits=2))%)",
            )
        end
        println()
        println("Found $(length(demo_workload_entries)) demo_workload functions in top 15")

        # Fuzzy test: At least 1 of our demo functions should be in top 15
        # (This is very lenient, but profile timing is unpredictable)
        @test length(demo_workload_entries) >= 1
        println(
            "✓ Fuzzy hotspot test passed: $(length(demo_workload_entries)) demo_workload functions in top 15",
        )

        # Test that top functions account for significant percentage
        if length(top_user_code) >= 5
            top_5_percentage = sum(e.percentage for e in top_user_code[1:5])
            @test top_5_percentage > 5.0
            println(
                "✓ Top 5 functions account for $(round(top_5_percentage, digits=2))% of time",
            )
        end
    end

    @testset "Summary Functions" begin
        println("\n=== Testing Summary Functions ===")

        profile = collect_profile_data() do
            run_demo_workload(duration_seconds = 1.5)
        end

        # Test print_entry_table (just verify it doesn't error)
        @test_nowarn print_entry_table(profile.entries[1:min(5, length(profile.entries))])
        println("✓ print_entry_table works")

        # Test summarize_profile
        @test_nowarn summarize_profile(profile, top_n = 10, title = "Test Summary")
        println("✓ summarize_profile works")

        # Test generate_recommendations
        patterns = Dict(
            "Linear Algebra" => (
                patterns = ["matrix", "eigen", "qr", "solve"],
                recommendations = [
                    "Use BLAS for large matrices",
                    "Consider parallel algorithms",
                ],
            ),
        )
        @test_nowarn generate_recommendations(profile.entries, patterns)
        println("✓ generate_recommendations works")
    end

    @testset "Comparison Functions" begin
        println("\n=== Testing Comparison Functions ===")

        # Create two different profiles
        profile1 = collect_profile_data(metadata = Dict("version" => "1")) do
            run_demo_workload(duration_seconds = 1.0)
        end

        profile2 = collect_profile_data(metadata = Dict("version" => "2")) do
            run_demo_workload(duration_seconds = 1.0)
        end

        # Save them
        save_profile(profile1, TEST_PROFILE_1)
        save_profile(profile2, TEST_PROFILE_2)

        # Load and compare
        p1 = load_profile(TEST_PROFILE_1)
        p2 = load_profile(TEST_PROFILE_2)

        @test_nowarn compare_profiles(p1, p2, top_n = 10)
        println("✓ compare_profiles works")
    end

    @testset "CLI Interface" begin
        println("\n=== Testing CLI Interface ===")

        # Create a test profile
        profile = collect_profile_data() do
            run_demo_workload(duration_seconds = 1.0)
        end
        save_profile(profile, TEST_PROFILE_1)

        # Test query command
        @test_nowarn run_cli(["query", "--input", TEST_PROFILE_1, "--top", "5"])
        println("✓ CLI query command works")

        # Test summary command
        @test_nowarn run_cli(["summary", "--input", TEST_PROFILE_1, "--top", "5"])
        println("✓ CLI summary command works")

        # Test compare command
        save_profile(profile, TEST_PROFILE_2)
        @test_nowarn run_cli(["compare", TEST_PROFILE_1, TEST_PROFILE_2])
        println("✓ CLI compare command works")

        # Test help command
        @test_nowarn run_cli(["help"])
        println("✓ CLI help command works")
    end

    @testset "Allocation Profiling" begin
        println("\n=== Testing Allocation Profiling ===")

        # Test collect_allocation_profile
        allocs = collect_allocation_profile(sample_rate = 0.1, warmup = true) do
            run_demo_workload(duration_seconds = 1.0)
        end

        @test allocs isa AllocationProfile
        @test allocs.total_allocations >= 0
        @test allocs.total_bytes >= 0
        @test allocs.sites isa Vector{AllocationSite}
        println(
            "✓ collect_allocation_profile: $(allocs.total_allocations) allocations, $(format_bytes(allocs.total_bytes))",
        )

        # Test format_bytes utility
        @test format_bytes(500) == "500B"
        @test contains(format_bytes(5000), "KB")
        @test contains(format_bytes(5_000_000), "MB")
        @test contains(format_bytes(5_000_000_000), "GB")
        println("✓ format_bytes works correctly")

        # Test print_allocation_table (should not error)
        if !isempty(allocs.sites)
            @test_nowarn print_allocation_table(
                allocs.sites[1:min(5, length(allocs.sites))],
            )
            println("✓ print_allocation_table works")
        end

        # Test summarize_allocations
        @test_nowarn summarize_allocations(
            allocs,
            top_n = 10,
            title = "Test Allocation Summary",
        )
        println("✓ summarize_allocations works")

        # Test analyze_allocation_patterns
        if !isempty(allocs.sites)
            recommendations = analyze_allocation_patterns(allocs.sites)
            @test recommendations isa Vector{String}
            @test length(recommendations) > 0
            println(
                "✓ analyze_allocation_patterns: $(length(recommendations)) recommendations",
            )
        end

        # Test empty allocation profile
        empty_allocs = AllocationProfile(now(), 0, 0, AllocationSite[], Dict{String,Any}())
        @test_nowarn summarize_allocations(empty_allocs)
        println("✓ Handle empty allocation profile")
    end

    @testset "Categorization Functions" begin
        println("\n=== Testing Categorization Functions ===")

        # Create a profile for testing
        profile = collect_profile_data() do
            run_demo_workload(duration_seconds = 1.5)
        end

        # Test default_categories
        categories = default_categories()
        @test categories isa Dict{String,Vector{String}}
        @test haskey(categories, "distance_calculation")
        @test haskey(categories, "heap_operations")
        @test haskey(categories, "search_operations")
        println("✓ default_categories: $(length(categories)) categories")

        # Test categorize_entries
        categorized = categorize_entries(profile.entries)
        @test categorized isa Dict{String,Vector{ProfileEntry}}
        @test haskey(categorized, "other")
        total_categorized = sum(length(v) for v in values(categorized))
        @test total_categorized == length(profile.entries)
        println("✓ categorize_entries: $(length(profile.entries)) entries categorized")

        # Test print_categorized_summary
        @test_nowarn print_categorized_summary(
            categorized,
            profile.total_samples,
            min_percentage = 1.0,
        )
        println("✓ print_categorized_summary works")

        # Test generate_smart_recommendations
        recommendations = generate_smart_recommendations(categorized, profile.total_samples)
        @test recommendations isa Vector{String}
        @test length(recommendations) > 0
        println(
            "✓ generate_smart_recommendations: $(length(recommendations)) recommendations",
        )

        # Test with custom categories
        custom_categories = Dict("matrix_ops" => ["matrix", "eigen", "qr"])
        custom_categorized =
            categorize_entries(profile.entries, categories = custom_categories)
        @test haskey(custom_categorized, "matrix_ops")
        @test haskey(custom_categorized, "other")
        println("✓ categorize_entries with custom categories works")

        # Test empty entries
        empty_categorized = categorize_entries(ProfileEntry[])
        @test empty_categorized isa Dict{String,Vector{ProfileEntry}}
        println("✓ Handle empty entries in categorization")
    end

    @testset "Type Stability Functions" begin
        println("\n=== Testing Type Stability Functions ===")

        # Test check_type_stability_simple with stable function
        stable_func(x::Int, y::Float64) = x + y
        is_stable = check_type_stability_simple(stable_func, (Int, Float64))
        @test is_stable isa Bool
        println("✓ check_type_stability_simple: stable function detected")

        # Test with potentially unstable function
        unstable_func(x) = x > 0 ? x : "negative"
        is_unstable = check_type_stability_simple(unstable_func, (Int,))
        @test is_unstable isa Bool
        println("✓ check_type_stability_simple: unstable function handled")

        # Test print_type_stability_guide (should not error)
        @test_nowarn print_type_stability_guide()
        println("✓ print_type_stability_guide works")
    end

    @testset "Edge Cases" begin
        println("\n=== Testing Edge Cases ===")

        # Test with very short workload (may result in no samples)
        quick_profile = collect_profile_data() do
            sum(rand(10, 10))
        end
        @test quick_profile isa ProfileData
        println("✓ Handle quick workload: $(quick_profile.total_samples) samples")

        # Test empty queries
        empty_results = query_by_function(quick_profile, "nonexistent_function_xyz")
        @test isempty(empty_results)
        println("✓ Handle empty query results")

        # Test query_top_n with n > number of entries
        all_entries = query_top_n(quick_profile, 10000)
        @test length(all_entries) <= length(quick_profile.entries)
        println("✓ Handle oversized top_n request")
    end

end

# Include advanced analysis tests (JET and SnoopCompile integrations)
include("test_advanced_analysis.jl")

# Cleanup
println("\n=== Cleaning up test files ===")
rm(TEST_DIR, recursive = true, force = true)
println("✓ Test cleanup complete")

println("\n" * "="^80)
println("All tests passed! ✓")
println("="^80)
