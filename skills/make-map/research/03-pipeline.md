# 03 — Blender → Roblox pipeline for environments, terrain, CC0 fetching

Researched 2026-10-24 for "Roblox Maps by fwjelaa" (`/make-map`). Research only: nothing was run in Studio or Blender.
Tags: **[DOC]** official Roblox/Blender doc (fetched 2026-10-24; most Roblox pages `last_updated 2026-10-23`), **[API]** Roblox API dump (client 0.744.0) or OpenAPI spec, **[FORUM]** DevForum, **[3P]** third party, **[MEAS]** measured (by us or noted by whom), **[OLD]** older than 2025, re-check before relying on it.

---

## 0. TL;DR: the route to use

| Content | Route | Why |
|---|---|---|
| Tileable PBR textures (walls, floors, terrain looks) | Download CC0 maps (Poly Haven `nor_gl`, ambientCG `NormalGL`) → upload as **Image** → `MaterialVariant` (+ `MaterialService:SetBaseMaterialOverride` for terrain) | No mesh needed; `StudsPerTile` gives correct texel density on Parts and terrain |
| Images in a **user-owned** place | **Studio MCP `upload_image`** (uploads as the Studio user, loads at once [MEAS by coordinator]) **or** Open Cloud with `"assetPrivacy":"openUse"` **or** Open Cloud plus a Universe grant (section 1) | A group-owned image is Restricted by default for groups created after 2026-05-05 |
| Meshes (props, rocks, building pieces) | **Blender → mesh data → Luau `EditableMesh` → `AssetService:CreateAssetAsync(em, Enum.AssetType.Mesh, {CreatorType=User})` → `AssetService:CreateMeshPartAsync(Content.fromAssetId(id))`** | User-owned mesh asset, so no permission problems, and a real asset id survives Play and save. Needs to be measured (section 3.4) |
| Fallback for meshes | Open Cloud **Model** upload of **.glb** (not FBX) → grant `Use` to the universe → insert | Models and packages are **always Restricted** [FORUM 2026-05]. FBX arrived 100× too big in one third-party test [3P 2026-10] |
| Ground of realistic maps | Heightfield in Python/Blender → numbers embedded in Luau → `Terrain:WriteVoxels` (one call is enough for 300×300 studs) | The heightmap importer (`HeightmapImporterService`) is RobloxScriptSecurity, so scripts cannot call it [API] |
| Stylized blocky maps | Plain Parts + MaterialVariants. No upload at all | Fastest, and works on phones |

---

## 1. Coordinator finding: group-owned Open Cloud image does not load in a USER-owned place

**Measured by coordinator (2026-10-24):** Image uploaded through Open Cloud (`assetType:"Image"`, `creator.groupId <group id>`) is moderation-approved, but in a user-owned place `ContentProvider:PreloadAsync` returns Failure and the decal stays blank. Studio MCP `upload_image` (uploads as the Studio user) loads at once.

### 1.1 Probable cause: Asset Privacy is now on by default for new groups
- "[Full Release] Privacy for Newly-Created Image, Mesh, and Decal Assets", 2026-05-05: *"All newly-created accounts and Groups will now have Asset Privacy enabled by default."* With privacy ON, new **Image, Mesh, Decal** = "Restricted" by default (can be set to Open Use). **Audio, Video, Package, Model, MeshPart = always Restricted, can NEVER be set to Open Use**, whatever the privacy setting. [FORUM] https://devforum.roblox.com/t/full-release-privacy-for-newly-created-image-mesh-and-decal-assets/4620416
- A Restricted asset loads only in experiences that were granted permission. *"Your assets are always accessible to you in your own games regardless of their privacy setting."* A user-owned place is not the group's game, so a group asset needs a grant there. [DOC] https://create.roblox.com/docs/projects/assets/privacy
- Grants to a game are **permanent**: "Once a game has permission to use a restricted asset, you cannot revoke access." Setting an asset to **Open Use is irreversible**. [DOC] same page
- Inserting a restricted asset in Studio automatically grants the experience: *"You automatically grant the experience permission to use an asset when you successfully insert the asset into one of the places in the experience in Studio."* [FORUM 4620416]. Setting a `ColorMapContent` id from a script probably does **not** count as an insert (to be measured).

### 1.2 Fix A (images, decals, meshes): create them as Open Use
`creationContext.assetPrivacy` accepts `"default" | "restricted" | "openUse"`. Its description: "Desired privacy setting for the asset on creation. Only applies to asset types that support privacy override" (Image, Decal, Mesh). [API openapi.json `AssetPrivacy`, `CreationContext`] https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/cloud/openapi.json
```bash
curl -X POST https://apis.roblox.com/assets/v1/assets \
  -H "x-api-key: $ROBLOX_API_KEY" \
  -F 'request={"assetType":"Image","displayName":"brick_wall_01_diff","description":"CC0 Poly Haven",
     "creationContext":{"creator":{"groupId":<group id>},"assetPrivacy":"openUse"}};type=application/json' \
  -F 'fileContent=@brick_wall_01_diff_1k.png;type=image/png'
```
This is fine for CC0 textures, because anyone may use them anyway. **It cannot help Models or MeshParts.**

