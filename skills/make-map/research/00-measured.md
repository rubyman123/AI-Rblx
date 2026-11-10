# Measured facts (trust these over docs)

Measured 2026-10-24 on the creator's Studio 0.744.0.7441077, place "Untitled Experience" (placeId <place id>,
owned by user <user id>), through the Roblox Studio MCP.

## Studio MCP (execute_luau context)
- `Lighting.Technology` cannot be read or written: "lacking capability RobloxScript". Same for
  `MaterialService.Use2022Materials`. The user has to set Technology in the Properties window (or the skill
  tells them to); scripts cannot.
- `Terrain.Decoration` and `Terrain.GrassLength` are "not a valid member" from this context: terrain grass is
  not script-controllable here.
- `Terrain:ImportHeightmap` does not exist. `Terrain:WriteVoxelChannels` does (and `WriteVoxels`).
- `AssetService:CreateEditableMesh` and `InsertService:LoadAsset` exist.
- HttpEnabled = true and StreamingEnabled = true in a fresh place made by the creator.
- Fresh place Lighting children: Sky, SunRaysEffect, Atmosphere, BloomEffect, DepthOfFieldEffect.
  Defaults: Brightness 3, ClockTime 14.5, ShadowSoftness 0.2, EnvironmentDiffuseScale 1.

## Studio MCP tools that matter
- `upload_image(imagePaths[])`: uploads images served over http (e.g. a local http.server) to Roblox through
  Studio's login and returns `rbxassetid://` ids. No Open Cloud key needed. (Untested yet: owner, moderation
  delay, size limits.)
- `insert_asset(assetId)`: inserts a model/mesh/image by id into the place.
- `screen_capture(camera_position, look_at_position)`: edit-time screenshot from any camera pose. This is how the
  skill sees its own work.
- `character_navigation` (Client, play mode) walks the character to a point: walkability test.
- `skill rbx-scene-analysis`: SceneAnalysisService (play mode only). `GetTriangleCompositionAsync()` gives
  triangles + draw calls per render pass for the current view. Roblox's reference: ~800k triangles and ~600 draw
  calls is where most devices hold 60 fps; one draw call costs about 20k triangles of GPU; exclude the Shadows
  pass. Each Decal/Texture adds a draw call; MaterialVariants take part in instancing and do not.
  Source: Roblox's Studio Assistant scene-analysis skill (third-party; kept locally while building, not shipped).

## Open Cloud key (the creator's, stored outside the pack at %USERPROFILE%\.fwjelaa\roblox-open-cloud.key)
- Introspection OK. `asset` read+write is scoped to GROUP <group id> (not the user). The test place is owned by
  the USER <user id>.
- NEVER copy the key into the pack folder or the zip.

## Upload probe (2026-10-24)
- Open Cloud `POST /assets/v1/assets` multipart (`request` JSON + `fileContent`), `assetType: "Image"`,
  `creationContext.creator.groupId` → operation done in ~2 s, returns the IMAGE id directly (no decal→image
  conversion). Moderation "Reviewing" → "Approved" within ~1 min.
- That GROUP-owned image (<image id>) does NOT load in the USER-owned place even after approval:
  ContentProvider:PreloadAsync → AssetFetchStatus.Failure, Decal renders blank. Asset permissions, not delay.
- Studio MCP `upload_image("http://127.0.0.1:8766/probe_checker.png")` → rbxassetid://<image id>, owned by
  the Studio user, loads instantly (Success) and renders. Zero setup.
- Rule: the uploader must be the place's owner (same user or same group), or permission must be granted.
  Probe parts live in workspace._probe_fwjelaa (remove when done).

## What execute_luau may write (2026-10-24)
- MaterialVariant: create, set ColorMap (and pattern Regular), parent to MaterialService: OK. A Part with
  Material=Concrete + MaterialVariant="ProbeChecker" renders the custom texture tiled (StudsPerTile 4). Seen.
- SurfaceAppearance: ColorMap writable, but "can only be parented to MeshParts".
- MeshPart.MeshId: NOT writable ("lacking capability NotAccessible"). Routes: insert_asset / InsertService,
  AssetService:CreateMeshPartAsync (exists), AssetService:CreateAssetAsync (exists).
- Lighting.ShadowSoftness / EnvironmentSpecularScale, SoundService.AmbientReverb, Terrain:GetMaterialColor:
  readable and writable.
