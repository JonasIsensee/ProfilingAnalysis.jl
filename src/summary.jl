"""
summary.jl

Summary and reporting functions for profile analysis.
"""

using Printf

"""
    print_entry_table(entries::Vector{ProfileEntry}; max_width=120)

Print entries in a formatted table.
"""
function print_entry_table(entries::Vector{ProfileEntry}; max_width = 120)
    if isempty(entries)
        println("No entries found.")
        return
    end

    println(
        @sprintf(
            "%-5s %-10s %-8s %-s",
            "Rank",
            "Samples",
            "% Total",
            "Function @ File:Line"
        )
    )
    println("-" ^ max_width)

    for (idx, entry) in enumerate(entries)
        # Format location
        location = "$(entry.func) @ $(entry.file):$(entry.line)"
        if length(location) > max_width - 30
            location = location[1:(max_width-33)] * "..."
        end

        println(
            @sprintf(
                "%-5d %-10d %-8.2f %s",
                idx,
                entry.samples,
                entry.percentage,
                location
            )
        )
    end
end

"""
    summarize_profile(profile::ProfileData;
                      filter_fn=nothing,
                      top_n=20,
                      title="Profile Summary")

Generate a summary of profile data.

# Arguments
- `profile`: Profile data to summarize
- `filter_fn`: Optional filter function to apply (e.g., to show only specific code)
- `top_n`: Number of top entries to show
- `title`: Title for the summary section
"""
function summarize_profile(
    profile::ProfileData;
    filter_fn = nothing,
    top_n = 20,
    title = "Profile Summary",
)
    println("=" ^ 80)
    println(title)
    println("=" ^ 80)
    println("Timestamp: ", profile.timestamp)
    println("Total samples: ", profile.total_samples)
    println("Unique locations: ", length(profile.entries))
    println()

    # Apply filter if provided
    entries = profile.entries
    if filter_fn !== nothing
        entries = filter(filter_fn, entries)
        total_filtered = sum(e.samples for e in entries)
        pct_filtered = 100.0 * total_filtered / profile.total_samples
        println(
            "Filtered samples: $total_filtered / $(profile.total_samples) ($(round(pct_filtered, digits=2))%)",
        )
        println()
    end

    # Show top entries
    println("=" ^ 80)
    println("Top $top_n Hotspots")
    println("=" ^ 80)
    println()

    display_count = min(top_n, length(entries))
    print_entry_table(entries[1:display_count])
    println()
end

"""
    generate_recommendations(entries::Vector{ProfileEntry}, patterns::Dict{String, Vector{String}})

Generate performance recommendations based on hotspots and user-defined patterns.

# Arguments
- `entries`: Profile entries to analyze
- `patterns`: Dict mapping category names to lists of pattern strings and recommendations

# Example
```julia
patterns = Dict(
    "Distance Calculations" => (
        patterns = ["distance", "metric"],
        recommendations = [
            "Add @inbounds for array access",
            "Use @simd for vectorization",
            "Consider early termination"
        ]
    ),
    "Search Operations" => (
        patterns = ["search", "knn"],
        recommendations = [
            "Optimize priority queue operations",
            "Reduce allocations in search loop"
        ]
    )
)
generate_recommendations(entries, patterns)
```
"""
function generate_recommendations(
    entries::Vector{ProfileEntry},
    patterns::Dict{String,T} where {T},
)
    println("=" ^ 80)
    println("Performance Recommendations")
    println("=" ^ 80)
    println()

    for (category, config) in patterns
        # Check if any entries match the patterns
        pattern_list = config[:patterns]
        has_match = any(
            entry -> any(
                p ->
                    contains(lowercase(entry.func), lowercase(p)) ||
                    contains(lowercase(entry.file), lowercase(p)),
                pattern_list,
            ),
            entries,
        )

        if has_match
            println("🔥 $(uppercase(category)) IN HOT PATH:")
            for rec in config[:recommendations]
                println("   • $rec")
            end
            println()
        end
    end
end

"""
    quick_summary(profile::ProfileData; top_n=5, filter_fn=nothing)

Generate a concise, LLM-friendly summary of profile data.
Shows only the most critical information with hints for deeper analysis.

# Arguments
- `profile`: Profile data to summarize
- `top_n`: Number of top hotspots to show (default: 5)
- `filter_fn`: Optional filter function (e.g., e -> !is_system_code(e))

# Example
```julia
profile = collect_profile_data(() -> my_function())
quick_summary(profile, filter_fn=e -> !is_system_code(e))
```
"""
function quick_summary(profile::ProfileData; top_n = 5, filter_fn = nothing)
    # Apply filter if provided
    entries = filter_fn === nothing ? profile.entries : filter(filter_fn, profile.entries)

    if isempty(entries)
        println("⚠️  No entries found (all filtered out)")
        return
    end

    display_count = min(top_n, length(entries))

    println("📊 PROFILE QUICK SUMMARY")
    println()
    println(
        "Total samples: $(profile.total_samples) | Unique locations: $(length(entries))",
    )

    if filter_fn !== nothing
        filtered_samples = sum(e.samples for e in entries)
        filtered_pct = round(100.0 * filtered_samples / profile.total_samples, digits = 1)
        println("Showing: $filtered_samples samples ($filtered_pct% of total)")
    end

    println()
    println("Top $display_count hotspots:")

    for (i, entry) in enumerate(entries[1:display_count])
        file_short = basename(entry.file)
        func_short = length(entry.func) > 40 ? entry.func[1:37] * "..." : entry.func
        println(
            @sprintf(
                "  %d. %5.1f%% | %s @ %s:%d",
                i,
                entry.percentage,
                func_short,
                file_short,
                entry.line
            )
        )
    end

    println()
    println("💡 Quick actions:")
    println("   • Use print_entry_table(entries) for detailed view")
    println("   • Use categorize_entries(profile.entries) for automatic grouping")
    println("   • Use generate_smart_recommendations() for optimization tips")
    println("   • Use query_by_file() or query_by_function() to drill down")
