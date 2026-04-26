using System.Diagnostics;

namespace BluePosts.Automation;

internal sealed class GitClient(string repoRoot)
{
    public async Task EnsureRepositoryAsync(string? repoUrl, string? branchName, CancellationToken cancellationToken)
    {
        if (Directory.Exists(Path.Combine(repoRoot, ".git")))
        {
            return;
        }

        if (string.IsNullOrWhiteSpace(repoUrl))
        {
            throw new InvalidOperationException($"Repository not found at {repoRoot}. Provide --repo-url to clone it.");
        }

        Directory.CreateDirectory(Directory.GetParent(repoRoot)?.FullName ?? throw new InvalidOperationException("Repository root must have a parent directory."));
        var arguments = new List<string> { "clone" };
        if (!string.IsNullOrWhiteSpace(branchName))
        {
            arguments.AddRange(["--branch", branchName]);
        }

        arguments.AddRange([repoUrl, repoRoot]);
        await RunGitAsync(Directory.GetParent(repoRoot)!.FullName, arguments, cancellationToken);
    }

    public async Task EnsureCleanWorkingTreeAsync(CancellationToken cancellationToken)
    {
        var status = await GetStatusAsync(Array.Empty<string>(), cancellationToken);
        if (status.Count > 0)
        {
            var preview = string.Join(Environment.NewLine, status.Take(20));
            throw new InvalidOperationException($"Repository must be clean before running the pipeline.{Environment.NewLine}{preview}");
        }
    }

    public async Task FetchAsync(string remoteName, CancellationToken cancellationToken)
    {
        await RunGitAsync(repoRoot, ["fetch", remoteName, "--tags", "--prune"], cancellationToken);
    }

    public async Task PullAsync(string remoteName, string? branchName, CancellationToken cancellationToken)
    {
        if (!string.IsNullOrWhiteSpace(branchName))
        {
            await RunGitAsync(repoRoot, ["checkout", branchName], cancellationToken);
            await RunGitAsync(repoRoot, ["pull", "--ff-only", remoteName, branchName], cancellationToken);
            return;
        }

        await RunGitAsync(repoRoot, ["pull", "--ff-only", remoteName], cancellationToken);
    }

    public async Task<IReadOnlyList<string>> GetStatusAsync(IReadOnlyList<string> paths, CancellationToken cancellationToken)
    {
        var arguments = new List<string> { "status", "--porcelain" };
        if (paths.Count > 0)
        {
            arguments.Add("--");
            arguments.AddRange(paths);
        }

        var result = await RunGitAsync(repoRoot, arguments, cancellationToken);
        return result.StandardOutput
            .Split(['\r', '\n'], StringSplitOptions.RemoveEmptyEntries)
            .ToList();
    }

    public async Task AddAsync(IReadOnlyList<string> paths, CancellationToken cancellationToken)
    {
        var arguments = new List<string> { "add", "--" };
        arguments.AddRange(paths);
        await RunGitAsync(repoRoot, arguments, cancellationToken);
    }

    public async Task CommitAsync(string message, CancellationToken cancellationToken)
    {
        await RunGitAsync(repoRoot, ["commit", "-m", message], cancellationToken);
    }

    public async Task TagAsync(string tagName, string message, CancellationToken cancellationToken)
    {
        await RunGitAsync(repoRoot, ["tag", "-a", tagName, "-m", message], cancellationToken);
    }

    public async Task PushAsync(string remoteName, string? branchName, CancellationToken cancellationToken)
    {
        if (!string.IsNullOrWhiteSpace(branchName))
        {
            await RunGitAsync(repoRoot, ["push", remoteName, branchName], cancellationToken);
            return;
        }

        await RunGitAsync(repoRoot, ["push", remoteName, "HEAD"], cancellationToken);
    }

    public async Task PushTagAsync(string remoteName, string tagName, CancellationToken cancellationToken)
    {
        await RunGitAsync(repoRoot, ["push", remoteName, tagName], cancellationToken);
    }

    public async Task<IReadOnlyList<string>> GetTagsAsync(CancellationToken cancellationToken)
    {
        var result = await RunGitAsync(repoRoot, ["tag", "--list"], cancellationToken);
        return result.StandardOutput
            .Split(['\r', '\n'], StringSplitOptions.RemoveEmptyEntries)
            .ToList();
    }

    private static async Task<GitCommandResult> RunGitAsync(string workingDirectory, IReadOnlyList<string> arguments, CancellationToken cancellationToken)
    {
        var startInfo = new ProcessStartInfo("git")
        {
            WorkingDirectory = workingDirectory,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true
        };

        foreach (var argument in arguments)
        {
            startInfo.ArgumentList.Add(argument);
        }

        using var process = new Process { StartInfo = startInfo };
        process.Start();

        var standardOutputTask = process.StandardOutput.ReadToEndAsync(cancellationToken);
        var standardErrorTask = process.StandardError.ReadToEndAsync(cancellationToken);

        await process.WaitForExitAsync(cancellationToken);
        var standardOutput = (await standardOutputTask).Trim();
        var standardError = (await standardErrorTask).Trim();

        if (process.ExitCode != 0)
        {
            throw new InvalidOperationException($"git {string.Join(' ', arguments)} failed with exit code {process.ExitCode}.{Environment.NewLine}{standardError}");
        }

        return new GitCommandResult(standardOutput, standardError);
    }

    private sealed record GitCommandResult(string StandardOutput, string StandardError);
}