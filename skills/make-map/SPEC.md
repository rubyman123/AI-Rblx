# Roblox Maps by fwjelaa (`/make-map`): design spec

Written 2026-10-24. Status: **draft for the creator's review**. Research behind every number: `research/00-05`.

## 1. Goal

A downloadable Claude Code pack that lets anyone type a map idea ("abandoned farmhouse at night", "lift a boulder
simulator") and get a **walkable, good-looking Roblox map built in their open Studio place**, in two families:

- **Realistic:** abandoned horror house, liminal/backrooms, realistic nature. CC0 PBR textures, Blender-made meshes,
  terrain written by code, mood lighting, ambient sound.
- **Stylized:** blocky simulator maps in the 2026 "lift a ___" style. Parts only, saturated BrickColor palettes,
  bright Soft lighting, phone-cheap.

It is for the creator's YouTube video (one-prompt showcase **and** a without-vs-with comparison) and for the viewers who
download it afterwards.

### Success criteria

1. All four demo maps are built **by the pack itself** in the creator's Studio, pass the QA gates in section 8, and look
   good from every shot in their shot list (the creator's eye is the final judge).
2. A viewer with Studio + Claude Code can unzip the pack, follow README, and get a map without editing code.
3. Every Roblox-specific claim the pack relies on is either measured in Studio (logged in `research/00-measured.md`
   and the CLAUDE.md gotchas) or marked as unverified.
4. The without/with comparison is fair: same prompt, same Studio, the only difference is the pack.

## 2. Decisions (the creator, 2026-10-24)

| Question | Decision |
|---|---|
| Format | fwjelaa pack zip, like the car and animation packs |
| Command | `/make-map` |
| Video | one-prompt showcase + without-vs-with comparison; the creator films the "without" take in a fresh session |
| Demo maps | blocky simulator, backrooms, horror house, realistic nature (build in that order) |
| Map scope | walkable showcase, about 300x300 studs: spawn, collisions, lighting, sound; not a full game |
| Devices | PC first, phones playable; the skill reports the budget |
| Outside assets | **CC0 libraries only** (Poly Haven, ambientCG). No Creator Store models, no Roblox AI generators. Everything else Claude builds (code, Blender, procedural textures) |
| Uploads | automatic. The creator adds their user account to the key's Assets scope so uploads are user-owned |
| Plan step | `/make-map` shows a 5-line plan and waits for "go"; "just build it" skips it |
| Looks | Claude picks the target look per map from research references |
| Approach | kit + skill (tested library, tools, style guides, saved specs, QA loop) |
| Realism bar (later, same day) | horror house and nature must be **super realistic**: scanned CC0 meshes (Poly Haven models) and Blender-made meshes with PBR SurfaceAppearance instead of part-built props, real-scale architecture, Realistic lighting. PC gets the full look; phones must still run (budget reported). The creator: "don't stop to ask, just build" for Plans 3-4 |

## 3. Constraints and measured facts that shape the design

- **Studio MCP is the only way into Studio.** `execute_luau` is stateless and freezes Studio until it yields: build
  in chunks (about 1000 instances), parent once per chunk, `task.wait()` between chunks.
- **Not scriptable from the MCP** (measured): `Lighting.Technology` (deprecated anyway), terrain grass
  (`Terrain.Decoration`), `MeshPart.MeshId`, `AssetService:CreateAssetAsync` ("not available yet"), heightmap import.
  **Scriptable** (measured): `Lighting.LightingStyle`, `PrioritizeLightingQuality`, MaterialVariant with custom maps,
  SurfaceAppearance maps (MeshParts only), `MaterialService:SetBaseMaterialOverride`, `Terrain:WriteVoxels`.
- **Asset ownership:** an asset only loads in a place if the place's owner owns it or was granted it. Group uploads
  in a user place render blank (measured). So uploads must be made as the place owner.
- **Textures:** Studio MCP `upload_image` uploads from a localhost URL as the Studio user and loads at once
  (measured). Normal maps must be OpenGL (Poly Haven `nor_gl`, ambientCG `NormalGL`). Author 1K, hero 2K.
- **Meshes:** 20k triangles per mesh hard limit. Upload Blender GLB as a Model with the Open Cloud key, insert by id.
- **Budgets:** Roblox's own reference is about 800k triangles and 600 draw calls per view for 60 fps on most
  devices; phone-safe target about 500k and 500. One draw call costs about as much as 20k triangles. Each Decal or
  Texture adds a draw call; MaterialVariants instance. Shadows switch off below graphics quality 4, and Realistic
  falls back to Soft on low settings, so every map must still read in Soft.
- **Player metrics:** character about 5 studs, WalkSpeed 16, JumpHeight 7.2, max flat jump about 8.7 studs (design
  gaps of 6 or less), doors 4x7 (realistic) or 8x12 (stylized), ceilings 10-14, main paths 12-16 wide.
- **The API key never enters the pack.** It lives at `%USERPROFILE%\.fwjelaa\roblox-open-cloud.key` (or the
  `ROBLOX_API_KEY` environment variable). The zip script refuses to pack anything that looks like a key.

## 4. Pack layout

```
roblox-maps/
  README.md            quick start (install, first map, troubleshooting)
  GUIDE.md / GUIDE.html  full guide: how it works, styles, tuning, uploads, budgets
  CLAUDE.md            rules for Claude: the workflow, gotchas (measured), what never to do
  CREDITS.md           fwjelaa; CC0 sources; MIT ports (stravant's GapFill, ResizeAlign, Redupe, polymap)
  SPEC.md              this file
  .claude/skills/make-map/
    SKILL.md           the /make-map entry point (short: when to use, workflow, gotchas, pointers)
    workflow.md        phase-by-phase instructions
    qa.md              shot list rules, rubric, budgets, walk test
  styles/              one style guide per family (section 6): horror-house.md, backrooms.md, nature.md,
                       simulator.md, _custom.md (template for anything else)
  kit/
    studio/MapKit/     Luau library loaded into Studio (section 5)
    blender/           headless Blender scripts: texture prep, mesh kits, GLB export
    tools/run.py       CLI: check, serve, fetch, prep, upload, shots, zip
  maps/<map-id>/       one folder per map: map.json (spec), notes.md, shots/
  assets.json          upload manifest: source URL, licence, local file, asset id, owner
  research/            sources and measured facts
  ref/                 reference boards per style (links + CC0 images only)
  prompts/             the "without the skill" prompts for the comparison video
```

## 5. Components

Each unit has one job and a small interface. Studio code is Luau ModuleScripts under `ServerStorage.MapKit`,
loaded from `run.py serve` (localhost) by a short bootstrap, the same way the car pack loads its installer.

| Unit | Job | Interface (sketch) |
|---|---|---|
| `Root` | Find or create the map root folder tree (`Workspace.Map_<id>/{Terrain,Blockout,Structures,Props,Foliage,Lights,Spawns,QA}`); re-acquired every call | `Root.get(id)`, `Root.clear(id, layer)` |
| `Build` | Chunked instance creation: build outside the DataModel, parent per chunk, `task.wait()`; one ChangeHistory recording per phase | `Build.batch(list, parent)`, `Build.part(props)` |
| `Geo` | Architecture from primitives: wall runs with door/window openings, floors, stairs, ramps, gable/hip roofs, trims, arches; ports of GapFill (triangle fill), ResizeAlign (face join), Redupe (arrays) | `Geo.wall(a, b, h, t, openings)`, `Geo.stairs(...)`, `Geo.roof(...)`, `Geo.tri(a,b,c,t)`, `Geo.array(...)` |
| `Terrain` | Heightfield → `WriteVoxels` (seeded fBm, explicit peaks, lake basins), paint by slope and height, water, carved paths | `Terrain.heightfield(spec)`, `Terrain.paint(rules)`, `Terrain.water(...)`, `Terrain.path(points, w)` |
| `Scatter` | Poisson-disk placement with clusters, slope/height masks, exclusion zones, align to normal, scale and yaw jitter; reuses MeshIds; per-device density caps | `Scatter.run{assets, region, density, minDist, masks, exclude}` |
| `Props` | Prop recipes: stylized (trees from balls, rocks from tilted blocks, fences, crates, signs, clouds) and realistic part-built props (furniture, planks, debris) | `Props.make(name, cframe, opts)` |
| `Decay` | Age a structure: broken/missing boards, boarded windows, grime overlays at contact edges, debris piles, dust motes, cobwebs | `Decay.apply(model, level)` |
| `Materials` | Create MaterialVariants from the manifest; terrain overrides | `Materials.install(set)` |
| `Lighting` | Apply a mood preset (LightingStyle, Atmosphere, Clouds, post FX, sky), place local lights with a shadow budget, flicker scripts | `Lighting.preset(name)`, `Lighting.light(cf, kind, opts)` |
| `Sound` | Ambience layers, reverb zones, a few 3D emitters | `Sound.ambience(name)` |
| `QA` | Validator (unanchored, floating, below floor, default grey, z-fighting, decor collision flags), part/light counts, walk test (PathfindingService spawn → every POI), budget via SceneAnalysisService in Play | `QA.validate(id)`, `QA.walk(id)`, `QA.budget(id)` |

Python and Blender side:

| Unit | Job |
|---|---|
| `run.py check` | Studio MCP reachable, place visible, Python + Pillow, Blender 4.2+ (only needed for realistic meshes), key valid (introspection) |
| `run.py serve` | Serves `kit/studio` and prepared textures on `127.0.0.1:8777` |
| `run.py fetch` | Downloads CC0 textures and HDRIs from Poly Haven / ambientCG by id, with a polite User-Agent; writes licence + source to `assets.json` |
| `run.py prep` | Resize (1K default, 2K hero), OpenGL normals, roughness/metalness to Roblox's expected channels, sky faces from an HDRI (1024 per face) |
| `run.py upload` | Images: through the Studio MCP `upload_image` (Claude calls it) or Open Cloud; meshes: GLB as Model via Open Cloud; polls operations; records ids. Skips anything already in the manifest |
| `blender/kit_*.py` | Headless Blender kits: rocks, pine and broadleaf trees (alpha-card leaves), logs, stumps, ferns, grass clumps; bake to one 1K or 2K material per kit; under 20k tris; GLB export |

## 6. Style guides (data, not prose)

Each `styles/<family>.md` holds: the look in one paragraph; 6-10 reference links; palette; material set (which
CC0 textures, StudsPerTile); lighting preset table; metrics (grid, door, ceiling, path widths); kit list; density
targets; decay level; sound layers; the shot list; and that family's "looks fake" tells. Starting values come from
`research/02` (lighting presets) and `research/04` (palettes, metrics). `_custom.md` is the template Claude fills
for any prompt that matches no family (it picks the nearest family and writes down what it changed).

## 7. `/make-map` workflow

1. **Setup check** (first run): `run.py check`. Tells the user exactly what to click if something is missing,
   for example "set Lighting → LightingStyle" if a write ever fails, or "keep the Studio window visible".
2. **Plan:** pick the family and layout grammar, write a 5-line plan (style, layout, focal point, mood, size) and
   wait for "go" unless the user said "just build it".
3. **Spec:** write `maps/<id>/map.json`: seed, origin, size, zones/rooms, POIs, palette, materials, lighting
   preset, budgets. This is the source of truth, so a crashed or disconnected build resumes from the last phase.
4. **Materials:** fetch → prep → upload what the manifest lacks → `Materials.install`.
5. **Greybox:** layout, terrain blockout, structure shells. Screenshot from the spawn and zone entrances, run
   the walk test. Fix scale problems now.
6. **Terrain** (realistic outdoor maps).
7. **Structures** (kit pieces replace greybox).
8. **Props and decay.**
9. **Scatter** (foliage, debris).
10. **Lighting, atmosphere, sound.**
11. **QA loop:** shot list → compare with the style guide's references and tells → fix → repeat, at least two
    rounds, until the rubric passes. Then the budget check and the validator.
12. **Handoff:** report (what was built, budget numbers, shots in `maps/<id>/shots/`) and "save the place
    (Ctrl+S)". Claude never publishes.

## 8. QA gates (a map is done only when all pass)

- **Shots:** every shot in the style's shot list (spawn view, hero view, eye-level walk views, one top-down, one
  16:9 and one phone-aspect framing) captured with `screen_capture` and judged against the references.
- **Rubric ("looks fake" tells):** evenly spread scatter; one tree/rock size; default grey Plastic; everything
  perfectly aligned (no tilt or variation); floating or sunk objects; no wear where things meet (wall bases, door
  frames); flat lighting with no focal contrast; obvious texture tiling; wrong scale (giant doors, low ceilings);
  identical props repeated in one shot; clutter spread evenly with no quiet areas; no clear focal point from spawn.
- **Walk test:** PathfindingService reaches every POI from spawn; spot walks with `character_navigation`;
  no required jump over 6 studs; ceilings at least 10; no way out of bounds.
- **Budget:** SceneAnalysisService triangles and draw calls at the hero views (Play mode, shadows pass excluded):
  PC target 800k/600, phone target 500k/500. Part count, shadowed lights per room (1-3), texture count reported.
- **Validator:** no unanchored map parts, no default grey Plastic left, decor has collision off and CastShadow off
  under 4 studs, nothing below the floor.

## 9. Demo maps (Claude's chosen looks)

| Map | Description | Pipeline pieces it proves |
|---|---|---|
| 1. **Lift a Boulder** (simulator) | Island on water. 50x50 spawn plaza at the south edge, a 14-wide route north through Meadow → Desert → Snow → Volcano bands, upgrade pads and liftable rocks that grow per band, white ground arrows, zone gates as landmarks, a giant boulder on a plateau at the north end visible from spawn. Part-built trees, rocks, clouds, fences; studded ground; bright Soft lighting | Root, Build, Geo, Props (stylized), Scatter (parts), Lighting presets, QA |
| 2. **Backrooms Level 0** | About 240x240 seeded maze of mono-yellow rooms and halls, 10-stud ceilings, damp carpet, fluorescent panel grid (lots of Neon + a few shadowed lights), a few "wrong" spaces (pillar room, dead end, dark area), buzzing hum | Material pipeline (fetch/prep/upload/MaterialVariant), procedural layout, light budget, Sound |
| 3. **Abandoned farmhouse** (horror) | Two-storey wooden house (porch, hall, living room, kitchen, stairs, two bedrooms, bathroom, attic hatch) on an overgrown lot: dead trees, broken picket fence, mailbox, dirt path, fog, moonlit night. Peeling wallpaper, broken floorboards, boarded windows, debris, overturned furniture, cobwebs, flicker lights | Geo architecture with openings, Decay, interiors, Realistic lighting + local lights, Terrain (small) |
| 4. **Forest lake at golden hour** (nature) | Terrain valley with a lake, a stream and rocky slopes; pine and broadleaf trees, ferns, grass clumps, fallen logs, stumps, rocks; god rays, atmosphere depth, wind and bird ambience | Terrain by code, Blender mesh kits, GLB upload, Scatter (meshes), sky from HDRI |

## 10. Video support

- `prompts/without-skill.md`: the exact prompts to type in a fresh session with no pack, one per demo map, plus the
  same prompts for the "with" take.
- Every map keeps its QA shots (`maps/<id>/shots/`), so before/after stills come free.
- Claude doesn't record or render video; the creator does.

## 11. Testing the kit

- Every MapKit module has a `selftest()` run in Studio through `execute_luau` (geometry asserts: wall openings
  leave the right gaps, stairs rise the right height, scatter respects min distance and masks, voxel writes land
  where expected). Self-tests build into `Workspace._MapKitTest` and clean up after themselves.
- Python tools have offline checks (`run.py check --offline`: manifest schema, image prep output sizes and normal
  convention, zip contents contain no key).
- Each new Roblox fact the kit depends on is measured once and logged (CLAUDE.md gotchas + `research/00`).

## 12. Out of scope

Gameplay systems (lifting, currency, pets, saving), publishing, monetization, multiplayer, NPCs, Creator Store or
AI-generated assets, a cinematic camera tool, and Studio Assistant packaging (possible later).

## 13. Risks

| Risk | Mitigation |
|---|---|
| Studio window hidden → screenshots and asset loads stall (seen today) | `run.py check` and the skill tell the user to keep Studio visible; every wait has a timeout |
| A preload hangs and drops the MCP | Preloads run in `task.spawn` with a polled timeout; builds resume from `map.json` |
| Upload ownership mismatch | Upload as the place owner; `check` compares the key's owners with `game.CreatorId` |
| Mesh GLB scale/orientation off | Measure once with a test cube; record the export settings in the kit |
| Realistic look falls apart on phones (Soft fallback) | Bake grime and shading into textures; capture one shot with LightingStyle Soft |
| Roblox changes an API | Measured facts carry a date and Studio version; `check` re-tests the critical ones |

## 14. Open question for the creator

**Sound:** ambience needs audio assets. Default plan: CC0 sounds from Freesound (CC0 filter only) uploaded with the
key. Alternative: also allow Roblox's own official sound library (free, but it lives in the Creator Store).
