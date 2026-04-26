using Google.Apis.Auth.OAuth2;
using Google.Apis.Drive.v3;
using Google.Apis.Services;

namespace BluePosts.Automation;

internal sealed class GoogleDriveDownloader
{
    private readonly DriveService driveService;
    private int downloadedFileCount;
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
        PrepareDestination(destinationPath);
        downloadedFileCount = 0;
        visitedFolderCount = 0;
        rootDestinationPath = Path.GetFullPath(destinationPath);

        Console.WriteLine($"[drive] Export destination: {rootDestinationPath}");
        await DownloadFolderRecursiveAsync(folderId, rootDestinationPath, cancellationToken, 0);
        Console.WriteLine($"[drive] Download complete: {downloadedFileCount} file(s) across {visitedFolderCount} folder(s)");
    }

    private static void PrepareDestination(string destinationPath)
    {
        if (Directory.Exists(destinationPath))
        {
            Directory.Delete(destinationPath, true);
        }

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
        foreach (var item in items)
        {
            cancellationToken.ThrowIfCancellationRequested();

            var targetPath = Path.Combine(destinationPath, item.Name);
            var relativeTargetPath = GetDisplayPath(targetPath);
            if (item.MimeType == "application/vnd.google-apps.folder")
            {
                Console.WriteLine($"{itemIndent}[drive] Entering folder: {relativeTargetPath}");
                Directory.CreateDirectory(targetPath);
                await DownloadFolderRecursiveAsync(item.Id, targetPath, cancellationToken, depth + 1);
            }
            else
            {
                downloadedFileCount++;
                Console.WriteLine($"{itemIndent}[drive] Downloading file #{downloadedFileCount}: {relativeTargetPath}");
                await DownloadFileAsync(item.Id, targetPath, cancellationToken);
            }
        }
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
            request.Fields = "nextPageToken, files(id, name, mimeType)";
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
                    file.MimeType ?? string.Empty)));
            }

            pageToken = response.NextPageToken;
        }
        while (!string.IsNullOrWhiteSpace(pageToken));

        return items;
    }

    private async Task DownloadFileAsync(string fileId, string destinationPath, CancellationToken cancellationToken)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(destinationPath) ?? throw new InvalidOperationException("Destination path must include a directory."));
        await using var stream = File.Create(destinationPath);
        var request = driveService.Files.Get(fileId);
        request.SupportsAllDrives = true;
        await request.DownloadAsync(stream, cancellationToken);
    }

    private sealed record DriveItem(string Id, string Name, string MimeType);
}