### 1.3 Fix B (any type, including Model packages): Asset Permissions API grant to the universe
- Endpoint: `PATCH https://apis.roblox.com/asset-permissions-api/v1/assets/permissions`. BETA. Auth `x-api-key`. Scope `asset-permissions:write`. Body `application/json-patch+json` (or `application/json`, as in the doc's curl example). Rate limit 100/min per key owner. [DOC] https://create.roblox.com/docs/cloud/reference/features/assets#patch_asset_permissions_api_v1_assets_permissions
- Enums [API openapi.json]: `SubjectType` = `Invalid | User | Group | GroupRoleset | All | Universe`; `AssetAction` = `Invalid | Edit | Use | Download | CopyFromRcc | UpdateFromRcc`.
- Valid combinations (verbatim from the spec): Image/Decal/Mesh: `All|Group|User|Universe` + `Use`. MeshPart: `Group|User|Universe` + `Use`. Model: `User` + `Edit`, or `Group|User|Universe` + `Use`. Animation, Audio, Video: `Group|User|Universe` + `Use`.
- `requests[]` replaces the deprecated `assetIds[]`. `grantToDependencies:true` also grants the meshes and images inside a Model, "asynchronously after the main grant". `subjectId` must be empty for `All`.
```bash
curl -X PATCH https://apis.roblox.com/asset-permissions-api/v1/assets/permissions \
  -H "x-api-key: $ROBLOX_API_KEY" -H "Content-Type: application/json-patch+json" \
  -d '{"subjectType":"Universe","subjectId":"<game.GameId of the user place>","action":"Use",
       "requests":[{"assetId":123456789,"grantToDependencies":true}]}'
# 200 → {"successAssetIds":[...],"errors":[{"assetId":..,"code":"CannotManageSubject"}]}
```
- Error codes to expect: `CannotManageAsset`, `CannotManageSubject`, `SubjectNotFound`, `AssetTypeNotEnabled`, `PublicAssetCannotBeGrantedTo` (the asset is already Open Use), `AlreadyHasAccess`, `PermissionLimitReached`, `DependenciesLimitReached`, `BatchSizeLimitExceeded`, `RateLimited`, `CallerNotOwner`. [API]
- Authorization: "Authorization is required to grant permissions to the subject and asset IDs in the request." [DOC] API keys are now **user-owned**: "An API key's access is determined by the permissions of the user who owns it ... their individual games and any group-owned games where they have the appropriate role." [DOC 2026-10-23] https://create.roblox.com/docs/cloud/auth/api-keys. So the grant should work if the key's user owns the target universe and has asset-manage rights in group <group id>. **Not measured.** The universe id is `game.GameId` in Studio.
- Whether the grant **fixes loading** has not been measured. That is the first item in section 8.

### 1.4 Fix C: make the assets user-owned (no grants ever needed)
1. Edit the API key in Creator Dashboard so the `asset` scope also lists the user (`userIds`), then upload with `"creator":{"userId":...}`. Check the key with `POST https://apis.roblox.com/api-keys/v1/introspect {"apiKey":"..."}`. It returns `authorizedUserId` and per-scope `groupIds`/`userIds` [DOC api-keys]. This is a key settings change, so the user has to do it.
2. Images: Studio MCP `upload_image(imagePaths=[http(s) URLs])` returns `{url: "rbxassetid://..."}` [tool schema 2026-10-24]. Because it takes URLs, serve local files from a localhost HTTP server. This route loads at once [MEAS coordinator].
3. Meshes: `AssetService:CreateAssetAsync` (section 3.4). By default it uploads as the logged-in Studio user.

### 1.5 Fix D (user settings, the user decides)
- Group owner turns Asset Privacy OFF: Creator Hub → group → Settings → Group Profile → Asset Privacy. Then future Images, Meshes and Decals become Open Use. Models stay Restricted. [DOC privacy]
- Or move the experience into the group, so group assets are the group's own.

---

## 2. Open Cloud Assets API (apis.roblox.com/assets/v1)

All endpoints are marked **BETA**. [DOC] https://create.roblox.com/docs/cloud/reference/features/assets · guide https://create.roblox.com/docs/cloud/guides/usage-assets

| Endpoint | Scope | Rate limit (per key owner) |
|---|---|---|
| `POST /assets/v1/assets` (create, multipart) | asset:read+write | **120/min** |
| `GET /assets/v1/assets/{id}?readMask=description%2CdisplayName` | asset:read | 120/min |
| `PATCH /assets/v1/assets/{id}?updateMask=…` (content update: **Model/FBX only**, makes a new version) | asset:read+write | 120/min |
| `GET /assets/v1/operations/{operationId}` | asset:read | **300/min** |
| `GET /assets/v1/assets/{id}/versions[?maxPageSize=1..50]`, `…/versions/{n}`, `POST …/versions:rollback`, `POST …/{id}:archive`, `…:restore` | | 100/min |
| `GET /asset-delivery-api/v1/assetId/{id}` → `{location: temp CDN URL}` (use gzip) | legacy-asset:manage | 1000/min |
| `GET /cloud/v2/users/{user_id}/asset-quotas?filter=quotaType == RateLimitUpload && assetType == Image` | asset:read | 60/min |
| `PATCH /asset-permissions-api/v1/assets/permissions` | asset-permissions:write | 100/min |
| `POST /api-keys/v1/introspect` | none | n/a |

**Request format** (multipart/form-data): part `request` = JSON `{assetType, displayName, description (≤1000 chars), creationContext:{creator:{userId|groupId}, assetPrivacy?, expectedPrice?}}`, and part `fileContent` = the file with its content type. `expectedPrice`: if the upload fee is higher, the call fails with 400.

**Types and limits** [DOC usage-assets]: one asset per call, **≤ 20 MB**.

| assetType | Files (content type) | Notes |
|---|---|---|
| `Decal`, `Image` | png, jpeg, bmp, tga (`image/png` …) | < 8000×8000 px. Not updatable. Use **`Image`**: the response id is already the image id (`rbxassetid://<assetId>`), no Decal→Image conversion needed. |
| `Model` | `.fbx` (`model/fbx`), `.gltf` (`model/gltf+json`), `.glb` (`model/gltf-binary`), `.rbxm` (`model/x-rbxm`) | Becomes a `Model` holding ≥1 `MeshPart`. **Uploaded as a package**. `.rbxmx` was rejected ("not supported yet") in 2025-10 [FORUM 4022082]. |
| `Mesh` | Roblox mesh only (`model/x-file-mesh-data`) | "Only content downloaded from Asset delivery API is accepted". OBJ is not accepted. |
| Audio / Video / Animation | | not needed here |

**FBX/GLB → Model mapping** [FORUM, staff, 2023-05, OLD]: "FBX scene is imported as a single model/package asset; hierarchy mirrors the scene; each mesh in the FBX will be a unique MeshPart; returned asset ID is the package; the MeshPart will not be uploaded to your inventory." https://devforum.roblox.com/t/introducing-open-cloud-assets-api/2245171. The Studio Importer docs say glTF gives an extra `Model` per glTF mesh, with **one MeshPart per primitive (per material)** [DOC] https://create.roblox.com/docs/studio/importer. How embedded textures turn into `SurfaceAppearance` on the Open Cloud path is **not documented** (measure it).

**Polling:** create returns `{"path":"operations/{id}","done":false}`. Poll `GET /assets/v1/operations/{id}` until `done:true`, then read `response.assetId` and `response.moderationResult.moderationState` (`Reviewing|Rejected|Approved`) or `error {code,message}`. One report had a ~20 MB FBX still not done after hours (2024, OLD) https://devforum.roblox.com/t/opencloud-assets-api-post-on-assets-operation-is-not-done-after-hours/2898058. Use backoff starting at 1 s, retry 429 with exponential backoff [DOC cloud llms.txt].

**Using the id:** `rbxassetid://<assetId>` in properties, or `Content.fromAssetId(id)` for `Content` properties such as `Decal.ColorMapContent` [DOC usage-assets]. Old Decal ids → image id: `game:GetObjects("rbxassetid://<decalId>")[1].ColorMapContent` (command bar) [DOC DataModel:GetObjects].

**Upload quotas:** No count is published for images. Use the asset-quotas endpoint (per **user** only) [DOC]. Keys auto-expire after 60 days of no use [DOC api-keys].

**Texture size reality (2026):** 4K rendering through texture streaming has been live since 2026-01-30. Images can be imported up to 8K, are stored at original quality and are transcoded to ≤4096. Covers MeshPart, SurfaceAppearance, Texture, Decal, MaterialVariant [FORUM] https://devforum.roblox.com/t/4k-texture-rendering/4316229. A 2026-06 report says the **Decal upload page still downsizes to 1024** (https://devforum.roblox.com/t/decal-upload-page-still-mentions-1024x1024-limit-instead-of-4096x4096/4526770). That is one more reason to use `Image`.

---

## 3. Getting assets into the open Studio place from Luau

| API | Security / context | Ownership rule |
|---|---|---|
| `InsertService:LoadAsset(id)` → Model | None, capability LoadOwnedAsset | Asset must be **created/owned by the game creator**, **shared by the owner**, or owned by Roblox [DOC] https://create.roblox.com/docs/reference/engine/classes/InsertService |
| `AssetService:LoadAssetAsync(id)` → Model (Sandboxed=true, no script capabilities) | None, LoadUnownedAsset | Same rule. Third-party public Store assets load only if "Allow Loading Third Party Assets" is on [DOC] https://create.roblox.com/docs/reference/engine/classes/AssetService |
| `game:GetObjects("rbxassetid://id")` → {Instance} | **PluginSecurity** (command bar/plugin) | "If the asset is not owned by the logged in user it must be freely available" [DOC DataModel]. Reports of 403 for non-owned assets since 2025-04 [FORUM 3226166] |
| Studio MCP `insert_asset(assetId, assetType∈Model/Package/Mesh/MeshPart/Image/Decal/…)` | MCP tool | Probably the Toolbox insert path, which **auto-grants** the experience. Not documented. Measure it |
| `AssetService:CreateMeshPartAsync(meshContent: Content, options?)` → MeshPart | None | options `{CollisionFidelity, RenderFidelity, FluidFidelity}`. Works on `Content.fromAssetId(meshId)` or an EditableMesh. `MeshPart.MeshId` is `NotAccessibleSecurity` for writing, so this is the only way to make a MeshPart from an id [API][DOC MeshPart] |
| `InsertService:CreateMeshPartAsync(meshId, collisionFidelity, renderFidelity)` | None | Legacy form of the same |
| `MeshPart:ApplyMesh(src)` | None | Copies mesh, texture, collision and fidelity from another MeshPart |

### 3.1 Not scriptable (confirmed in API dump, client 0.744)
`AssetImportService:*` (StartSessionWithPath, UploadAssetFromPathAsync …) and all `HeightmapImporterService` members are **RobloxScriptSecurity** [API]. This matches our earlier measurement that Import 3D cannot be scripted.

### 3.2 Writable from plugin or command bar (PluginSecurity)
`SurfaceAppearance.ColorMapContent/NormalMapContent/RoughnessMapContent/MetalnessMapContent/EmissiveMaskContent` (write = PluginSecurity) and the same on `MaterialVariant` (read+write PluginSecurity). `AlphaMode`, `Color`, `StudsPerTile` are writable by any script [API]. `AssetService:CreateSurfaceAppearanceAsync({ColorMap=Content…})` accepts **only EditableImage** today, so it is runtime-only and not useful for saved maps [DOC].

### 3.3 Why the EditableMesh MeshParts we tried lost their geometry
An EditableMesh is a runtime object (`FixedSize` and the like have `can_load:false`). A MeshPart pointing at `Content.fromObject(editableMesh)` keeps no asset to serialize. The fix is to **publish the EditableMesh as a Mesh asset** (section 3.4) and build the MeshPart from that asset id.

### 3.4 Mesh route without Import 3D: `AssetService:CreateAssetAsync`
- Signature [DOC + FORUM]: `AssetService:CreateAssetAsync(object, assetType: Enum.AssetType, requestParameters?) -> (Enum.CreateAssetResult, number|string)` and `CreateAssetVersionAsync(object, assetType, targetAssetId, options)`. Version updates work **only for Model and Plugin**.
- Options: `Name`, `Description` (default "Created with AssetService:CreateAssetAsync"), `CreatorId` (default: the logged-in Studio user), `CreatorType` (`Enum.AssetCreatorType.User|Group`, default User), `IsPackage` (Model only, default true). CreatorId and CreatorType are required in Open Cloud Luau Execution.
- Supported pairs: `Model`/`Plugin` + any Instance root; **`Mesh` + EditableMesh**; **`Image` + EditableImage** (EditableImage max **1024×1024** [DOC EditableImage]); Animation since 2025-05. Results: `Success=1, PermissionDenied=2, UploadFailed=3, Unknown=4` [DOC enum CreateAssetResult].
- Context: *"Currently, this method can only be used in locally loaded plugins and uploads assets **without prompting** first."* [DOC]. The 2024 beta post said "make a local plugin, **or call it from the command bar**" and needed the Studio beta "CreateAssetAsync Luau API" [FORUM 2024-12, OLD] https://devforum.roblox.com/t/beta-lua-asset-creation-for-creator-tooling-with-createassetasync/3294134. Still **blocked for Creator Store plugins** as of 2026-02 and 2026-05 ("CreateAssetAsync and CreateAssetVersionAsync can not be used from store plugins yet") [FORUM same thread #85, #89]. The API dump shows Security None plus capability `AssetCreateUpdate` [API]. **Unknown:** whether Studio MCP `execute_luau` counts as a local plugin or command bar, and whether the beta toggle is still needed.
- Limits: 60 calls/min (raised from 30 on 2025-05-15, staff) [FORUM #74]. EditableMesh ≤ **60,000 vertices / 20,000 triangles** (a quad counts as 2) [DOC EditableMesh]. Models containing CSG unions fail ("unpublished content") [FORUM #65–66].
- Moderated like any other upload [FORUM OP].
- EditableMesh methods [API]: `AssetService:CreateEditableMesh(opts?)`, `AddVertex(Vector3)`, `AddTriangle(v0,v1,v2)`, `AddFace({ids})`, `AddUV(Vector2)`, `AddNormal(Vector3?)`, `AddColor(Color3, alpha)`, `SetFaceUVs/SetFaceNormals/SetFaceColors(faceId,{ids})`, `BatchAdd(Enum.MeshAttribute.Vertex|Normal|Color|UV|Face, data)`, `BatchSetFaceAttributes`.

Sketch (untested):
```lua
-- runs via execute_luau (Edit DataModel). V/T/UV come from Blender (see 4.4), sent in chunks
local AssetService = game:GetService("AssetService")
local em = AssetService:CreateEditableMesh()
local vid, uid = {}, {}
for i = 1, #V, 3 do vid[#vid+1] = em:AddVertex(Vector3.new(V[i], V[i+1], V[i+2])) end
for i = 1, #UV, 2 do uid[#uid+1] = em:AddUV(Vector2.new(UV[i], 1 - UV[i+1])) end -- check the V flip
for i = 1, #T, 3 do
  local f = em:AddTriangle(vid[T[i]], vid[T[i+1]], vid[T[i+2]])
  em:SetFaceUVs(f, {uid[T[i]], uid[T[i+1]], uid[T[i+2]]})
end
local res, idOrErr = AssetService:CreateAssetAsync(em, Enum.AssetType.Mesh,
  {Name = "rock_01", CreatorId = game:GetService("StudioService"):GetUserId(),
   CreatorType = Enum.AssetCreatorType.User})
assert(res == Enum.CreateAssetResult.Success, tostring(idOrErr))
local mp = AssetService:CreateMeshPartAsync(Content.fromAssetId(idOrErr),
  {CollisionFidelity = Enum.CollisionFidelity.Hull, RenderFidelity = Enum.RenderFidelity.Automatic})
mp.Anchored = true; mp.Parent = workspace.Map.Props
local sa = Instance.new("SurfaceAppearance") -- ColorMapContent write = PluginSecurity
sa.ColorMapContent = Content.fromAssetId(colorImageId); sa.Parent = mp
```
(`StudioService:GetUserId()` was used by Roblox staff from the command bar [FORUM #77].) Keep execute_luau calls small and yield between chunks [Studio MCP tool description].

### 3.5 Experimental: write Roblox `.mesh` files and upload as Mesh
Open Cloud accepts `Mesh` only as Roblox mesh format. A community spec exists for versions 1.00–7.00 (rev. 2025-03-30) https://devforum.roblox.com/t/roblox-filemesh-format-specification/326114. A v2.00 file written in Python *might* be accepted (Roblox: "files edited externally might not upload successfully" [FORUM 4022082]). If it works, it is a fully headless mesh path: Python → .mesh → `assetType:"Mesh"` + `assetPrivacy:"openUse"` → `CreateMeshPartAsync`. Measure before relying on it.

---

## 4. Mesh rules

- **Triangle budget:** "Individual meshes can not exceed 20,000 triangles". Watertight, no zero-thickness faces, quads where possible [DOC] https://create.roblox.com/docs/art/modeling/specifications. EditableMesh has the same 20k triangle cap plus 60k vertices.
- **Size:** BasePart dimensions 0.001–**2048** studs per axis [DOC BasePart]. Map 300×300 is well inside.
- **One material per MeshPart:** "Mesh objects can only have one material assigned" [DOC texture-specifications]. glTF: one MeshPart per primitive (= per material) [DOC importer]. So in Blender, either split by material or atlas or trim-sheet into one material per object. Studio can apply 1 `TextureID`, or 4–5 PBR maps through `SurfaceAppearance`, or a `MaterialVariant` [DOC meshes].
- **Pivot and origin:** The Importer defaults are "Set Pivot to Scene Origin" ON and per-object "Use Imported Pivot" ON [DOC importer]. Open Cloud has no settings. One third-party GLB test found results "off by its import location" until it centred and grounded objects before export [3P] https://github.com/orangutanger1/blox/pull/67. **Rule:** in Blender, apply transforms, put the origin at bottom-centre, place the object at the world origin, and position it in Luau with `PivotTo`.
- **Scale:** Roblox: set Blender **Scene → Units → Unit System = None** so 1 BU = 1 stud [DOC] https://create.roblox.com/docs/art/blender. Physics: 1 stud = 28 cm [DOC] https://create.roblox.com/docs/physics/units.
  - FBX: Blender's defaults "often import at an unexpectedly large scale". Recommended: **Apply Scalings = FBX Unit Scale** (`apply_scale_options='FBX_SCALE_UNITS'`), or Scale 0.01, or Scene Unit Scale 0.01. "glTF ... do not require these additional scaling configurations" [DOC art/blender].
  - **[3P, 2026-10-02, live Open Cloud test]:** FBX with `apply_unit_scale` came in "400×400×400 studs (100×, cm units), colour lost". GLB came in "4×2.5×2 studs (1 Blender unit = 1 stud)" with colours kept. → **Upload GLB.** https://github.com/orangutanger1/blox/blob/main/docs/superpowers/specs/2026-10-02-opencloud-upload-path-design.md
- **Axes:** glTF exporter `export_yup=True` (default). [3P]: "Roblox turns glTF +Z (Blender −Y, our front) into its look direction −Z". So **model the front facing Blender −Y** and it faces the Roblox front (−Z), no pre-rotation. The Roblox docs' FBX settings are Forward = Z, Up = Y [DOC art/blender].
- **Vertex colours:** FBX and glTF import support them ("Ignore Vertex Colors" option) [DOC importer]. Staff: a .glb with vertex colours uploads fine through Open Cloud (2025-10) [FORUM 4022082 #19]. [3P]: vertex colours are **multiplied by `MeshPart.Color`** (default grey 163 → 0.64×), so set `Color = 255,255,255`. sRGB values in `COLOR_0` render as intended. Blender exporter: `export_vertex_color='MATERIAL'|'ACTIVE'|'NAME'|'NONE'` [DOC bpy.ops.export_scene]. Vertex colour plus base materials is the cheapest stylized look.
- **Collision:** `CollisionFidelity` = `Default` (voxel convex decomposition, weak in holes and doorways) | `Hull` | `Box` | `PreciseConvexDecomposition` (most precise, most expensive) | `Tunable` (with a `CollisionPrecision` slider) [DOC enum/meshes]. Settable in Edit (write security None [API]). Set it at creation through `CreateMeshPartAsync` options. Environment rule: decorative → `CanCollide=false`, `CanQuery/CanTouch=false`. Rocks and props → Hull/Box. Walkable ground → terrain or invisible block Parts. The Roblox curriculum uses Hull for wall trims, not Box [DOC assemble-an-asset-library].
- **LOD:** No custom LOD import. `RenderFidelity.Automatic` = highest detail <250 studs, medium 250–500, lowest ≥500. `Precise` = always full detail. `Performance` = may discard appearance [DOC MeshPart, enum]. `MeshPartDetailLevel` lists LOD indices 00–09, so the engine generates up to 10 levels [API enum]. Ship ONE ≤20k-tri mesh. On a 300-stud map almost everything sits within 250–500 studs.
- **Double-sided:** `MeshPart.DoubleSided` costs more. Use it for leaf and grass cards [DOC].

### 4.4 Blender export calls (bpy, Blender 5.2 API)
- `bpy.ops.export_scene.gltf(filepath=..., export_format='GLB', use_selection=True, export_apply=True, export_yup=True, export_texcoords=True, export_normals=True, export_vertex_color='ACTIVE', export_materials='EXPORT', export_image_format='AUTO')` [DOC] https://docs.blender.org/api/current/bpy.ops.export_scene.html
- `bpy.ops.export_scene.fbx(filepath=..., use_selection=True, apply_scale_options='FBX_SCALE_UNITS', axis_forward='-Z', axis_up='Y', path_mode='COPY', embed_textures=True, add_leaf_bones=False, bake_anim=False, use_mesh_modifiers=True)`. Defaults to watch: `path_mode='AUTO'`, `embed_textures=False`, `add_leaf_bones=True`, `bake_anim=True` [DOC same page].
- Blender 5.0 (2025-11-18): the C++ FBX **importer** is now the default (the Python importer is legacy). The exporter is unchanged. 5.1: FBX exports shape-key normals. 5.2 LTS (2026-07-14, supported to 2028-07): glTF vertex-colour export fix [DOC] https://projects.blender.org/blender/blender-developer-docs/raw/branch/main/docs/release_notes/5.0/pipeline_io.md
- For the EditableMesh route: dump `positions`, `uv`, `triangles` (loop triangles) from `obj.data` after `bpy.ops.object.transform_apply` as JSON. Convert Blender (X, Y, Z-up) to Roblox (X, Y-up, Z) yourself, e.g. (x, z, −y) with front = −Y. Measure the handedness.

---

## 5. Texture rules

- **Formats:** png, jpg, tga, bmp (Studio also gif) [DOC texture-specifications, importer].
- **Resolution:** docs say "up to 4096×4096 (4K)", and an older line on the same page still says "Maximum Texture Resolution 1024×1024". The 2026-01 4K streaming post settles it: 4K is rendered when the device can, otherwise mips are streamed lower [FORUM 4316229]. Open Cloud accepts up to <8000 px.
- **Phone-first budgets:** doc guidance 256 px for a 5×5-stud object, 512 for 10×10, 1024 for 20×20 (≈51 px/stud). Built-ins: Parts show 1024 px per 8 studs (128 px/stud), terrain 512 per 8 studs (**64 px/stud**) [DOC]. PBR budget: 256² per 2×2×2-stud volume, "1024×1024 (maximum)" for 8×8×8 [DOC]. **Target 64 px/stud for walls and floors through `StudsPerTile`.** A 1K tile covering 16 studs equals 64 px/stud. Use 2K only for hero props.
- **PBR channels (SurfaceAppearance/MaterialVariant):** ColorMap RGB (+alpha for AlphaMode Overlay (default)/Transparency/TintMask/Opaque-beta); Normal RGB, **OpenGL tangent space only**; Roughness, Metalness, EmissiveMask single-channel 8-bit (only R is read) [DOC surface-appearance, AssetService]. Poly Haven `arm` = AO/Rough/Metal packed: **split G→roughness and B→metalness** into separate grayscale PNGs. Drop AO, which Roblox has no slot for (or multiply it into albedo lightly).
- **Normal map convention:** Roblox = **OpenGL (+Y green up)**. Poly Haven → `nor_gl`. ambientCG → `*_NormalGL.jpg`. Blender bakes OpenGL by default (`normal_g='POS_Y'`). DirectX maps need the green channel inverted [DOC surface-appearance].
- **Tileables and trim sheets:** `MaterialVariant` (in `MaterialService`) = 4 tileable maps + `StudsPerTile` + `MaterialPattern` (Regular/Organic to break up repetition) + `BaseMaterial` physics. Assign with `part.Material=Base; part.MaterialVariant="Name"`. Trim sheets go in **one `SurfaceAppearance`** reused by every modular mesh whose UVs map to the sheet. Roblox's own curriculum packages that SurfaceAppearance [DOC] https://create.roblox.com/docs/tutorials/curriculums/environmental-art/assemble-an-asset-library. Blender: UV with Follow Active Quads for trims [DOC art/blender].
- **Baking PBR in Blender 5.x (Cycles):** `scene.render.engine='CYCLES'`. The low-poly object needs a UV map and an **active Image Texture node** as the bake target. `bpy.ops.object.bake(type=..., pass_filter=..., use_selected_to_active=True, cage_extrusion=0.02, max_ray_distance=0.0, margin=16, margin_type='EXTEND'|'ADJACENT_FACES', normal_space='TANGENT', target='IMAGE_TEXTURES', use_clear=True)` [DOC] https://docs.blender.org/api/current/bpy.ops.object.html. Bake types: `COMBINED, AO, SHADOW, POSITION, NORMAL, UV, ROUGHNESS, EMIT, ENVIRONMENT, DIFFUSE, GLOSSY, TRANSMISSION` (**there is no METALLIC**) [DOC enum].
  - Albedo: `type='DIFFUSE', pass_filter={'COLOR'}`. Normal: `type='NORMAL'`. Roughness: `type='ROUGHNESS'`. **Metalness: temporarily wire the Metallic input into Emission Strength/Color and bake `EMIT`**, then restore (common workaround, not an official API).
  - Selected to Active: "rays are cast from the low-poly object inwards towards the high-poly"; tune Extrusion/Max Ray Distance or use a cage. Join high-poly parts to save memory [DOC] https://docs.blender.org/manual/en/latest/render/cycles/baking.html. Save with `img.filepath_raw=...; img.file_format='PNG'; img.save()`. Normal and data images must use `colorspace_settings.name='Non-Color'`.
  - Blender 5.0 Python change: `bpy.context.scene['cycles']` style dict access to add-on props is gone. Use `scene.cycles.samples` [DOC 5.0 python_api].

---

## 6. Terrain

### 6.1 Script APIs (Security None unless noted) [API, DOC] https://create.roblox.com/docs/reference/engine/classes/Terrain
- `Terrain:WriteVoxels(region: Region3, resolution: float, materials: {{{Enum.Material}}}, occupancy: {{{number}}})`: resolution **must be 4**; region **aligned to the 4-stud grid** (`Region3:ExpandToGrid(4)`); **≤ 4,194,304 voxels per call**.
- `Terrain:WriteVoxelChannels(region, 4, {SolidMaterial=…, SolidOccupancy=…, LiquidOccupancy=…})`: same limits. Water = `SolidMaterial Air` + `LiquidOccupancy x`.
- `ReadVoxels`, `ReadVoxelChannels`, `FillBlock(cframe, size, material)`, `FillWedge(cframe, size, material)`, `FillBall`, `FillCylinder`, `FillRegion(region, 4, material)`, `ReplaceMaterial(region, 4, src, dst)`, `SetMaterialColor(material, Color3)`, `Clear()`, `CopyRegion/PasteRegion`.
- Undocumented betas exist in the dump: `ReadVoxelsAsync_beta`, `WriteVoxelsAsync_beta`, `ModifyVoxelsAsync_beta`, `IterateVoxelsAsync_beta`, `ClearVoxelsAsync_beta` (None). `CreateVoxelBuffer_beta` and all `*Slot` methods (`FillBlockSlot`…, `SmoothRegion`) are **RobloxScriptSecurity**. Don't depend on them.
- **No scriptable heightmap import.** `HeightmapImporterService:ImportHeightmap(region: Region3, heightmapAssetId: ContentId, colormapAssetId: ContentId, defaultMaterial: Enum.Material)` [Yields] and `ImportHeightmapWithMaterialSlotsAsync(region, heightmapAssetId, colormapAssetId, defaultMaterialIndex: int)`, plus `IsValidHeightmap`, `IsValidColormap`, `GetHeightmapPreviewAsync`, `CancelImportHeightmap`, `SetImportHeightmapPaused` and events `ProgressUpdate(progressRatio, operation)`, `ColormapHasUnknownPixels`. All are **RobloxScriptSecurity**. The service is "Studio-only ... members require elevated security and are not callable from experience scripts" [API][DOC] https://create.roblox.com/docs/reference/engine/classes/HeightmapImporterService
- Manual importer facts (useful as a spec): 1 heightmap pixel = 4 studs, max 4096×4096 px, jpg or png. Height range = the selected region's Y size (black = −Y/2, white = +Y/2 around the centre). Colormap key, exact RGB with hard edges: Asphalt 737B6B, Basalt 1E1E25, Brick 8A563E, Cobblestone 847B5A, Concrete 7F663F, CrackedLava E89C4A, Glacier 65B0EA, Grass 6A7F3F, Ground 665C3B, Ice 81C2E0, LeafyGrass 73844A, Limestone CEAD94, Mud 3A2E24, Pavement 94948C, Rock 666C6F, Salt C6BDB5, Sand 8F7E5F, Sandstone 895A47, Slate 3F7F6B, Snow C3C7DA, WoodPlanks 8B6D4F, Water 0C545C, Air FFFFFF [DOC] https://create.roblox.com/docs/parts/terrain. Reuse this as the colour→material table in our own Luau writer.

### 6.2 Recipe: heightfield → smooth terrain (300×300 studs)
Size: 300/4 = 75 → 76×76 columns. Vertical span 0–128 studs = 32 voxels → 76×32×76 = **184,832 voxels (4.4% of the per-call cap). One `WriteVoxels` call.** Payload: 5,776 heights as text ≈ 30–40 KB, so embed the numbers directly in the execute_luau code. No image upload or EditableImage needed (EditableImage is capped at 1024² anyway).
```lua
-- H[x][z] = surface height in studs (from Blender/numpy), M[x][z] = Enum.Material; untested
local N, Y = 76, 32
local region = Region3.new(Vector3.new(-152, 0, -152), Vector3.new(152, Y*4, 152)):ExpandToGrid(4)
local mats, occ = table.create(N), table.create(N)
for x = 1, N do
  mats[x], occ[x] = table.create(Y), table.create(Y)
  for y = 1, Y do
    local m, o = table.create(N), table.create(N)
    local y0 = (y - 1) * 4
    for z = 1, N do
      local f = math.clamp((H[x][z] - y0) / 4, 0, 1)   -- partial fill = smooth surface
      o[z] = f; m[z] = (f > 0) and M[x][z] or Enum.Material.Air
    end
    mats[x][y], occ[x][y] = m, o
  end
end
workspace.Terrain:WriteVoxels(region, 4, mats, occ)
```
Material by rule (slope >35° → Rock, height < water level+2 → Sand, else Grass/LeafyGrass/Ground noise). Then water with `WriteVoxelChannels` (LiquidOccupancy) below sea level. Looks: `Terrain.Decoration=true` (animated grass, Grass only) and `GrassLength` 0.1–1 [DOC parts/terrain]. Custom look: `MaterialVariant` (BaseMaterial Grass) + `MaterialService:SetBaseMaterialOverride(Enum.Material.Grass, "MyGrass")` (Security None) + `TerrainDetail` top/side/bottom [DOC materials, MaterialService]. "Expanded Terrain" (up to 62 custom materials, place restart needed) exists, but painting its slots from scripts goes through RobloxScriptSecurity `*Slot` APIs → Studio UI only [DOC custom-terrain-materials][API].

### 6.3 Making the heightfield (Blender 5.x side)
- **A.N.T. Landscape** is now a community extension (v0.2.0, published 2024-05-14, "Blender 4.2 LTS and newer", "offered as it is, with limited support", bundled only up to 4.1) [DOC/OLD] https://extensions.blender.org/add-ons/antlandscape/. Installing it is an extension download, so ask the user. Not required.
- No built-in erosion node in the Blender 4.5–5.2 Geometry Nodes release notes (searched 2026-10-24: they cover bundles and closures) [DOC release notes]. **Recommended:** a numpy heightfield in Blender's bundled Python (fBm noise + a few hundred droplets of simple hydraulic erosion + terraces), run headless with `blender -b --factory-startup --python gen.py`. Write a JSON 76×76 for Luau and also a preview PNG.
- **CC0 alternative:** ambientCG `type=terrain` assets (Gaea-made, `technique=terrain-gaea`). Example `Terrain005` ships 2K/4K/8K **EXR heightmaps** + OBJ (the 1K OBJ is 118 MB) [MEAS API call 2026-10-24]. Load the EXR with `bpy.data.images.load`, sample 76×76, scale heights to studs.

### 6.4 Smooth terrain vs mesh terrain
- Smooth terrain: exact walkable collision, cheap authoring through the API, grass and water, built-in LOD, 64 px/stud textures, no upload or permissions. Minimum feature ≈ 4 studs, so no crisp cliffs. → **Default for nature maps and horror-house exteriors.** Backrooms are pure interiors and need no terrain.
- Mesh terrain: crisp shapes and baked texture. One MeshPart ≤20k tris → a 300² stud field at a 4-stud grid = 75² quads = 11,250 tris (fits); at 2-stud = 45,000 → 4 tiles. Collision on big concave meshes is approximate (`PreciseConvexDecomposition` expensive, `Default` bad on cavities [DOC]). → Use it for cliffs and rock faces as dressing (Hull or no collision) on top of smooth terrain. Stylized blocky maps: Parts.

---

## 7. CC0 sources with APIs

### 7.1 Poly Haven (https://api.polyhaven.com), measured 2026-10-24
- Licence: assets **CC0, no attribution ever**. **API ToS:** free for any use including commercial. Calls must send a **unique User-Agent or Referer** naming the app. If you use the live API *inside your software* to surface content, show a light credit ("Powered by Poly Haven" or naming Poly Haven) [DOC] https://github.com/Poly-Haven/Public-API/blob/master/ToS.md. → Set UA `roblox-maps-by-fwjelaa/1.0` and add a credit line in the skill's output and README.
- Endpoints: `GET /types` → `["hdris","textures","models"]`. `GET /categories/{type}`. `GET /assets?t=textures&c=brick` → {id: meta}. `GET /info/{id}`. `GET /files/{id}`. Docs: https://redocly.github.io/redoc/?url=https://api.polyhaven.com/api-docs/swagger.json
- Counts (2026-10-24): textures 869 (wall 244, floor 271, brick 108, plaster-concrete 136, rock 125, terrain 131, wood 138, roofing 23); models 521 (props 176, nature 110, furniture 85, plants 57, rocks 37, trees 20, buildings 13).
- `/files/{texture}` keys: `Diffuse, nor_gl, nor_dx, Rough, arm, AO, Displacement, rough_ao, blend, gltf, mtlx` → `{1k|2k|4k|8k}` → `{jpg|png|exr}` → `{url,size,md5}`. Example URL: `https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/blue_floor_tiles_01/blue_floor_tiles_01_nor_gl_1k.jpg`. Models add `fbx, gltf (with include map of textures + .bin), usd`.
- **Model polycounts are scan-grade:** boulder_01 123,976; coast_land_rocks_02 2,420,895; fir_tree_01 7,853,731 (`lods:true` on rocks). → In Blender: decimate or remesh to ≤20k tris (rocks 2–6k), then bake albedo, normal and roughness from the scan onto the low-poly (section 5).

### 7.2 ambientCG (https://ambientCG.com/api/v3/...)
- Licence: **CC0 1.0**. Credit appreciated, not required ("Created using <asset> from ambientCG.com, licensed under CC0 1.0") [DOC] https://docs.ambientcg.com/license/. Run by one person: "potentially not as reliable or stable as needed for an 'enterprise-level' application" → cache locally [DOC] https://docs.ambientcg.com/api/
- `GET /api/v3/assets?type=material&q=brick&sort=popular&limit=1..500&offset=&include=downloads,maps,dimensions,technique,title,tags`. `type ∈ material, hdri, substance, decal, atlas, 3d-model, plain-image, brush, terrain, hdri-element`. Also `/api/v3/categories`, `/collections`, `/rss`. An optional Patreon `Authorization: Bearer` header unlocks early access only [DOC] https://docs.ambientcg.com/api/v3/assets/
- Response: `{totalResults, nextPageHttp, assets:[{id, title, maps:["color","normal","roughness","ambient-occlusion","displacement"], dimensions:{width,height}(cm), downloads:[{attributes:"1K-JPG", extension:"zip", url:"https://ambientcg.com/get?file=Ground111_1K-JPG.zip", size}]}]}`. The get URL redirects to `acg-download.struffelproductions.com` [MEAS].
- Zip contents (read through an HTTP range request, no download) [MEAS 2026-10-24]: `_Color.jpg, _NormalGL.jpg, _NormalDX.jpg, _Roughness.jpg, _AmbientOcclusion.jpg, _Displacement.jpg` + `.blend/.mtlx/.usdc/.tres`. → Use **NormalGL**. Metal materials also ship `_Metalness`.
- 3D models are few (`type=3d-model` total 34). Terrains: Gaea EXR heightmaps (section 6.3).

### 7.3 Other CC0 (optional; the project rule says Poly Haven + ambientCG)
Kenney: "all game assets ... public domain licensed (CC0)", attribution not required [DOC] https://kenney.nl/support (stylized). 3dtextures.me: "All textures on this site are licensed as CC0" https://3dtextures.me/about/. ShareTextures says "CC0 Textures & Models" on its homepage https://www.sharetextures.com/. Quaternius and cgbookcase CC0 claims were **not confirmed** today. Poly Pizza and Sketchfab mix CC0 with CC-BY, so filter per asset. Blender MCP `search_assets/import_asset` (Poly Haven, Sketchfab, Poly Pizza) only allows Poly Haven under our rule.

---

## 8. Verify by measuring (in this order)

1. **Group image + Universe grant:** `PATCH /asset-permissions-api/v1/assets/permissions` `{subjectType:"Universe", subjectId:<game.GameId>, action:"Use", requests:[{assetId, grantToDependencies:true}]}` → read `successAssetIds/errors` (look for `CannotManageSubject`). Then repeat the coordinator's `PreloadAsync` test. Also check how long the grant takes to apply.
2. **`assetPrivacy:"openUse"` on create** with the group creator → is it accepted? Does the image load in the user place? (It is irreversible, so test on a throwaway image.)
3. **`POST /api-keys/v1/introspect`** on our key → `authorizedUserId`, and which `groupIds/userIds` the `asset` scope has. Could the user add their own userId?
4. **CreateAssetAsync from execute_luau:** `pcall(AssetService.CreateAssetAsync, AssetService, AssetService:CreateEditableMesh()-with-one-triangle, Enum.AssetType.Mesh, {Name="probe"})`. Record the result enum and error text (store-plugin block? beta disabled? PermissionDenied?), whether a dialog appears, and the asset owner.
5. **Persistence:** MeshPart from `CreateMeshPartAsync(Content.fromAssetId(newMeshId))`. Check geometry in Play (client and server), after File→Save and reopen, and after publish. Also check the moderation state and how long until it renders for a second account.
6. **SurfaceAppearance through execute_luau:** can it write `ColorMapContent`, `NormalMapContent` (PluginSecurity)? Do they persist?
7. **execute_luau size limit:** largest code string accepted (try 100 KB, 500 KB, 2 MB) → decides chunk size for mesh and heightfield data. Does `_G` or a ModuleScript persist between calls for staging chunks?
8. **Open Cloud GLB → Model:** scale (1 BU = 1 stud?), X handedness (an asymmetric probe with +X marker), front (−Y → −Z?), pivot and position, multi-material split, whether embedded textures become a SurfaceAppearance (which maps?), vertex colours × `MeshPart.Color`, default CollisionFidelity and Anchored.
9. **Same with FBX** using `apply_scale_options='FBX_SCALE_UNITS'` (the Roblox-documented fix) to confirm or refute the 100× result.
10. **Insert paths for a group-owned package into the user place:** Studio MCP `insert_asset` vs `game:GetObjects` vs `InsertService:LoadAsset`. Which succeed, and does `insert_asset` auto-grant the universe?
11. **Hand-written `.mesh` v2.00 upload** as `assetType:"Mesh"`: accepted or rejected?
12. **WriteVoxels 76×32×76:** wall time of building the tables plus the write in Edit (expect <1 s) and on a phone-class client (streaming); voxel alignment of a Region3 centred on 0.
13. **4K vs 1K texture** on a mid phone: memory and download (Developer Console → Memory → GraphicsTexture) for one 2K hero SurfaceAppearance vs 1K MaterialVariants.
14. **Blender headless bake** (`-b --factory-startup`) on this PC: Cycles CPU vs GPU time for a 1K albedo+normal+roughness bake of a decimated Poly Haven rock; the metal-via-EMIT trick.
15. **Asset-quotas endpoint** for the user (`quotaType == RateLimitUpload && assetType == Image`) → the real image upload cap before batch-uploading texture sets.

---

## 9. Sources
- Open Cloud Assets usage guide: https://create.roblox.com/docs/cloud/guides/usage-assets
- Assets feature reference (endpoints, rate limits): https://create.roblox.com/docs/cloud/reference/features/assets
- OpenAPI spec (enums AssetPrivacy, SubjectType, AssetAction): https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/cloud/openapi.json
- Asset Permissions API: https://create.roblox.com/docs/reference/cloud/asset-permissions-api/v1 (md: /docs/en-us/reference/cloud/asset-permissions-api/v1.md)
- Asset privacy: https://create.roblox.com/docs/projects/assets/privacy
- Full Release asset privacy (2026-05-05): https://devforum.roblox.com/t/full-release-privacy-for-newly-created-image-mesh-and-decal-assets/4620416
- API keys and introspect: https://create.roblox.com/docs/cloud/auth/api-keys
- Open Cloud more asset types (2025-10): https://devforum.roblox.com/t/open-cloud-upload-support-for-more-asset-types/4022082
- Open Cloud Assets API announcement (2023): https://devforum.roblox.com/t/introducing-open-cloud-assets-api/2245171
- Model upload → MeshId thread: https://devforum.roblox.com/t/how-to-get-meshid-from-model-upload-cloud-assets-api/3226166
- Permissions API help (2026-03): https://devforum.roblox.com/t/help-with-permissions-api/4529547
- CreateAssetAsync beta and updates (2024-12 → 2026-08): https://devforum.roblox.com/t/beta-lua-asset-creation-for-creator-tooling-with-createassetasync/3294134
- AssetService / InsertService / DataModel / MeshPart / SurfaceAppearance / MaterialVariant / MaterialService / EditableMesh / EditableImage / Terrain / HeightmapImporterService refs: https://create.roblox.com/docs/reference/engine/classes/<Name>
- Roblox API dump (security levels, client 0.744.0): https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/Full-API-Dump.json
- Importer: https://create.roblox.com/docs/studio/importer · Meshes: https://create.roblox.com/docs/parts/meshes
- Mesh specs: https://create.roblox.com/docs/art/modeling/specifications · Export: https://create.roblox.com/docs/art/modeling/export-requirements · Blender guide: https://create.roblox.com/docs/art/blender
- Textures: https://create.roblox.com/docs/art/modeling/texture-specifications · PBR: https://create.roblox.com/docs/art/modeling/surface-appearance · assign textures: https://create.roblox.com/docs/art/modeling/assign-textures
- 4K textures (2026-01-30): https://devforum.roblox.com/t/4k-texture-rendering/4316229 · Decal 1024 note: https://devforum.roblox.com/t/decal-upload-page-still-mentions-1024x1024-limit-instead-of-4096x4096/4526770
- Asset library / trim sheets: https://create.roblox.com/docs/tutorials/curriculums/environmental-art/assemble-an-asset-library · Materials: https://create.roblox.com/docs/parts/materials
- Terrain: https://create.roblox.com/docs/parts/terrain · editor: https://create.roblox.com/docs/studio/terrain-editor · custom terrain materials: https://create.roblox.com/docs/parts/custom-terrain-materials
- Units: https://create.roblox.com/docs/physics/units · Studio MCP tool list: https://create.roblox.com/docs/studio/mcp
- FileMesh spec (community): https://devforum.roblox.com/t/roblox-filemesh-format-specification/326114
- Third-party Open Cloud GLB/FBX measurements (2026-10-02): https://github.com/orangutanger1/blox/pull/67 and https://github.com/orangutanger1/blox/blob/main/docs/superpowers/specs/2026-10-02-opencloud-upload-path-design.md
- Blender: export ops https://docs.blender.org/api/current/bpy.ops.export_scene.html · bake op https://docs.blender.org/api/current/bpy.ops.object.html · bake types https://docs.blender.org/api/current/bpy_types_enum_items/bake_pass_type_items.html · baking manual https://docs.blender.org/manual/en/latest/render/cycles/baking.html · release notes 5.0/5.1/5.2 https://developer.blender.org/docs/release_notes/5.2/ · A.N.T. https://extensions.blender.org/add-ons/antlandscape/
- Poly Haven API: https://github.com/Poly-Haven/Public-API · ToS https://github.com/Poly-Haven/Public-API/blob/master/ToS.md · live https://api.polyhaven.com
- ambientCG: https://docs.ambientcg.com/api/ · v3 assets https://docs.ambientcg.com/api/v3/assets/ · licence https://docs.ambientcg.com/license/
- Kenney licence: https://kenney.nl/support · 3dtextures.me: https://3dtextures.me/about/ · ShareTextures: https://www.sharetextures.com/
