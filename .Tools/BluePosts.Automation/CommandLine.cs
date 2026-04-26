namespace BluePosts.Automation;

internal static class CommandLine
{
    public static string HelpText =>
        """
        BluePosts.Automation

        Commands:
                pipeline    Pull the repo, download Google Drive source data, rebuild addon data, commit, tag, push, then delete downloaded data.
          build-data  Rebuild BluePosts_Data.lua and Media/Posts from a local exported BluePosts folder.
          help        Show this help.

        pipeline options:
                --repo-root <path>             Repository root. Temporary clone folders are cleaned before startup.
          --repo-url <url>               Optional git URL used to clone the repository when repo-root does not exist yet.
                --source-path <path>           Temporary local folder used for the downloaded Google Drive tree. Cleaned before startup.
          --drive-folder-id <id>         Google Drive folder ID containing the exported BluePosts data.
          --google-credentials <value>   Path to a service account JSON file or the raw JSON content itself.
          --remote <name>                Git remote name. Default: origin.
          --branch <name>                Branch to pull and push.
          --version <x.y.z>              Explicit release version. If omitted, the version is auto-incremented.
                --version-bump <kind>          major, minor, or patch. Default: patch.
          --dry-run                      Run download/build/version resolution without git commit, tag, or push.
          --allow-dirty                  Skip the clean working tree guard.

        build-data options:
          --source-path <path>           Local exported BluePosts folder.
          --output-path <path>           Destination Lua data file. Default: <repo-root>/BluePosts_Data.lua.
          --media-root <path>            Destination generated media folder. Default: <repo-root>/Media/Posts.

        Environment variables:
          BLUEPOSTS_REPO_ROOT
          BLUEPOSTS_REPO_URL
          BLUEPOSTS_SOURCE_PATH
          BLUEPOSTS_DRIVE_FOLDER_ID
          BLUEPOSTS_GOOGLE_CREDENTIALS
          BLUEPOSTS_GIT_REMOTE
          BLUEPOSTS_GIT_BRANCH
          BLUEPOSTS_VERSION
          BLUEPOSTS_VERSION_BUMP
        """;

    public static Command Parse(string[] args)
    {
        if (args.Length == 0)
        {
            return BuildPipelineCommand(Array.Empty<string>());
        }

        if (IsHelpToken(args[0]))
        {
            return new HelpCommand();
        }

        var commandName = args[0].StartsWith("--", StringComparison.Ordinal) ? "pipeline" : args[0].ToLowerInvariant();
        var optionArgs = commandName == "pipeline" && args[0].StartsWith("--", StringComparison.Ordinal)
            ? args
            : args.Skip(1).ToArray();

        return commandName switch
        {
            "pipeline" => BuildPipelineCommand(optionArgs),
            "build-data" => BuildBuildDataCommand(optionArgs),
            "help" => new HelpCommand(),
            _ => throw new CliException($"Unknown command '{commandName}'.")
        };
    }

    private static Command BuildPipelineCommand(string[] args)
    {
        var options = ParseOptions(args);
        if (HasHelp(options))
        {
            return new HelpCommand();
        }

        var repoRoot = GetPathOption(options, "repo-root", "BLUEPOSTS_REPO_ROOT") ?? FindDefaultRepoRoot();
        var sourcePath = GetPathOption(options, "source-path", "BLUEPOSTS_SOURCE_PATH")
            ?? Path.Combine(Path.GetTempPath(), "blueposts-source");

        var resolvedRepoRoot = Path.GetFullPath(repoRoot);
        var outputPath = GetPathOption(options, "output-path", null)
            ?? Path.Combine(resolvedRepoRoot, "BluePosts_Data.lua");
        var mediaRoot = GetPathOption(options, "media-root", null)
            ?? Path.Combine(resolvedRepoRoot, "Media", "Posts");
        var driveFolderId = GetRequiredOption(options, "drive-folder-id", "BLUEPOSTS_DRIVE_FOLDER_ID");
        var googleCredentials = GetRequiredOption(options, "google-credentials", "BLUEPOSTS_GOOGLE_CREDENTIALS");
        var remoteName = GetOption(options, "remote", "BLUEPOSTS_GIT_REMOTE") ?? "origin";
        var branchName = GetOption(options, "branch", "BLUEPOSTS_GIT_BRANCH");
        var version = GetOption(options, "version", "BLUEPOSTS_VERSION");
        var versionBump = (GetOption(options, "version-bump", "BLUEPOSTS_VERSION_BUMP") ?? "patch").ToLowerInvariant();
        var repoUrl = GetOption(options, "repo-url", "BLUEPOSTS_REPO_URL");

        return new PipelineCommand(new PipelineOptions(
            RepoRoot: resolvedRepoRoot,
            RepoUrl: repoUrl,
            SourcePath: Path.GetFullPath(sourcePath),
            DriveFolderId: driveFolderId,
            GoogleCredentials: googleCredentials,
            OutputPath: Path.GetFullPath(outputPath),
            MediaRoot: Path.GetFullPath(mediaRoot),
            RemoteName: remoteName,
            BranchName: branchName,
            Version: version,
            VersionBump: ParseVersionBump(versionBump),
            DryRun: options.ContainsKey("dry-run"),
            AllowDirty: options.ContainsKey("allow-dirty")));
    }

