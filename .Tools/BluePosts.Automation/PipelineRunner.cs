using System.Diagnostics;

namespace BluePosts.Automation;

internal sealed class PipelineRunner(BuildDataRunner buildDataRunner)
{
    public async Task RunAsync(PipelineOptions options, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(options.RepoRoot))
        {
            throw new InvalidOperationException("Repository root is required.");
        }

        Console.WriteLine("[pipeline] Starting BluePosts automation pipeline");
        Console.WriteLine($"[pipeline] Repository root: {options.RepoRoot}");
        Console.WriteLine($"[pipeline] Google Drive export path: {options.SourcePath}");
        Console.WriteLine($"[pipeline] Generated data output: {options.OutputPath}");

        await RunStepAsync("Preparing working directories", () => PrepareWorkingDirectoriesAsync(options, cancellationToken));

        var git = new GitClient(options.RepoRoot, options.GithubToken);
        await RunStepAsync("Ensuring repository is available", () => git.EnsureRepositoryAsync(options.RepoUrl, options.BranchName, cancellationToken));

        if (!options.AllowDirty)
        {
            await RunStepAsync("Validating clean working tree", () => git.EnsureCleanWorkingTreeAsync(cancellationToken));
        }

        await RunStepAsync("Fetching and fast-forwarding the repository", async () =>
        {
            await git.FetchAsync(options.RemoteName, cancellationToken);
            await git.PullAsync(options.RemoteName, options.BranchName, cancellationToken);
        });

        var downloader = new GoogleDriveDownloader(options.GoogleCredentials);
        await RunStepAsync("Downloading Google Drive export", () => downloader.DownloadFolderAsync(options.DriveFolderId, options.SourcePath, cancellationToken));

        var buildResult = await RunStepAsync("Rebuilding addon data", () => buildDataRunner.RunAsync(
            new BuildDataOptions(options.SourcePath, options.OutputPath, options.MediaRoot),
            cancellationToken));
        Console.WriteLine($"[pipeline] Generated {buildResult.PostCount} post(s) -> {buildResult.OutputPath}");
        Console.WriteLine($"[pipeline] Refreshed media assets in {buildResult.MediaRoot}");

        var changedPaths = ParseStatusPaths(await git.GetStatusAsync(Array.Empty<string>(), cancellationToken));
        var generatedChangePaths = changedPaths
            .Where(IsGeneratedContentPath)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .OrderBy(path => path, StringComparer.OrdinalIgnoreCase)
            .ToList();
        var addonLuaFiles = changedPaths
            .Where(IsAddonLuaReleasePath)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .OrderBy(path => path, StringComparer.OrdinalIgnoreCase)
            .ToList();

        if (generatedChangePaths.Count == 0 && addonLuaFiles.Count == 0)
        {
            Console.WriteLine("[pipeline] No releasable generated content or addon Lua changes detected. Nothing to commit.");
            return;
        }

        if (generatedChangePaths.Count > 0)
        {
            Console.WriteLine($"[pipeline] Detected {generatedChangePaths.Count} generated change(s):");
            foreach (var generatedChangePath in generatedChangePaths)
            {
                Console.WriteLine($"[pipeline]   {generatedChangePath}");
            }
        }

        if (addonLuaFiles.Count > 0)
        {
            Console.WriteLine($"[pipeline] Detected {addonLuaFiles.Count} addon Lua file change(s); this release will use a beta tag:");
            foreach (var addonLuaFile in addonLuaFiles)
            {
                Console.WriteLine($"[pipeline]   {addonLuaFile}");
            }
        }

        var version = await ResolveVersionAsync(options, git, cancellationToken);
        Console.WriteLine($"[pipeline] Resolved release version: {version}");

        var isBetaRelease = addonLuaFiles.Count > 0;
        var tagName = BuildTagName(version, isBetaRelease);
        var commitMessage = isBetaRelease
            ? $"chore: prepare blueposts beta {tagName}"
            : $"chore: refresh blueposts data for {tagName}";

        var filesToCommit = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        if (generatedChangePaths.Count > 0)
        {
            filesToCommit.Add("BluePosts_Data.lua");
            filesToCommit.Add("Media/Posts");
        }

