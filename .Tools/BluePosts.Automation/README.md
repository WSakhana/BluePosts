# BluePosts.Automation

A .NET 10 console application that replaces `BuildData.ps1` and automates the full BluePosts pipeline in Docker/Linux for n8n-triggered runs.

## What the binary does

- `build-data`: rebuilds `BluePosts_Data.lua` and `Media/Posts` from a local `BluePosts` export.
- `pipeline`:
  - prepares working directories and cleans the temporary git clone only when needed
  - clones the repository into a temporary directory if `BLUEPOSTS_REPO_ROOT` does not already contain a git repo
  - validates that the local git repository is clean
  - runs `git fetch` and `git pull --ff-only`
  - syncs the Google Drive `BluePosts` folder by downloading only new or changed files
  - regenerates `BluePosts_Data.lua` and `Media/Posts`
  - updates `CHANGELOG.md` at the top of the file with player-friendly release notes and any newly bundled blue post titles
  - creates the git commit
  - creates the git tag
  - pushes the commit and tag

## Google Drive authentication

The container uses a Google Drive service account through the Drive API.

1. Create a service account in Google Cloud.
2. Enable the Google Drive API.
3. Share the `BluePosts` Drive folder with the service account email address.
4. Mount the service account JSON into the container at `/run/secrets/google-service-account.json`, or pass its raw contents or a custom path through `BLUEPOSTS_GOOGLE_CREDENTIALS`.

Default mount path used automatically by the container when `BLUEPOSTS_GOOGLE_CREDENTIALS` is not set:

```text
/run/secrets/google-service-account.json
```

The file must be the original JSON downloaded from Google Cloud. Never commit this file or its contents to the repository, even in examples.

## Build the Docker image

From the repository root:

```bash
docker build -t blueposts-automation .Tools/BluePosts.Automation
```

To publish the image to Docker Hub with an explicit tag:

```bash
docker login
docker build -t sakhana88/blueposts.automation:tagname .Tools/BluePosts.Automation
docker push sakhana88/blueposts.automation:tagname
```

If the local `blueposts-automation` image already exists, you can also retag it before pushing:

```bash
docker tag blueposts-automation sakhana88/blueposts.automation:tagname
docker push sakhana88/blueposts.automation:tagname
```

## Run with Docker

Recommended example for an ephemeral container run:

Paths defined in `--env-file` are read by the process inside the Linux container. Use container paths such as `/tmp/...` or `/run/secrets/...` in `.env`, even if the mounted host path is a Windows path.

For GitHub HTTPS authentication, keep `BLUEPOSTS_REPO_URL` free of embedded credentials and provide `BLUEPOSTS_GITHUB_TOKEN` through a secret or environment variable instead.

```bash
docker run --rm \
  -v /path/to/google-service-account.json:/run/secrets/google-service-account.json:ro \
  --env-file .Tools/BluePosts.Automation/.env.example \
  blueposts-automation
```

In this mode, the repo can be cloned into a temporary container directory. That temporary clone is cleaned at the start of the next run if it is different from the current repo. The local Google Drive mirror is preserved to support incremental syncs.

The Docker image also defines a default git identity so `git commit` and `git tag` work in an ephemeral container. To override it, pass `GIT_AUTHOR_NAME`, `GIT_AUTHOR_EMAIL`, `GIT_COMMITTER_NAME`, and `GIT_COMMITTER_EMAIL` through `docker run` or your orchestrator.

The temporary git clone is cleaned at the start of the next run if it is separate from the current repo. The local Google Drive folder is not purged between runs. It is synced as an incremental mirror, downloading new files, refreshing modified files, and deleting stale local items.

The default `CMD` runs `pipeline`. To run only the local conversion step:

```bash
docker run --rm \
  --workdir /workspace \
  -v "$PWD:/workspace" \
  blueposts-automation build-data --source-path /workspace/.sample-export
```

## n8n

Two straightforward integrations:

1. `Execute Command`: runs `docker run ... blueposts-automation`.
2. `Docker` node: starts the image with the repository volume, Google secret, and environment variables.

Minimum variables to provide to n8n:

- `BLUEPOSTS_REPO_ROOT`
- `BLUEPOSTS_REPO_URL`
- `BLUEPOSTS_DRIVE_FOLDER_ID`
- `BLUEPOSTS_GIT_BRANCH`

If the secret is mounted at `/run/secrets/google-service-account.json`, `BLUEPOSTS_GOOGLE_CREDENTIALS` is optional.

Optional variables:

- `BLUEPOSTS_GITHUB_TOKEN` to authenticate `git clone`, `fetch`, `pull`, and `push` over HTTPS without embedding the token in `BLUEPOSTS_REPO_URL`
- `BLUEPOSTS_REPO_URL`
- `BLUEPOSTS_SOURCE_PATH`
- `BLUEPOSTS_VERSION`
- `BLUEPOSTS_VERSION_BUMP`
- `BLUEPOSTS_GIT_REMOTE`

## Local commands

```bash
dotnet build .Tools/BluePosts.Automation/BluePosts.Automation.csproj
dotnet run --project .Tools/BluePosts.Automation/BluePosts.Automation.csproj -- help
dotnet run --project .Tools/BluePosts.Automation/BluePosts.Automation.csproj -- build-data --source-path /path/to/BluePosts
```

## Windows examples outside Docker

These Windows paths apply to `dotnet run` executed on the host. For `docker run --env-file`, use Linux container paths such as `/tmp/...` and `/run/secrets/...`.

Full dry run:

```powershell
dotnet run --project ".Tools\BluePosts.Automation\BluePosts.Automation.csproj" --pipeline --repo-root "D:\Temp\blueposts-repo" --repo-url "https://github.com/WSakhana/BluePosts.git" --source-path "D:\Temp\blueposts-source" --drive-folder-id "153osz5cXU3C0Ju07AJ0YArt2LQbbsjny" --google-credentials "D:\VM\n8n-gdrive-493909-c9fa3e30cfcf.json" --remote "origin" --branch "main" --version-bump "patch" --dry-run
```

Full execution:

```powershell
dotnet run --project ".Tools\BluePosts.Automation\BluePosts.Automation.csproj" --pipeline --repo-root "D:\Temp\blueposts-repo" --repo-url "https://github.com/WSakhana/BluePosts.git" --source-path "D:\Temp\blueposts-source" --drive-folder-id "153osz5cXU3C0Ju07AJ0YArt2LQbbsjny" --google-credentials "D:\VM\n8n-gdrive-493909-c9fa3e30cfcf.json" --remote "origin" --branch "main" --version-bump "patch"
```

## Operational notes

- The pipeline fails if the repository already contains local changes, unless `--allow-dirty` is used.
- If regeneration does not change `BluePosts_Data.lua` or `Media/Posts`, no commit, tag, or push is created.
- Git tags must use the direct `1.0.2` format without a `v` prefix.
- Versioning is calculated from the latest valid tag, then incremented automatically following `1.0.2 -> 1.0.3 -> ... -> 1.0.9 -> 1.1.0`.
- The pipeline preserves `BLUEPOSTS_SOURCE_PATH` between runs and keeps it in sync with Google Drive incrementally.
- If `BLUEPOSTS_REPO_ROOT` is a separate temporary directory outside the current repo, it is also cleaned before recloning.