end

"""
    tldr_summary(profile::ProfileData; filter_fn=nothing) -> String

Generate an ultra-concise one-paragraph summary suitable for LLM context.
Returns a string summarizing the key bottlenecks.

# Arguments
- `profile`: Profile data to summarize
- `filter_fn`: Optional filter function

# Example
```julia
summary_text = tldr_summary(profile, filter_fn=e -> !is_system_code(e))
println(summary_text)
```
"""
function tldr_summary(profile::ProfileData; filter_fn = nothing)
    entries = filter_fn === nothing ? profile.entries : filter(filter_fn, profile.entries)

    if isempty(entries)
        return "No hotspots found (all entries filtered out)."
    end

    # Get top 3
    top_3 = entries[1:min(3, length(entries))]

    # Build summary
    parts = String[]
    push!(
        parts,
        "Profile has $(profile.total_samples) samples across $(length(entries)) locations.",
    )

    top_pct = sum(e.percentage for e in top_3)
    push!(parts, "Top $(length(top_3)) hotspots account for $(round(top_pct, digits=1))%:")

    for (i, entry) in enumerate(top_3)
        file_short = basename(entry.file)
        push!(
            parts,
            "$i) $(entry.func) ($(round(entry.percentage, digits=1))%) @ $file_short:$(entry.line)",
        )
    end

    return join(parts, " ")
end

"""
    compact_hotspots(entries::Vector{ProfileEntry}; max_display=10)

Print hotspots in a compact single-line format.

# Example
```julia
top_entries = query_top_n(profile, 10)
compact_hotspots(top_entries)
```
"""
function compact_hotspots(entries::Vector{ProfileEntry}; max_display = 10)
    if isempty(entries)
        println("No entries to display.")
        return
    end

    display_count = min(max_display, length(entries))

    for (i, entry) in enumerate(entries[1:display_count])
        file_short = basename(entry.file)
        println(
            @sprintf(
                "%2d. %5.1f%% %-40s %s:%d",
                i,
                entry.percentage,
                length(entry.func) > 40 ? entry.func[1:37] * "..." : entry.func,
                file_short,
                entry.line
            )
        )
    end
end

"""
    analyze_profile_concise(profile::ProfileData;
                           filter_fn=e -> !is_system_code(e),
                           top_n=5,
                           show_categories=true,
                           show_recommendations=true)

All-in-one concise analysis. Perfect for LLM agents.

Provides:
- Quick summary
- Top hotspots
- Category breakdown
- Smart recommendations

# Example
```julia
profile = collect_profile_data(() -> my_function())
analyze_profile_concise(profile)
```
"""
function analyze_profile_concise(
    profile::ProfileData;
    filter_fn = e -> !is_system_code(e),
    top_n = 5,
    show_categories = true,
    show_recommendations = true,
)
    println("=" ^ 70)
    println("CONCISE PROFILE ANALYSIS")
    println("=" ^ 70)
    println()

    # TL;DR
    println("📝 Summary:")
    println(tldr_summary(profile, filter_fn = filter_fn))
    println()

    # Top hotspots
    entries = filter_fn === nothing ? profile.entries : filter(filter_fn, profile.entries)
    display_count = min(top_n, length(entries))

    println("🔥 Top $display_count Hotspots:")
    compact_hotspots(entries, max_display = display_count)
    println()

    # Categories
    if show_categories
        cat_summary = quick_categorize(entries, profile.total_samples, min_percentage = 3.0)
        println("🏷️  $cat_summary")
        println()
    end

    # Recommendations
    if show_recommendations
        categorized = categorize_entries(entries)
        recs = generate_smart_recommendations(categorized, profile.total_samples)

        if !isempty(recs)
            println("💡 Recommendations:")
            for rec in recs
                println(rec)
            end
            println()
        end
    end

    println("=" ^ 70)
    println("💭 For more details:")
    println("   • quick_summary(profile) - Expanded view")
    println("   • query_by_file(profile, \"file.jl\") - File-specific")
    println("   • print_entry_table(entries) - Full table")
    println("=" ^ 70)
end
