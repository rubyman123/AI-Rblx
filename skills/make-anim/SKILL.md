---
name: make-anim
description: Makes a finished Roblox character animation (R6 or R15) with Blender or straight in Roblox Studio, from a reference clip, GIF or screenshots or from a description, checks it frame by frame and gets it playing in Studio (method by fwjelaa, FWJ STUDIOS). Use when the user sends or names a reference of a move (video, GIF, pictures) or asks for a Roblox animation (run, walk, idle, punch, M1 combo, kick, sword/spear slash, block, parry, dash, hit reaction, special, ultimate, emote), or types /make-anim.
---

# Make a Roblox animation

## The pack (works from any folder)

This skill carries the whole pack: the kit, the animation library in `anims/`, the Roblox helpers in `roblox/`
and the research. It lives in this skill's base directory, the folder shown as "Base directory for this skill"
when the skill loads (**PACK** below).

- Every relative path in `CLAUDE.md` (`kit/...`, `anims/...`, `roblox/...`, `research/...`, `config.json`) means
  that path inside PACK, not in the current project.
- Run the kit from PACK, in Bash: `cd "<PACK>" && python kit/run.py <command>`.
- Results land in `PACK/out/`. Copy anything you want to keep somewhere else: reinstalling or updating the
  fwjelaa plugin replaces PACK.
- Auto-upload is optional. It needs your own `PACK/config.json` (start from `config.example.json`); without it,
  import the `.rbxmx` by hand.

**A reference came with the request** (a clip, a GIF, screenshots, or a path to one)? Follow
**"When the user sends a reference"** in `CLAUDE.md`: timing sheet with `python kit/run.py ref`, study the
phases and poses, build, then `python kit/run.py compare` until it matches, then the checks and Studio steps.

**Just a description?** Follow **"When the user asks for an animation"** in `CLAUDE.md`.

Either way use its kit, pose language, timing cheat sheet, craft rules, quality bar and gotchas, and read
`anims/_lib.py`, `anims/_m1.py` and `anims/R6_Run.py` before writing your first animation. Anything typed after
`/make-anim` is the move and any notes ("weighty", "R15", "with a spear", "loop", a file path).

Pick the path from the tools you have: the Blender MCP (or Blender installed) → Path A; only the Roblox Studio MCP
→ Path B (Moon Animator 2). Work until the export prints `CHECKS: all clear` (deliberate strike smears aside),
the sheets (and the compare, for references) pass the quality bar from two angles, and, when Studio is connected,
`AnimKit.verify` prints `MATCHES BLENDER`. Then show the final sheet and tell the user how to watch it in Studio,
open it in Moon Animator 2, publish it and play it in their game.

Method by fwjelaa (FWJ STUDIOS).
