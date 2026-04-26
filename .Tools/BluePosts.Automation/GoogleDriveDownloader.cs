using Google.Apis.Auth.OAuth2;
using Google.Apis.Drive.v3;
using Google.Apis.Services;

namespace BluePosts.Automation;

internal sealed class GoogleDriveDownloader
{
    private static readonly StringComparer EntryNameComparer = OperatingSystem.IsWindows() ? StringComparer.OrdinalIgnoreCase : StringComparer.Ordinal;
    private static readonly TimeSpan ModifiedTimeTolerance = TimeSpan.FromSeconds(2);

    private readonly DriveService driveService;
    private int downloadedFileCount;
    private int skippedFileCount;
    private int deletedEntryCount;
    private int ignoredDuplicateCount;
    private int visitedFolderCount;
    private string? rootDestinationPath;

    public GoogleDriveDownloader(string credentials)
    {
        var googleCredential = File.Exists(credentials)
            ? GoogleCredential.FromFile(credentials)
            : GoogleCredential.FromJson(credentials);

        driveService = new DriveService(new BaseClientService.Initializer
        {
            HttpClientInitializer = googleCredential.CreateScoped(DriveService.Scope.DriveReadonly),
            ApplicationName = "BluePosts.Automation"
        });
    }

    public async Task DownloadFolderAsync(string folderId, string destinationPath, CancellationToken cancellationToken)
    {
        EnsureDestination(destinationPath);
        downloadedFileCount = 0;
        skippedFileCount = 0;
        deletedEntryCount = 0;
        ignoredDuplicateCount = 0;
        visitedFolderCount = 0;
        rootDestinationPath = Path.GetFullPath(destinationPath);

        Console.WriteLine($"[drive] Export destination: {rootDestinationPath}");
        await DownloadFolderRecursiveAsync(folderId, rootDestinationPath, cancellationToken, 0);
        Console.WriteLine($"[drive] Sync complete: {downloadedFileCount} downloaded, {skippedFileCount} unchanged, {deletedEntryCount} stale item(s) removed, {ignoredDuplicateCount} duplicate Drive item(s) ignored across {visitedFolderCount} folder(s)");
    }

    private static void EnsureDestination(string destinationPath)
    {
        Directory.CreateDirectory(destinationPath);
    }

    private async Task DownloadFolderRecursiveAsync(string folderId, string destinationPath, CancellationToken cancellationToken, int depth)
    {
        var folderIndent = GetIndent(depth);
        var displayPath = GetDisplayPath(destinationPath);

        Console.WriteLine($"{folderIndent}[drive] Listing folder: {displayPath}");
        var items = await ListFolderItemsAsync(folderId, cancellationToken);
        visitedFolderCount++;
        Console.WriteLine($"{folderIndent}[drive] Found {items.Count} item(s) in {displayPath}");

        var itemIndent = GetIndent(depth + 1);
        var uniqueItems = SelectUniqueItems(items, destinationPath, itemIndent);
        var remoteEntryNames = uniqueItems
            .Select(item => item.Name)
            .ToHashSet(EntryNameComparer);

        foreach (var item in uniqueItems)
        {
            cancellationToken.ThrowIfCancellationRequested();

            var targetPath = Path.Combine(destinationPath, item.Name);
            var relativeTargetPath = GetDisplayPath(targetPath);
            if (item.MimeType == "application/vnd.google-apps.folder")
            {
                if (File.Exists(targetPath))
                {
                    DeleteFile(targetPath);
                    deletedEntryCount++;
                    Console.WriteLine($"{itemIndent}[drive] Removed stale file before folder sync: {relativeTargetPath}");
                }

                Console.WriteLine($"{itemIndent}[drive] Entering folder: {relativeTargetPath}");
                Directory.CreateDirectory(targetPath);
                await DownloadFolderRecursiveAsync(item.Id, targetPath, cancellationToken, depth + 1);
            }
            else
            {
                if (Directory.Exists(targetPath))
                {
                    DeleteDirectory(targetPath);
                    deletedEntryCount++;
                    Console.WriteLine($"{itemIndent}[drive] Removed stale folder before file sync: {relativeTargetPath}");
                }

                if (ShouldDownloadFile(item, targetPath))
                {
                    downloadedFileCount++;
                    Console.WriteLine($"{itemIndent}[drive] Downloading file #{downloadedFileCount}: {relativeTargetPath}");
                    await DownloadFileAsync(item, targetPath, cancellationToken);
                }
                else
                {
                    skippedFileCount++;
                    Console.WriteLine($"{itemIndent}[drive] Skipping unchanged file #{skippedFileCount}: {relativeTargetPath}");
                }
            }
        }

        RemoveStaleEntries(destinationPath, remoteEntryNames, itemIndent);
    }

    private string GetDisplayPath(string path)
    {
        if (string.IsNullOrWhiteSpace(rootDestinationPath))
        {
            return path;
        }

        var relativePath = Path.GetRelativePath(rootDestinationPath, path);
        return relativePath == "." ? rootDestinationPath : relativePath;
    }

