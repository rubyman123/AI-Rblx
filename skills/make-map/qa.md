# QA loop for /make-map (method by fwjelaa, FWJ STUDIOS)

A map is done only when all four pass.

## 1. Shots

Every map.json has a `shots` list: `{"name", "cam": [x,y,z], "look": [x,y,z]}`. Always include:
- `spawn_view`: what a new player sees (eye height about 5 above the spawn, looking along the main axis)
- `hero`: high three-quarter view of the whole map (the thumbnail shot)
- one eye-level shot per zone or room, from its entrance
- `top_down`: straight down from far above (use a look point 1 stud off the camera's X/Z so lookAt is defined)
- one shot of the main landmark from below

Take each one in two calls:
1. `execute_luau`: `return require(game.ServerStorage.MapKit.MapKit).shot("<id>", "<name>")` parks Studio's real
   camera at the shot.
2. `screen_capture` with **no** camera arguments.

Don't pass `camera_position` to `screen_capture`: it grabs the frame before Roblox lights that spot, so every
PointLight/SurfaceLight/SpotLight room comes out dark (measured on the Backrooms: the pillar room looked unlit,
then over-bright once the camera was really there). Sun-lit outdoor maps look the same either way, but use
`K.shot` everywhere so you never tune lights on a wrong picture.

If a textured map looks white or flat, the textures are still streaming in: capture again before judging.

**Terrain maps: shoot in Play.** After the terrain has been rewritten a few times, Edit can draw stale water (flat
gold or white sheets no voxel holds). Start Play, then pin the camera in the Client and capture:

```lua
local RunService = game:GetService("RunService")
local cam = workspace.CurrentCamera
cam.CameraType = Enum.CameraType.Scriptable
local tgt = CFrame.lookAt(Vector3.new(camX, camY, camZ), Vector3.new(lookX, lookY, lookZ))
pcall(function() game.Players.LocalPlayer:RequestStreamAroundAsync(tgt.Position, 10) end)
RunService:UnbindFromRenderStep("MapKitShot")
RunService:BindToRenderStep("MapKitShot", Enum.RenderPriority.Last.Value, function() cam.CFrame = tgt end)
```

A prop that stays a smooth white (or black) blob in Play is not streaming: see CLAUDE.md, Gotchas (untextured scans).

Copy the returned image file into `maps/<id>/shots/<name>.jpg` for the shots you show the user. If a capture
times out, the Studio window is hidden: bring it to the front (CLAUDE.md, Gotchas).

## 2. Rubric (judge every shot; fix the biggest failure first)

1. **Focal point:** from spawn you can see where to go and what the big landmark is (the "weenie").
2. **Readable at phone size:** paths contrast with the ground in hue and brightness; signs ≥ 1.5 studs tall up
   close, ≥ 3 studs when read from 40+ studs.
3. **Grouping, not sprinkling:** props in clusters of 3-5 with quiet areas between. Even scatter with the same
   spacing everywhere is the number one "AI-made" tell.
4. **Variation:** at least two sizes and two tints of every repeated prop; nothing lines up by accident.
5. **Nothing floats or sinks wrongly:** bases touch the ground and step edges are clean.
6. **Palette discipline:** one hue family per zone; the brightest accent only on interactables; Neon only on
   pads, gates, crystals, lava.
7. **Scale:** doors, paths, steps and props read right against a 5-stud character. Put a dummy in when unsure:
   `K.Build.part({Size = Vector3.new(2, 5, 1), CFrame = ..., Color = Color3.new(1,0,0)})`, then delete it.
8. **Lighting:** the critical path and exits are the brightest, most contrasted things in frame (squint test).

## 3. Validator + walk test

`return require(game.ServerStorage.MapKit.MapKit).qa("<id>")` must start with `QA PASS` (realistic maps with
4-stud doors set `"agent": {"radius": 1.25, "height": 5.5}` in map.json): no unanchored parts,
nothing below the floor, no kit part left default grey, every POI reachable from spawn. Fix every WARN too unless
it is deliberate. Then check what the report can't:
- **Jumps:** a WALK line with jumps on the critical path means a step or gap; no required jump over 6 studs
  (phones), so add a ramp or stairs.
- **Ceilings:** interiors need at least 10 studs of headroom on every walkable route.
- **Spot walk:** `start_stop_play(is_start = true)`, then `character_navigation` (datamodel `Client`) to the
  landmark and to one far POI; watch for snagging on props. Stop play after.
- **Out of bounds:** try to walk past every edge (invisible walls, water, kill floor); nobody should fall off the
  map or walk into the void.

## 4. Budget

1. `python kit/tools/run.py budget <id>` prints a Luau snippet.
2. `start_stop_play(is_start = true)`, wait about 5 s.
3. `execute_luau` the snippet with datamodel `Client`.
4. `start_stop_play(is_start = false)`.

Targets per view, shadows excluded: **PC 800k triangles / 600 draw calls**, **phones 500k / 500**. Draw calls
matter most (one costs about as much as 20k triangles). Over target? Find the pass first (the snippet's numbers
are totals; read `tri.Children` for Opaque / Terrain / Transparent), then:
- **Terrain water first.** Measured: 5800 parts cost about 11 draw calls (instancing held even with many colours),
  while a 2000-stud terrain sea cost about 350 per view. Keep terrain water to about 700 studs around the play
  area and finish the horizon with one flat part.
- `Build.decor` and no shadows on small things.
- Fewer transparent parts (overdraw).
- Thin out the scatter far from the paths.
