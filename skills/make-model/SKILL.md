---
name: make-model
description: Turns a reference picture into a polished, textured Roblox model built in Blender (method by fwjelaa, FWJ STUDIOS). Use when the user sends, attaches or names a picture of a character or prop and wants a 3D model, a Roblox model or "this made in Blender", or types /make-model. For a model described only in words, with no picture, use fwjelaa-blender-modeling.
---

# Make a Roblox model from a picture

## The pack (works from any folder)

This skill carries the whole pack: the kit, the finished examples in `build/` and the Roblox helpers in
`roblox/`. It lives in this skill's base directory, the folder shown as "Base directory for this skill" when the
skill loads (**PACK** below).

- Every relative path in `CLAUDE.md` (`kit/...`, `build/...`, `roblox/...`, `config.json`) means that path
  inside PACK, not in the current project.
- Run the kit from PACK, in Bash: `cd "<PACK>" && python kit/run.py <command>`.
- Results land in `PACK/out/`. Copy anything you want to keep somewhere else: reinstalling or updating the
  fwjelaa plugin replaces PACK.
- Auto-upload is optional. It needs your own `PACK/config.json` (start from `config.example.json`); without it,
  use File → Import 3D in Studio.

Follow **"When the user sends a picture"** in `CLAUDE.md` from start to finish, using the kit rules, quality bar and
gotchas there. `build/BearBuddy.py` is the finished example.

Anything the user typed after `/make-model` is the model's name or extra notes ("make the hat bigger", "it's a
pet, not a character").

Work until the model passes the quality bar and `python kit/run.py export <ModelId>` prints `ROBLOX READY`. Then show
the final compare image, list the Roblox files, and explain how to get it into Roblox (auto-upload if set up,
otherwise File → Import 3D).

Method by fwjelaa (FWJ STUDIOS).