    private static string GetIndent(int depth) => new(' ', depth * 2);

    private async Task<IReadOnlyList<DriveItem>> ListFolderItemsAsync(string folderId, CancellationToken cancellationToken)
    {
        var items = new List<DriveItem>();
        string? pageToken = null;

        do
        {
            var request = driveService.Files.List();
            request.Q = $"'{folderId}' in parents and trashed = false";
            request.Fields = "nextPageToken, files(id, name, mimeType, modifiedTime, size)";
            request.PageSize = 1000;
            request.IncludeItemsFromAllDrives = true;
            request.SupportsAllDrives = true;
            request.OrderBy = "folder,name";
            request.PageToken = pageToken;

            var response = await request.ExecuteAsync(cancellationToken);
            if (response.Files is not null)
            {
                items.AddRange(response.Files.Select(file => new DriveItem(
                    file.Id ?? throw new InvalidOperationException("Google Drive file id is missing."),
                    file.Name ?? throw new InvalidOperationException("Google Drive file name is missing."),
                    file.MimeType ?? string.Empty,
                    file.ModifiedTimeDateTimeOffset,
                    file.Size)));
            }

            pageToken = response.NextPageToken;
        }
        while (!string.IsNullOrWhiteSpace(pageToken));

        return items;
    }

    private IReadOnlyList<DriveItem> SelectUniqueItems(IReadOnlyList<DriveItem> items, string destinationPath, string itemIndent)
    {
        var uniqueItems = new List<DriveItem>();

        foreach (var group in items.GroupBy(item => item.Name, EntryNameComparer))
        {
            var preferredItem = group
                .OrderByDescending(IsFolder)
                .ThenByDescending(item => item.ModifiedTime ?? DateTimeOffset.MinValue)
                .ThenByDescending(item => item.Size ?? -1)
                .ThenBy(item => item.Id, StringComparer.Ordinal)
                .First();

            uniqueItems.Add(preferredItem);

            var skippedItems = group
                .Where(item => !string.Equals(item.Id, preferredItem.Id, StringComparison.Ordinal))
                .ToList();

            if (skippedItems.Count == 0)
            {
                continue;
            }

            ignoredDuplicateCount += skippedItems.Count;
            var relativeTargetPath = GetDisplayPath(Path.Combine(destinationPath, preferredItem.Name));
            var preferredKind = IsFolder(preferredItem) ? "folder" : "file";
            Console.WriteLine($"{itemIndent}[drive] Ignoring {skippedItems.Count} duplicate Drive item(s) for {relativeTargetPath}; keeping the preferred {preferredKind}.");
        }

        return uniqueItems;
    }

    private static bool IsFolder(DriveItem item) => item.MimeType == "application/vnd.google-apps.folder";

    private bool ShouldDownloadFile(DriveItem item, string destinationPath)
    {
        if (!File.Exists(destinationPath))
        {
            return true;
        }

        var fileInfo = new FileInfo(destinationPath);
        if (item.Size.HasValue && fileInfo.Length != item.Size.Value)
        {
            return true;
        }

        if (!item.ModifiedTime.HasValue)
        {
            return false;
        }

        return fileInfo.LastWriteTimeUtc.Add(ModifiedTimeTolerance) < item.ModifiedTime.Value.UtcDateTime;
    }

    private async Task DownloadFileAsync(DriveItem item, string destinationPath, CancellationToken cancellationToken)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(destinationPath) ?? throw new InvalidOperationException("Destination path must include a directory."));
        await using var stream = File.Create(destinationPath);
        var request = driveService.Files.Get(item.Id);
        request.SupportsAllDrives = true;
        await request.DownloadAsync(stream, cancellationToken);

        if (item.ModifiedTime.HasValue)
        {
            File.SetLastWriteTimeUtc(destinationPath, item.ModifiedTime.Value.UtcDateTime);
        }
    }

    private void RemoveStaleEntries(string destinationPath, HashSet<string> remoteEntryNames, string itemIndent)
    {
        foreach (var entryPath in Directory.EnumerateFileSystemEntries(destinationPath))
        {
            var entryName = Path.GetFileName(entryPath);
            if (remoteEntryNames.Contains(entryName))
            {
                continue;
            }

            var relativePath = GetDisplayPath(entryPath);
            if (Directory.Exists(entryPath))
            {
                DeleteDirectory(entryPath);
                Console.WriteLine($"{itemIndent}[drive] Removed stale folder: {relativePath}");
            }
            else
            {
                DeleteFile(entryPath);
                Console.WriteLine($"{itemIndent}[drive] Removed stale file: {relativePath}");
            }

            deletedEntryCount++;
        }
    }

    private static void DeleteDirectory(string path)
    {
        ResetAttributes(path);
        Directory.Delete(path, true);
    }

    private static void DeleteFile(string path)
    {
        File.SetAttributes(path, FileAttributes.Normal);
        File.Delete(path);
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

    private sealed record DriveItem(string Id, string Name, string MimeType, DateTimeOffset? ModifiedTime, long? Size);
}