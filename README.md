# fwjelaa vault

A Roblox game studio for Claude Code. 1,400+ notes you can read in Obsidian, plus a Claude Code plugin whose
skills build Roblox games the right way and check their own work: maps, animations, models, UI, VFX, sound,
safe gameplay code, and picking which game to make.

Made by fwjelaa (FWJ STUDIOS). Join the Discord: https://discord.gg/GgV7TWpwd9

## Install (about 5 minutes)

1. Unzip `fwjelaa-vault-<version>.zip` straight into `C:\Vaults\`. You get `C:\Vaults\fwjelaa\`.
   Keep the path short: long paths break unzipping on Windows. It's about 0.3 GB unzipped, mostly the
   1,700 reference pictures in `fwjelaa vault\80 Reference Library`, and installing the plugin copies it once more.
2. **Notes:** install Obsidian from obsidian.md, click "Open folder as vault" and pick
   `C:\Vaults\fwjelaa\fwjelaa vault`, the folder *inside*, not the outer `fwjelaa` folder. If you see
   folders called `skills`, `hooks` and `agents`, you opened the plugin: close it and pick `fwjelaa vault`.
   It opens on `000 Home`. The **fwjelaa's Infinite Void** theme turns on by itself.
3. **Claude Code**, connect the plugin:

   - **Claude desktop app:** open the plugin settings, click **Add marketplace**, paste
     `file:///C:/Vaults/fwjelaa` (no quotes) and click **Sync**. Then install **fwjelaa** from it.
   - **Claude Code in a terminal:** paste these two commands, one at a time:

     ```
     /plugin marketplace add "C:\Vaults\fwjelaa"
     /plugin install fwjelaa@fwjelaa
     ```

   Start a new session, then ask for anything Roblox in plain words. The right skill loads on its own.

## What's inside

| Area | Skills and commands |
|---|---|
| Knowledge | `fwjelaa` (finds the right notes for each task), `fwjelaa-lookup` agent |
| Maps | `make-map` (builds a walkable map in Studio and checks it), `fwjelaa-worldbuilding` |
| Animation | `make-anim` (R6/R15 from a clip or a description, verified against Blender) |
| Models | `make-model` (picture → Roblox model), `fwjelaa-blender-modeling`, `fwjelaa-asset-import` |
| UI | `fwjelaa-ui`, `fwjelaa-ui-builder`, `fwjelaa-figma` |
| VFX and sound | `fwjelaa-vfx`, `fwjelaa-sfx` |
| Gameplay code | `fwjelaa-systems`, `fwjelaa-system-builder`, `fwjelaa-secure-remotes`, `fwjelaa-datastore-safety`, `fwjelaa-monetization-compliance`, `fwjelaa-anti-exploit-review`, `fwjelaa-performance-audit`, `fwjelaa-debugging` |
| Game design | `/fwjelaa:debate`, `/fwjelaa:council`, `fwjelaa-trend-game`, `fwjelaa-tutorial` |
| Quality | `quality-score`, `/fwjelaa:audit` |

## Save your work

`make-map`, `make-anim` and `make-model` save what they make inside the plugin folder (`maps\<id>`, `out\`).
Reinstalling or updating the plugin replaces that folder, so copy anything you want to keep somewhere else first.

## Code check

The plugin checks every Luau file Claude writes for common Roblox mistakes (unsafe remotes, DataStore bugs,
purchase handling, deprecated APIs) and tells Claude to fix them. Turn it off with the environment variable
`FWJELAA_HOOK=off`.

## Themes

**fwjelaa's Infinite Void** (the default) is Gojo's domain: a black hole with gas spiralling in, the Six Eyes,
and 無量空処. **FWJ Sigil**, the red and black look, is still there: pick either in Obsidian under
Settings → Appearance → Themes. To use one in another vault, copy its folder from
`fwjelaa vault\.obsidian\themes\` into that vault's `.obsidian\themes` folder.

## Community

Questions, builds and updates: https://discord.gg/GgV7TWpwd9

## License

See `LICENSE.md`.
