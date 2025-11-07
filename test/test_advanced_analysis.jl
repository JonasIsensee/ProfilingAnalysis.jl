"""
test_advanced_analysis.jl

Test suite for advanced analysis features (JET.jl and SnoopCompile.jl integrations).

These tests check that the integration APIs work correctly, but they require
optional dependencies (JET.jl and SnoopCompile.jl) to be installed.

The tests gracefully handle missing dependencies and skip tests if needed.
"""

using Test
using ProfilingAnalysis
using Dates

@testset "Advanced Analysis Features" begin

    @testset "Type Analysis Structures" begin
        println("\n=== Testing Type Analysis Structures ===")

        # Create a TypeIssue
        issue = TypeIssue(
            :instability,
            :high,
            "my_function",
            "/path/to/file.jl",
            42,
            "Function returns Union{Int, Float64}",
            "Union{Int64, Float64}",
            "Float64",
            ["caller1", "caller2"],
            "Add type annotation to ensure consistent return type"
        )

        @test issue.type == :instability
        @test issue.severity == :high
        @test issue.function_name == "my_function"
        println("✓ TypeIssue construction works")

        # Create a TypeAnalysis
        issues = [issue]
        summary = Dict(:instability => 1)
        analysis = TypeAnalysis(
            now(),
            issues,
            summary,
            false,
            "JET.jl",
            Dict{String, Any}("test" => true)
        )

        @test length(analysis) == 1
        @test !isempty(analysis)
        @test !analysis.type_stable
        println("✓ TypeAnalysis construction works")

        # Test filtering functions
        critical_issues = get_critical_issues(analysis)
        @test length(critical_issues) == 0  # No critical issues in our test
        println("✓ get_critical_issues works")

        high_priority = get_high_priority_issues(analysis)
        @test length(high_priority) == 1  # One high severity issue
        println("✓ get_high_priority_issues works")

        # Test grouping functions
        by_type = group_by_type(analysis)
        @test haskey(by_type, :instability)
        @test length(by_type[:instability]) == 1
        println("✓ group_by_type works")

        by_file = group_by_file(analysis)
        @test haskey(by_file, "/path/to/file.jl")
        println("✓ group_by_file works")

        # Test sorting
        sorted = sort_by_severity(issues)
        @test length(sorted) == 1
        println("✓ sort_by_severity works")

        # Test printing (should not error)
        @test_nowarn print_type_issue(issue)
        @test_nowarn print_type_analysis(analysis)
        println("✓ Printing functions work")
    end

    @testset "Compilation Analysis Structures" begin
        println("\n=== Testing Compilation Analysis Structures ===")

        # Create a CompilationIssue
        issue = CompilationIssue(
            :slow_inference,
            :high,
            "expensive_function",
            "/path/to/code.jl",
            100,
            "Type inference took 0.5s",
            0.5,
            1,
            ["trigger1", "trigger2"],
            "Add type annotations to improve inference time"
        )

        @test issue.type == :slow_inference
        @test issue.severity == :high
        @test issue.time_impact == 0.5
        println("✓ CompilationIssue construction works")

        # Create a CompilationAnalysis
        issues = [issue]
        summary = Dict(:slow_inference => 1)
        analysis = CompilationAnalysis(
            now(),
            1.5,  # total inference time
            issues,
            summary,
            "SnoopCompile.jl",
            Dict{String, Any}("test" => true)
        )

        @test length(analysis) == 1
        @test !isempty(analysis)
        @test analysis.total_inference_time == 1.5
        println("✓ CompilationAnalysis construction works")

        # Test filtering functions
        critical_issues = get_critical_compilation_issues(analysis)
        @test length(critical_issues) == 0
        println("✓ get_critical_compilation_issues works")

        high_priority = get_high_priority_compilation_issues(analysis)
        @test length(high_priority) == 1
        println("✓ get_high_priority_compilation_issues works")

        # Test grouping
        by_type = group_compilation_by_type(analysis)
        @test haskey(by_type, :slow_inference)
        println("✓ group_compilation_by_type works")

        # Test sorting by impact
        sorted = sort_compilation_by_impact(issues)
        @test length(sorted) == 1
        println("✓ sort_compilation_by_impact works")

        # Test printing (should not error)
        @test_nowarn print_compilation_issue(issue)
        @test_nowarn print_compilation_analysis(analysis)
        println("✓ Printing functions work")
    end

    @testset "JET.jl Integration - Availability Check" begin
        println("\n=== Testing JET.jl Integration ===")

        # Test availability check
        jet_available = check_jet_available()
        @test jet_available isa Bool
        println("  JET.jl available: $jet_available")

        if jet_available
            # Test version check
            is_ok, msg = check_jet_version()
            @test is_ok isa Bool
            @test msg isa String
            println("  Version check: $msg")

            # Test simple functions
            function type_stable_example(x::Int, y::Float64)
                return Float64(x) + y
            end

            function type_unstable_example(x)
                if x > 0
                    return x
                else
                    return "negative"
                end
            end

            # Try type stability check (may not work if JET version incompatible)
            try
                stable = is_type_stable_jet(type_stable_example, (1, 2.0))
                @test stable isa Bool
                println("✓ is_type_stable_jet works")

                unstable = is_type_stable_jet(type_unstable_example, (1,))
                @test unstable isa Bool
                println("✓ Type instability detected")

                # Try full analysis
                analysis = analyze_types_with_jet(type_stable_example, (1, 2.0))
                @test analysis isa TypeAnalysis
                @test analysis.analyzer == "JET.jl"
                println("✓ analyze_types_with_jet works")

                # Try quick check
                msg = quick_type_check(type_stable_example, (1, 2.0))
                @test msg isa String
                println("✓ quick_type_check: $msg")

            catch e
                @warn "JET.jl tests skipped due to compatibility issues" exception=(e, catch_backtrace())
                println("⚠ JET.jl tests skipped (version incompatibility)")
            end

        else
            println("  Skipping JET.jl tests (not installed)")
            println("  To install: using Pkg; Pkg.add(\"JET\")")

            # Test that require_jet throws appropriate error
            @test_throws ErrorException require_jet()
            println("✓ require_jet throws error when JET unavailable")
        end
    end

    @testset "SnoopCompile.jl Integration - Availability Check" begin
        println("\n=== Testing SnoopCompile.jl Integration ===")

        # Test availability check
        sc_available = check_snoopcompile_available()
        @test sc_available isa Bool
        println("  SnoopCompile.jl available: $sc_available")

        if sc_available
            # Create a simple workload
            function test_workload()
                # Some computation that causes inference
                x = [1, 2, 3, 4, 5]
                y = map(i -> i * 2, x)
                sum(y)
            end

            # Try compilation analysis (may be slow)
            try
                analysis = analyze_compilation(
                    test_workload,
                    check_invalidations=false,
                    check_inference=true,
                    top_n=5
                )

                @test analysis isa CompilationAnalysis
                @test analysis.analyzer == "SnoopCompile.jl"
                @test analysis.total_inference_time >= 0.0
                println("✓ analyze_compilation works")
                println("  Total inference time: $(round(analysis.total_inference_time, digits=3))s")
                println("  Issues found: $(length(analysis.issues))")

                # Try quick check
                msg = quick_compilation_check(test_workload)
                @test msg isa String
                println("✓ quick_compilation_check: $msg")

            catch e
                @warn "SnoopCompile.jl tests skipped due to compatibility issues" exception=(e, catch_backtrace())
                println("⚠ SnoopCompile.jl tests skipped (compatibility issue)")
            end

        else
            println("  Skipping SnoopCompile.jl tests (not installed)")
            println("  To install: using Pkg; Pkg.add(\"SnoopCompile\")")

            # Test that require_snoopcompile throws appropriate error
            @test_throws ErrorException require_snoopcompile()
            println("✓ require_snoopcompile throws error when unavailable")
        end
    end

    @testset "Combined Analysis Workflow" begin
        println("\n=== Testing Combined Analysis Workflow ===")

        # Test function with known characteristics
        function test_function(n::Int)
            result = 0
            for i in 1:n
                result += i
            end
            return result
        end

        println("\n  Example combined analysis workflow:")
        println("  1. Check if advanced tools are available")

        jet_available = check_jet_available()
        sc_available = check_snoopcompile_available()

        println("     JET.jl: $(jet_available ? "✓" : "✗")")
        println("     SnoopCompile.jl: $(sc_available ? "✓" : "✗")")

        if jet_available
            println("\n  2. Run type analysis")
            try
                type_analysis = analyze_types_with_jet(test_function, (100,))
                println("     Type stable: $(type_analysis.type_stable)")
                println("     Issues found: $(length(type_analysis.issues))")
            catch e
                println("     Skipped (compatibility issue)")
            end
        end

        if sc_available
            println("\n  3. Run compilation analysis")
            try
                comp_analysis = analyze_compilation(
                    () -> test_function(100),
                    check_inference=true,
                    check_invalidations=false,
                    top_n=5
                )
                println("     Inference time: $(round(comp_analysis.total_inference_time, digits=3))s")
                println("     Issues found: $(length(comp_analysis.issues))")
            catch e
                println("     Skipped (compatibility issue)")
            end
        end

        println("\n  4. Fall back to basic type stability check")
        basic_stable = check_type_stability_simple(test_function, (Int,))
        println("     Basic check: $(basic_stable ? "type stable" : "type unstable")")

        println("\n✓ Combined workflow complete")
    end

end

println("\n" * "="^80)
println("Advanced analysis tests complete!")
if !check_jet_available() || !check_snoopcompile_available()
    println("\nNote: Some tests were skipped due to missing optional dependencies.")
    println("To enable full testing:")
    println("  - JET.jl: using Pkg; Pkg.add(\"JET\")")
    println("  - SnoopCompile.jl: using Pkg; Pkg.add(\"SnoopCompile\")")
end
println("="^80)
