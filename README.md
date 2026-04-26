# BluePosts - Blizzard Blue Posts Reader for WoW

**BluePosts** is a lightweight World of Warcraft Retail addon for Midnight that lets you read bundled Blizzard blue posts directly in game.

Stay informed about **class changes, hotfixes, announcements and community updates** without alt-tabbing. BluePosts includes a clean in-game reader with search, category filters, unread tracking, login notifications, minimap support and quick links to the original Blizzard forum posts.

[![CurseForge](https://img.shields.io/badge/CurseForge-BluePosts-orange?logo=curseforge)](https://www.curseforge.com/wow/addons/blueposts)
![WoW Retail](https://img.shields.io/badge/WoW-Retail-blue)
![Game Version](https://img.shields.io/badge/Midnight-12.0.5-blueviolet)
![Language](https://img.shields.io/badge/Lua-90%25-2C2D72)
![License](https://img.shields.io/badge/License-Apache--2.0-green)

## Why BluePosts?

Blizzard blue posts often contain important information about WoW updates, class tuning, hotfixes and upcoming changes. BluePosts brings those packaged official posts into your World of Warcraft UI so you can browse them from inside the game client.

BluePosts does not fetch live forum data while you play. Posts are bundled with each addon release for a fast, lightweight and reliable in-game archive. With CurseForge automatic updates enabled, new BluePosts releases can be installed automatically when they become available.

## Features

- Browse bundled Blizzard blue posts in a dedicated in-game reader.
- Search posts by title or category.
- Filter posts by category and region.
- Track read and unread posts per character profile.
- Toggle an unread-only view from the header.
- Open posts from a minimap or LibDataBroker launcher.
- Open an in-window settings panel from the title bar.
- Show a login toast when the current addon snapshot bundles new unread blue posts.
- Configure notifications, toast duration and position, reader text size, minimap visibility, auto-read behavior, and guild share confirmation.
- Copy the original forum link for the selected post.
- Share the selected post to guild chat.
- Jump directly to class sections inside class hotfix posts.

## Requirements

- World of Warcraft Retail
- Midnight 12.0.5 client

## Installation

1. Extract the `BluePosts` folder into `World of Warcraft\_retail_\Interface\AddOns`.
2. Launch the game and enable `BluePosts` on the character selection screen.

No external dependencies are required for the release package. The required libraries are bundled with the addon.

## Usage

- `/blueposts` opens or toggles the main window.
- `/bp` is the short command alias.
- `/bp reset` resets the window position and size.
- `/bp minimap` toggles the minimap icon.
- `/bp toasts` toggles login notifications for newly packaged unread posts.
- `/bp toasttest` previews the current toast without consuming the saved login notification state.
- `/bp settings` or `/bp options` opens the settings panel.

## Included Files

The release archive contains only addon runtime files:

- Lua source files
- TOC metadata
- Bundled libraries
- Bundled post media
- Release documentation

Build scripts and local tooling are not part of the packaged addon.

## Notes

- Post content is packaged with the addon release. New Blizzard posts require a newer addon package.
- Read state, minimap visibility, window placement, reader preferences, and toast preferences are saved in `BluePostsDB` account-wide.
