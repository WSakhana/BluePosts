FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

COPY . ./
RUN dotnet publish BluePosts.Automation.csproj -c Release -r linux-x64 --self-contained false -o /app/publish

FROM mcr.microsoft.com/dotnet/runtime:10.0 AS runtime
RUN apt-get update \
    && apt-get install -y --no-install-recommends git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
COPY --from=build /app/publish /app

ENV BLUEPOSTS_REPO_ROOT=/tmp/blueposts-repo \
    BLUEPOSTS_REPO_URL=https://github.com/WSakhana/BluePosts.git \
    BLUEPOSTS_SOURCE_PATH=/tmp/blueposts-source \
    BLUEPOSTS_DRIVE_FOLDER_ID=153osz5cXU3C0Ju07AJ0YArt2LQbbsjny \
    BLUEPOSTS_GOOGLE_CREDENTIALS=/run/secrets/google-service-account.json \
    BLUEPOSTS_GIT_REMOTE=origin \
    BLUEPOSTS_GIT_BRANCH=main \
    BLUEPOSTS_VERSION_BUMP=patch \
    GIT_AUTHOR_NAME="BluePosts Automation" \
    GIT_AUTHOR_EMAIL=blueposts-automation@local \
    GIT_COMMITTER_NAME="BluePosts Automation" \
    GIT_COMMITTER_EMAIL=blueposts-automation@local

ENTRYPOINT ["/app/BluePosts.Automation"]
CMD ["pipeline"]