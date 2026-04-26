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

        var changedGeneratedFiles = await git.GetStatusAsync(["BluePosts_Data.lua", "Media/Posts"], cancellationToken);
        if (changedGeneratedFiles.Count == 0)
        {
            Console.WriteLine("[pipeline] No generated content changes detected. Nothing to commit.");
            return;
        }

        Console.WriteLine($"[pipeline] Detected {changedGeneratedFiles.Count} generated change(s):");
        foreach (var changedGeneratedFile in changedGeneratedFiles)
        {
            Console.WriteLine($"[pipeline]   {changedGeneratedFile}");
        }

        var version = await ResolveVersionAsync(options, git, cancellationToken);
        Console.WriteLine($"[pipeline] Resolved release version: {version}");

        var tagName = version.ToString();
        var commitMessage = $"chore: refresh blueposts data for {version}";

        var filesToCommit = new List<string> { "BluePosts_Data.lua", "Media/Posts" };
        if (buildResult.NewPosts.Count > 0)
        {
            Console.WriteLine($"[pipeline] Detected {buildResult.NewPosts.Count} new blue post(s) for changelog update.");
        }
        else
        {
            Console.WriteLine("[pipeline] No new blue posts detected. Recording the commit message in CHANGELOG.md.");
        }

        var changelogUpdated = await RunStepAsync("Updating CHANGELOG.md", () =>
            new ChangelogUpdater(Path.Combine(options.RepoRoot, "CHANGELOG.md"))
                .PrependEntryAsync(tagName, buildResult.NewPosts, commitMessage, cancellationToken));

        if (changelogUpdated)
        {
            filesToCommit.Add("CHANGELOG.md");
            Console.WriteLine("[pipeline] Updated changelog: CHANGELOG.md");
        }

        if (options.DryRun)
        {
            Console.WriteLine("[pipeline] Dry run enabled. Skipping commit, tag, and push.");
            return;
        }

        await RunStepAsync($"Creating git commit '{commitMessage}' and tag '{tagName}'", async () =>
        {
            await git.AddAsync(filesToCommit, cancellationToken);
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
            return SemanticVersion.Parse(options.Version);
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
        SemanticVersion.TryParse(tag, out var version) ? version : null;
}