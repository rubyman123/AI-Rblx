# 02 — Realism technique bible (Roblox, as of 2026-10-24)

Scope: exact properties + starting values Claude can set from Luau (Studio MCP `execute_luau`, plugin security) for REALISTIC maps (horror house, liminal/backrooms, forest/lake), ~300x300 studs, PC first, phones playable.

Legend: **[doc]** official Creator Docs / API reference (live, updated 2026-10-23). **[staff]** Roblox staff DevForum post. **[community]** DevForum user post. **[derived]** my own starting value built from the sourced facts; must be tuned by eye. **[OLD]** source older than 2024, possibly outdated.

---

## 0. The 12 rules that matter most

1. `Lighting.Technology` is **deprecated and not writable from scripts** (RobloxScriptSecurity). Use `Lighting.LightingStyle = Enum.LightingStyle.Realistic` + `Lighting.PrioritizeLightingQuality = true`. Mapping from the old modes: Future = Realistic + Prioritize on, ShadowMap = Soft + Prioritize on, Voxel = Soft + Prioritize off. [doc] https://create.roblox.com/docs/reference/engine/classes/Lighting , [staff] https://devforum.roblox.com/t/3401512 (Unified Lighting, fully live 2025-07-23)
2. Whether `LightingStyle`/`PrioritizeLightingQuality` can be set **by script** is contested: the launch post said "neither of these properties are scriptable" and users reported the same in 2025-07 and 2026-04, but the current API reference and the rbx-dom reflection DB (v0.741) list both as ReadWrite with security None. Wrap the write in `pcall`, and if it fails, ask the user to set it once in the Properties panel (it saves in the place). See Verify list. [staff] https://devforum.roblox.com/t/3401512 , [community] https://devforum.roblox.com/t/3826475 , https://devforum.roblox.com/t/4566329 , [doc] https://github.com/rojo-rbx/rbx-dom/blob/master/rbx_dom_lua/src/database.json
3. **Realistic drops to Soft on lower graphics quality.** You can't force it. Phones will often see Soft, and Soft makes local lights look much brighter. Design every scene so it still reads in Soft: moderate light Brightness, and bake AO/grime into textures. [community] https://devforum.roblox.com/t/4871374 (2026-09), https://devforum.roblox.com/t/4027710 (2025-10), https://devforum.roblox.com/t/4911437 (2026-10)
4. Shadows turn off entirely below graphics quality **4**. [doc] https://create.roblox.com/docs/performance-optimization/improve
5. The local light Range cap is **120 studs** (raised from 60 on 2025-09-23). [staff] https://devforum.roblox.com/t/3954367
6. Shadowed local lights cost far more than unshadowed ones. From cheapest to most expensive: SpotLight (angle under 120°), SurfaceLight, PointLight (most expensive by a margin). The engine also limits how many per-pixel and shadowed lights it draws each frame. [staff][OLD 2020, still the latest official ranking] https://devforum.roblox.com/t/878634
7. `MaterialVariant` (tiling PBR from ambientCG/Poly Haven) gives the **most realism per unit of effort**. Use `SurfaceAppearance` for unique Blender meshes, and `Texture`/PBR `Decal` overlays for grime.
8. Normal maps must be **OpenGL tangent space** (Y+). Use ambientCG `*_NormalGL` and Poly Haven `nor_gl`. [doc] https://create.roblox.com/docs/art/modeling/texture-specifications
9. Uploads up to **4096²** now stream at 4K (live in published games since 2026-01-30). Low-end phones under 3.5 GB RAM have 4K disabled. Author at 1K by default and 2K for hero assets. [staff] https://devforum.roblox.com/t/4144950 , https://devforum.roblox.com/t/4144855
10. Hard limit of **20,000 triangles per mesh**. A mobile-safe view budget is about **500k triangles and 500 draw calls**, with client memory under **1.3 GB**. [doc] https://create.roblox.com/docs/art/modeling/specifications , [community expert guest article, 2024-08] https://devforum.roblox.com/t/3127146
11. Large MeshParts sunk into terrain can get **dark patches that don't match the sun**. Setting `CollisionFidelity = Box` removes them (it is the collision geometry, not the render mesh, that causes them). Keep the real collision on a separate invisible part. [community 2026-08/09] https://devforum.roblox.com/t/4821616 , https://devforum.roblox.com/t/4874817
12. Put lights in an `Attachment`, not straight in the visible bulb part. That lets you move the light freely; docs recommend Attachment for PointLight. [doc] https://create.roblox.com/docs/effects/light-sources , [community] https://devforum.roblox.com/t/3901114

---

## 1. Lighting service

### 1.1 Property reference

| Property | Type / range | Default (Instance.new, rbx-dom v0.741) | Notes |
|---|---|---|---|
| `LightingStyle` | Enum `Realistic`(0) / `Soft`(1) | Soft | Realistic = most advanced lights and shadows; Soft = flat retro look. Writable from script is unconfirmed (rule 2). [doc] |
| `PrioritizeLightingQuality` | bool | false | true = keep lighting quality and cut draw distance first. Turn on for realism. [doc] |
| `Technology` | deprecated | — | RobloxScriptSecurity, so you can't write it from a script. Enum also lists `Unified`(5, deprecated) and `Compatibility`(deprecated). [doc] https://create.roblox.com/docs/reference/engine/enums/Technology |
| `Brightness` | float | 1.98 | Sun/moon intensity. |
| `ExposureCompensation` | -5..5 | 0 | +1 = 2× exposure, -1 = ½. Applied before tonemap. [doc] |
| `Ambient` | Color3 | API text says default 0,0,0 (template); Instance.new 127,127,127 | Light hue in areas occluded from the sky (interiors). [doc] |
| `OutdoorAmbient` | Color3 | 127,127,127 | Clamped to be ≥ Ambient per channel. Ignored when GlobalShadows = false. [doc] |
| `ColorShift_Top` / `_Bottom` | Color3 | 0,0,0 | Tint on faces toward/away from the sun. Good for warm sun tint. [doc] |
| `EnvironmentDiffuseScale` | 0..1 | 0 | Ambient light taken from the sky (IBL). When you raise it, lower Ambient/OutdoorAmbient. [doc] |
| `EnvironmentSpecularScale` | 0..1 | 0 | Sky reflections. Metalness maps do nothing when this is 0. [doc] |
| `GlobalShadows` | bool | false (Instance.new) | Must be true for realism. |
| `ShadowSoftness` | 0..1 | API text says 0.2; rbx-dom Instance.new says 0.5 | Only applies with Realistic (guide), or ShadowMap/Future (API). [doc] |
| `ClockTime` | 0..24 | — | Linked to `TimeOfDay` ("17:30"). |
| `GeographicLatitude` | degrees | 41.7333 | Moves sun/moon paths. |
| `FogStart`/`FogEnd`/`FogColor` | — | — | **Hidden and ignored when an Atmosphere exists.** Use Atmosphere. [doc] |
| `ExtendLightRangeTo120` | hidden | — | Unused; the 120 cap is always on. [doc] |