- `Lighting.LightingStyle` IS writable from execute_luau (Soft → Realistic → Soft, read back each time), and
  `PrioritizeLightingQuality` too. Fresh place default: LightingStyle Soft, PrioritizeLightingQuality true.
  (Technology stays locked, and is deprecated anyway.)
- `MaterialService:SetBaseMaterialOverride` exists.
- `AssetService:CreateAssetAsync` from execute_luau → error "CreateAssetAsync and CreateAssetVersionAsync are not
  available yet". The MCP context cannot publish meshes. Mesh route = Open Cloud Model upload or Import 3D.

## Kit build facts (2026-10-24, Plan 1)
- WedgePart: high at its +Z end (raycast). Part Cylinder: axis = local X. Ball Shape keeps a non-uniform Size
  set from script (6,3,6 stays 6,3,6). Minimum part size 0.001.
- PathfindingService:ComputeAsync works in Edit mode (Status Success, 12 waypoints on the baseplate).
- SceneAnalysisService exists in the Edit DataModel (it only reports during Play).
- ModuleScript.Source is writable from execute_luau, and HttpService:GetAsync to 127.0.0.1:8777 works in Edit.
- ChangeHistoryService recording + FinishRecording(Cancel) from execute_luau does NOT roll back a failed phase:
  the phase cleared 3 parts and made 1 before erroring, and the 1 stayed. Rely on phases clearing their own
  layers, not on undo.
- screen_capture timed out for ~1 h while the Studio window was in the background; it worked right after
  ShowWindow(SW_RESTORE) + SetForegroundWindow on the RobloxStudioBeta main window (PowerShell user32 call).

- Budget on Lift a Boulder (5816 parts, Play/Client, SceneAnalysisService): Opaque parts = 11 draw calls
  (part instancing works even with many colours). A 2000x2000-stud terrain-water sea = 344-364 draw calls and
  ~230k triangles per view. Shrinking terrain water to 700 studs plus one flat 8000-stud part for the far sea cut
  draws to 136-363 per view and looked identical.
- Two screen_capture calls sent in parallel collide (one times out). Capture one at a time.
- Terrain:FillBlock water in a previously untouched area is invisible to workspace:Raycast (IgnoreWater = false)
  in the same frame and sometimes a frame later (4/4 fresh areas: nil); Terrain:ReadVoxels returns Water with
  occupancy > 0 at once. It showed up as a flaky Scatter test right after stopping Play. Scatter.run now checks
  the voxel above each hit (regression test "run skips water written the same frame").
- screen_capture uses a very wide aspect (~2.8:1), so objects at the frame edges look bigger and closer.

## Texture pipeline (Plan 2, 2026-10-24)
- `run.py material backrooms_carpet --from ambientcg:Carpet012` (10.9 MB zip, cached) → prep → 3 Open Cloud Image
  uploads as the user in ~10 s; all three moderation-Approved by the first check 17 s later.
- As a MaterialVariant (Fabric, StudsPerTile 6, Organic) the carpet renders and tiles cleanly (screenshot).
- `ContentProvider:PreloadAsync({"rbxassetid://<image>"}, cb)` reported **Failure** for these image ids even while
  `GetAssetFetchStatus` said Success and the texture rendered. Don't trust the PreloadAsync callback for raw image
  ids; check `GetAssetFetchStatus` or take a screenshot.