        foreach (var addonLuaFile in addonLuaFiles)
        {
            filesToCommit.Add(addonLuaFile);
        }

        if (buildResult.PostChanges.HasVisibleChanges)
        {
            Console.WriteLine($"[pipeline] Post change summary: {buildResult.PostChanges.AddedPosts.Count} added, {buildResult.PostChanges.ModifiedPosts.Count} modified, {buildResult.PostChanges.RemovedPosts.Count} removed.");
        }
        else
        {
            Console.WriteLine(generatedChangePaths.Count > 0
                ? "[pipeline] No added/modified/removed blue posts detected. Writing fallback changelog notes."
                : "[pipeline] No blue post content diff detected. Writing beta changelog notes for addon Lua changes.");
        }

        var changelogUpdated = await RunStepAsync("Updating changelogs", () =>
            new ChangelogUpdater(
                    Path.Combine(options.RepoRoot, "CHANGELOG.md"),
                    Path.Combine(options.RepoRoot, "LATEST_CHANGELOG.md"))
                .PrependEntryAsync(tagName, buildResult.PostChanges, addonLuaFiles, generatedChangePaths.Count > 0, cancellationToken));

        if (changelogUpdated)
        {
            filesToCommit.Add("CHANGELOG.md");
            filesToCommit.Add("LATEST_CHANGELOG.md");
            Console.WriteLine("[pipeline] Updated changelogs: CHANGELOG.md, LATEST_CHANGELOG.md");
        }

        if (options.DryRun)
        {
            Console.WriteLine("[pipeline] Dry run enabled. Skipping commit, tag, and push.");
            return;
        }

        await RunStepAsync($"Creating git commit '{commitMessage}' and tag '{tagName}'", async () =>
        {
            await git.AddAsync(filesToCommit.OrderBy(path => path, StringComparer.OrdinalIgnoreCase).ToList(), cancellationToken);
            await git.CommitAsync(commitMessage, cancellationToken);
            await git.TagAsync(tagName, tagName, cancellationToken);
        });

        await RunStepAsync("Pushing commit and tag", async () =>
        {
            await git.PushAsync(options.RemoteName, options.BranchName, cancellationToken);
            await git.PushTagAsync(options.RemoteName, tagName, cancellationToken);
        });

