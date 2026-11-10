---
name: make-map
description: Builds a finished, walkable Roblox map in the open Roblox Studio place: stylized blocky simulator maps ("lift a ___" style), backrooms/liminal spaces, super-realistic abandoned horror houses at night (scanned CC0 props, PBR materials), and realistic nature (terrain valleys, lakes, generated trees, HDRI skies). It builds with the MapKit kit, then checks the map with screenshots, a walk test and a performance budget (method by fwjelaa, FWJ STUDIOS). Use when the user asks for a Roblox map, level, world, lobby, scene or environment, describes a place to build in Studio, or types /make-map. To plan or critique a layout without building it, use fwjelaa-worldbuilding.
argument-hint: "[map idea + notes, e.g. lift a boulder simulator, just build it]"
---

# Make a Roblox map

## The pack (works from any folder)

This skill carries the whole pack: the MapKit kit, style guides, examples and research. It lives in this
skill's base directory, the folder shown as "Base directory for this skill" when the skill loads (**PACK** below).

- Every relative path in `CLAUDE.md` and `qa.md` (`kit/...`, `maps/...`, `styles/...`, `research/...`, `ref/...`,
  `assets.json`) means that path inside PACK, not in the current project.
- New maps go in `PACK/maps/<id>/` (`map.json`, `build.luau`, `notes.md`, `shots/`). `run.py serve` serves PACK
  to Studio, so `K.run` only finds maps there.
- Run the pack's tools from PACK, in Bash: `cd "<PACK>" && python
  kit/tools/run.py <command>`. Start `serve` that way with `run_in_background`. The `cd` also avoids the "path
  longer than allowed" error Python gives when the session's folder has a very long path.

## The workflow

Follow **"When the user asks for a map"** in `PACK/CLAUDE.md`. It covers setup, the 5-line plan,
`maps/<id>/map.json` and `build.luau`, building phase by phase through the Studio MCP, and the QA loop in
`PACK/qa.md`.

Before writing your first map, read `maps/lift-a-boulder/build.luau`, `kit/studio/MapKit/Props.luau` and the
family's style guide in `styles/`. Anything typed after `/make-map` is the map idea plus notes ("just build it",
"bigger", "night"). If nothing was typed, ask what to build and offer the four examples (`lift-a-boulder`,
`backrooms-level-0`, `farmhouse-night`, `forest-lake`).

Work until `K.qa(id)` prints `QA PASS`, every shot in the spec passes the rubric in `qa.md` (two rounds at
least), and the budget is inside the targets. Then hand over: say what was built, show the best shots, give the
budget numbers, and remind the user to save the place (Ctrl+S).

Method by fwjelaa (FWJ STUDIOS).
