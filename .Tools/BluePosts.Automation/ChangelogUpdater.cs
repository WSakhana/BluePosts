using System.Globalization;
using System.Text;

namespace BluePosts.Automation;

internal sealed class ChangelogUpdater(string changelogPath)
{
    public async Task<bool> PrependNewPostsEntryAsync(string tag, IReadOnlyList<NewPostSummary> newPosts, CancellationToken cancellationToken)
    {
        if (newPosts.Count == 0)
        {
            return false;
        }

        if (!File.Exists(changelogPath))
        {
            throw new InvalidOperationException($"Changelog not found: {changelogPath}");
        }

        var content = await File.ReadAllTextAsync(changelogPath, cancellationToken);
        var newline = content.Contains("\r\n", StringComparison.Ordinal) ? "\r\n" : "\n";
        var lines = content.Split(["\r\n", "\n"], StringSplitOptions.None);
        var headingIndex = Array.FindIndex(lines, line => line.Equals("# Changelog", StringComparison.Ordinal));

        if (headingIndex < 0)
        {
            throw new InvalidOperationException($"Could not find '# Changelog' heading in {changelogPath}");
        }

        var restIndex = headingIndex + 1;
        while (restIndex < lines.Length && string.IsNullOrWhiteSpace(lines[restIndex]))
        {
            restIndex++;
        }

        var updatedLines = new List<string>(lines.Length + newPosts.Count + 4);
        updatedLines.AddRange(lines.Take(headingIndex + 1));
        updatedLines.Add(string.Empty);
        updatedLines.Add($"## {tag} - {DateTime.UtcNow.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture)} - New Blue Posts");

        foreach (var newPost in newPosts)
        {
            updatedLines.Add($"- {newPost.Title}");
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