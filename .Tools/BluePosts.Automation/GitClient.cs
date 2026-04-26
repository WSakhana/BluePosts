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
        var result = await RunGitAsync(repoRoot, ["remote", "get-url", remoteName], cancellationToken, logOutput: false);
        return result.StandardOutput;
    }

    private async Task<GitCommandResult> RunGitAsync(
        string workingDirectory,
        IReadOnlyList<string> arguments,
        CancellationToken cancellationToken,
        string? authenticatedUrl = null,
        bool logOutput = true)
    {
        var commandText = FormatCommandForDisplay(arguments);
        Console.WriteLine($"[git] Starting: {commandText}");

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
        var stopwatch = Stopwatch.StartNew();
        process.Start();

        var standardOutputTask = process.StandardOutput.ReadToEndAsync(cancellationToken);
        var standardErrorTask = process.StandardError.ReadToEndAsync(cancellationToken);

        await process.WaitForExitAsync(cancellationToken);
        stopwatch.Stop();
        var standardOutput = (await standardOutputTask).Trim();
        var standardError = (await standardErrorTask).Trim();

        if (process.ExitCode != 0)
        {
            throw new InvalidOperationException($"git {commandText} failed with exit code {process.ExitCode}.{Environment.NewLine}{FormatFailureOutput(standardOutput, standardError)}");
        }

        if (logOutput)
        {
            WriteCommandOutput("stdout", standardOutput);
            WriteCommandOutput("stderr", standardError);
        }

        Console.WriteLine($"[git] Completed: {commandText} ({FormatElapsed(stopwatch.Elapsed)})");

        return new GitCommandResult(standardOutput, standardError);
    }

    private static string FormatCommandForDisplay(IReadOnlyList<string> arguments) =>
        string.Join(' ', arguments.Select(argument => FormatArgumentForDisplay(SanitizeSensitiveText(argument))));

    private static string FormatArgumentForDisplay(string argument) =>
        argument.Contains(' ', StringComparison.Ordinal) ? $"\"{argument}\"" : argument;

    private static void WriteCommandOutput(string streamName, string output)
    {
        if (string.IsNullOrWhiteSpace(output))
        {
            return;
        }

        foreach (var line in output.Split(['\r', '\n'], StringSplitOptions.RemoveEmptyEntries))
        {
            Console.WriteLine($"[git]   {streamName}: {SanitizeSensitiveText(line)}");
        }
    }

    private static string FormatFailureOutput(string standardOutput, string standardError)
    {
        var lines = new List<string>();

        if (!string.IsNullOrWhiteSpace(standardError))
        {
            lines.AddRange(standardError
                .Split(['\r', '\n'], StringSplitOptions.RemoveEmptyEntries)
                .Select(line => $"stderr: {SanitizeSensitiveText(line)}"));
        }

        if (!string.IsNullOrWhiteSpace(standardOutput))
        {
            lines.AddRange(standardOutput
                .Split(['\r', '\n'], StringSplitOptions.RemoveEmptyEntries)
                .Select(line => $"stdout: {SanitizeSensitiveText(line)}"));
        }

        return lines.Count == 0 ? "No git output was captured." : string.Join(Environment.NewLine, lines);
    }

    private static string SanitizeSensitiveText(string text)
    {
        var tokens = text.Split(' ', StringSplitOptions.RemoveEmptyEntries);
        if (tokens.Length == 0)
        {
            return text;
        }

        return string.Join(' ', tokens.Select(SanitizeToken));
    }

    private static string SanitizeToken(string token)
    {
        if (!token.Contains("://", StringComparison.Ordinal)
            || !Uri.TryCreate(token, UriKind.Absolute, out var uri))
        {
            return token;
        }

        var path = string.IsNullOrEmpty(uri.AbsolutePath) ? "/" : uri.AbsolutePath;
        return $"{uri.Scheme}://{uri.Host}{path}";
    }

    private static string FormatElapsed(TimeSpan elapsed) =>
        elapsed.TotalMinutes >= 1
            ? elapsed.ToString(@"m\:ss")
            : $"{elapsed.TotalSeconds:F1}s";

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