        Console.WriteLine("[pipeline] Pipeline completed successfully.");
    }

    private static async Task RunStepAsync(string description, Func<Task> action)
    {
        await RunStepAsync(description, async () =>
        {
            await action();
            return true;
        });
    }

    private static async Task<T> RunStepAsync<T>(string description, Func<Task<T>> action)
    {
        Console.WriteLine($"[pipeline] Starting: {description}");
        var stopwatch = Stopwatch.StartNew();
        var result = await action();
        Console.WriteLine($"[pipeline] Completed: {description} ({FormatElapsed(stopwatch.Elapsed)})");
        return result;
    }

    private static string FormatElapsed(TimeSpan elapsed) =>
        elapsed.TotalMinutes >= 1
            ? elapsed.ToString(@"m\:ss")
            : $"{elapsed.TotalSeconds:F1}s";

    private static async Task PrepareWorkingDirectoriesAsync(PipelineOptions options, CancellationToken cancellationToken)
    {
        Directory.CreateDirectory(options.SourcePath);

        if (ShouldCleanupRepoRoot(options.RepoRoot))
        {
            await CleanupDirectoryAsync(options.RepoRoot, "downloaded git repository", cancellationToken);
        }
    }

    private static bool ShouldCleanupRepoRoot(string repoRoot)
    {
        if (!Directory.Exists(repoRoot))
        {
            return false;
        }

        var currentDirectory = Path.GetFullPath(Directory.GetCurrentDirectory()).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        var candidate = Path.GetFullPath(repoRoot).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);

        return !PathsOverlap(currentDirectory, candidate);
    }

    private static bool PathsOverlap(string left, string right)
    {
        if (left.Equals(right, StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }

        var leftPrefix = left + Path.DirectorySeparatorChar;
        var rightPrefix = right + Path.DirectorySeparatorChar;

        return left.StartsWith(rightPrefix, StringComparison.OrdinalIgnoreCase)
            || right.StartsWith(leftPrefix, StringComparison.OrdinalIgnoreCase);
    }

    private static async Task CleanupDirectoryAsync(string path, string label, CancellationToken cancellationToken)
    {
        if (!Directory.Exists(path))
        {
            return;
        }

        Exception? lastException = null;

        for (var attempt = 0; attempt < 10; attempt++)
        {
            cancellationToken.ThrowIfCancellationRequested();

            try
            {
                ResetAttributes(path);
                Directory.Delete(path, true);
                Console.WriteLine($"Deleted {label}: {path}");
                return;
            }
            catch (Exception exception) when (exception is IOException or UnauthorizedAccessException)
            {
                lastException = exception;
                await Task.Delay(250, cancellationToken);
            }
        }

        throw new InvalidOperationException($"Could not delete {label}: {path}", lastException);
    }

    private static void ResetAttributes(string path)
    {
        foreach (var filePath in Directory.EnumerateFiles(path, "*", SearchOption.AllDirectories))
        {
            File.SetAttributes(filePath, FileAttributes.Normal);
        }

        foreach (var directoryPath in Directory.EnumerateDirectories(path, "*", SearchOption.AllDirectories))
        {
            File.SetAttributes(directoryPath, FileAttributes.Normal);
        }

        File.SetAttributes(path, FileAttributes.Normal);
    }

    private async Task<SemanticVersion> ResolveVersionAsync(PipelineOptions options, GitClient git, CancellationToken cancellationToken)
    {
        if (!string.IsNullOrWhiteSpace(options.Version))
        {
            return SemanticVersion.Parse(StripTagSuffix(options.Version));
        }

        var knownVersions = (await git.GetTagsAsync(cancellationToken))
            .Select(NormalizeTag)
            .Where(version => version is not null)
            .Select(version => version!.Value)
            .ToList();

        var current = knownVersions.Count == 0 ? new SemanticVersion(1, 0, 0) : knownVersions.Max();
        return current.Increment(options.VersionBump);
    }

    private static SemanticVersion? NormalizeTag(string tag) =>
        SemanticVersion.TryParse(StripTagSuffix(tag), out var version) ? version : null;

    private static string BuildTagName(SemanticVersion version, bool isBetaRelease) =>
        isBetaRelease ? $"{version}-beta" : version.ToString();

    private static string StripTagSuffix(string tag)
    {
        var separatorIndex = tag.IndexOf('-', StringComparison.Ordinal);
        return separatorIndex >= 0 ? tag[..separatorIndex] : tag;
    }

    private static List<string> ParseStatusPaths(IReadOnlyList<string> statusLines)
    {
        var paths = new List<string>(statusLines.Count);
        foreach (var statusLine in statusLines)
        {
            var pathStartIndex = statusLine.Length > 2 && statusLine[2] == ' '
                ? 3
                : statusLine.Length > 1 && statusLine[1] == ' '
                    ? 2
                    : -1;

            if (pathStartIndex < 0 || statusLine.Length <= pathStartIndex)
            {
                continue;
            }

            var path = statusLine[pathStartIndex..].Trim();
            var renameSeparatorIndex = path.IndexOf(" -> ", StringComparison.Ordinal);
            if (renameSeparatorIndex >= 0)
            {
                path = path[(renameSeparatorIndex + 4)..];
            }

            if (path.Length == 0)
            {
                continue;
            }

            paths.Add(path.Replace('\\', '/'));
        }

        return paths;
    }

    private static bool IsGeneratedContentPath(string path) =>
        path.Equals("BluePosts_Data.lua", StringComparison.OrdinalIgnoreCase)
        || path.StartsWith("Media/Posts/", StringComparison.OrdinalIgnoreCase);

    private static bool IsAddonLuaReleasePath(string path)
    {
        if (!path.EndsWith(".lua", StringComparison.OrdinalIgnoreCase)
            || path.Equals("BluePosts_Data.lua", StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }

        return path
            .Split('/', StringSplitOptions.RemoveEmptyEntries)
            .All(segment => !segment.StartsWith(".", StringComparison.Ordinal));
    }
}