- Open Cloud **Audio** upload with the user key works (`run.py hum backrooms_hum`: 8 s mono 16-bit WAV,
  706 KB → rbxassetid://<image id>). Moderation: Reviewing for ~2.7 min, then Approved. No ID-verification
  error at this size/count.

## Key #2 (2026-10-24, later)
- A second key, owned by the creator's user, with Assets read/write for that user, worked for user-owned uploads. The guide must tell viewers to make a minimal key: Assets API read+write for
  their own user + asset-permissions write, nothing else.
- Open Cloud upload with `creator.userId` works: image <image id>. Loading in the place not yet judged
  (Studio stopped fetching/rendering: every new asset stays AssetFetchStatus.None, screen_capture times out).

## Asset permissions (2026-10-24)
- Asset-permissions grant `PATCH /asset-permissions-api/v1/assets/permissions` {subjectType Universe, subjectId
  game.GameId, action Use} → 200 successAssetIds for group images. The earlier-failed image still failed after the
  grant (maybe cached for the session). Fresh uploads (granted-before-use <image id>, openUse
  <image id>) could not be judged: Studio stopped fetching new assets and screen_capture timed out at that
  point (window probably hidden). Re-test with Studio visible.
- `creationContext.assetPrivacy: "openUse"` is accepted on a group Image upload (no error).
- A preload of a not-yet-loaded asset can hang execute_luau long enough to drop the MCP connection. Always run
  PreloadAsync inside task.spawn and poll with a timeout.

## Backrooms Level 0 (Plan 2, 2026-10-24)
- **`screen_capture(camera_position, look_at_position)` shows local lights unlit.** With 216 SurfaceLights, the
  pillar room (about 180 studs from the parked Studio camera) came out dark brown in every camera-argument
  capture, even twice in a row and with `Camera.Focus` moved. Setting `workspace.CurrentCamera.CFrame` with
  `execute_luau` and then calling `screen_capture` with no arguments showed it fully lit, with no extra wait
  (the round trip is enough; `K.shot` waits 1 s anyway).
- **A MaterialVariant's ColorMap is multiplied by `Part.Color`.** Parts left at the default grey (163,162,165)
  rendered their textures about 36% darker; white shows the texture as made.
- Budget, 873 parts and 216 SurfaceLights (no shadows), indoor: 92k-182k triangles and 126-238 draw calls per
  view (Play, Client, shadows excluded).
- The flicker script (a server Script made by the build) runs in Play: 12 material flips in 10 s on 6 panels.
- A generated 8 s hum loops in Play (IsLoaded, IsPlaying, Looped, TimeLength 8.00).

## Mesh pipeline spike (Plan 3, 2026-10-24)
- Poly Haven model `Rockingchair_01` (glTF 1k, 11,866 tris) → Blender 5.1 import → scale 1/0.28 (1 BU = 1 stud) →
  origin bottom-centre → GLB export (`use_selection=True, use_active_scene=True`; without `use_active_scene` the
  exporter also pulled the Cube from another scene) → Open Cloud `Model` upload as the user (`model/gltf-binary`)
  → done within seconds.
- Inserted (MCP `insert_asset`, and also `InsertService:LoadAsset(id)` / `game:GetObjects` from `execute_luau`):
  a package Model → one sub-Model per Blender object → a MeshPart with a **SurfaceAppearance holding all four PBR
  maps** (Roblox split glTF metallicRoughness into RoughnessMap + MetalnessMap itself).
- The MeshPart arrives **unanchored**, CollisionFidelity Default, DoubleSided false, Color default grey.
  `Part.Color` has no effect under the SurfaceAppearance (Overlay mode). `Clone()` keeps the MeshId, so a cached
  template can be copied freely.
- Axes (asymmetric probe): Blender (x, y, z) → MeshPart local (−x, z, y). That is a 180° turn, **not a mirror**:
  Blender's front (−Y) is the part's LookVector (−Z), so text/clock faces read the same way round.
- `insert_asset` turns the model to face the camera; always place with `PivotTo`.
- **Captures time out while the display sleeps** (Studio stops drawing): 20 min without input → every
  screen_capture timed out with Studio in front; one mouse nudge fixed it. A background
  SetThreadExecutionState(ES_DISPLAY_REQUIRED) loop did NOT keep the display on (captures timed out again); a
  one-pixel SendInput nudge before each capture batch did.
- Headless Blender works: `blender.exe -b --factory-startup --python-expr ...` (5.1.2).
- **`MeshPart.CollisionFidelity` can't be set from `execute_luau`** (the write is silently ignored, stays
  Default). `part:ApplyMesh(AssetService:CreateMeshPartAsync(Content.fromUri(part.MeshId), {CollisionFidelity =
  X}))` sets it and keeps the SurfaceAppearance and size (`K.Models` does this per template).
- `InsertService:LoadAsset(id)` returns the prepped model unrotated with its bottom-centre at the origin.

## Alpha leaf cards (Plan 4 spike, 2026-10-24)
- A GLB material with only a colour texture imports as `MeshPart.TextureID` (no SurfaceAppearance). Its alpha
  renders **black** at Transparency 0. Two ways that cut it out properly (both measured, both cast shaped shadows):
  `MeshPart.Transparency = 0.02` with the TextureID, or a SurfaceAppearance made by script with `ColorMap` = the
  image and `AlphaMode = Transparency` (writable from `execute_luau`; keeps normal maps).
