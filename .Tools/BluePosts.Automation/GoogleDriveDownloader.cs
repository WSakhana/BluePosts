using Google.Apis.Auth.OAuth2;
using Google.Apis.Drive.v3;
using Google.Apis.Services;

namespace BluePosts.Automation;

internal sealed class GoogleDriveDownloader
{
    private readonly DriveService driveService;

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
        await DownloadFolderRecursiveAsync(folderId, destinationPath, cancellationToken);
    }

    private static void PrepareDestination(string destinationPath)
    {
        if (Directory.Exists(destinationPath))
        {
            Directory.Delete(destinationPath, true);
        }

        Directory.CreateDirectory(destinationPath);
    }

    private async Task DownloadFolderRecursiveAsync(string folderId, string destinationPath, CancellationToken cancellationToken)
    {
        var items = await ListFolderItemsAsync(folderId, cancellationToken);
        foreach (var item in items)
        {
            cancellationToken.ThrowIfCancellationRequested();

            var targetPath = Path.Combine(destinationPath, item.Name);
            if (item.MimeType == "application/vnd.google-apps.folder")
            {
                Directory.CreateDirectory(targetPath);
                await DownloadFolderRecursiveAsync(item.Id, targetPath, cancellationToken);
            }
            else
            {
                await DownloadFileAsync(item.Id, targetPath, cancellationToken);
            }
        }
    }

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