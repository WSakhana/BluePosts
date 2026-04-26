using System.Globalization;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;
using HtmlAgilityPack;
using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Formats.Jpeg;
using SixLabors.ImageSharp.PixelFormats;
using SixLabors.ImageSharp.Processing;

namespace BluePosts.Automation;

internal sealed class BuildDataRunner
{
    private static readonly Regex DeveloperNoteRegex = new("^(?i:Developers.? notes:)\\s*", RegexOptions.Compiled);
    private static readonly Regex GeneratedPostIdRegex = new(@"^\s*\[""(?<id>[^""]+)""\]\s*=\s*\{$", RegexOptions.Compiled);
    private static readonly Regex PackageTimestampRegex = new(@"^\s*package_timestamp\s*=\s*(?<timestamp>\d+)\s*,\s*$", RegexOptions.Compiled);
    private static readonly Regex WhitespaceRegex = new("\\s+", RegexOptions.Compiled);
    private static readonly StringComparer PathComparer = OperatingSystem.IsWindows()
        ? StringComparer.OrdinalIgnoreCase
        : StringComparer.Ordinal;
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true
    };

    public async Task<BuildDataResult> RunAsync(BuildDataOptions options, CancellationToken cancellationToken)
    {
        if (!Directory.Exists(options.SourcePath))
        {
            throw new InvalidOperationException($"Source path not found: {options.SourcePath}");
        }

        var existingData = await ReadExistingGeneratedDataAsync(options.OutputPath, cancellationToken);

        Directory.CreateDirectory(Path.GetDirectoryName(options.OutputPath) ?? throw new InvalidOperationException("Output path must include a directory."));
        Directory.CreateDirectory(options.MediaRoot);
        var generatedMediaFiles = new HashSet<string>(PathComparer);

        var sourceFolders = Directory.GetDirectories(options.SourcePath)
            .OrderBy(path => Path.GetFileName(path), StringComparer.OrdinalIgnoreCase)
            .Where(folderPath =>
                File.Exists(Path.Combine(folderPath, "metadata.json"))
                && File.Exists(Path.Combine(folderPath, "index.html")))
            .ToList();

        Console.WriteLine($"[build] Found {sourceFolders.Count} post folder(s) in {options.SourcePath}");

        var posts = new List<PostRecord>();
        for (var index = 0; index < sourceFolders.Count; index++)
        {
            cancellationToken.ThrowIfCancellationRequested();

            var folderPath = sourceFolders[index];
            var metadataPath = Path.Combine(folderPath, "metadata.json");
            var htmlPath = Path.Combine(folderPath, "index.html");

            var metadata = await ReadMetadataAsync(metadataPath, cancellationToken);
            var postId = string.IsNullOrWhiteSpace(metadata.FolderName)
                ? Path.GetFileName(folderPath)
                : metadata.FolderName!;

            Console.WriteLine($"[build] [{index + 1}/{sourceFolders.Count}] Processing {postId}");

            var html = await File.ReadAllTextAsync(htmlPath, cancellationToken);
            var content = ConvertHtmlToBlocks(html, folderPath, postId, options.MediaRoot, generatedMediaFiles);
            posts.Add(new PostRecord(
                Id: postId,
                PostKey: metadata.PostKey ?? string.Empty,
                Title: metadata.Title ?? string.Empty,
                Category: metadata.Category ?? string.Empty,
                Timestamp: GetUnixTimestamp(metadata.ExportedAt),
                Url: metadata.SourceUrl ?? string.Empty,
                Content: content));
        }

        var orderedPosts = posts
            .OrderByDescending(post => post.Timestamp)
            .ThenBy(post => post.Title, StringComparer.OrdinalIgnoreCase)
            .ToList();

        var newPosts = orderedPosts
            .Where(post => !existingData.PostIds.Contains(post.Id))
            .Select(post => new NewPostSummary(post.Id, post.Title))
            .ToList();

        PruneStaleMedia(options.MediaRoot, generatedMediaFiles);

        var generatedContent = BuildLuaData(
            orderedPosts,
            newPosts,
            existingData.PackageTimestamp ?? DateTimeOffset.UtcNow.ToUnixTimeSeconds());

        var dataFileChanged = !GeneratedPayloadEquals(existingData.Content, generatedContent);
        if (dataFileChanged)
        {
            generatedContent = BuildLuaData(orderedPosts, newPosts, DateTimeOffset.UtcNow.ToUnixTimeSeconds());
            Console.WriteLine($"[build] Writing generated data file: {options.OutputPath}");
            await File.WriteAllTextAsync(options.OutputPath, generatedContent, new UTF8Encoding(false), cancellationToken);
        }
        else
        {
            Console.WriteLine($"[build] Generated data payload unchanged; keeping existing file: {options.OutputPath}");
        }

        Console.WriteLine($"[build] Rebuilt {orderedPosts.Count} post(s) and synchronized media in {options.MediaRoot}");
        Console.WriteLine($"[build] Detected {newPosts.Count} new post(s)");

        return new BuildDataResult(orderedPosts.Count, options.OutputPath, options.MediaRoot, newPosts);
    }

    private static async Task<SourceMetadata> ReadMetadataAsync(string metadataPath, CancellationToken cancellationToken)
    {
        await using var stream = File.OpenRead(metadataPath);
        var metadata = await JsonSerializer.DeserializeAsync<SourceMetadata>(stream, JsonOptions, cancellationToken);
        return metadata ?? throw new InvalidOperationException($"Could not deserialize metadata from {metadataPath}");
    }

    private static async Task<ExistingGeneratedData> ReadExistingGeneratedDataAsync(string outputPath, CancellationToken cancellationToken)
    {
        if (!File.Exists(outputPath))
        {
            return new ExistingGeneratedData(null, null, []);
        }

        var content = await File.ReadAllTextAsync(outputPath, cancellationToken);
        var postIds = new HashSet<string>(StringComparer.Ordinal);
        long? packageTimestamp = null;

        using var reader = new StringReader(content);
        while (reader.ReadLine() is { } line)
        {
            var postIdMatch = GeneratedPostIdRegex.Match(line);
            if (postIdMatch.Success)
            {
                postIds.Add(postIdMatch.Groups["id"].Value);
                continue;
            }

            if (packageTimestamp is not null)
            {
                continue;
            }

            var timestampMatch = PackageTimestampRegex.Match(line);
            if (timestampMatch.Success
                && long.TryParse(timestampMatch.Groups["timestamp"].Value, CultureInfo.InvariantCulture, out var parsedTimestamp))
            {
                packageTimestamp = parsedTimestamp;
            }
        }

        return new ExistingGeneratedData(content, packageTimestamp, postIds);
    }

    private static bool GeneratedPayloadEquals(string? existingContent, string generatedContent)
    {
        if (existingContent is null)
        {
            return false;
        }

        return string.Equals(
            NormalizeGeneratedPayload(existingContent),
            NormalizeGeneratedPayload(generatedContent),
            StringComparison.Ordinal);
    }

    private static string NormalizeGeneratedPayload(string content)
    {
        var normalized = content.Replace("\r\n", "\n", StringComparison.Ordinal);
        var builder = new StringBuilder(normalized.Length);
        using var reader = new StringReader(normalized);
        var skippingNewPostIds = false;

        while (reader.ReadLine() is { } line)
        {
            var trimmed = line.TrimStart();
            if (trimmed.StartsWith("package_timestamp = ", StringComparison.Ordinal))
            {
                continue;
            }

            if (!skippingNewPostIds && trimmed.StartsWith("new_post_ids = {", StringComparison.Ordinal))
            {
                skippingNewPostIds = true;
                continue;
            }

            if (skippingNewPostIds)
            {
                if (trimmed.StartsWith("},", StringComparison.Ordinal))
                {
                    skippingNewPostIds = false;
                }

                continue;
            }

            builder.AppendLine(line);
        }

        return builder.ToString();
    }

    private static string BuildLuaData(IReadOnlyList<PostRecord> orderedPosts, IReadOnlyList<NewPostSummary> newPosts, long packageTimestamp)
    {
        var builder = new StringBuilder();
        builder.AppendLine("-- Generated data. Do not edit manually.");
        builder.AppendLine("BluePosts_Data = {");
        builder.AppendLine($"    package_timestamp = {packageTimestamp},");
        builder.AppendLine("    new_post_ids = {");

        foreach (var newPost in newPosts)
        {
            builder.AppendLine($"        {GetLuaString(newPost.Id)},");
        }

        builder.AppendLine("    },");
        builder.AppendLine("    posts = {");

        foreach (var post in orderedPosts)
        {
            builder.AppendLine($"        [{GetLuaString(post.Id)}] = {{");
            builder.AppendLine($"            id = {GetLuaString(post.Id)},");
            builder.AppendLine($"            post_key = {GetLuaString(post.PostKey)},");
            builder.AppendLine($"            title = {GetLuaString(post.Title)},");
            builder.AppendLine($"            category = {GetLuaString(post.Category)},");
            builder.AppendLine($"            timestamp = {post.Timestamp},");
            builder.AppendLine($"            url = {GetLuaString(post.Url)},");
            builder.AppendLine("            content = {");

            foreach (var block in post.Content)
            {
                WriteLuaBlock(builder, block);
            }

            builder.AppendLine("            },");
            builder.AppendLine("        },");
        }

        builder.AppendLine("    },");
        builder.AppendLine("}");
        return builder.ToString();
    }

    private static void PruneStaleMedia(string mediaRoot, HashSet<string> generatedMediaFiles)
    {
        if (!Directory.Exists(mediaRoot))
        {
            return;
        }

        foreach (var file in Directory.GetFiles(mediaRoot, "*", SearchOption.AllDirectories))
        {
            var fullPath = Path.GetFullPath(file);
            if (!generatedMediaFiles.Contains(fullPath))
            {
                File.Delete(fullPath);
            }
        }

        var directories = Directory.GetDirectories(mediaRoot, "*", SearchOption.AllDirectories)
            .OrderByDescending(path => path.Length)
            .ToList();

        foreach (var directory in directories)
        {
            if (!Directory.EnumerateFileSystemEntries(directory).Any())
            {
                Directory.Delete(directory);
            }
        }
    }

    private static List<PostBlock> ConvertHtmlToBlocks(
        string html,
        string folderPath,
        string postId,
        string mediaRoot,
        HashSet<string> generatedMediaFiles)
    {
        var normalizedHtml = html.Replace("&nbsp;", "&#160;", StringComparison.Ordinal);
        var document = new HtmlDocument();
        document.LoadHtml($"<root>{normalizedHtml}</root>");

        var blocks = new List<PostBlock>();
        var imageCache = new Dictionary<string, GeneratedImageEntry>(StringComparer.OrdinalIgnoreCase);
        var root = document.DocumentNode.SelectSingleNode("/root");
        if (root is null)
        {
            return blocks;
        }

        foreach (var node in root.ChildNodes)
        {
            ProcessNode(node, blocks, folderPath, postId, mediaRoot, imageCache, generatedMediaFiles);
        }

        return blocks;
    }

    private static void ProcessNode(
        HtmlNode node,
        List<PostBlock> blocks,
        string folderPath,
        string postId,
        string mediaRoot,
        Dictionary<string, GeneratedImageEntry> imageCache,
        HashSet<string> generatedMediaFiles)
    {
        if (node.NodeType != HtmlNodeType.Element)
        {
            return;
        }

        var name = node.Name.ToLowerInvariant();
        switch (name)
        {
            case "h1":
                AddBlock(blocks, "h1", GetCleanText(node.InnerText).ToUpperInvariant());
                return;

            case "h2":
                AddBlock(blocks, "h2", GetCleanText(node.InnerText).ToUpperInvariant());
                return;

            case "h3":
                AddBlock(blocks, "h3", GetCleanText(node.InnerText));
                return;

            case "h4":
                AddBlock(blocks, "h2", GetCleanText(node.InnerText).ToUpperInvariant());
                return;

            case "hr":
                AddBlock(blocks, "hr", string.Empty);
                return;

            case "img":
                AddImageBlock(node, blocks, folderPath, postId, mediaRoot, imageCache, generatedMediaFiles);
                return;

            case "p":
                ProcessParagraph(node, blocks, folderPath, postId, mediaRoot, imageCache, generatedMediaFiles);
                return;

            case "ul":
                foreach (var child in node.ChildNodes.Where(child => child.NodeType == HtmlNodeType.Element && child.Name.Equals("li", StringComparison.OrdinalIgnoreCase)))
                {
                    ProcessListItem(child, blocks, folderPath, postId, mediaRoot, imageCache, generatedMediaFiles, 0);
                }

                return;

            default:
                foreach (var child in node.ChildNodes)
                {
                    ProcessNode(child, blocks, folderPath, postId, mediaRoot, imageCache, generatedMediaFiles);
                }

                return;
        }
    }

    private static void ProcessParagraph(
        HtmlNode node,
        List<PostBlock> blocks,
        string folderPath,
        string postId,
        string mediaRoot,
        Dictionary<string, GeneratedImageEntry> imageCache,
        HashSet<string> generatedMediaFiles)
    {
        var images = node.SelectNodes(".//img");
        if (images is { Count: > 0 })
        {
            foreach (var image in images)
            {
                AddImageBlock(image, blocks, folderPath, postId, mediaRoot, imageCache, generatedMediaFiles);
            }

            return;
        }

        var text = GetCleanText(node.InnerText);
        if (TestDeveloperNote(text))
        {
            AddBlock(blocks, "dev_note", text);
        }
        else if (TestHeadingParagraph(node, text))
        {
            AddBlock(blocks, "h3", text);
        }
        else
        {
            AddBlock(blocks, "p", text);
        }
    }

    private static void ProcessListItem(
        HtmlNode node,
        List<PostBlock> blocks,
        string folderPath,
        string postId,
        string mediaRoot,
        Dictionary<string, GeneratedImageEntry> imageCache,
        HashSet<string> generatedMediaFiles,
        int level)
    {
        var text = GetInlineTextWithoutNestedLists(node);
        if (!string.IsNullOrWhiteSpace(text))
        {
            AddBlock(blocks, TestDeveloperNote(text) ? "dev_note" : "list_item", text, level: level);
        }

        foreach (var child in node.ChildNodes.Where(child => child.NodeType == HtmlNodeType.Element))
        {
            if (child.Name.Equals("ul", StringComparison.OrdinalIgnoreCase))
            {
                foreach (var nested in child.ChildNodes.Where(nested => nested.NodeType == HtmlNodeType.Element && nested.Name.Equals("li", StringComparison.OrdinalIgnoreCase)))
                {
                    ProcessListItem(nested, blocks, folderPath, postId, mediaRoot, imageCache, generatedMediaFiles, level + 1);
                }
            }
            else if (child.Name.Equals("img", StringComparison.OrdinalIgnoreCase))
            {
                AddImageBlock(child, blocks, folderPath, postId, mediaRoot, imageCache, generatedMediaFiles);
            }
        }
    }

    private static void AddImageBlock(
        HtmlNode node,
        List<PostBlock> blocks,
        string folderPath,
        string postId,
        string mediaRoot,
        Dictionary<string, GeneratedImageEntry> imageCache,
        HashSet<string> generatedMediaFiles)
    {
        var src = node.GetAttributeValue("src", string.Empty);
        if (string.IsNullOrWhiteSpace(src))
        {
            return;
        }

        var sourceFile = Path.Combine(folderPath, Uri.UnescapeDataString(src).Replace('/', Path.DirectorySeparatorChar));
        var entry = GetGeneratedImageEntry(sourceFile, postId, mediaRoot, imageCache, generatedMediaFiles);
        if (entry is null)
        {
            return;
        }

        AddBlock(
            blocks,
            "image",
            string.Empty,
            width: entry.Width,
            height: entry.Height,
            u: entry.U,
            v: entry.V,
            file: entry.File);
    }

    private static GeneratedImageEntry? GetGeneratedImageEntry(
        string sourceFile,
        string postId,
        string mediaRoot,
        Dictionary<string, GeneratedImageEntry> imageCache,
        HashSet<string> generatedMediaFiles)
    {
        if (!File.Exists(sourceFile))
        {
            return null;
        }

        if (imageCache.TryGetValue(sourceFile, out var existing))
        {
            return existing;
        }

        var baseName = Path.GetFileNameWithoutExtension(sourceFile);
        var postMedia = Path.Combine(mediaRoot, postId);
        Directory.CreateDirectory(postMedia);

        var destinationFile = Path.Combine(postMedia, $"{baseName}.jpg");
        generatedMediaFiles.Add(Path.GetFullPath(destinationFile));
        var result = ConvertImageToJpeg(sourceFile, destinationFile);
        var entry = new GeneratedImageEntry(
            File: $"Interface\\AddOns\\BluePosts\\Media\\Posts\\{postId}\\{baseName}.jpg",
            Width: result.Width,
            Height: result.Height,
            U: result.U,
            V: result.V);

        imageCache[sourceFile] = entry;
        return entry;
    }

    private static GeneratedImageEntry ConvertImageToJpeg(string sourceFile, string destinationFile)
    {
        using var image = Image.Load<Rgb24>(sourceFile);

        const double maxWidth = 720.0;
        const double maxHeight = 420.0;
        var scale = Math.Min(1.0, Math.Min(maxWidth / image.Width, maxHeight / image.Height));
        var drawWidth = Math.Max(1, (int)Math.Round(image.Width * scale, MidpointRounding.AwayFromZero));
        var drawHeight = Math.Max(1, (int)Math.Round(image.Height * scale, MidpointRounding.AwayFromZero));
        var texWidth = GetNextPowerOfTwo(drawWidth);
        var texHeight = GetNextPowerOfTwo(drawHeight);

        using var resized = image.Clone(context => context.Resize(new ResizeOptions
        {
            Mode = ResizeMode.Stretch,
            Size = new Size(drawWidth, drawHeight)
        }));

        using var bitmap = new Image<Rgb24>(texWidth, texHeight, Color.Black);
        bitmap.Mutate(context => context.DrawImage(resized, new Point(0, 0), 1f));
        ExpandEdgePadding(bitmap, drawWidth, drawHeight);

        Directory.CreateDirectory(Path.GetDirectoryName(destinationFile) ?? throw new InvalidOperationException("Destination file must include a directory."));
        using var stream = new MemoryStream();
        bitmap.SaveAsJpeg(stream, new JpegEncoder());
        WriteBytesIfChanged(destinationFile, stream.ToArray());

        return new GeneratedImageEntry(
            File: destinationFile,
            Width: drawWidth,
            Height: drawHeight,
            U: Math.Round((double)drawWidth / texWidth, 6),
            V: Math.Round((double)drawHeight / texHeight, 6));
    }

    private static void ExpandEdgePadding(Image<Rgb24> bitmap, int contentWidth, int contentHeight)
    {
        if (contentWidth <= 0 || contentHeight <= 0)
        {
            return;
        }

        if (contentWidth < bitmap.Width)
        {
            for (var y = 0; y < contentHeight; y++)
            {
                var color = bitmap[contentWidth - 1, y];
                for (var x = contentWidth; x < bitmap.Width; x++)
                {
                    bitmap[x, y] = color;
                }
            }
        }

        if (contentHeight < bitmap.Height)
        {
            for (var x = 0; x < bitmap.Width; x++)
            {
                var color = bitmap[x, contentHeight - 1];
                for (var y = contentHeight; y < bitmap.Height; y++)
                {
                    bitmap[x, y] = color;
                }
            }
        }
    }

    private static int GetNextPowerOfTwo(int value)
    {
        var power = 1;
        while (power < value)
        {
            power *= 2;
        }

        return Math.Max(16, power);
    }

    private static void WriteBytesIfChanged(string path, byte[] content)
    {
        if (File.Exists(path))
        {
            var existing = File.ReadAllBytes(path);
            if (existing.AsSpan().SequenceEqual(content))
            {
                return;
            }
        }

        File.WriteAllBytes(path, content);
    }

    private static void AddBlock(
        List<PostBlock> blocks,
        string type,
        string text,
        int? level = null,
        int? width = null,
        int? height = null,
        double? u = null,
        double? v = null,
        string? file = null)
    {
        var clean = GetCleanText(text);
        if (!type.Equals("image", StringComparison.Ordinal) && !type.Equals("hr", StringComparison.Ordinal) && string.IsNullOrWhiteSpace(clean))
        {
            return;
        }

        if (type.Equals("dev_note", StringComparison.Ordinal))
        {
            clean = DeveloperNoteRegex.Replace(clean, string.Empty);
        }

        blocks.Add(new PostBlock(type, type is "image" or "hr" ? null : clean, level, width, height, u, v, file));
    }

    private static string GetCleanText(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return string.Empty;
        }

        var decoded = HtmlEntity.DeEntitize(value);
        return WhitespaceRegex.Replace(decoded, " ").Trim();
    }

    private static bool TestDeveloperNote(string text) => DeveloperNoteRegex.IsMatch(text);

    private static string GetInlineTextWithoutNestedLists(HtmlNode node)
    {
        var parts = new List<string>();
        foreach (var child in node.ChildNodes)
        {
            if (child.NodeType == HtmlNodeType.Element && child.Name.Equals("ul", StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            parts.Add(child.InnerText);
        }

        return GetCleanText(string.Join(' ', parts));
    }

    private static bool TestHeadingParagraph(HtmlNode node, string text)
    {
        if (string.IsNullOrWhiteSpace(text) || text.Length > 90)
        {
            return false;
        }

        var hasStrong = false;
        foreach (var child in node.ChildNodes)
        {
            if (child.NodeType == HtmlNodeType.Text)
            {
                continue;
            }

            if (child.NodeType != HtmlNodeType.Element)
            {
                return false;
            }

            if (child.Name.Equals("strong", StringComparison.OrdinalIgnoreCase))
            {
                hasStrong = true;
            }
            else
            {
                return false;
            }
        }

        return hasStrong;
    }

    private static long GetUnixTimestamp(JsonElement value)
    {
        return value.ValueKind switch
        {
            JsonValueKind.String => DateTimeOffset.Parse(value.GetString() ?? throw new InvalidOperationException("exported_at is empty."), CultureInfo.InvariantCulture).ToUnixTimeSeconds(),
            JsonValueKind.Number => value.GetInt64(),
            _ => throw new InvalidOperationException("Unsupported exported_at format in metadata.json.")
        };
    }

    private static string GetLuaString(string? value)
    {
        if (value is null)
        {
            return "\"\"";
        }

        var escaped = value
            .Replace("\\", "\\\\", StringComparison.Ordinal)
            .Replace("\"", "\\\"", StringComparison.Ordinal)
            .Replace("\r", string.Empty, StringComparison.Ordinal)
            .Replace("\n", "\\n", StringComparison.Ordinal)
            .Replace("\t", "\\t", StringComparison.Ordinal);

        return $"\"{escaped}\"";
    }

    private static void WriteLuaBlock(StringBuilder builder, PostBlock block)
    {
        builder.Append("            { type = ");
        builder.Append(GetLuaString(block.Type));

        if (block.Text is not null)
        {
            builder.Append(", text = ");
            builder.Append(GetLuaString(block.Text));
        }

        if (block.Level is not null)
        {
            builder.Append(", level = ");
            builder.Append(block.Level.Value.ToString(CultureInfo.InvariantCulture));
        }

        if (block.Width is not null)
        {
            builder.Append(", width = ");
            builder.Append(block.Width.Value.ToString(CultureInfo.InvariantCulture));
        }

        if (block.Height is not null)
        {
            builder.Append(", height = ");
            builder.Append(block.Height.Value.ToString(CultureInfo.InvariantCulture));
        }

        if (block.U is not null)
        {
            builder.Append(", u = ");
            builder.Append(block.U.Value.ToString(CultureInfo.InvariantCulture));
        }

        if (block.V is not null)
        {
            builder.Append(", v = ");
            builder.Append(block.V.Value.ToString(CultureInfo.InvariantCulture));
        }

        if (block.File is not null)
        {
            builder.Append(", file = ");
            builder.Append(GetLuaString(block.File));
        }

        builder.AppendLine(" },");
    }

    private sealed record SourceMetadata(
        [property: JsonPropertyName("folder_name")] string? FolderName,
        [property: JsonPropertyName("post_key")] string? PostKey,
        [property: JsonPropertyName("title")] string? Title,
        [property: JsonPropertyName("category")] string? Category,
        [property: JsonPropertyName("exported_at")] JsonElement ExportedAt,
        [property: JsonPropertyName("source_url")] string? SourceUrl);

    private sealed record ExistingGeneratedData(string? Content, long? PackageTimestamp, HashSet<string> PostIds);
}

internal sealed record BuildDataResult(int PostCount, string OutputPath, string MediaRoot, IReadOnlyList<NewPostSummary> NewPosts);

internal sealed record NewPostSummary(string Id, string Title);

internal sealed record PostRecord(string Id, string PostKey, string Title, string Category, long Timestamp, string Url, IReadOnlyList<PostBlock> Content);

internal sealed record PostBlock(string Type, string? Text, int? Level, int? Width, int? Height, double? U, double? V, string? File);

internal sealed record GeneratedImageEntry(string File, int Width, int Height, double U, double V);