Sources: [doc] https://create.roblox.com/docs/reference/engine/classes/Lighting , https://create.roblox.com/docs/environment/lighting , rbx-dom DB https://github.com/rojo-rbx/rbx-dom/blob/master/rbx_dom_lua/src/database.json

Official "most realistic" recipe: EnvironmentDiffuseScale = 1, EnvironmentSpecularScale = 1, Ambient = OutdoorAmbient = 0,0,0. PBR (MaterialVariant/SurfaceAppearance) looks best this way. [doc] https://create.roblox.com/docs/reference/engine/classes/SurfaceAppearance , https://create.roblox.com/docs/tutorials/use-case-tutorials/lighting/enhance-outdoor-environments

Official evening campfire tutorial values: Realistic; EnvDiffuse/EnvSpec 1; ClockTime 17; Ambient = OutdoorAmbient 156,136,176 (purple evening); Atmosphere Density 0.272, Haze 1, Color 85,78,54; campfire PointLight Range 48, Brightness 2, Color 255,179,73, Shadows on. [doc] same tutorial URL.

### 1.2 Sky / skybox

- The `Sky` object takes 6 LDR faces: `SkyboxBk/Dn/Ft/Lf/Rt/Up`, or the newer `Skybox*Content` (Content type). HDR is not supported, so you need to tonemap an HDRI to 8-bit first. [doc] https://create.roblox.com/docs/reference/engine/classes/Sky
- **Face limit 1024²** [community 2025-04] https://devforum.roblox.com/t/3624829 . Texture streaming support for Sky is still "work in progress", so 4K skies are not supported. [staff] https://devforum.roblox.com/t/4144855
- **HDRI → faces:** take a 2:1 equirect (Poly Haven CC0) and run it through Jaxry's Panorama-to-Cubemap. Mapping: `pz→SkyboxBk`, `ny→SkyboxDn (rotate 90° CCW)`, `nz→SkyboxFt`, `nx→SkyboxLf`, `px→SkyboxRt`, `py→SkyboxUp (rotate 90° CW)`. [2024-02] https://devforum.roblox.com/t/2849003
- `SkyboxOrientation` (Vector3 in degrees, Y applied first) has been live since 2025-06. Use it to line the HDRI's baked sun up with the Roblox sun. [staff] https://devforum.roblox.com/t/3674945 . Bug: Atmosphere does not re-render for a rotated sky (2026-08). https://devforum.roblox.com/t/4796988
- Other properties: `CelestialBodiesShown` (set false if the HDRI already has a sun or moon), `SunAngularSize` (default 21, clamped 0..60), `MoonAngularSize` (11), `StarCount` (3000). [doc]
- With EnvironmentDiffuse/Specular at 1, **the skybox lights the scene.** An overcast HDRI gives a flat grey ambient for free; a sunset HDRI tints everything orange. Pick the sky first.

### 1.3 Recommended value sets [derived from the sources above; tune by eye]

All presets: `LightingStyle=Realistic`, `PrioritizeLightingQuality=true`, `GlobalShadows=true`. Colors are RGB 0–255.

| Property | Horror night interior (abandoned house) | Foggy horror exterior | Liminal fluorescent interior | Golden-hour forest | Overcast forest |
|---|---|---|---|---|---|
| ClockTime | 0.5 | 21 (or 4.5 for blue dawn) | 12 (sun irrelevant indoors) | 17.4 | 13 |
| GeographicLatitude | 41.7 | 41.7 | 41.7 | 45 (lower sun) | 41.7 |
| Brightness | 0.4 | 0.8 | 1 | 3 | 1 |
| ExposureCompensation | -0.3 | -0.2 | +0.3 | 0 | +0.2 |
| Ambient | 6,6,8 | 12,13,16 | 105,100,78 | 35,30,30 | 55,57,60 |
| OutdoorAmbient | 25,28,38 | 55,60,70 | 105,100,78 | 110,95,85 | 125,130,135 |
| ColorShift_Top | 0,0,0 | 0,0,0 | 0,0,0 | 255,205,150 | 0,0,0 |
| ColorShift_Bottom | 0,0,0 | 0,0,0 | 0,0,0 | 40,30,55 | 0,0,0 |
| EnvironmentDiffuseScale | 0.3 | 0.6 | 0.4 | 1 | 1 |
| EnvironmentSpecularScale | 1 | 0.6 | 0.4 (1 for poolrooms) | 1 | 0.5 |
| ShadowSoftness | 0.3 | 0.6 | 0.6 | 0.15 | 1 |
| Atmosphere Density | 0.30 | 0.60 | 0.22 | 0.30 | 0.42 |
| Atmosphere Offset | 0.10 | 0.00 | 0.00 | 0.25 | 0.05 |
| Atmosphere Color | 45,50,60 | 110,115,120 | 200,190,150 | 200,170,108 | 185,190,195 |
| Atmosphere Decay | 20,22,28 | 70,75,85 | 150,140,110 | 92,60,14 | 140,145,150 |
| Atmosphere Glare | 0 | 0 | 0 | 1.5 | 0 |
| Atmosphere Haze | 1.5 | 3 | 0.5 | 1.5 | 2 |
| Clouds (under Terrain) Cover / Density | none | 0.8 / 0.9 | none | 0.45 / 0.5 | 0.95 / 0.85 |
| Sky | dark night HDRI, StarCount 1500 | foggy/overcast night HDRI, CelestialBodiesShown false | black sky (unseen) | sunset HDRI, SkyboxOrientation aligned to sun | overcast HDRI, CelestialBodiesShown false |
| Bloom Intensity / Size / Threshold | 0.6 / 30 / 1.2 | 0.3 / 24 / 1.5 | 0.8 / 40 / 0.95 | 0.35 / 24 / 1.2 | 0.2 / 24 / 1.5 |
| ColorCorrection Brightness / Contrast / Saturation | -0.02 / 0.15 / -0.35 | 0 / 0.10 / -0.40 | +0.02 / -0.05 / -0.10 | 0 / 0.10 / +0.10 | 0 / 0.05 / -0.15 |
| ColorCorrection TintColor | 225,232,255 | 215,225,235 | 255,248,225 | 255,240,220 | 235,240,245 |
| SunRays Intensity / Spread | off | 0.05 / 0.5 | off | 0.12 / 0.6 | off |
| DepthOfField (Far / FocusDist / InFocusRadius / Near) | off | 0.15 / 40 / 50 / 0 | 0.15 / 30 / 40 / 0 | 0.10 / 60 / 80 / 0 | off |
| SoundService.AmbientReverb | LivingRoom (zones: Room, Bathroom) | Forest / Plain | Hallway (StoneCorridor for concrete) | Forest | Forest |

