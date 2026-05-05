using System.Net;
using System.Text;

namespace BluePosts.Automation;

internal sealed class ChangelogUpdater(string changelogPath, string latestChangelogPath)
{
    public async Task<bool> PrependEntryAsync(
        string tag,
        PostChangeSummary postChanges,
        IReadOnlyList<string> addonLuaFiles,
        bool generatedDataChanged,
        CancellationToken cancellationToken)
    {
        if (!File.Exists(changelogPath))
        {
            throw new InvalidOperationException($"Changelog not found: {changelogPath}");
        }

        var content = await File.ReadAllTextAsync(changelogPath, cancellationToken);
        var newline = content.Contains("\r\n", StringComparison.Ordinal) ? "\r\n" : "\n";
        var lines = content.Split(["\r\n", "\n"], StringSplitOptions.None);
        var headingIndex = Array.FindIndex(lines, line => line.Equals("# Changelog", StringComparison.Ordinal));

        var prefixLines = headingIndex >= 0
            ? lines.Take(headingIndex + 1).ToList()
            : [];

        var restIndex = headingIndex >= 0 ? headingIndex + 1 : 0;
        while (restIndex < lines.Length && string.IsNullOrWhiteSpace(lines[restIndex]))
        {
            restIndex++;
        }

        var updatedLines = new List<string>(lines.Length + postChanges.AddedPosts.Count + postChanges.ModifiedPosts.Count + postChanges.RemovedPosts.Count + addonLuaFiles.Count + 8);
        updatedLines.AddRange(prefixLines);
        updatedLines.AddRange(BuildEntryLines(tag, postChanges, addonLuaFiles, generatedDataChanged, includeLeadingBlank: updatedLines.Count > 0));

        if (restIndex < lines.Length)
        {
            updatedLines.Add(string.Empty);
            updatedLines.AddRange(lines.Skip(restIndex));
        }

        var updatedContent = string.Join(newline, updatedLines) + newline;
        await File.WriteAllTextAsync(changelogPath, updatedContent, new UTF8Encoding(false), cancellationToken);

        var latestContent = string.Join(newline, BuildEntryLines(tag, postChanges, addonLuaFiles, generatedDataChanged, includeLeadingBlank: false)) + newline;
        await File.WriteAllTextAsync(latestChangelogPath, latestContent, new UTF8Encoding(false), cancellationToken);
        return true;
    }

    private static List<string> BuildEntryLines(
        string tag,
        PostChangeSummary postChanges,
        IReadOnlyList<string> addonLuaFiles,
        bool generatedDataChanged,
        bool includeLeadingBlank)
    {
        var lines = new List<string>(postChanges.AddedPosts.Count + postChanges.ModifiedPosts.Count + postChanges.RemovedPosts.Count + addonLuaFiles.Count + 8);
        if (includeLeadingBlank)
        {
            lines.Add(string.Empty);
        }

        lines.Add($"## {tag}");

        AppendPostChangeLines(lines, "Added", postChanges.AddedPosts);
        AppendPostChangeLines(lines, "Updated", postChanges.ModifiedPosts);
        AppendPostChangeLines(lines, "Removed", postChanges.RemovedPosts);

        if (addonLuaFiles.Count > 0)
        {
            lines.Add($"- Addon Lua changes: {FormatAddonLuaFiles(addonLuaFiles)}.");
        }

        if (lines.Count == (includeLeadingBlank ? 2 : 1))
        {
            lines.Add(generatedDataChanged
                ? "- Updated bundled blue post data."
                : "- Updated addon release files.");
        }

        return lines;
    }

    private static void AppendPostChangeLines(
        List<string> lines,
        string action,
        IReadOnlyList<PostSummary> posts)
    {
        if (posts.Count == 0)
        {
            return;
        }

        var seenTitles = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var listedTitles = 0;
        var hiddenTitles = 0;

        foreach (var post in posts)
        {
            var title = GetDisplayTitle(post);
            if (!seenTitles.Add(title))
            {
                continue;
            }

            if (listedTitles < 6)
            {
                lines.Add($"- {action}: {title}");
                listedTitles++;
                continue;
            }

            hiddenTitles++;
        }

        if (hiddenTitles > 0)
        {
            lines.Add($"- {action}: {hiddenTitles} more post{(hiddenTitles == 1 ? string.Empty : "s")}.");
        }
    }

    private static string GetDisplayTitle(PostSummary post)
    {
        var title = GetMarkdownText(post.Title);
        return title.Length > 0 ? title : post.Id;
    }

    private static string FormatAddonLuaFiles(IReadOnlyList<string> addonLuaFiles)
    {
        var uniqueFiles = addonLuaFiles
            .Select(path => path.Replace('\\', '/'))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .OrderBy(path => path, StringComparer.OrdinalIgnoreCase)
            .ToList();

        var visibleFiles = uniqueFiles.Take(5).ToList();
        return uniqueFiles.Count > visibleFiles.Count
            ? $"{string.Join(", ", visibleFiles)}, +{uniqueFiles.Count - visibleFiles.Count} more"
            : string.Join(", ", visibleFiles);
    }

    private static string GetMarkdownText(string value)
    {
        var decoded = WebUtility.HtmlDecode(value) ?? string.Empty;
        decoded = decoded.Replace('\u00a0', ' ');
        return string.Join(' ', decoded.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries));
    }
}
