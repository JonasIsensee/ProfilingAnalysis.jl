"""
export.jl

Export functions for saving profile data in various formats.
"""

using Printf
using Dates

"""
    export_to_csv(profile::ProfileData, filename::String;
                  filter_fn=nothing,
                  top_n=nothing)

Export profile data to CSV format.

# Arguments
- `profile`: Profile data to export
- `filename`: Output CSV file path
- `filter_fn`: Optional filter function to apply before export
- `top_n`: Optional limit on number of entries to export

# Example
```julia
# Export all user code to CSV
export_to_csv(
    profile,
    "hotspots.csv",
    filter_fn=e -> !is_system_code(e)
)

# Export top 50 hotspots
export_to_csv(profile, "top50.csv", top_n=50)
```
"""
function export_to_csv(
    profile::ProfileData,
    filename::String;
    filter_fn = nothing,
    top_n = nothing,
)
    # Apply filter if provided
    entries = profile.entries
    if filter_fn !== nothing
        entries = filter(filter_fn, entries)
    end

    # Limit to top N if specified
    if top_n !== nothing
        entries = entries[1:min(top_n, length(entries))]
    end

    # Create directory if needed
    mkpath(dirname(filename))

    # Write CSV
    open(filename, "w") do io
        # Header
        println(io, "Rank,Function,File,Line,Samples,Percentage")

        # Data rows
        for (idx, entry) in enumerate(entries)
            # Escape quotes in strings
            func = replace(entry.func, "\"" => "\"\"")
            file = replace(entry.file, "\"" => "\"\"")

            println(
                io,
                "$(idx),\"$(func)\",\"$(file)\",$(entry.line),$(entry.samples),$(entry.percentage)",
            )
        end
    end

    println("Exported $(length(entries)) entries to: $filename")
end

"""
    export_to_markdown(profile::ProfileData, filename::String;
                      filter_fn=nothing,
                      top_n=20,
                      include_summary=true,
                      include_recommendations=false)

Export profile data as a Markdown report.

# Arguments
- `profile`: Profile data to export
- `filename`: Output Markdown file path
- `filter_fn`: Optional filter function
- `top_n`: Number of top entries to include (default: 20)
- `include_summary`: Include summary section (default: true)
- `include_recommendations`: Include smart recommendations (default: false)

# Example
```julia
# Full markdown report
export_to_markdown(
    profile,
    "profile_report.md",
    filter_fn=e -> !is_system_code(e),
    include_recommendations=true
)
```
"""
function export_to_markdown(
    profile::ProfileData,
    filename::String;
    filter_fn = nothing,
    top_n = 20,
    include_summary = true,
    include_recommendations = false,
)
    # Apply filter
    entries = profile.entries
    if filter_fn !== nothing
        entries = filter(filter_fn, entries)
    end

    # Limit entries
    display_entries = entries[1:min(top_n, length(entries))]

    # Create directory
    mkpath(dirname(filename))

    # Write markdown
    open(filename, "w") do io
        # Title
        println(io, "# Profile Analysis Report")
        println(io, "")
        println(io, "**Generated:** $(now())")
        println(io, "**Profile Timestamp:** $(profile.timestamp)")
        println(io, "")

        # Summary section
        if include_summary
            println(io, "## Summary")
            println(io, "")
            println(io, "- **Total Samples:** $(profile.total_samples)")
            println(io, "- **Unique Locations:** $(length(profile.entries))")

            if filter_fn !== nothing
                filtered_samples = sum(e.samples for e in entries)
                filtered_pct = round(100.0 * filtered_samples / profile.total_samples, digits = 1)
                println(io, "- **Filtered Samples:** $filtered_samples ($filtered_pct%)")
            end

            println(io, "")
        end

        # Hotspots table
        println(io, "## Top $top_n Hotspots")
        println(io, "")
        println(io, "| Rank | Function | File:Line | Samples | % Time |")
        println(io, "|------|----------|-----------|---------|--------|")

        for (idx, entry) in enumerate(display_entries)
            func_short = length(entry.func) > 40 ? entry.func[1:37] * "..." : entry.func
            file_short = basename(entry.file)
            location = "$file_short:$(entry.line)"
            pct_str = @sprintf("%.2f%%", entry.percentage)

            println(
                io,
                "| $idx | `$func_short` | `$location` | $(entry.samples) | $pct_str |",
            )
        end

        println(io, "")

        # Recommendations
        if include_recommendations
            println(io, "## Recommendations")
            println(io, "")

            categorized = categorize_entries(entries)
            recs = generate_smart_recommendations(categorized, profile.total_samples)

            if !isempty(recs)
                for rec in recs
                    println(io, rec)
                end
            else
                println(io, "No specific recommendations generated.")
            end

            println(io, "")
        end

        # Footer
        println(io, "---")
        println(io, "")
        println(io, "*Generated by ProfilingAnalysis.jl*")
    end

    println("Markdown report exported to: $filename")
end

"""
    export_allocations_to_csv(profile::AllocationProfile, filename::String;
                             filter_fn=nothing,
                             top_n=nothing)

Export allocation profile data to CSV format.

# Arguments
- `profile`: Allocation profile to export
- `filename`: Output CSV file path
- `filter_fn`: Optional filter function for allocation sites
- `top_n`: Optional limit on number of sites to export

# Example
```julia
# Export all allocation sites
export_allocations_to_csv(allocs, "allocations.csv")

# Export top 100 by bytes
export_allocations_to_csv(allocs, "top_allocations.csv", top_n=100)
```
"""
function export_allocations_to_csv(
    profile::AllocationProfile,
    filename::String;
    filter_fn = nothing,
    top_n = nothing,
)
    # Apply filter
    sites = profile.sites
    if filter_fn !== nothing
        sites = filter(filter_fn, sites)
    end

    # Limit to top N
    if top_n !== nothing
        sites = sites[1:min(top_n, length(sites))]
    end

    # Create directory
    mkpath(dirname(filename))

    # Write CSV
    open(filename, "w") do io
        # Header
        println(io, "Rank,Function,File,Line,Count,TotalBytes,AvgBytes")

        # Data rows
        for (idx, site) in enumerate(sites)
            func = replace(site.func, "\"" => "\"\"")
            file = replace(site.file, "\"" => "\"\"")

            println(
                io,
                "$(idx),\"$(func)\",\"$(file)\",$(site.line),$(site.count),$(site.total_bytes),$(site.avg_bytes)",
            )
        end
    end

    println("Exported $(length(sites)) allocation sites to: $filename")
end
