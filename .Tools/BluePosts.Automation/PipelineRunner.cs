namespace BluePosts.Automation;

internal sealed class PipelineRunner(BuildDataRunner buildDataRunner)
{
    public async Task RunAsync(PipelineOptions options, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(options.RepoRoot))
        {
            throw new InvalidOperationException("Repository root is required.");
        }

        await CleanupTemporaryDirectoriesAsync(options, cancellationToken);

        var git = new GitClient(options.RepoRoot, options.GithubToken);
        await git.EnsureRepositoryAsync(options.RepoUrl, options.BranchName, cancellationToken);

        if (!options.AllowDirty)
        {
            await git.EnsureCleanWorkingTreeAsync(cancellationToken);
        }

        Console.WriteLine("Fetching and fast-forwarding the repository...");
        await git.FetchAsync(options.RemoteName, cancellationToken);
        await git.PullAsync(options.RemoteName, options.BranchName, cancellationToken);

        Console.WriteLine("Downloading Google Drive export...");
        var downloader = new GoogleDriveDownloader(options.GoogleCredentials);
        await downloader.DownloadFolderAsync(options.DriveFolderId, options.SourcePath, cancellationToken);

        Console.WriteLine("Rebuilding addon data...");
        _ = await buildDataRunner.RunAsync(
            new BuildDataOptions(options.SourcePath, options.OutputPath, options.MediaRoot),
            cancellationToken);

        var changedGeneratedFiles = await git.GetStatusAsync(["BluePosts_Data.lua", "Media/Posts"], cancellationToken);
        if (changedGeneratedFiles.Count == 0)
        {
            Console.WriteLine("No generated content changes detected. Nothing to commit.");
            return;
        }

        var version = await ResolveVersionAsync(options, git, cancellationToken);
        Console.WriteLine($"Resolved release version: {version}");

        if (options.DryRun)
        {
            Console.WriteLine("Dry run enabled. Skipping commit, tag, and push.");
            return;
        }

        Console.WriteLine("Creating git commit and tag...");
        await git.AddAsync(["BluePosts_Data.lua", "Media/Posts"], cancellationToken);

        var commitMessage = $"chore: refresh blueposts data for {version}";
        var tagName = version.ToString();
        await git.CommitAsync(commitMessage, cancellationToken);
        await git.TagAsync(tagName, tagName, cancellationToken);

        Console.WriteLine("Pushing commit and tag...");
        await git.PushAsync(options.RemoteName, options.BranchName, cancellationToken);
        await git.PushTagAsync(options.RemoteName, tagName, cancellationToken);
    }

    private static async Task CleanupTemporaryDirectoriesAsync(PipelineOptions options, CancellationToken cancellationToken)
    {
        await CleanupDirectoryAsync(options.SourcePath, "downloaded Google Drive data", cancellationToken);

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