- Blender 5.1 exports a material with Alpha wired into the BSDF as glTF `alphaMode: BLEND`.

## Skybox face orientation (Plan 4 spike, 2026-10-24)
Six labelled faces (arrow at the image top, text left-to-right) viewed from the camera in Studio:
- `SkyboxFt` faces -Z, `SkyboxRt` -X, `SkyboxBk` +Z, `SkyboxLf` +X: all upright, none mirrored (image right is
  the camera's right when looking that way: Ft → +X, Rt → -Z, Bk → -X, Lf → +Z).
- `SkyboxUp`: looking up with screen-up = +Z, the image top points +X and the image right points -Z (a turn, not
  a mirror). `SkyboxDn`: looking down with screen-up = -Z, the image top points -X and the image right points -Z.
- So a face pixel (u right, v down, 0..1) looks along: Ft (2u-1, 1-2v, -1); Rt (-1, 1-2v, 1-2u);
  Bk (1-2u, 1-2v, 1); Lf (1, 1-2v, 2u-1); Up (1-2v, 1, 1-2u); Dn (2v-1, -1, 1-2u).

## Forest lake build (Plan 4, 2026-10-25)
- **Sky face size**: six 1024² PNG faces (~0.9 MB each, Open Cloud `Image`, approved) loaded as Decals and fetched
  "Success", but the Sky never drew them: in Edit Studio kept drawing the previous skybox (the lettered spike
  faces) even after the Sky was re-created; in Play it fell back. The same panorama as 512² faces rendered at once,
  with and without an Atmosphere (Density 0.3, Haze 1.5).
- **Stale terrain water in Edit**: after ~8 rewrites of the same terrain box (FillBlock Air + WriteVoxelChannels),
  Edit drew flat, untextured gold sheets with straight edges over land. `ReadVoxelChannels` showed no liquid
  there, a test Part with the same MaterialVariant rendered textured beside it, and a Play client showed the
  terrain correctly. Raycasts (which can't see fresh water anyway) hit the land below.
- **Untextured scans**: `boulder_01` (several uploads) and `tree_stump_02` (four uploads, two with a different
  triangle count, so a different mesh id, and one with every texture re-encoded) rendered as smooth white blobs
  (black in shade) in Edit and Play. All four SurfaceAppearance maps were Approved/Active and drew correctly in
  ImageLabels. Identical bytes re-upload to the same image/mesh asset ids (Roblox deduplicates), so a failed one
  stays failed. A `boulder_01` upload with its JPEGs re-encoded at quality 90 (new image ids) rendered;
  `tree_stump_02` never did; `tree_stump_01` did. Working models carry JPEGs up to 1.06 MB, so size alone does
  not explain it.
- **Client fetch status**: in a Play client `GetAssetFetchStatus` reports `None` for SurfaceAppearance maps that are
  drawing fine; only `Failure` means something.
- **Scan topology**: Poly Haven's `boulder_01` glTF imports with nearly every vertex doubled along UV seams (67,042
  vertices for 66,122 faces, 114,778 open edges); Blender's collapse decimate stalled at 26.6k triangles for a 9k
  target. Welding (remove_doubles 1e-4) first reached the target; UVs survive (Blender keeps them per corner).
- **Terrain water depth**: a stream 1.4 studs deep (LiquidOccupancy ~0.35 in 4-stud voxels) did not render as
  water; 2.8 deep and 10 wide did.
- **Low sun in a valley**: sun 14° up (matched to the HDRI) behind a 36-56-stud hill rim 150-250 studs away put the
  whole valley floor in shadow; OutdoorAmbient 170,162,156 + exposure 0.35 kept it readable.
- `MaterialService:GetBaseMaterialOverride(m)` returned the material's own name (`"Plastic"`) for unset overrides in
  this place, and `""` after `SetBaseMaterialOverride(m, "")`.
- Budget (forest-lake, Play, shadows excluded): 330-690k triangles at eye level, 779k top-down, 176-257 draw calls;
  90 MeshPart trees (3.5-4.1k triangles each) and 139 scattered scans.
