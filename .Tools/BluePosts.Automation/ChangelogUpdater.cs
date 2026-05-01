using System.Text;

namespace BluePosts.Automation;

internal sealed class ChangelogUpdater(string changelogPath)
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
        if (updatedLines.Count > 0)
        {
            updatedLines.Add(string.Empty);
        }

        updatedLines.Add($"## {tag}");

        if (newPosts.Count > 0)
        {
            updatedLines.Add($"- Added {newPosts.Count} new blue post{(newPosts.Count == 1 ? string.Empty : "s")} to the in-game reader.");

            var seenTitles = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (var newPost in newPosts)
            {
                var title = newPost.Title.Trim();
                if (title.Length == 0 || !seenTitles.Add(title))
                {
                    continue;
                }

                updatedLines.Add($"- {title}");
            }
        }

        if (restIndex < lines.Length)
        {
            updatedLines.Add(string.Empty);
            updatedLines.AddRange(lines.Skip(restIndex));
        }

        var updatedContent = string.Join(newline, updatedLines) + newline;
        await File.WriteAllTextAsync(changelogPath, updatedContent, new UTF8Encoding(false), cancellationToken);
        return true;
    }
}