Notes on these values:
- **Golden hour:** Atmosphere Color/Decay above are the engine's own Instance.new defaults (200,170,108 / 92,60,14), which are already a warm, dusty preset (rbx-dom DB). The sun meets the horizon around ClockTime 18 at the default latitude; Verify.
- **Horror night:** keep Ambient slightly above pure black. Pure 0,0,0 plus the Soft fallback on phones gives unreadable blackness, and older horror threads say the same: "both at 0 is too dark". [community][OLD] https://devforum.roblox.com/t/2168646 . Horror fog guidance from older threads: Haze 2–4 (higher covers the whole sky), Density 0.2–0.4. [community][OLD 2021] https://devforum.roblox.com/t/1307486
- **Liminal:** the flat, even backrooms look is close to what Soft looks like anyway, so this preset survives the phone fallback best.

### 1.4 Apply-preset helper (Luau, run via execute_luau)

```lua
local Lighting = game:GetService("Lighting")
local function set(inst, props)
  for k, v in pairs(props) do
    local ok, err = pcall(function() inst[k] = v end)
    if not ok then warn(("[preset] %s.%s failed: %s"):format(inst.ClassName, k, err)) end
  end
end
local function ensure(className, parent)
  local o = parent:FindFirstChildOfClass(className) or Instance.new(className)
  o.Parent = parent
  return o
end
-- LightingStyle/PrioritizeLightingQuality may be NotScriptable: pcall reports it
set(Lighting, {LightingStyle = Enum.LightingStyle.Realistic, PrioritizeLightingQuality = true,
  GlobalShadows = true, ClockTime = 17.4, Brightness = 3, ExposureCompensation = 0,
  Ambient = Color3.fromRGB(35,30,30), OutdoorAmbient = Color3.fromRGB(110,95,85),
  EnvironmentDiffuseScale = 1, EnvironmentSpecularScale = 1, ShadowSoftness = 0.15})
set(ensure("Atmosphere", Lighting), {Density = 0.3, Offset = 0.25, Haze = 1.5, Glare = 1.5,
  Color = Color3.fromRGB(200,170,108), Decay = Color3.fromRGB(92,60,14)})
set(ensure("BloomEffect", Lighting), {Intensity = 0.35, Size = 24, Threshold = 1.2})
set(ensure("ColorCorrectionEffect", Lighting), {Contrast = 0.1, Saturation = 0.1, TintColor = Color3.fromRGB(255,240,220)})
set(ensure("SunRaysEffect", Lighting), {Intensity = 0.12, Spread = 0.6})
set(ensure("Clouds", workspace.Terrain), {Cover = 0.45, Density = 0.5})
```

---

## 2. Atmosphere, Clouds, post effects

### 2.1 Atmosphere (child of Lighting)

| Property | Range | Instance.new default | What it does |
|---|---|---|---|
| `Density` | 0..1 | 0.395 | Particles in the air. Hides objects and terrain, not the skybox directly. |
| `Offset` | 0..1 | 0 | High = horizon silhouettes; low = distant objects blend into the sky. Too low causes "ghosting" (sky visible through objects). |
| `Haze` | 0..10 | 0 | Haziness above the horizon and in the distance. Pair with Color. |
| `Color` | Color3 | 200,170,108 | Atmosphere hue. Official tip: pick a color near the average of the scene. |
| `Glare` | 0..10 | 0 | Glow around the sun. Needs Haze > 0. |
| `Decay` | Color3 | 92,60,14 | Hue away from the sun. Needs Haze > 0 and Glare > 0. |

[doc] https://create.roblox.com/docs/environment/atmosphere , https://create.roblox.com/docs/reference/engine/classes/Atmosphere ; defaults from rbx-dom DB. The 0..10 ranges for Haze and Glare come from the Properties-panel slider; Verify.

### 2.2 Clouds

A `Clouds` object only renders when **parented to `workspace.Terrain`**. Properties: `Cover` 0..1 (default 0.5), `Density` 0..1 (default 0.7), `Color`. Lighting and Atmosphere also tint the clouds. Clouds move with `workspace.GlobalWind`. [doc] https://create.roblox.com/docs/environment/clouds , https://create.roblox.com/docs/environment/global-wind

### 2.3 Post effects

Parent to `Lighting` for everyone, or to `Camera` for one player. Studio only shows some effects at the highest Editor Quality Level (Studio Settings → Rendering). [doc] https://create.roblox.com/docs/environment/post-processing-effects

| Effect | Properties (Instance.new default) | Realism range [derived] |
|---|---|---|
| `BloomEffect` | Intensity 0.4, Size 24, Threshold 0.95 | Intensity 0.2–0.8, Size 24–40, Threshold 0.95–1.5 (only real light sources and Neon should bloom) |
| `ColorCorrectionEffect` | Brightness 0, Contrast 0, Saturation 0, TintColor 255,255,255 | Contrast 0.05–0.15; Saturation -0.4 (horror) to +0.1 (golden hour); faint tint. Never strong. |
| `SunRaysEffect` | Intensity 0.25, Spread 1 (keep in 0..1) | 0.05–0.15. Objects between camera and sun shape the rays, which gives canopy god rays for free. |
| `DepthOfFieldEffect` | FarIntensity 0.75, FocusDistance 0.05, InFocusRadius 10, NearIntensity 0.75 | Showcase only: Far 0.1–0.2, Focus 30–60, InFocus 40–80, Near 0. Hurts gameplay readability and works badly with semi-transparent alpha. |
| `BlurEffect` | Size 24 | Menus only. |
| `ColorGradingEffect` (new) | `TonemapperPreset`: `Default` (post-2019 look) / `Retro` (pre-2019, low contrast) | Keep Default for realism. Only the most recently parented instance applies. |

[doc] https://create.roblox.com/docs/reference/engine/classes/ColorGradingEffect , https://create.roblox.com/docs/reference/engine/enums/TonemapperPreset ; defaults from rbx-dom DB.

Community recipe from a stylized-realistic neon alley (2026-07): fake each light source with several Spot and Point lights, then add a bit of bloom and subtle ColorCorrection contrast, on Future/Realistic. https://devforum.roblox.com/t/4762297

---

## 3. Materials

### 3.1 Which surface tool to use

| Tool | Tiles? | Applies to | Best for | Effort to realism |
|---|---|---|---|---|
| **MaterialVariant** (in MaterialService) | Yes, `StudsPerTile` (default 10), `MaterialPattern` Regular/Organic | Parts, MeshParts, and terrain (via override) | Walls, floors, ground, rock, wood, concrete. Set once, reuse everywhere, batches well. | **Best** |
| **SurfaceAppearance** (child of MeshPart) | No. UV 0..1, one UV set. | MeshParts only | Unique Blender props with baked textures, trim sheets, foliage cards | High quality, needs UVs and a bake |
| **Texture** (Decal subclass) | Yes, `StudsPerTileU/V`, `OffsetStudsU/V` | One part face | Grime, stains, wet patches layered over a base material | Cheap wins, but each one is an extra draw call |
| **Decal** | No | One part face | Posters, cracks, single stains | Same as Texture |
| **Built-in 2022 materials** | Yes | Everything | Fallback; `MaterialService.Use2022Materials` (not scriptable) | OK, but recognisably "Roblox" |

