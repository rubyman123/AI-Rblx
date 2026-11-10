# Roblox maps, built by Claude: describe a place, get a walkable map in Studio

> **Method by fwjelaa (FWJ STUDIOS).** See CREDITS.md. When you finish a map, remind the user once that this
> method is by fwjelaa.

The user describes a map ("lift a boulder simulator", later "abandoned farmhouse at night", "backrooms", "forest
lake") and wants it **built in the Roblox Studio place they have open**: walkable, lit, good-looking from every
angle, playable on phones. You build it with the MapKit kit through the Roblox Studio MCP, check it with
screenshots, a walk test and a budget, and fix it until it passes. The user never places a part.

`maps/lift-a-boulder/` is the finished worked example. **Read `maps/lift-a-boulder/build.luau`,
`kit/studio/MapKit/Props.luau` and the family's style guide before writing a map.** `research/` holds the sources
behind every number, and `research/00-measured.md` what was measured in Studio. Measured facts beat docs.

## Families

| Family | Style guide | Ready |
|---|---|---|
| Blocky simulator ("lift a ___", tycoon/simulator hubs) | `styles/simulator.md` | yes (`lift-a-boulder`) |
| Backrooms / liminal (fluorescent office mazes, poolrooms, empty malls) | `styles/backrooms.md` | yes (`backrooms-level-0`) |
| Abandoned horror house (realistic, night) | `styles/horror-house.md` | yes (`farmhouse-night`) |
| Realistic nature (forest, lake, hills) | `styles/nature.md` | yes (`forest-lake`) |

Anything else: copy `styles/_custom.md` to `maps/<id>/style.md` and fill it from the nearest family's guide
(name that family in the plan), then log what you changed in `maps/<id>/notes.md` as you build.

## When the user asks for a map

1. **Setup (first time in a session).**
   - `python kit/tools/run.py check`.
   - Start `python kit/tools/run.py serve` in the background and leave it running.
   - `list_roblox_studios`: use the studio the user means. Several sessions may share one Studio, so re-check the
     place name before every edit.
   - Send `kit/studio/install.luau` with `execute_luau` (datamodel `Edit`). It must say `MapKit ... installed`.
   - Take one test `screen_capture`. If it times out, Studio's window is behind other windows or minimized: ask
     the user to bring it to the front (on Windows you can do it yourself, see Gotchas).
2. **Plan.** Pick the family and the layout grammar (style guide). Write a 5-line plan: style, layout, focal
   point (the thing you see from spawn), mood/lighting, size. Show it and wait for "go", unless they said
   "just build it". Ask only what really is unclear.
3. **Spec.** Pick an id (kebab-case, no brand names), then write `maps/<id>/map.json`: `id`, `title`, `family`,
   `seed`, `spawn`, `pois` (everything the player should reach), `shots` (see `qa.md`), `lighting`, plus the
   map's own data (zones, palette, positions). Data goes in the JSON; code goes in `build.luau`.
4. **Materials (textured maps: backrooms, horror house, nature).** Before any build phase, make every CC0 material
   the map needs:
   `python kit/tools/run.py material <name> --from ambientcg:<ID> [--tint "#hex"] [--motif chevron:128:0.1]
   [--studs 8] [--base Fabric] [--pattern Organic]`. It downloads, preps, uploads (with a key) and records the ids
   in `assets.json`. Without a key it prints the files to upload with `upload_image`, then
   `run.py record <name> color=rbxassetid://..`. Sounds: `run.py hum <name>` makes and uploads a looping hum, and
   `run.py record-sound <name> rbxassetid://..` records one the user uploaded. Image uploads are approved in
   under 20 s; Audio takes about 3 minutes. Blocky simulator maps skip this step.
   **Props (realistic maps)**: `run.py model <name> --from polyhaven:<id> [--tris 18000] [--collision Box|Hull|none]`
   fetches a scanned CC0 model, preps it in headless Blender (studs, under 20k triangles, origin at the
   bottom-centre, front = -Z) and uploads it as a Model; `run.py tree <name> --seed N --height H` grows a dead
   tree in Blender. Needs Blender (`run.py check`). Night/outdoor ambience: `run.py wind <name>`.
   **Nature**: `run.py tree <name> --kind broadleaf|pine --seed N --height H --bark polyhaven:<bark> --leaves
   ambientcg:LeafSet010` (pines: `--leaves needles`) grows a living tree with alpha leaf cards; `run.py clump <name>
   --leaves ambientcg:Foliage001` a grass or reed tuft patch; `run.py sky <name> --from polyhaven:<hdri>_puresky
   --azimuth <deg>` turns an HDRI into six 512² sky faces with its sun at that bearing (without a key it prints the
   six files for `upload_image`, then `run.py record-sky <name> Bk=rbxassetid://.. ...`); `run.py water <name>` a
   lapping-water loop. Asset commands may run in parallel: every `assets.json` write is locked.
   Every entry records the exact command that made it (`remake`); on a fresh pack the `materials`/`models` phases
   list every missing one with its command in a single error, so run them all, then the phase again. **Realistic
   example maps need an Open Cloud key in practice** (the farmhouse has 13 materials and 38 models; without a key
   each model is a manual Studio import). A fresh pack's `assets.json`
   has each example's recipe but no ids (ids only load for whoever uploaded them), so the first build of an
   example stops at its materials phase with the exact `run.py material ...` command to run.
5. **Build script.** Write `maps/<id>/build.luau` in the style of the examples (`lift-a-boulder` outdoors,
   `backrooms-level-0` indoors): `return function(K, spec)` returning phases. Each phase clears its own layers
   first (`K.Root.clear`) so it can be re-run. Order: (materials →) base (ground, borders) → route (paths,
   spawn) → landmarks → scatter → lighting. Add an `all` phase that runs them in order.
6. **Build phase by phase:** `execute_luau`
   `return require(game.ServerStorage.MapKit.MapKit).run("<id>", "<phase>")`. One phase per call, never `all` in
   one call on big maps. After `base` and `route`, take the spawn shot and run `K.qa(id)` before going on (cheap
   scale fixes now).
7. **QA loop** (`qa.md`): all shots (`K.shot`, then `screen_capture` with no camera
   arguments), the rubric, `K.qa(id)`, the budget. Fix the biggest problem first, re-run only the phases that
   changed, shoot again. At least two rounds; expect 3-5.
8. **Hand over:** what was built (zones, landmarks, part count), the best 3-4 shots (copy them into
   `maps/<id>/shots/`), the budget numbers, then "save the place (Ctrl+S)". Never publish.

## Kit (`local K = require(game.ServerStorage.MapKit.MapKit)`)

| Call | What it does |
|---|---|
| `K.run(id, phase)` / `K.qa(id)` | run one phase of `maps/<id>/build.luau` / validator + walk test report |
| `K.shot(id, name)` | parks Studio's real camera at one of the map's `shots`; then `screen_capture` with no camera arguments |
| `K.test({"Geo", ...})` | the kit's own tests (`kit/studio/tests/`) |
| `K.Root.get(id)`, `.layer(id, name)`, `.clear(id, name)` | `Workspace.Map_<id>` with layers Terrain, Ground, Structures, Route, Landmarks, Props, Foliage, Lights, Spawns, QA |
| `K.Root.removeTemplate()` | moves the template Baseplate/SpawnLocation to `ServerStorage.MapKit_Removed` (never deletes) |
| `K.Root.claimTerrain(id, cf, size)` | **call before every terrain write**: clears the box this map claimed last run, refuses (error) if the new box already holds terrain the map didn't make, records the box |
| `K.Build.part(props, class?)` | Anchored, SmoothPlastic, smooth surfaces; `Parent` set last |
| `K.Build.decor(inst)` | no collision/touch/query; no shadow under 4 studs |
| `K.Build.flush(items, parent)` | parent in chunks (never freeze Studio) |
| `K.Geo.box / slab / wall / stairs / ramp / tri` | blocks; slab with its top at cf; wall a→b with door/window openings; stairs and ramps rising along LookVector; solid triangle (low-poly terrain, roofs, rocks) |
| `K.Props.tree / pine / rock / bush / cloud / crate / flower / cactus / deadTree / boulder` | stylized scenery (`opts.rng`, `opts.scale`, colours as hex) |
| `K.Props.pad / arrow / sign / gate / stall / fence` | simulator furniture: upgrade pads, ground arrows, signs (LookVector at the reader), zone gates with names, shop stalls, fences a→b |
| `K.Materials.install(names)` / `.apply(part, name, tint?)` | MaterialVariants from `assets.json` (all names checked before any is made) / put one on a part: white shows the texture as made, a hex tint darkens or warms it |
| `K.Sound.ambience(id, name, soundId, opts)` / `.reverb(kind)` | a looped ambient Sound in the map / SoundService ambient reverb |
| `K.Models.install(names)` / `.place(name, cframe, opts?)` / `.variants(name)` | scanned models from `assets.json` loaded once into `ServerStorage.MapKit_Assets` / a clone at a pivot (bottom-centre, front = LookVector); opts `collision` (Box/Hull/Default/none), `shadow`, `scale`, `tint` (darkens the scan's textures), `variant` (one piece of a multi-variant file), `parent` / how many pieces. Parts named `Leaves*` (tree and tuft cards) are made see-through and never collide |
| `K.Materials.override(Enum.Material.Grass, name)` | terrain (and every part) of that material uses the variant; global to the place |
| `K.Root.releaseTerrain(id, parent?)` | hand a map's claimed terrain back (switching maps in one place); re-running its base phase rebuilds it |
| `K.Scatter.run{min, max, seed, spacing or clusters, exclude, clearance, maxSlope, params, make, parent}` | Poisson/cluster placement on the ground (min/max are **Vector2** X/Z), never on water, steep slopes or within `clearance` studs of an excluded zone (set it to the prop's footprint radius) |
| `K.Lighting.preset(name)` | mood preset (`simulator`, `liminal`, `night`, `golden`); returns what could not be set |
| `K.Terrain.heightfield{box, min, max, bottom, height(x,z), material(x,z,h,slope), water}` | terrain from one height function (Vector2 min/max, 4-stud columns), materials by rule, water a level or a per-column function; refuses before writing if the field leaves the claimed box |
| `K.Sky.apply(name)` / `K.Sky.matchSun(dir)` | a sky from `assets.json` `skies` (other Skies moved to `MapKit_Removed`) and the sun direction it was made with / latitude and ClockTime that put Roblox's sun there |
| `K.QA.validate / walk / report` | used by `K.qa`; map.json `"agent": {"radius", "height"}` sizes the walker (realistic 4-stud doors need radius 1.25) |

Need something the kit lacks? Write it in the map's `build.luau` first. Move it into the kit only when a second
map needs it, then add a test in `kit/studio/tests/`.

## Conventions

- Studs. Ground top y = 0. North = -Z (the LookVector of `CFrame.new()`). Spawn on the south (+Z) side facing north.
- Player: 5 studs tall, WalkSpeed 16, jump 7.2. Gaps ≤ 6 on the critical path, never a precise jump.
- Stylized: doors 8x12, paths 12-16 wide (secondary 8-10), blocking walls ≥ 12 tall. Grid of 4 studs; whole-stud
  sizes on studded surfaces.
- Colours in specs are hex strings of official BrickColors (`styles/simulator.md` has the palette).
- Seed everything: same spec → same map.
- The template's `Baseplate` and `SpawnLocation` get moved to `ServerStorage.MapKit_Removed`
  (`K.Root.removeTemplate`), never deleted. Never delete anything the user made.
- **Terrain belongs to the user.** Only write terrain inside a box claimed with `K.Root.claimTerrain` in the same
  phase; never `FillBlock(Air)` outside it. If the claim refuses, tell the user (fresh Baseplate place, or move
  the map) instead of forcing it.
- Every kit part needs a `Color`: `K.qa` fails parts left at the default grey.
- Re-running a phase rebuilds its layers from scratch: anything the user added inside `Map_<id>` layers by hand
  is lost. Say so in the handoff.

## Gotchas (measured in Studio 0.744, 2026-10-24)

- **`Lighting.Technology` cannot be read or written by scripts** (and it's deprecated). Use `LightingStyle`
  (Realistic/Soft) + `PrioritizeLightingQuality`; both are writable from `execute_luau`.
- **Terrain grass (`Terrain.Decoration`) is not scriptable.** If a map wants grass, tell the user where to tick it.
- **`MeshPart.MeshId` is not writable** from scripts, and `AssetService:CreateAssetAsync` says "not available
  yet". Meshes come in as uploaded Models: `K.Models.install` loads them with `InsertService:LoadAsset` (a deadline
  stops a stalled load with a message; it reloads a template whose manifest id changed).
- **WedgePart is high at its +Z end.** `K.Geo.ramp` already turns it round.
- **Part cylinders run along local X.** Props stand them up with `CFrame.Angles(0, 0, math.pi / 2)`.
- **Pathfinding works in Edit mode**, so `K.qa` needs no Play.
- **A phase that errors keeps whatever it built before the error** (the undo recording's Cancel does not roll it
  back from the MCP). Fix the cause and run the phase again: it clears its layers first.
- **Screenshots time out and new assets never load while the Studio window is in the background or minimized.**
  Ask the user to bring Studio to the front. On Windows you can do it yourself (the user asked for this once):
  PowerShell with user32 `ShowWindow(handle, 9)` + `SetForegroundWindow(handle)` on the `RobloxStudioBeta`
  process's `MainWindowHandle` (tap Alt first so Windows allows the focus change).
- **`ContentProvider:PreloadAsync` on an asset that can't load can hang `execute_luau` until the MCP drops.** Only
  preload inside `task.spawn`, polled with a timeout.
- **Uploads must be owned by the place's owner.** A group-owned image renders blank in a user-owned place.
- **SceneAnalysisService only reports in Play mode**, from the Client datamodel (the budget snippet).
- **Terrain water is the draw-call hog, not parts.** Thousands of parts cost about 11 draw calls (instancing); a
  2000-stud terrain sea cost about 350 per view. Keep terrain water to about 700 studs around the playable area
  and finish the horizon with one flat part (`maps/lift-a-boulder` base phase).
- **Raycasts don't see terrain water written moments ago** (fresh `FillBlock` water in an untouched area was
  invisible to `workspace:Raycast` in 4/4 trials, even a frame later); `Terrain:ReadVoxels` sees it at once.
  `K.Scatter.run` checks the voxel above every hit, so build water before scattering and it just works.
- **`screen_capture` with `camera_position` shows lit rooms dark.** It grabs the frame before Roblox lights that
  spot, so PointLights/SurfaceLights far from Studio's real camera look off. Park the real camera with `K.shot(id,
  name)` (or set `workspace.CurrentCamera.CFrame` in `execute_luau`), then capture with no camera arguments.
  Never tune lights on a camera-argument screenshot.
- **A MaterialVariant's texture is multiplied by `Part.Color`.** The default grey makes it about a third darker.
  `K.Materials.apply` sets white (or your tint); if you change `Color` afterwards you are tinting the texture.
- **`ContentProvider:PreloadAsync`'s callback says Failure for raw image ids that load fine.** Check
  `ContentProvider:GetAssetFetchStatus` or take a screenshot instead.
- **One map per place.** Maps are built round the origin, so two in one place overlap. To build another: hand the
  old map's terrain back (`K.Root.releaseTerrain(id)`), clear its MaterialService overrides, and move `Map_<id>` to
  `ServerStorage.MapKit_Stash` (never delete it). Moving it back means re-running its `base` phase (terrain) and
  the phase that sets its lighting preset (`lighting`, or `ambience` in the backrooms): both are global.
- **Captures time out when the display sleeps** (unattended builds): Studio stops drawing. A one-pixel mouse nudge
  (SendInput) before a capture wakes it; `SetThreadExecutionState` from a background process did not keep it on.
- **Textures stream in after a wake.** A capture right after waking can show every MaterialVariant white; capture
  again a few seconds later before judging the look.
- **`MeshPart.CollisionFidelity` can't be set from scripts** (silently ignored). `K.Models` rebuilds collision with
  `CreateMeshPartAsync` + `ApplyMesh`.
- **Scanned meshes ignore `Part.Color`** (the SurfaceAppearance wins); tint them with `SurfaceAppearance.Color`
  (`K.Models.place` `tint`).
- **Roblox's terrain grass blades grow through floors.** Make the terrain under buildings and porches Mud or Ground.
  The blades also cost 180-310k triangles per view; Roblox thins them on low settings.
- **A light inside a lamp model is shadowed by the lamp itself.** Place lamp/lantern/bulb props with `shadow = false`.
- **`Build.decor` turns off shadows for parts under 4 studs.** Turn `CastShadow` back on for pieces whose shadow
  matters (laths and flaps that shape a moonbeam).
- **Free-standing furniture in a room's middle can make the pathfinder fail a whole route** while every leg of it
  passes. Put big pieces against walls (that's where they belong in a real house anyway).
- **MaterialService overrides are global.** Clear them (`SetBaseMaterialOverride(material, "")`) when switching to
  another map in the same place.
- **Capture one screenshot at a time.** Two `screen_capture` calls in parallel collide and one times out. The
  capture is very wide (~2.8:1), so things at the frame edges look bigger than they are.
- **Judge terrain maps in Play, not Edit.** After the terrain was rewritten several times, Studio's Edit view kept
  old water meshes: flat gold sheets over land that no voxel held and Play did not show. Shoot with a
  `BindToRenderStep` camera in the Client (`maps/forest-lake/notes.md`).
- **Sky faces must be 512².** 1024² faces load as images but never render as a skybox (Studio keeps the old sky or
  shows its lettered placeholder). `run.py sky` makes 512 by default.
- **Some scanned models render as a smooth white (or black, in shade) blob** in Edit and Play although every map is
  approved and loads as an image. Roblox reuses an identical image or mesh, failed processing included, so
  re-uploading the same file never helps. `run.py model` re-encodes big JPEG textures (new images), which fixed
  `boulder_01`; `tree_stump_02` stayed white through fresh meshes and textures, so swap such a scan for a sibling.
- **A low sun leaves a valley in the rim's shadow.** A 14° sun behind 40-stud hills shades the whole floor; lift
  the shade (the `golden` preset does) rather than raising the sun away from the sky's.
- **Thin terrain water disappears.** Water under ~2.5 studs deep in 4-stud voxels doesn't render; make streams at
  least 10 wide and 2.8 deep, and sink them to the lake's level where they meet it.
- **`GetBaseMaterialOverride` returns the material's own name** for an unset override in some places; set `""`
  to clear, and only touch materials whose override names one of your variants.
- **A gate (or any beam) close in front of spawn hides the far landmark.** Check the sightline from the spawn
  camera to the landmark against every beam on the way; keep the first ~60 studs in front of spawn beam-free.

## Safety

- The Roblox API key lives outside the pack (`%USERPROFILE%\.fwjelaa\roblox-open-cloud.key` or `ROBLOX_API_KEY`).
  Never print it, show it, or copy it into the pack. `serve` and `zip` refuse it.
- Never use Creator Store models or Roblox's AI generators (`generate_*`, `search_asset` on the Creator Store).
  Everything is built by the kit or comes from CC0 libraries.
- Never publish the place. Upload (Open Cloud with the user's key, or Studio's `upload_image` without one) only
  the textures, sounds and meshes the map being built needs; they go to the user's own account.
