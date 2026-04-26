# BluePosts.Automation

Console .NET 10 qui remplace `BuildData.ps1` et automatise le pipeline complet dans Docker/Linux pour un déclenchement par n8n.

## Ce que fait le binaire

- `build-data` : reconstruit `BluePosts_Data.lua` et `Media/Posts` a partir d'un export local `BluePosts`.
- `pipeline` :
  - nettoie les dossiers temporaires configures avant de demarrer
  - clone le repo dans un dossier temporaire si `BLUEPOSTS_REPO_ROOT` ne contient pas deja un repo git
  - verifie un repo git local propre
  - fait `git fetch` puis `git pull --ff-only`
  - telecharge le dossier Google Drive `BluePosts`
  - regenere `BluePosts_Data.lua` et `Media/Posts`
  - cree le commit git
  - cree le tag git
  - pousse le commit et le tag

## Auth Google Drive

Le conteneur utilise un compte de service Google Drive via l'API Drive.

1. Cree un service account dans Google Cloud.
2. Active l'API Google Drive.
3. Partage le dossier Drive `BluePosts` avec l'email du service account.
4. Monte le JSON du service account dans le conteneur ou passe son contenu brut via `BLUEPOSTS_GOOGLE_CREDENTIALS`.

Exemple de montage avec `BLUEPOSTS_GOOGLE_CREDENTIALS=/run/secrets/google-service-account.json`:

```text
/run/secrets/google-service-account.json
```

Le fichier doit etre le JSON original telecharge depuis Google Cloud. Ne commitez jamais ce fichier ni son contenu dans le repo, meme pour un exemple de documentation.

## Build Docker

Depuis la racine du repo:

```bash
docker build -t blueposts-automation .Tools/BluePosts.Automation
```

Pour publier l'image sur Docker Hub avec un tag explicite:

```bash
docker login
docker build -t sakhana88/blueposts.automation:tagname .Tools/BluePosts.Automation
docker push sakhana88/blueposts.automation:tagname
```

Si l'image locale `blueposts-automation` existe deja, vous pouvez aussi simplement la re-tagger avant le push:

```bash
docker tag blueposts-automation sakhana88/blueposts.automation:tagname
docker push sakhana88/blueposts.automation:tagname
```

## Execution Docker

Exemple recommande pour un conteneur ephemere qui ne conserve rien apres execution:

Les chemins declares dans le `--env-file` sont lus par le processus dans le conteneur Linux. Utilisez donc des chemins comme `/tmp/...` ou `/run/secrets/...` dans `.env`, meme si le chemin monte cote hote est un chemin Windows.

Pour l'auth GitHub en HTTPS, laissez `BLUEPOSTS_REPO_URL` sans credentials et fournissez plutot `BLUEPOSTS_GITHUB_TOKEN` via un secret ou une variable d'environnement.

```bash
docker run --rm \
  -v /path/to/google-service-account.json:/run/secrets/google-service-account.json:ro \
  --env-file .Tools/BluePosts.Automation/.env.example \
  blueposts-automation
```

Dans ce mode, le repo est clone dans un dossier temporaire du conteneur, puis supprime apres le `git push`. Le dossier Google Drive telecharge est aussi supprime.

L'image Docker definit aussi une identite git par defaut pour permettre les `git commit` et `git tag` dans un conteneur ephemere. Pour la remplacer, passez `GIT_AUTHOR_NAME`, `GIT_AUTHOR_EMAIL`, `GIT_COMMITTER_NAME` et `GIT_COMMITTER_EMAIL` au `docker run` ou via votre orchestrateur.

Les dossiers temporaires sont nettoyes au debut du lancement suivant. Ils ne sont plus supprimes automatiquement en fin d'execution.

Le `CMD` par defaut lance `pipeline`. Pour ne lancer que la conversion locale:

```bash
docker run --rm \
  --workdir /workspace \
  -v "$PWD:/workspace" \
  blueposts-automation build-data --source-path /workspace/.sample-export
```

## n8n

Deux integrations simples:

1. `Execute Command` : lance la commande `docker run ... blueposts-automation`.
2. `Docker` node : demarre l'image avec le volume du repo, le secret Google et les variables d'environnement.

Variables minimales a fournir a n8n:

- `BLUEPOSTS_REPO_ROOT`
- `BLUEPOSTS_REPO_URL`
- `BLUEPOSTS_DRIVE_FOLDER_ID`
- `BLUEPOSTS_GOOGLE_CREDENTIALS`
- `BLUEPOSTS_GIT_BRANCH`

Variables optionnelles:

- `BLUEPOSTS_GITHUB_TOKEN` pour authentifier `git clone`, `fetch`, `pull` et `push` en HTTPS sans mettre le token dans `BLUEPOSTS_REPO_URL`
- `BLUEPOSTS_REPO_URL`
- `BLUEPOSTS_SOURCE_PATH`
- `BLUEPOSTS_VERSION`
- `BLUEPOSTS_VERSION_BUMP`
- `BLUEPOSTS_GIT_REMOTE`

## Commandes locales

```bash
dotnet build .Tools/BluePosts.Automation/BluePosts.Automation.csproj
dotnet run --project .Tools/BluePosts.Automation/BluePosts.Automation.csproj -- help
dotnet run --project .Tools/BluePosts.Automation/BluePosts.Automation.csproj -- build-data --source-path /path/to/BluePosts
```

## Exemples Windows hors conteneur

Ces chemins Windows s'appliquent a `dotnet run` lance sur l'hote. Pour `docker run --env-file`, utilisez des chemins du conteneur Linux comme `/tmp/...` et `/run/secrets/...`.

Dry run complet:

```powershell
dotnet run --project ".Tools\BluePosts.Automation\BluePosts.Automation.csproj" --pipeline --repo-root "D:\Temp\blueposts-repo" --repo-url "https://github.com/WSakhana/BluePosts.git" --source-path "D:\Temp\blueposts-source" --drive-folder-id "153osz5cXU3C0Ju07AJ0YArt2LQbbsjny" --google-credentials "D:\VM\n8n-gdrive-493909-c9fa3e30cfcf.json" --remote "origin" --branch "main" --version-bump "patch" --dry-run
```

Execution complete:

```powershell
dotnet run --project ".Tools\BluePosts.Automation\BluePosts.Automation.csproj" --pipeline --repo-root "D:\Temp\blueposts-repo" --repo-url "https://github.com/WSakhana/BluePosts.git" --source-path "D:\Temp\blueposts-source" --drive-folder-id "153osz5cXU3C0Ju07AJ0YArt2LQbbsjny" --google-credentials "D:\VM\n8n-gdrive-493909-c9fa3e30cfcf.json" --remote "origin" --branch "main" --version-bump "patch"
```

## Notes d'exploitation

- Le pipeline echoue si le repo contient deja des changements locaux, sauf avec `--allow-dirty`.
- Si la regeneration ne modifie pas `BluePosts_Data.lua` ou `Media/Posts`, aucun commit, tag ou push n'est cree.
- Les tags git doivent etre au format direct `1.0.2`, sans prefixe `v`.
- Le versioning est calcule depuis le dernier tag valide, puis incremente automatiquement au format `1.0.2 -> 1.0.3 -> ... -> 1.0.9 -> 1.1.0`.
- Le pipeline nettoie `BLUEPOSTS_SOURCE_PATH` au debut d'un lancement.
- Si `BLUEPOSTS_REPO_ROOT` est un dossier temporaire separe du repo courant, il est aussi nettoye au debut d'un lancement avant reclonage.