Sources: [doc] https://create.roblox.com/docs/parts/materials , https://create.roblox.com/docs/reference/engine/classes/MaterialVariant , https://create.roblox.com/docs/reference/engine/classes/MaterialService , https://create.roblox.com/docs/reference/engine/enums/MaterialPattern , https://create.roblox.com/docs/art/modeling/surface-appearance , https://create.roblox.com/docs/reference/engine/classes/Texture

### 3.2 SurfaceAppearance facts

- Maps (all PluginSecurity writes, so execute_luau can set them in edit mode): `ColorMap`/`ColorMapContent`, `NormalMap(Content)`, `RoughnessMap(Content)`, `MetalnessMap(Content)`, `EmissiveMaskContent`, plus `EmissiveStrength` and `EmissiveTint`. There is **no AO slot**: multiply AO into the albedo lightly. [doc API] https://create.roblox.com/docs/reference/engine/classes/SurfaceAppearance
- Map formats: Albedo RGB 24-bit; Normal RGB 24-bit **OpenGL tangent space** (flat = 127,127,255); Roughness, Metalness and Emissive single-channel 8-bit. [doc] https://create.roblox.com/docs/art/modeling/texture-specifications
- `AlphaMode` (enum values): `Overlay`(0, default) shows MeshPart.Color through the alpha; `Transparency`(1) cuts out; `TintMask`(2) puts `SurfaceAppearance.Color` tint where alpha = 1; `Opaque`(3) ignores alpha.
- **Foliage and lace:** use `AlphaMode=Transparency` **with `MeshPart.Transparency=0`**. That gives an opaque cutout with correct depth, and it works better with DepthOfField and with water reflection/refraction. Use `Transparency ≥ 0.02` only for soft gradients like dirty glass. [doc] https://create.roblox.com/docs/art/modeling/surface-appearance
- `SurfaceAppearance.Color` multiplies the ColorMap (author maps near-white for the strongest tint). It is free, so reuse one map with many tints. `ResampleMode` Default/Pixelated. [doc]
- Map properties can't be changed during a running game (pre-processing). Tint and AlphaMode can. [doc]
- **SurfaceAppearance doesn't tile:** UVs must stay within 0..1 (the texture spec page lists 1024² as the UV-space maximum, an older line next to the new 4K text). For big surfaces use trim sheets (Beyond the Dark) or MaterialVariant. [doc] https://create.roblox.com/docs/art/modeling/texture-specifications , https://create.roblox.com/docs/resources/beyond-the-dark/building-architecture
- Roughness tip: Roblox's fresnel can over-shine. Add about +0.1 roughness if surfaces look wet. [doc]

### 3.3 Texture sizes

- Upload formats: png, jpg, tga, bmp. Up to **4096²** (4K) since 2026-01-30, served by texture streaming. The engine streams mips based on importance and memory, and low-end devices under 3.5 GB get no 4K. [doc] https://create.roblox.com/docs/art/modeling/texture-specifications , [staff] https://devforum.roblox.com/t/4144950 , https://devforum.roblox.com/t/4144855
- Doc guidance: 256² for about 5×5-stud objects, 512² for 10×10, 1024² for 20×20. Built-in part materials are 1024² per 8×8 studs; terrain is 512² per 8×8 studs. [doc]
- GPU memory follows pixel count (1024² = 4× 512²). [doc] https://create.roblox.com/docs/performance-optimization/improve
- Starting values [derived]: MaterialVariants 1024 (2048 for ground and main walls); SurfaceAppearance props 512–1024; hero props 2048; skybox faces 1024.

### 3.4 MaterialVariant setup (all scriptable except the override name properties)

```lua
local MS = game:GetService("MaterialService")
local mv = Instance.new("MaterialVariant")
mv.Name = "Concrete_ambientCG_022"
mv.BaseMaterial = Enum.Material.Concrete          -- PluginSecurity write: OK from execute_luau
mv.ColorMap     = "rbxassetid://<color>"          -- or ColorMapContent = Content.fromUri(...)
mv.NormalMap    = "rbxassetid://<normalGL>"
mv.RoughnessMap = "rbxassetid://<rough>"
mv.MetalnessMap = "rbxassetid://<metal>"          -- optional
mv.StudsPerTile = 8                               -- real-world size in metres × ~3.5 (1 stud = 0.28 m)
mv.MaterialPattern = Enum.MaterialPattern.Organic -- Organic = less visible repetition (stone/dirt); Regular = bricks/planks/tiles
mv.Parent = MS
part.Material = Enum.Material.Concrete; part.MaterialVariant = mv.Name
-- global swap, including terrain: the MaterialService.<X>Name props are NotScriptable, so use the method:
MS:SetBaseMaterialOverride(Enum.Material.Concrete, mv.Name)
```

- MaterialVariant ColorMap alpha is ignored unless the **"MaterialVariant Alpha Mode" Studio Beta** is on (2026-02). With it on, AlphaMode works like SurfaceAppearance, which enables tiling fences and grates. [staff] https://devforum.roblox.com/t/4406303
- Terrain faces: `TerrainDetail` children (top/side/bottom) customise how a MaterialVariant looks on terrain voxels. [doc] https://create.roblox.com/docs/parts/materials
- Unit check: physics docs define **1 stud = 28 cm**. [doc] https://create.roblox.com/docs/physics/units . ambientCG/Poly Haven materials list their real-world size, so StudsPerTile ≈ metres / 0.28.

### 3.5 Grime and overlays

- Layer a `Texture` over a SurfaceAppearance or MaterialVariant for dirt and ageing. Duvall Drive did this for brick dirt and aged wood. [doc][OLD 2022] https://create.roblox.com/docs/resources/the-mystery-of-duvall-drive/develop-a-moving-world
- **New: PBR Decals.** `Decal` (and `Texture`, which inherits from it) now has `NormalMapContent`, `RoughnessMapContent`, `MetalnessMapContent`, `EmissiveMaskContent`, `Rotation`, `UVOffset`, `UVScale`, `ZIndex`. That means wet patches, puddles and embossed stains with real normals and roughness. [doc] https://create.roblox.com/docs/reference/engine/classes/Decal . Upload warnings exist: https://devforum.roblox.com/t/4822449
- Each decal or texture breaks batching and adds overdraw, so use them sparingly. [doc] https://create.roblox.com/docs/performance-optimization/improve
- Prefer baking grime into the SurfaceAppearance albedo (Blender) for props. Overlays are for big part-built walls.

### 3.6 Emissive and Neon

- `Neon` material glows (with bloom) but **casts no light**. Pair it with a SurfaceLight or PointLight.
- `EmissiveMaskContent` + `EmissiveStrength` + `EmissiveTint` on SurfaceAppearance, MaterialVariant or Decal lets only part of a surface glow: lamp shades, screens, embers. Very bright values clip to white. [doc]
- Fluorlite's 2026 showcases rely on 4K textures everywhere, emissive maps for fire and lava, and custom MaterialVariants for terrain. [Roblox newsroom 2026-07] https://about.roblox.com/newsroom/2026/07/roblox-studio-fidelity-creator-interviews-twin-atlas-fluorlite-maximillian-ecos

