# BluePosts: experimental WoW Forever support

Version: `4.4.1-beta.1`. One source branch and version serve both editions.

## Behavior

Retail and Forever load the same generated BluePosts_Data.lua and Media/Posts corpus. Article formatting, class navigation, PTR/Classic and region filters match the existing reader. No client-specific corpus or summary collector is required. Existing n8n and .NET generation/publication pipelines are unchanged. The source TOC keeps @project-version@ for the existing packager. Guild sharing is blocked in Forever combat/instances. Local QA helpers live under the packager's already ignored .Tools directory.

## Validation status

The implementation is checked against the extracted Forever UI source
`1.60.1.70338` (project `WOW_PROJECT_CAMELOT`, interface `16001`). This is a source
reference, not an in-game test. Static checks and mocked Lua checks do not establish
combat safety, visual correctness, SavedVariables persistence or dependency compatibility.

Forever runtime: **pending, no local Forever client**. Retail runtime: **pending**.
Dependencies: **pending in-game validation**.

In game, `/bluepostsclient` prints the actual client/build and required dependency versions.
Record the tested build, tester, evidence and statuses in `.Tools/ForeverMigration/validation.json`.

## In-game checks

Shared corpus and images on both clients, unchanged region/Classic filters, search, read/unread persistence, notifications, source-link copying, guild-share restrictions, reader and class navigation. The existing pipeline remains the only automatic article generator. The local packaging helper creates QA drafts only; it does not replace or control the production pipeline.

For both editions: clean installation, options, `/reload`, relog, full restart,
settings persistence, relevant group/combat content, Lua errors and taint logs.
Use separate client installations and keep existing user profiles; there is no
automatic Retail-to-Forever SavedVariables transfer.

## Packages

Run `py .Tools/ForeverMigration/package.py --output .release` locally to create **QA drafts**:

- `BluePosts-4.4.1-beta.1-Retail.zip`
- `BluePosts-4.4.1-beta.1-Forever.zip`

Each archive contains the unchanged addon folder name and edition-specific TOC
metadata. Install a draft only in the intended client's `Interface/AddOns` directory.
`BUILD.json` records the source commit, dirty state, file hashes and QA status.

For a fully validated stable package, use `--release --tag <matching-version-tag>` from a clean,
tagged checkout after recording PASS for static checks, Forever runtime, Retail
runtime and dependencies, plus the actual Forever build and tester. The builder
does not create tags, install addons or upload files. The existing CurseForge
project can host both edition files. Initial public Forever versions are experimental betas. Their in-game checks remain pending.

## Sources

- [Forever client constants](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_ProjectConstants/Camelot/ProjectConstants.lua)
- [Forever UI source](https://github.com/Gethe/wow-ui-source/tree/forever)

## Experimental beta distribution

A public beta uses one archive with the existing client interfaces and Forever
interface 16001. Beta publication does not change the pending in-game validation
above. Stable releases remain blocked until those checks pass.
