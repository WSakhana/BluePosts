using System.Text;

namespace BluePosts.Automation;

internal sealed class ChangelogUpdater(string changelogPath, string latestChangelogPath)
{
    public async Task<bool> PrependEntryAsync(
        string tag,
        IReadOnlyList<NewPostSummary> newPosts,
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

        var updatedLines = new List<string>(lines.Length + newPosts.Count + 4);
        updatedLines.AddRange(prefixLines);
        updatedLines.AddRange(BuildEntryLines(tag, newPosts, includeLeadingBlank: updatedLines.Count > 0));

        if (restIndex < lines.Length)
        {
            updatedLines.Add(string.Empty);
            updatedLines.AddRange(lines.Skip(restIndex));
        }

        var updatedContent = string.Join(newline, updatedLines) + newline;
        await File.WriteAllTextAsync(changelogPath, updatedContent, new UTF8Encoding(false), cancellationToken);

        var latestContent = string.Join(newline, BuildEntryLines(tag, newPosts, includeLeadingBlank: false)) + newline;
        await File.WriteAllTextAsync(latestChangelogPath, latestContent, new UTF8Encoding(false), cancellationToken);
        return true;
    }

    private static List<string> BuildEntryLines(string tag, IReadOnlyList<NewPostSummary> newPosts, bool includeLeadingBlank)
    {
        var lines = new List<string>(newPosts.Count + 3);
        if (includeLeadingBlank)
        {
            lines.Add(string.Empty);
        }

        lines.Add($"## {tag}");

        if (newPosts.Count > 0)
        {
            lines.Add($"- Added {newPosts.Count} new blue post{(newPosts.Count == 1 ? string.Empty : "s")} to the in-game reader.");

            var seenTitles = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (var newPost in newPosts)
            {
                var title = newPost.Title.Trim();
                if (title.Length == 0 || !seenTitles.Add(title))
                {
                    continue;
                }

                lines.Add($"- {title}");
            }
        }

        return lines;
    }
}