---

## 4. Terrain

### 4.1 Properties

| Property / method | Default | Notes |
|---|---|---|
| `Terrain.WaterColor` | 0.05,0.33,0.36 (dark teal ≈ 13,84,92) | Lake [derived]: 28,48,42 (murky green-brown); clear pond 35,70,75 |
| `Terrain.WaterTransparency` | 0.3 | Lake 0.55–0.7 so the bed is visible near shore |
| `Terrain.WaterReflectance` | 1 | 0.6–1 (1 = mirror-calm lake) |
| `Terrain.WaterWaveSize` | 0.15 (0..1) | Lake 0.05–0.1 |
| `Terrain.WaterWaveSpeed` | 10 (0..100 per minute) | Lake 4–8 |
| `Terrain.Decoration` | false | Animated grass on `Grass` material only |
| `Terrain.GrassLength` | 0.7 (0.1..1) | 0.5–0.8 |
| `Terrain:SetMaterialColor(mat, Color3)` | — | `MaterialColors` itself is NotScriptable, so use this method |
| `Fill*` / `WriteVoxels` | — | Voxel = 4 studs |
| `workspace.GlobalWind` | — | Drives grass, clouds, and particles (with Drag > 0 and WindAffectsDrag) |

[doc] https://create.roblox.com/docs/reference/engine/classes/Terrain , https://create.roblox.com/docs/parts/terrain , https://create.roblox.com/docs/environment/global-wind ; defaults from rbx-dom DB.

