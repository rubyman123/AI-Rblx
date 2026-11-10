# Prompts for the comparison video. Method by fwjelaa (FWJ STUDIOS).

Film each map twice with the **same words**. The only difference is the pack.

## Setup for a fair test
- **Both takes:** a fresh Baseplate place in Roblox Studio, the Studio MCP connected, the same Claude model, the
  Studio window visible the whole time.
- **Without:** open Claude Code in an empty folder (no pack, no CLAUDE.md, no skills) and type the prompt as it is.
- **With:** open Claude Code in the unzipped pack folder and type `/make-map ` followed by the same prompt.
- Let both run until Claude says it is done. Don't help either take; if Claude asks a question, give both the same
  answer ("you choose" works).
- Screenshot the same three views in both: the spawn view, a view of the main landmark, and top-down.

## Two choices to make before filming
1. **The pack ships the four finished examples** (`maps/lift-a-boulder`, `maps/backrooms-level-0`,
   `maps/farmhouse-night`, `maps/forest-lake`), and the prompts below describe them closely. In the "with" take
   Claude may rebuild the shipped example instead of designing from your words. For an honest comparison, delete
   that map's folder from your unzipped copy before its "with" take: Claude then builds from scratch with the same
   kit and style guides. Or keep it and say on camera that the pack includes a finished example.
2. **Both takes load your own Claude Code setup** (your user-level CLAUDE.md, skills and plugins). That is the same
   in both, so the difference you film is still the pack. If you want the "without" take to be plain Claude, turn
   your own skills and plugins off for both takes.

## 1. Lift a Boulder (blocky simulator)

```
Make me a "lift a boulder" simulator map in my open Roblox Studio place. Bright blocky style, a spawn area, zones
that get harder as you go, upgrade pads, and a giant boulder at the end you can see from spawn.
```

## 2. Backrooms Level 0

```
Build the backrooms Level 0 in my open Roblox Studio place: endless yellow office rooms, damp carpet, buzzing
fluorescent lights. It should feel empty and wrong.
```

## 3. Abandoned farmhouse at night (horror)

```
Build an abandoned two-storey farmhouse at night in my open Roblox Studio place. Make it super realistic: a
porch, rooms you can walk through, broken furniture, a dead tree, moonlight. Scary but walkable.
```

## 4. Forest lake at golden hour (nature)

```
Build a realistic forest lake at golden hour in my open Roblox Studio place: hills, a lake with a pier, a stream,
real-looking trees, rocks and grass, and a campfire on the shore.
```

## After filming
- The "with" take keeps its shots in `maps/<id>/shots/`, and its notes in `maps/<id>/notes.md` say what the QA
  loop fixed; good material for the voice-over.
- Delete or regenerate your Open Cloud key after filming if it was ever on screen.
