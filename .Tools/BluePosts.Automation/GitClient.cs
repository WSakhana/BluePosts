using System.Diagnostics;
using System.Text;

namespace BluePosts.Automation;

internal sealed class GitClient(string repoRoot, string? githubToken)
{
    private readonly string? normalizedGitHubToken = string.IsNullOrWhiteSpace(githubToken) ? null : githubToken.Trim();

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
        await RunGitAsync(Directory.GetParent(repoRoot)!.FullName, arguments, cancellationToken, repoUrl);
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
        var remoteUrl = await GetRemoteUrlAsync(remoteName, cancellationToken);
        await RunGitAsync(repoRoot, ["fetch", remoteName, "--tags", "--prune"], cancellationToken, remoteUrl);
    }

    public async Task PullAsync(string remoteName, string? branchName, CancellationToken cancellationToken)
    {
        var remoteUrl = await GetRemoteUrlAsync(remoteName, cancellationToken);

        if (!string.IsNullOrWhiteSpace(branchName))
        {
            await RunGitAsync(repoRoot, ["checkout", branchName], cancellationToken);
            await RunGitAsync(repoRoot, ["pull", "--ff-only", remoteName, branchName], cancellationToken, remoteUrl);
            return;
        }

        await RunGitAsync(repoRoot, ["pull", "--ff-only", remoteName], cancellationToken, remoteUrl);
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
        var remoteUrl = await GetRemoteUrlAsync(remoteName, cancellationToken);

        if (!string.IsNullOrWhiteSpace(branchName))
        {
            await RunGitAsync(repoRoot, ["push", remoteName, branchName], cancellationToken, remoteUrl);
            return;
        }

        await RunGitAsync(repoRoot, ["push", remoteName, "HEAD"], cancellationToken, remoteUrl);
    }

    public async Task PushTagAsync(string remoteName, string tagName, CancellationToken cancellationToken)
    {
        var remoteUrl = await GetRemoteUrlAsync(remoteName, cancellationToken);
        await RunGitAsync(repoRoot, ["push", remoteName, tagName], cancellationToken, remoteUrl);
    }

    public async Task<IReadOnlyList<string>> GetTagsAsync(CancellationToken cancellationToken)
    {
        var result = await RunGitAsync(repoRoot, ["tag", "--list"], cancellationToken);
        return result.StandardOutput
            .Split(['\r', '\n'], StringSplitOptions.RemoveEmptyEntries)
            .ToList();
    }

    private async Task<string> GetRemoteUrlAsync(string remoteName, CancellationToken cancellationToken)
    {
        var result = await RunGitAsync(repoRoot, ["remote", "get-url", remoteName], cancellationToken);
        return result.StandardOutput;
    }

    private async Task<GitCommandResult> RunGitAsync(string workingDirectory, IReadOnlyList<string> arguments, CancellationToken cancellationToken, string? authenticatedUrl = null)
    {
        var startInfo = new ProcessStartInfo("git")
        {
            WorkingDirectory = workingDirectory,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true
        };

        startInfo.Environment["GIT_TERMINAL_PROMPT"] = "0";
        ApplyGitHubAuthentication(startInfo, authenticatedUrl);

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

    private void ApplyGitHubAuthentication(ProcessStartInfo startInfo, string? authenticatedUrl)
    {
        if (string.IsNullOrWhiteSpace(normalizedGitHubToken)
            || !TryBuildGitHubExtraHeaderConfig(authenticatedUrl, normalizedGitHubToken, out var configKey, out var configValue))
        {
            return;
        }

        startInfo.Environment["GIT_CONFIG_COUNT"] = "1";
        startInfo.Environment["GIT_CONFIG_KEY_0"] = configKey;
        startInfo.Environment["GIT_CONFIG_VALUE_0"] = configValue;
    }

    private static bool TryBuildGitHubExtraHeaderConfig(string? remoteUrl, string token, out string configKey, out string configValue)
    {
        configKey = string.Empty;
        configValue = string.Empty;

        if (string.IsNullOrWhiteSpace(remoteUrl)
            || !Uri.TryCreate(remoteUrl, UriKind.Absolute, out var uri)
            || !uri.Scheme.Equals("https", StringComparison.OrdinalIgnoreCase)
            || !uri.Host.Contains("github", StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }

        var urlPrefix = uri.GetLeftPart(UriPartial.Authority) + "/";
        var basicAuthValue = Convert.ToBase64String(Encoding.UTF8.GetBytes($"x-access-token:{token}"));
        configKey = $"http.{urlPrefix}.extraheader";
        configValue = $"AUTHORIZATION: basic {basicAuthValue}";
        return true;
    }

    private sealed record GitCommandResult(string StandardOutput, string StandardError);
}