Desaturated "realistic" terrain colours [derived, starting points; built-in defaults from [doc] https://create.roblox.com/docs/parts/materials are Grass 111,126,62 / LeafyGrass 106,134,64 / Ground 140,130,104 / Rock 99,100,102 / Mud 121,112,98]:
Grass 92,104,60 · LeafyGrass 78,94,52 · Ground 98,86,68 · Mud 72,62,52 · Rock 92,92,90 · Slate 78,80,84 · Sand 160,148,120.

### 4.2 New in 2026

- **Expanded Terrain / Custom Terrain Materials** (full launch 2026-10-22): up to **62 paintable terrain materials**, each a base material plus Color plus an optional MaterialVariant, and several shades of grass in one place. Also 90% less terrain CPU memory overhead and 45% lower meshing latency in a benchmark. **`Workspace.ExpandedTerrain` is NotScriptable** and needs a save and reopen, and the material slots (`Terrain.Materials`) are hidden and NotScriptable. So Claude can't create slots by script: the user sets them up in the Terrain Materials Manager, or Claude falls back to `SetBaseMaterialOverride` + `SetMaterialColor` (one variant per base material). Known issue: terrain thinner than **16 voxels (64 studs)** can vanish with small streaming radii, so keep terrain thick. Custom physical properties are ignored for now. [staff] https://devforum.roblox.com/t/4950620 , [doc] https://create.roblox.com/docs/parts/custom-terrain-materials
- Coming (Early Access late Fall/Winter 2026, roadmap mid-2027): terrain scattering, path splines, projected terrain decals, virtual texturing, SDF terrain (no stair-stepping). [staff] https://devforum.roblox.com/t/4865617 , https://devforum.roblox.com/t/4865880

### 4.3 How showcase builders combine terrain with meshes

- Smooth terrain is the walkable base and fills the distance: ground, mud, grass with Decoration, and water.
- **Mesh rocks and cliffs sunk into terrain** give the silhouettes, plus PBR detail where terrain looks blobby.
  - Fix for dark shading on sunk meshes: `CollisionFidelity=Box` on the visible mesh, with collision on a separate invisible copy (Hull/Precise, `Transparency=1`). [community 2026-08] https://devforum.roblox.com/t/4821616 , confirmed in https://devforum.roblox.com/t/4874817 and in replies to [staff] https://devforum.roblox.com/t/4878198 (CollisionFidelity=`Tunable` + `CollisionPrecision`, 2026-09).
- Avoid giant parts: lighting is evaluated per part when its centre enters the lighting radius (seen with 2048-stud parts). Split floors and ground slabs into tiles of 128 studs or less [derived]. https://devforum.roblox.com/t/4874817
- Grass: terrain Decoration grass near paths; mesh grass and fern clumps (alpha cards) for hero patches; leave distant ground as plain textured terrain.
- Creatures of Sonaria cut terrain cells from 99M to 25M by carving away the underside of the map: big memory savings on mobile. [newsroom 2026-07] (URL above). Note this conflicts with the new 16-voxel minimum thickness under Expanded Terrain, so stay at 16 voxels or more.

---

## 5. Light sources

### 5.1 Properties

| Light | Key properties (Instance.new defaults) | Use |
|---|---|---|
| `PointLight` | Range 8 (max 120), Brightness 1, Shadows false | Bulbs, candles, fire. Most expensive when shadowed. |
| `SpotLight` | Range 16, Angle 90 (max 180), Face, Shadows false | Flashlights, ceiling cans, street lamps. **Cheapest shadowed light** when the angle is under 120°. |
| `SurfaceLight` | Range 16, Angle 90, Face, Shadows false | Fluorescent panels, windows, screens. Shadows limited by panel size and shadow-map resolution. |
| Shared (`Light`) | `Color`, `Brightness` (doesn't extend range), `Shadows`, `Enabled` | — |

Turn on **Studio Settings → Show Light Guides** to see cones and ranges. [doc] https://create.roblox.com/docs/effects/light-sources ; costs [staff][OLD 2020] https://devforum.roblox.com/t/878634 ; range cap [staff] https://devforum.roblox.com/t/3954367

### 5.2 Budget and performance

- There is no official numeric budget, and both the per-pixel light count and the shadowed-light count per frame are capped by the engine. Rule of thumb: "as few local lights as possible". [staff][OLD 2020] https://devforum.roblox.com/t/878634
- Starting budget [derived]: **1–3 shadowed lights per room** (prefer narrow SpotLights) and **no more than about 8 shadowed lights visible at once**. Unshadowed fills are cheap; MrChickenRocket adds "a few spot/point lights to break up flat shading … none shadow-casting, so they don't cost much". [2024-08] https://devforum.roblox.com/t/3127146
- One 120-range light is cheaper than four 60-range lights covering the same area. [staff] https://devforum.roblox.com/t/3954367
- Shadowed lights rebuild their shadows whenever **anything** moves inside them, even parts with `CastShadow=false` (CPU went from 4.5 to 8 ms in a repro). Keep shadowed lights away from moving things like swinging lamps, doors and NPCs. [community bug report 2025-02] https://devforum.roblox.com/t/3439857
- Shadow-map draws ("Draw (shadow)") matter less than scene draws. Still: turn `CastShadow` off on small details, and keep light areas small. [2024] https://devforum.roblox.com/t/3127146 ; [doc] https://create.roblox.com/docs/performance-optimization/improve
- Sun shadows only reach about 1000–1200 studs from the camera (no problem at 300×300). They are coarse at character scale, so small details won't cast visible sun shadows: use PointLight or SpotLight shadows for close-up drama at night. [community 2026-09] https://devforum.roblox.com/t/4874817

### 5.3 Fake-light tricks

- **Motivated sources:** every light needs a visible emitter (Neon part or emissive mask) or it reads as fake. Poolrooms advice: openings with glow parts behind them plus SurfaceLights. [community 2026-01] https://devforum.roblox.com/t/4258469
- **Composite lights:** build one sign or lamp from several Spot and Point lights. [community 2026-07] https://devforum.roblox.com/t/4762297
- **God rays:**
  - Outdoors, `SunRaysEffect` is already occluded by geometry such as tree canopies.
  - Indoors, use `Beam`s between two Attachments with a soft vertical-gradient texture: `LightEmission` 0.3–1, `Transparency` NumberSequence 0.85→1, `Brightness` 1–3, `FaceCamera` false. Duvall Drive used Beams for its "volumetric lighting". [doc][OLD 2022] https://create.roblox.com/docs/resources/the-mystery-of-duvall-drive/develop-a-moving-world
  - Community volumetric modules: Volumika (Elttob), mentioned in https://devforum.roblox.com/t/4258469 ; Re-Lume (2026-03) https://devforum.roblox.com/t/4471785 . Check the license before using either.
- **Dust motes** [derived]: `ParticleEmitter` in a box Part along the beam. Size 0.04–0.1, Rate 6–15, Lifetime 6–12, Speed 0.05–0.3, SpreadAngle 180,180, `LightInfluence` 1 and `LightEmission` 0 (so motes only show where light hits), Transparency about 0.3, Drag 1 with `WindAffectsDrag` true.
- **Flicker** [derived]: tween or step `Light.Brightness` (and the bulb's emissive or Neon colour) on a random timer: 0.05–0.15 s dips, at random 3–15 s intervals. Avoid toggling `Enabled` on shadowed lights every frame, and never move a shadowed light to flicker (rebuild cost above).
- **Survive the phone fallback:** bake soft AO and light gradients into albedo maps in Blender, since there's no runtime lightmap. [community 2025-10] https://devforum.roblox.com/t/4027710 . Experimental GI and baking: EditableImage baked lighting https://devforum.roblox.com/t/3191321 (2024-10), GI research https://devforum.roblox.com/t/4894935 (2026-09).

---

## 6. Foliage, props, scale

### 6.1 Trees and grass

- Alpha-card foliage from a **texture atlas** (one atlas per biome).
  - Cards should be clumps rather than single leaves for density; cut the card shape tight to the opaque pixels to reduce overdraw. Example: about 33% less transparency and 60% fewer triangles (240 → 144) for a fern.
  - Don't stack cards where the camera looks through many layers.
  - `MeshPart.DoubleSided = true` makes cards visible from behind but **doubles the cost**.
  
  [2024-09 Roblox-featured tutorial] https://devforum.roblox.com/t/3171224
- SurfaceAppearance on foliage: `AlphaMode=Transparency`, `MeshPart.Transparency=0` (cutout, correct depth). [doc]
- `RenderFidelity`: Automatic (default) or **Performance for foliage**; never Precise. Automatic LOD bands are about under 250 studs full detail, 250–500 reduced, over 500 lowest. [doc] https://create.roblox.com/docs/tutorials/curriculums/environmental-art/assemble-an-asset-library ; bands [community 2026-05] https://devforum.roblox.com/t/4629258
- `CastShadow`: on for trees beside paths, **off for undergrowth, grass clumps and edge-of-map foliage**. [doc] https://create.roblox.com/docs/tutorials/curriculums/environmental-art/optimize-your-experience
- Batching: reuse 3–5 tree meshes with random rotation, scale and `SurfaceAppearance.Color` tint. Same MeshContent plus an identical SurfaceAppearance means one draw call. [doc] https://create.roblox.com/docs/performance-optimization/improve
- Wind:
  - Terrain grass and particles follow GlobalWind.
  - Skinned trees with bone wind (CanopyFlow plugin, in development): about 225 tagged trees cost 0.43 ms on an RTX 4060 thanks to distance culling and batching. [community 2026-06/10] https://devforum.roblox.com/t/4693945 , https://devforum.roblox.com/t/4934470
  - Cheaper option: no wind on trees, wind only on grass and particles.
- Rocks: Blender-sculpted, decimated to 300–2,000 triangles [derived], one shared rock atlas, `CollisionFidelity` Box for decor and Hull for walk-on rocks (see 4.3).

### 6.2 Scale reference

Sourced facts:
- 1 stud = 28 cm [doc] https://create.roblox.com/docs/physics/units
- The classic noob avatar is **5 studs tall** [staff] https://devforum.roblox.com/t/3954367
- Beyond the Dark used a 16-stud modular grid [doc][OLD 2022] https://create.roblox.com/docs/resources/beyond-the-dark/building-architecture
- Measure the real R15 height with `character:GetExtentsSize().Y` [community] https://devforum.roblox.com/t/2946009

Recommended [derived] dimensions. At 0.28 m per stud a 7.5-stud door is 2.1 m, so these are near real-world while leaving third-person camera clearance:

| Element | Studs | Notes |
|---|---|---|
| Interior door (W × H) | 4 × 7.5 | Horror can go to 3.5 × 7 for a cramped feel |
| Exterior or double door | 6–7 × 8 | |
| Ceiling, house | 10–11 | About 2.8–3.1 m |
| Ceiling, backrooms | 10 | Low and oppressive |
| Ceiling, poolrooms or hall | 14–20 | |
| Floor-to-floor (incl. slab) | 12 | |
| Wall thickness | 0.5–1 | |
| Window sill height / window height | 3 / 4–5 | |
| Hallway width | 6–8 | Camera clearance |
| Stair rise / run | 0.75–1 / 1.25–1.5 | Visual steps `CanCollide=false` + an invisible `WedgePart` ramp collider ([community][OLD 2023] https://devforum.roblox.com/t/2739025) |
| Railing height | 3–3.5 | |
| Tree trunk diameter / height | 1.5–3 / 35–70 | |

---

## 7. Sound for atmosphere

| Tool | Properties | Starting values [derived] |
|---|---|---|
| `SoundService.AmbientReverb` | Enum ReverbType: NoReverb, GenericReverb, PaddedCell, Room, Bathroom, LivingRoom, StoneRoom, Auditorium, ConcertHall, Cave, Arena, Hangar, CarpettedHallway, Hallway, StoneCorridor, Alley, Forest, City, Mountains, Quarry, Plain, ParkingLot, SewerPipe, UnderWater | Swap per zone from a client script: house LivingRoom/Room, bathroom Bathroom, backrooms Hallway/CarpettedHallway, concrete StoneCorridor, poolrooms StoneRoom/Hangar, forest Forest, lake shore Plain/Mountains |
| `ReverbSoundEffect` (in a SoundGroup or Sound) | DecayTime 0.1–20 (1.5), Density 0–1 (1), Diffusion 0–1 (1), DryLevel -80..10 (-6), WetLevel -80..10 (0) | House DecayTime 0.6–1; backrooms 1.2–2; poolrooms 3–5 with WetLevel -3 |
| `Sound` 3D | `RollOffMode` Inverse / Linear / LinearSquare / **InverseTapered**; `RollOffMinDistance` (10); `RollOffMaxDistance` (10000); Volume 0–10 (0.5) | Spot sounds: InverseTapered, Min 5–10, Max 40–80 (fluorescent hum Min 3, Max 25) |
| `SoundService` | `RolloffScale` (1), `DistanceFactor` (3.33 studs per metre), `DopplerScale` | Leave at defaults |
| Advanced Audio API | `AudioPlayer` → `AudioEmitter` (`DistanceAttenuation` curve, `DistanceAttenuationBounds` default [4, 10000], `AngleAttenuation`) → `AudioListener` | Use this for emitters that need occlusion |
| **Acoustic Simulation** (out of beta 2026-09-22) | `SoundService.AcousticSimulationEnabled=true`; per-part `BasePart.AudioCanCollide`; material `AcousticAbsorption` and `Density` control echo and muffling; only works with Advanced Audio API emitters (Sound support planned) | Big win for horror: muffling through doors, echo in halls. Scales down with graphics quality. |

Layering recipe [derived]:
1. A 2D bed (Sound in SoundService, Looped, Volume 0.15–0.35): room tone, wind or forest bed.
2. 3D loops on emitters: hum, dripping, creek, rustle.
3. Random 3D one-shots every 8–25 s (creaks, distant thuds, birds) with `PlaybackSpeed` 0.9–1.1.
4. Reverb by zone.

Frontlines spent about 6 months on weapon audio bouncing off different surfaces; audio is part of the "realism" read. [newsroom 2026-07]

Sources: [doc] https://create.roblox.com/docs/reference/engine/classes/SoundService , https://create.roblox.com/docs/reference/engine/classes/ReverbSoundEffect , https://create.roblox.com/docs/reference/engine/enums/ReverbType , https://create.roblox.com/docs/reference/engine/enums/RollOffMode , https://create.roblox.com/docs/reference/engine/classes/AudioEmitter , [staff] https://devforum.roblox.com/t/4307121

---

## 8. Performance budgets (PC first, phones OK)

| Item | Budget / setting | Source |
|---|---|---|
| Triangles per mesh | **20,000 max** (hard) | [doc] https://create.roblox.com/docs/art/modeling/specifications |
| Triangles in view | **about 500k** (mobile Q10 at 60 FPS); worked example ceiling 1M | [2024] https://devforum.roblox.com/t/3127146 ; [doc] https://create.roblox.com/docs/performance-optimization/design |
| Scene draw calls in view | **about 500**; ceiling 1,000; UI under 150 | same |
| Client memory | **under 1.3 GB** (supports 2 GB phones). About 60% of Android players have 2–4 GB RAM. | [2024] t/3127146 ; [doc] https://create.roblox.com/docs/performance-optimization/test-on-hardware |
| Props [derived] | small 100–800 tris, medium 1–5k, hero 10–20k; tree 3–8k; grass clump 50–200 | — |
| Textures | author 512–1024, hero 2048; uploads up to 4096 (streamed) | see 3.3 |
| Lights | 1–3 shadowed per room, about 8 visible max [derived]; unshadowed fills cheap; Range ≤ 60 typical, 120 cap | see 5.2 |
| `BasePart.CastShadow` | off on small detail, grass, distant foliage, decals' host plates | [doc] improve page |
| `MeshPart.RenderFidelity` | Automatic (default) or Performance; avoid Precise | [doc] |
| `CollisionFidelity` | Box for decor (also fixes dark patches); Hull for rocks; PreciseConvexDecomposition only where needed; new `Tunable` + `CollisionPrecision` (2026-09). Writable in edit mode, not at runtime. | [doc] https://create.roblox.com/docs/reference/engine/classes/TriangleMeshPart , [staff] https://devforum.roblox.com/t/4878198 |
| Transparency | 0 or 1 only; alpha cutouts via `AlphaMode=Transparency` | [doc] ; https://devforum.roblox.com/t/4629258 |
| Instancing | same MeshContent + identical SurfaceAppearance (or TextureContent) = one draw call; parts and unions of the same shape and material batch too; shadows, particles and UI don't batch | [doc] improve page ; https://devforum.roblox.com/t/4629258 |
| Importer | doesn't dedupe meshes: import repeated assets once, then clone | [doc] improve page |
| `Workspace.StreamingEnabled` | default for new places; StreamingMinRadius 64, StreamingTargetRadius 1024. For a 300×300 map it is optional, but it is required for SLIM. | [doc] https://create.roblox.com/docs/reference/engine/classes/Workspace |
| `Model.LevelOfDetail` | `SLIM` (cloud-generated composite LODs; static models only; needs streaming, a published place and Team Create); legacy `StreamingMesh` | [doc] https://create.roblox.com/docs/workspace/streaming/slim |
| `Workspace.MeshStreamingAndImprovedLods` | NotScriptable RolloutState; default on since about July 2026 (better cloud LODs) | [staff] https://devforum.roblox.com/t/4601232 |
| Draw distance | low-end phones at Q1 currently render about 200 studs, rising to 500 in late 2026. A 300-stud map can lose its far edge on phones, so use Atmosphere to hide the cutoff. | [staff] https://devforum.roblox.com/t/4865880 |
| Shadows | off below quality level 4 | [doc] improve page |

Health check: Shift+F2 Render Stats shows Draw(scene) calls and tris; Shift+F2 Summary; F9 Developer Console memory; Ctrl+Alt+F6 MicroProfiler. The Studio emulator is wrong about memory. [doc] https://create.roblox.com/docs/performance-optimization/design

---

## 9. Standout realistic showcases and what they do

| # | Work (date) | Techniques (sourced) | Source |
|---|---|---|---|
| 1 | Fluorlite showcases: *Relived*, *The Jungle Hollow Showcase*, *Stormy Heights Showcase* (2026) | Assets made in Blender; composition and set dressing in Studio; **4K textures everywhere**; **emissive maps** for fire and lava; **custom MaterialVariants on terrain**; Redupe plugin to scatter and vary; procedural models for fences, ornaments and rocks along roads | https://about.roblox.com/newsroom/2026/07/roblox-studio-fidelity-creator-interviews-twin-atlas-fluorlite-maximillian-ecos |
| 2 | *Frontlines* / *Frontlines Versus* (Maximillian) | Blender + Substance + Adobe pipeline; Versus added reflective materials and bespoke high-quality assets; obsessive small details; months of surface-aware audio; runs on mobile | newsroom (above); https://www.pocketgamer.biz/maximilian-studios-on-the-success-of-frontlines-you-dont-need-a-3000-rig-or-a-500-console-you-can-boot-it-up-on-your-mobile-device/ ; https://www.dexerto.com/roblox/roblox-frontlines-creator-reveals-how-he-made-viral-call-of-duty-inspired-game-2338310/ |
| 3 | *Ecos: La Brea* | Scientifically accurate biome (real flora); PBR for fur and bark; skinned mesh rigs | newsroom (above) |
| 4 | *Creatures of Sonaria* (Twin Atlas) | Instance streaming; terrain cells cut 99M → 25M by carving the underside; Hull collisions; built-in Color/Material + SurfaceAppearance + emission maps | newsroom (above) |
| 5 | "Stray / Cyberpunk inspired environment" (Luukzie, 2026-07) | Each sign or lamp faked with several Spot and Point lights; bloom; subtle CC contrast; Future/Realistic; mostly Studio parts, Blender only for complex props | https://devforum.roblox.com/t/4762297 |
| 6 | sa_w1 forests: *Realistic Autumn Forest / Aspen Field*, *Pine and Birch Forest*, *Angara, Siberia* (2026-08–10) | Mixed species (aspen, birch, spruce) with colour variation between species; "very optimized despite the detail"; Aspen Field is playable for study | https://devforum.roblox.com/t/4893479 , https://devforum.roblox.com/t/4863725 , https://devforum.roblox.com/t/4931861 |
| 7 | CanopyFlow "Forest" (GraphicalElite, 2026-10) | Skinned trees with bone wind, distance culling, batching; real shadows | https://devforum.roblox.com/t/4934470 , https://devforum.roblox.com/t/4693945 |
| 8 | Poolrooms build (2025-09) + realistic poolrooms Q&A (2026-01) | Everything rendered in-engine; motivated light (openings with glow parts behind them + SurfaceLight); black sky; volumetrics through Volumika | https://devforum.roblox.com/t/3933191 , https://devforum.roblox.com/t/4258469 |
| 9 | Roblox *Beyond the Dark* / *Mystery of Duvall Drive* [OLD 2022, official] | 16-stud modular grid; trim sheets; shared SurfaceAppearance packages; Texture overlays over SurfaceAppearance for dirt; Beams for volumetric light; stacked semi-transparent cloud meshes | https://create.roblox.com/docs/resources/beyond-the-dark/building-architecture , https://create.roblox.com/docs/resources/the-mystery-of-duvall-drive/develop-a-moving-world |
| 10 | MrChickenRocket "Cardboard Box Simulator" (2024-08, guest article) | Budget first (500k tris / 500 draws); kitbash a few meshes; bake part-models to one mesh per material; non-shadow fill lights; client-side zone hiding and distance culling | https://devforum.roblox.com/t/3127146 |

**Doors, Pressure, The Mimic and Deepwoken:** I found **no primary-source technique write-ups** (developer posts or interviews) from 2024–2026, and the search results were fan wikis or SEO filler. I'm not claiming anything about their methods. Studying them means playing them and capturing reference screenshots (a separate task). One low-reliability fan-site note says Pressure recommends graphics level 8 or higher. https://bloxinformer.com/wikis/pressure/

---

## Verify in Studio (claims to measure before relying on them)

1. Does `game.Lighting.LightingStyle = Enum.LightingStyle.Realistic` and `PrioritizeLightingQuality = true` work from `execute_luau`? The API reference and rbx-dom say ReadWrite; the 2025 staff post and 2025/2026 users say NotScriptable. If it fails, the user has to set it by hand once.
2. `Lighting.Technology` write fails (RobloxScriptSecurity): confirm the error text.
3. ShadowSoftness default: is it 0.2 (API text) or 0.5 (rbx-dom Instance.new)? Read a fresh place, and check whether it has any effect under Soft.
4. Atmosphere defaults on Studio Insert vs Instance.new (rbx-dom gives Color 200,170,108 and Decay 92,60,14). Confirm the Haze and Glare slider max of 10.
5. Atmosphere Density vs visibility: at which distance does a grey 10-stud cube disappear at Density 0.3, 0.45, 0.6 and 0.75 (Offset 0)?
6. Do `Clouds` (Cover 1, Density 1) dim direct sunlight or shadows, or only the sky? If they don't, overcast has to be faked with Brightness and ShadowSoftness.
7. The graphics quality level where Realistic switches to Soft, and where shadows switch off (docs: below 4). Check with Studio's quality override.
8. Light `Range` = 200 clamps to 120.
9. Shadowed light count limit: place 10, 20 and 40 shadowed SpotLights and Points in view, and see when shadows drop and what Draw(shadow) and frame time do.
10. Real R15 height (`GetExtentsSize().Y`) for the default avatar; the highest step a Humanoid climbs without jumping; whether the 4 × 7.5 door feels right in first and third person.
11. On a large sunk MeshPart, `CollisionFidelity=Box` removes the dark patches.
12. Leaf cards: `AlphaMode=Transparency` with `MeshPart.Transparency` 0 vs 0.02 (sorting, DOF, shadows from alpha cards).
13. Is MaterialVariant AlphaMode still beta-gated (property present without the beta)? Does MaterialVariant on a MeshPart follow mesh UVs (tiling scaled by StudsPerTile) or project?
14. PBR channels on `Texture` (inherited from Decal): does a tiling grime Texture honour NormalMapContent and RoughnessMapContent?
15. Flicker cost: tweening `Light.Brightness` vs toggling `Enabled` on a shadowed light (MicroProfiler `ShadowMapSystem`, `computeLightingPerform`).
16. Skybox face mapping (ny → Dn rotated CCW, py → Up rotated CW) with Jaxry's tool output; seams; 1024 per face; does SkyboxOrientation align the HDRI sun?
17. Does terrain Decoration grass show on phones (low quality), and is it disabled at low levels?
18. A >1024 texture uploaded via Open Cloud streams at 2K/4K in Studio (4K Texture Rendering is no longer beta-gated).
19. `MaterialService:SetBaseMaterialOverride` works from execute_luau (the `*Name` properties are NotScriptable), including the terrain override.
20. `Workspace.ExpandedTerrain` can't be scripted; the reopen flow; whether `Terrain:FillBlock` can target a custom terrain material at all.
21. Acoustic simulation: AudioEmitter occlusion through a closed door part in a published test, and the `AcousticAbsorption` effect of different materials.
22. Golden-hour ClockTime: the sun-on-horizon time at latitudes 41.7 and 45.
23. Mobile draw distance about 200 studs at Q1: check whether the far edge of a 300×300 map is culled on a low-end phone.
24. Whether Bloom Threshold 0.95 (Instance.new default) makes ordinary white walls bloom under Realistic; tune the Threshold to 1.2–1.5.