    private static Command BuildBuildDataCommand(string[] args)
    {
        var options = ParseOptions(args);
        if (HasHelp(options))
        {
            return new HelpCommand();
        }

        var repoRoot = GetPathOption(options, "repo-root", "BLUEPOSTS_REPO_ROOT") ?? FindDefaultRepoRoot();
        var resolvedRepoRoot = Path.GetFullPath(repoRoot);
        var sourcePath = GetRequiredOption(options, "source-path", "BLUEPOSTS_SOURCE_PATH");
        var outputPath = GetPathOption(options, "output-path", null)
            ?? Path.Combine(resolvedRepoRoot, "BluePosts_Data.lua");
        var mediaRoot = GetPathOption(options, "media-root", null)
            ?? Path.Combine(resolvedRepoRoot, "Media", "Posts");

        return new BuildDataCommand(new BuildDataOptions(
            Path.GetFullPath(sourcePath),
            Path.GetFullPath(outputPath),
            Path.GetFullPath(mediaRoot)));
    }

    private static Dictionary<string, string?> ParseOptions(string[] args)
    {
        var options = new Dictionary<string, string?>(StringComparer.OrdinalIgnoreCase);

        for (var index = 0; index < args.Length; index++)
        {
            var token = args[index];
            if (!token.StartsWith("--", StringComparison.Ordinal))
            {
                throw new CliException($"Unexpected argument '{token}'.");
            }

            var name = token[2..];
            if (string.IsNullOrWhiteSpace(name))
            {
                throw new CliException("Encountered an empty option name.");
            }

            if (index + 1 < args.Length && !args[index + 1].StartsWith("--", StringComparison.Ordinal))
            {
                options[name] = args[index + 1];
                index++;
            }
            else
            {
                options[name] = null;
            }
        }

        return options;
    }

    private static bool HasHelp(Dictionary<string, string?> options) =>
        options.ContainsKey("help") || options.ContainsKey("?");

    private static bool IsHelpToken(string token) =>
        string.Equals(token, "help", StringComparison.OrdinalIgnoreCase)
        || string.Equals(token, "--help", StringComparison.OrdinalIgnoreCase)
        || string.Equals(token, "-h", StringComparison.OrdinalIgnoreCase)
        || string.Equals(token, "/?", StringComparison.OrdinalIgnoreCase);

    private static string GetRequiredOption(Dictionary<string, string?> options, string optionName, string? environmentName)
    {
        var value = GetOption(options, optionName, environmentName);
        if (string.IsNullOrWhiteSpace(value))
        {
            throw new CliException($"Missing required option --{optionName}.");
        }

        return value;
    }

    private static string? GetPathOption(Dictionary<string, string?> options, string optionName, string? environmentName)
    {
        var value = GetOption(options, optionName, environmentName);
        return string.IsNullOrWhiteSpace(value) ? null : value;
    }

    private static string? GetOption(Dictionary<string, string?> options, string optionName, string? environmentName)
    {
        if (options.TryGetValue(optionName, out var value) && !string.IsNullOrWhiteSpace(value))
        {
            return value;
        }

        return string.IsNullOrWhiteSpace(environmentName)
            ? null
            : Environment.GetEnvironmentVariable(environmentName);
    }

    private static VersionBump ParseVersionBump(string value) => value switch
    {
        "major" => VersionBump.Major,
        "minor" => VersionBump.Minor,
        "patch" => VersionBump.Patch,
        _ => throw new CliException($"Unsupported version bump '{value}'. Use major, minor, or patch.")
    };

    private static string FindDefaultRepoRoot()
    {
        var current = new DirectoryInfo(Directory.GetCurrentDirectory());
        while (current is not null)
        {
            if (Directory.Exists(Path.Combine(current.FullName, ".git"))
                || File.Exists(Path.Combine(current.FullName, "BluePosts.toc")))
            {
                return current.FullName;
            }

            current = current.Parent;
        }

        return Directory.GetCurrentDirectory();
    }
}

internal abstract record Command;

internal sealed record HelpCommand : Command;

internal sealed record BuildDataCommand(BuildDataOptions Options) : Command;

internal sealed record PipelineCommand(PipelineOptions Options) : Command;

internal sealed record BuildDataOptions(string SourcePath, string OutputPath, string MediaRoot);

internal sealed record PipelineOptions(
    string RepoRoot,
    string? RepoUrl,
    string SourcePath,
    string DriveFolderId,
    string GoogleCredentials,
    string OutputPath,
    string MediaRoot,
    string RemoteName,
    string? BranchName,
    string? Version,
    VersionBump VersionBump,
    bool DryRun,
    bool AllowDirty)
{
    public PipelineOptions()
        : this(string.Empty, null, string.Empty, string.Empty, string.Empty, string.Empty, string.Empty, "origin", null, null, VersionBump.Patch, false, false)
    {
    }
}

internal enum VersionBump
{
    Major,
    Minor,
    Patch
}

internal sealed class CliException(string message) : Exception(message);