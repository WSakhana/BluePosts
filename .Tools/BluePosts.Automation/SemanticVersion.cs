using System.Text.RegularExpressions;

namespace BluePosts.Automation;

internal readonly record struct SemanticVersion(int Major, int Minor, int Patch) : IComparable<SemanticVersion>
{
    private static readonly Regex VersionRegex = new("^(?<major>\\d+)\\.(?<minor>\\d+)\\.(?<patch>\\d+)$", RegexOptions.Compiled);

    public static SemanticVersion Parse(string value)
    {
        if (!TryParse(value, out var version))
        {
            throw new InvalidOperationException($"Invalid semantic version '{value}'.");
        }

        return version;
    }

    public static bool TryParse(string? value, out SemanticVersion version)
    {
        var match = VersionRegex.Match(value ?? string.Empty);
        if (!match.Success)
        {
            version = default;
            return false;
        }

        version = new SemanticVersion(
            int.Parse(match.Groups["major"].Value),
            int.Parse(match.Groups["minor"].Value),
            int.Parse(match.Groups["patch"].Value));
        return true;
    }

    public SemanticVersion Increment(VersionBump bump) => bump switch
    {
        VersionBump.Major => new SemanticVersion(Major + 1, 0, 0),
        VersionBump.Minor => new SemanticVersion(Major, Minor + 1, 0),
        _ => Patch < 9
            ? new SemanticVersion(Major, Minor, Patch + 1)
            : Minor < 9
                ? new SemanticVersion(Major, Minor + 1, 0)
                : new SemanticVersion(Major + 1, 0, 0)
    };

    public int CompareTo(SemanticVersion other)
    {
        var major = Major.CompareTo(other.Major);
        if (major != 0)
        {
            return major;
        }

        var minor = Minor.CompareTo(other.Minor);
        if (minor != 0)
        {
            return minor;
        }

        return Patch.CompareTo(other.Patch);
    }

    public override string ToString() => $"{Major}.{Minor}.{Patch}";
}