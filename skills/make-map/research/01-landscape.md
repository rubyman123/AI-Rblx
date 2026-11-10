# 01: Landscape of AI + tooling for Roblox world/map building

Research date: 2026-10-24. Scope: what exists for *building* maps (not gameplay scripting), so `/make-map` (Roblox Maps by fwjelaa) can borrow the best ideas and fill real gaps.

**Method.** I read the official Roblox docs (`*.md` endpoints, almost all stamped `last_updated: 2026-10-23`), official DevForum announcements (via the forum JSON API), GitHub repos (via the GitHub API: stars, push dates, licenses, file trees, READMEs and SKILL.md contents), and YouTube metadata (titles, publish dates, chapters). I also read the **tool schemas of the Studio MCP server installed on this machine** (they load into this Claude Code session as `mcp__Roblox_Studio__*`). That is primary evidence, but it has no URL; I cite it as **[local MCP schema]**. I made no Studio or Blender tool calls.

**Freshness flags.** Items from before 2024 are marked **(pre-2024, possibly outdated)**.

**Security flag.** Searching GitHub for "roblox mcp" now returns a cluster of fake repos. They were all created 2026-09-22, have about 70 stars, 0 forks and no license, and contain only a README, an `index.html`, some SVGs and an obfuscated `.github/workflows/*.yml`. Their READMEs say "Download" and link to raw files. Examples: `yarik-contr/mcp-forge-studio-bridge`, `Arther-hup/forge-context-engine`, `Daniel987654321/roblox-studio-agent-bridge`, `dong888666123/terrain-forge-studio`, `AallamR/RobloxForge-Intelligence`. Treat them as malware lures. Do not install, link or recommend them. (Checked via `gh api repos/<name>` and its git tree.)

---

## TL;DR

1. **The official Studio MCP is now built into Studio**, and the standalone Rust server is no longer developed ([docs](https://create.roblox.com/docs/en-us/studio/mcp.md), [archive notice](https://github.com/Roblox/studio-rust-mcp-server)). Our allowed tool subset is `execute_luau`, `screen_capture`, `character_navigation`, play control, inspection, docs and skills, plus `upload_image`/`insert_asset` for our own uploads. The rest is AI generation or Creator Store access, which our rules forbid.
2. **Nobody ships a map-building skill at the quality bar we want.** The best text-level building skills are [TabooHarmony/roblox-brain](https://github.com/TabooHarmony/roblox-brain) `roblox-building` (MIT, reviewed 2026-10-14) and [ohzw/roblox-dev-skills](https://github.com/ohzw/roblox-dev-skills) `building-maps` (no license). Both are generic. Neither has style bibles, a CC0 texture pipeline, Blender kits, terrain-by-code, scatter, lighting moods, phone budgets or automated walkability tests.
3. **Roblox is coming for the "prompt to scene" space.** The 2026 Fall roadmap lists **Scene Generation (Late 2026)**, the mobile AI "Build" app is in alpha, and Procedural Model/mesh/texture generators already ship ([roadmap](https://devforum.roblox.com/t/creator-roadmap-2026-fall-update/4880208), [RDC26](https://devforum.roblox.com/t/4865880)). Our edge is the opposite of that: no AI generation, CC0-only provenance, deterministic and editable geometry built by code, Blender-made kits, and a QA loop.
4. **Terrain is in flux.** Custom terrain materials (up to 62, needs **Expanded Terrain**) reached full launch on 2026-10-22. Scattering, path splines and projected decals are only due **Mid 2027**. Until then, scatter, paths and decals must be done by our own code ([launch](https://devforum.roblox.com/t/full-launch-publish-games-with-custom-terrain-materials-and-performance-improvements/4950620), [terrain updates](https://devforum.roblox.com/t/terrain-updates-object-scattering-path-splines-projected-terrain-decals-and-more/4865617)).
5. **The key builder plugins are open-source MIT now.** That covers stravant's GapFill, ResizeAlign, Redupe, ModelReflect 2, roblox-geometry, polymap and roadhelper ([github.com/stravant](https://github.com/stravant)). We can port their math into Luau helpers, with attribution.
6. **The upload path for meshes is not the MCP.** The official MCP can only upload images. Meshes go through the Open Cloud Assets API as **Model** (`.fbx/.gltf/.glb`, ≤20 MB). They arrive as packages, and Mesh is not uploadable from raw files ([usage guide](https://create.roblox.com/docs/en-us/cloud/guides/usage-assets.md)).

---

## 1. Existing skills, MCP servers and AI builders (community)

### 1a. Agent skills / SKILL.md packs that touch building

| Project | Activity / license | What it does for BUILDING | Good | Missing |
|---|---|---|---|---|
| [ohzw/roblox-dev-skills](https://github.com/ohzw/roblox-dev-skills) | 24★, last push 2026-03-02, **no license** (ideas only, don't copy text) | `building-maps` (6 phases: Layout → Ground & Boundaries → Zone Shells → Landmarks → Fill → Environment/Lighting/Spawns), `building-3d-objects` (Assess → Plan → Build → Verify, CSG patterns), `roblox-design-consultant` (vague prompt → Design Brief), `roblox-build-retrospective` (A/B logs) | Forces clarification of **scale, gameplay topology and zone list** before building. Uses an **Origin anchor + MapRoot folder** that is re-acquired every call because `run_code` is stateless. Gives part-count targets per call (10–40). Ships a validation script (unanchored parts, below floor, default grey plastic). Its A/B log found the phased skill wins at 500+ studs, while no-skill wins at 100×100, and that "part count ≠ quality" ([session log](https://github.com/ohzw/roblox-dev-skills/blob/main/.claude/skills/roblox-build-retrospective/knowledge/session-log.md)). Has a research report on why LLM primitive modeling fails (coordinate tokenization, no visual feedback, CSG limits) ([report](https://github.com/ohzw/roblox-dev-skills/blob/main/reports/ai-primitive-modeling-csg-countermeasures.md)) | Targets the old `mcp__roblox__run_code` tool (pre-built-in MCP). Has no screenshots in the loop, no terrain, textures, Blender, mobile budgets or genre styles. Its own log says Phase 6 lighting coverage was weak |
| [TabooHarmony/roblox-brain](https://github.com/TabooHarmony/roblox-brain) `roblox-building`, `roblox-lighting`, `roblox-studio-mcp`, `roblox-performance` | 125★, MIT, push 2026-10-15; SKILL `last_reviewed: 2026-10-14` | It has an MCP build contract: declare root, origin, dimensions, asset manifest and acceptance gates, build one bounded phase at a time, read back between phases, keep a mutation record. Also: a player-scale table (player about 5 studs, door 4×7, ceiling 10–14, path 6+), CSG epsilon rule, Cylinder/Wedge orientation quirks, Large-Place partitioned readback, player-route acceptance (spawn → landmark visibility, camera not inside geometry, recovery paths), evidence recipes (structural/visual/runtime), and an external Gaea → Blender → OBJ → voxel terrain pipeline ([full.md](https://github.com/TabooHarmony/roblox-brain/blob/main/skills/gameplay/roblox-building/references/full.md)) | The most rigorous verification thinking available. MIT, so we can adapt it | Text-only and generic. Its asset advice recommends the Creator Store and AI generators (forbidden for us). It has no art direction, CC0 texture pipeline, scatter, or genre recipes. Its asset-privacy note conflicts with the official doc (see §3) |
| [EL4CTEO/roblox-skills](https://github.com/EL4CTEO/roblox-skills) `roblox-world-building` | 43★, MIT, push 2026-10-17; ships a `roblox-assistant-skills.zip` for Studio Assistant | Luau idioms: set properties first and **parent last**; decorative parts get `CanCollide/CanTouch/CanQuery=false` and `CastShadow=false`; `LightingStyle` replaces `Technology`; Terrain `FillBlock/FillBall/WriteVoxels` in chunks; noise heightmaps with a seeded `Random`; GeometryService CSG | Concise and current API usage. Distributes to Assistant as well as Claude | No process, QA, or visual-quality guidance |
| [MSayib/roblox-dev-skill](https://github.com/MSayib/roblox-dev-skill) | 57★, MIT, push 2026-10-22, "verified against Studio 0.744" | Mostly code, with `mcp-integration.md`, `file-formats-and-assets.md` and worked examples | Version-pinned claims with a re-check recipe | Very little geometry |
| [brockmartin/roblox-game-skill](https://github.com/brockmartin/roblox-game-skill) | 270★, **no license**, push 2026-03-04 | A 121-line router SKILL.md with lazy references and genre docs (simulator, horror). "New Game in 8 steps" | Router plus lazy-reference structure | Stale: recommends `boshyxd/robloxstudio-mcp`, which is now archived. Generalist |
| [CodePhobiia/claude-roblox-game-studio](https://github.com/CodePhobiia/claude-roblox-game-studio) | 15★, MIT, 2026-04-16 | 36 agents, including `level-designer`, `world-builder` (lore, not geometry) and `blender-mcp-operator`. Skills `generate-asset` and `map-systems` | Shows a Claude-plus-Blender-MCP role split | Agent theatre, with thin building mechanics |
| [WildCake/roblox-blender-modelling](https://github.com/WildCake/roblox-blender-modelling) | 2★, MIT, 2026-09-30 | A Blender→Roblox modelling skill: physical texel density, directional UV distortion, **merge static pieces per rigid group**, publish a unique mesh once and **verify MeshId reuse**. Ships `uv_metrics.py` and `check_export.py`, which run in background Blender and write a JSON report. Its README shows 57k→16k tris and 7→2 MeshParts versus no skill | Numeric gates in headless Blender, the same pattern we want | Props and vehicles, not environments. No upload automation |
| [EL4CTEO/blender-skills](https://github.com/EL4CTEO/blender-skills) `blender-export-pipelines` | 461★, MIT, created 2026-10-14 (Blender 5.2) | Presets `roblox`/`roblox_gltf`. FBX: Apply Scalings = FBX Unit Scale, embed textures, leaf bones off. glTF "needs no scale tricks". `RenderFidelity=Automatic` makes LODs, so don't ship LOD meshes ([roblox.md](https://github.com/EL4CTEO/blender-skills/blob/main/skills/blender-export-pipelines/references/roblox.md)) | Tested export presets and an asset-QA profile | No Roblox upload or placement step |
| [gamedev-skills/awesome-gamedev-agent-skills](https://github.com/gamedev-skills/awesome-gamedev-agent-skills) `level-design` | 3.9k★, Apache-2.0, push 2026-10-24 | Engine-neutral: derive movement metrics → blockout → critical/golden path → tension-rest pacing → teach-then-test → gate. Its Roblox skills cover only characters and datastores | A clean level-design doctrine | Nothing Roblox-geometry-specific |
| Others checked | [nonlooped/roblox-suite](https://github.com/nonlooped/roblox-suite) (MIT), [sentinelcore/roblox-skills](https://github.com/sentinelcore/roblox-skills), [kennyzir/7deer_skills](https://github.com/kennyzir/7deer_skills) (game *websites*) | Code, UI or marketing only | – | No building content |

### 1b. MCP servers / Studio bridges

| Server | Activity / license | Building-relevant tools | Notes |
|---|---|---|---|
| **Official built-in Studio MCP** | Built into Studio; docs updated 2026-10-23 | See §2 | Recommended by Roblox |
| [Roblox/studio-rust-mcp-server](https://github.com/Roblox/studio-rust-mcp-server) | 496★, MIT, last push 2026-04-03 | (legacy `run_code`, `insert_model`) | "No longer being actively developed… shifted to the built-in MCP Server" |
| [boshyxd/robloxstudio-mcp](https://github.com/boshyxd/robloxstudio-mcp) | 496★, MIT, **archived**, last push 2026-06-06 | v2.7 "43 tools", plus a 31-tool read-only "inspector edition" | Archived. Its active fork is Chrrxs |
| [Chrrxs/robloxstudio-mcp](https://github.com/Chrrxs/robloxstudio-mcp) | 329★, MIT, push 2026-10-23 | `execute_luau`, `manage_instance`, `set_properties`, `capture_screenshot`, **`set_device_simulator` / `capture_device_matrix`**, `get_scene_analysis`, `get_memory_breakdown`, `export_rbxm`/`import_rbxm`, `upload_asset`, `insert_asset` (strips scripts and package links), multiplayer playtests, profilers ([definitions.ts](https://github.com/Chrrxs/robloxstudio-mcp/blob/main/packages/core/src/tools/definitions.ts)) | Best runtime/QA toolset. Its **device-matrix screenshots** idea is directly useful for "playable on phones" |
| [S4US/Roqer](https://github.com/S4US/Roqer) | 170★, **AGPL-3.0**, created 2026-09-25 | A full agent app: builds, scripts, playtests, **optional Blender integration with preview renders**, Open Cloud uploads with your own key, bundled skills. Its Studio tools can also run as a standalone MCP server | Closest product to our vision (Blender + Studio + uploads), but it is a general app. AGPL: don't copy code |
| [EL4CTEO/rbx-studio-mcp](https://github.com/EL4CTEO/rbx-studio-mcp) | 11★, MIT, push 2026-10-17 | `geometry`, `terrain`, `generate`, `assets op=upload` (Open Cloud key: audio/image/model/video), `collision`, `undo`, `screenshot`, `viewport`, `device`, `export`/`build` `.build.json` | "Write tools take arrays: ten edits is one call, **one Ctrl+Z**, all-or-nothing." A good transactional idea |
| [hope1026/weppy-roblox-mcp](https://github.com/hope1026/weppy-roblox-mcp) | 68★, **proprietary** "WEPPY SOFTWARE LICENSE", push 2026-10-24 | Terrain, lighting, a local **Asset Library → Open Cloud image upload → apply URI**, playtest, sync | The image-upload loop is like ours, but closed source. DevForum post: [4588907](https://devforum.roblox.com/t/4588907) |
| Dominus 2 | DevForum 2026-08-27 ([4833955](https://devforum.roblox.com/t/4833955)) | 46 typed tools, "revision-locked writes", "build geometry… verify its own work" | Concurrency-safe writes for multi-editor places |

### 1c. AI "build my map" products and generators (non-skill)

- **DevlHub "Expert Builder"** (DevForum 2026-10-13, [4931780](https://devforum.roblox.com/t/it-builds-96-error-free-in-your-studio-expert-builder/4931780)): plans on a **4-stud grid with a colour palette**, groups and names output, consults "21,000 distilled DevForum solutions", **takes Studio screenshots after each pass and fixes what it sees**, and puts everything under `workspace.DevlHubBuilder` per chat with one-step undo. It is commercial, and it still says "the first pass is not a promise".
- **RoAssistant** plugin (DevForum 2026-10-14, [4933085](https://devforum.roblox.com/t/4933085)) and RobloxAIBuilder ([4528734](https://devforum.roblox.com/t/robloxaibuilder-plugin-ai-assistant-coding-copilot-building/4528734)): I only saw the titles.
- **Rochipelago** (DevForum 2026-07-13, [4734869](https://devforum.roblox.com/t/4734869)): a runtime **part-only** blocky island generator. It uses fBm noise with domain warping, **explicit peaks for a readable silhouette**, per-tile beach classification (gentle = sand, steep = stone) and terraced hills. This is directly relevant to the stylized simulator style.
- [Tunahan-Uysal/RoGen](https://github.com/Tunahan-Uysal/RoGen) (BSD-2, 2026-07) is an image-to-map generator in Python + Lune. [RealRoyaltyTG/Da-LA-Streets-AI-Builder](https://github.com/RealRoyaltyTG/Da-LA-Streets-AI-Builder) turns a reference map into a city with road and building detection. Both are early hobby code.
- [mateirenn/solum](https://github.com/mateirenn/solum) (MIT, push 2026-10-23) is a desktop terrain studio that exports a **heightmap PNG + colormap PNG + RGB→Roblox-material manifest** for the Terrain Editor Import. It has no live sync.

---

## 2. Official Studio MCP server and Assistant (what exists in Oct 2026)

**Setup.** The server is built into Studio and speaks `stdio`. Enable it in Assistant → `…` → Manage MCP Servers → "Enable Studio as MCP server". Quick connect supports Claude Code, Codex CLI, Cursor, Gemini CLI, VS Code and Antigravity. The Windows CLI is `cmd.exe /c %LOCALAPPDATA%\Roblox\mcp.bat` ([docs](https://create.roblox.com/docs/en-us/studio/mcp.md)). Since 2026-08-19 **every tool takes `studio_id`**, `set_active_studio` is removed, and `list_roblox_studios` returns place IDs ([DevForum](https://devforum.roblox.com/t/studio-mcp-multi-agent-improvements-and-connected-ai-clients/4820583)).

### Tool inventory and use under our rules

| Tool | What it does | `/make-map` use |
|---|---|---|
| `execute_luau` | Runs Luau in Edit/Client/Server datamodels. The schema warns that Studio is **frozen until the code yields**: chunk heavy work (about 1000 items per batch), build each chunk in a container *outside* the DataModel, parent per chunk, and `task.wait()` once per chunk. Parent cost scales with the subtree size [local MCP schema] | **Core build primitive.** We need a chunked-build helper library |
| `screen_capture` | Captures the viewport, optionally from `camera_position` and `look_at_position` ([docs](https://create.roblox.com/docs/en-us/studio/mcp.md); [local MCP schema]) | **Shot-list QA** (hero, eye-level, top-down) |
| `character_navigation`, `user_keyboard_input`, `user_mouse_input`, `start_stop_play`, `get_studio_state`, `get_console_output` | Playtest control. The character walks to a position or instance | Walkability tests. Note that `get_console_output` "eats tokens" if you print per-frame data ([DevForum 4928494](https://devforum.roblox.com/t/get-console-output-eats-tokens-like-a-black-hole/4928494)) |
| `search_game_tree`, `inspect_instance`, `script_read/search/grep`, `multi_edit` | Inspection and script edits | Readback between phases |
| `upload_image` | Uploads a **batch of images from HTTP URLs** to the Roblox asset server and returns `{url: rbxassetid}`. The schema's example includes `http://localhost/image.png` [local MCP schema] | Possible key-free path for CC0 textures served from a local HTTP server (**untested**). The brief's Open Cloud path is the default |
| `store_image` | Local png/jpg (≤5 MB) → `IMAGEID_` URI, **only for passing to AI tools** [local MCP schema] | Not needed |
| `insert_asset` | Inserts by numeric asset ID (Model, Package, Mesh, MeshPart, Image/Decal, …) [local MCP schema] | Insert **our own** Open Cloud uploads |
| `search_asset` | Waterfall search: universe → group → user inventory → **Creator Store** | Only with `scope:"user"`/`"universe"` to find our own uploads. **Never the Creator Store** |
| `http_get` | Fetches only `create.roblox.com/docs/**/*.md` and `llms.txt` (plus the LibMP repo) [local MCP schema] | API lookups mid-build |
| `skill` | Roblox-authored skills: `rbx-device-simulator-lua`, `rbx-scene-analysis`, `rbx-perf-profiling`, `rbx-debug`, `rbx-docs-search`, `rbx-unit-test`, `rbx-create-skill` [local MCP schema] | Phone checks (device simulator) and the perf budget (Scene Analysis) |
| `subagent` | The docs list `explore` and `playtest` types; the **local schema lists `explore`, `screen_capture`, `unit_test`** | Version drift: check at runtime |
| `generate_mesh`, `generate_material`, `generate_procedural_model`, `generate_texture` (Fast 1K / Quality 4K PBR), `segment_mesh` (≤5 parts), `wait_job_finished` | Roblox AI generators. `generate_texture` and `segment_mesh` exist in the local schema but **not yet in the doc table** | **Forbidden** by our rules |

**No official mesh or model upload tool exists in the MCP.** Images are the only upload path ([docs table](https://create.roblox.com/docs/en-us/studio/mcp.md)).

**Assistant features that matter (all AI, so out of scope, but they define the competition).**
- Planning Mode (`/plan`) writes editable Markdown plans stored in the cloud, with an explicit **Build** approval gate.
- A screen-capture subagent ("Does this look right?").
- `/generate_mesh` can use a selected Part as a **bounding box**, with `maxTriangles` defaulting to 10k.
- Procedural models are capped at **50 per rolling 24h**.

Source: [Assistant guide](https://create.roblox.com/docs/en-us/assistant/guide.md). Texture Quality mode makes 4K PBR (color/roughness/metalness) in about 2 min; Fast makes 1K color in about 30 s ([DevForum 4938282](https://devforum.roblox.com/t/beta-introducing-quality-mode-for-texture-generation/4938282)). Roblox's April 2026 post says **44% of the top 1,000 creators use Assistant or third-party AI via MCP** ([newsroom](https://about.roblox.com/newsroom/2026/04/roblox-studio-going-agentic)).

**Creator-authored Skills (2026-07-09).** Assistant now takes Markdown skills (description plus instructions), and they "**also work in third-party MCP clients like Claude Desktop, Claude Code and Cursor**" via the `skill` tool ([DevForum 4728447](https://devforum.roblox.com/t/4728447)). So `/make-map` could also ship a slim Assistant-skill edition. EL4CTEO already ships an Assistant zip.

### Engine and Studio features in 2025–2026 that a map skill should exploit

- **ProceduralModel** (full release 2026-05-18). A ModuleScript generator returns `Attributes` plus `OnGenerate(params, GeneratedFolder)`, and the model regenerates when attributes or Size change. You bake it by clearing `Generator`. It works in Team Create and live games, **can't become a package yet**, and manual edits inside `GeneratedFolder` are lost on regeneration ([DevForum 4642542](https://devforum.roblox.com/t/full-release-procedural-models-build-parametrized-3d-models-with-code-or-ai/4642542), [docs](https://create.roblox.com/docs/en-us/parts/procedural-models.md)). **Writing generators by hand is not AI generation**, so we can ship our kit pieces as parametric ProceduralModels (stair count, shelf count, fence length). Example: stravant's road generators ([roblox-roadhelper](https://github.com/stravant/roblox-roadhelper): `StraightRoadGenerator` and `CurveRoadGenerator`).
- **Custom terrain materials** (full launch 2026-10-22). Set Workspace **Expanded Terrain = Enabled**, then save and reopen. You get up to **62** paintable materials (the early-access post said 64), each a base material or MaterialVariant plus a color tint. In one benchmark it cut CPU memory by 90% and meshing latency by 45%, but there was an iOS streaming crash with a fix pending ([DevForum 4950620](https://devforum.roblox.com/t/full-launch-publish-games-with-custom-terrain-materials-and-performance-improvements/4950620)). The docs describe creating these slots **only through UI**, and heightmap+colormap import "might produce different results" ([docs](https://create.roblox.com/docs/en-us/parts/custom-terrain-materials.md)).
- **Terrain roadmap.** Scattering (custom grass, rule-based density, non-destructive), path splines (terrain and foliage adapt to control points, PBR path texture), projected decals, virtual texturing and SDF terrain are all **Mid 2027**. Early access is "late Fall/Winter" ([DevForum 4865617](https://devforum.roblox.com/t/terrain-updates-object-scattering-path-splines-projected-terrain-decals-and-more/4865617), [roadmap](https://devforum.roblox.com/t/creator-roadmap-2026-fall-update/4880208)).
- **Terrain API reality.**
  - `ReadVoxelChannels`/`WriteVoxelChannels` take `SolidMaterial`, `SolidOccupancy` and `LiquidOccupancy` channels at resolution 4, up to **4,194,304 voxels per call** ([Terrain ref](https://create.roblox.com/docs/en-us/reference/engine/classes/Terrain.md)).
  - `HeightmapImporterService` is **Studio-only with elevated security, so scripts can't call it** ([ref](https://create.roblox.com/docs/en-us/reference/engine/classes/HeightmapImporterService.md)). Our heightmap → terrain path must therefore write voxels itself.
  - The Terrain Editor has Import (heightmap + colormap), Generate (biomes, blending, biome size, seed) and Draw/Sculpt/Smooth/Paint/Flatten/Sea Level ([editor docs](https://create.roblox.com/docs/en-us/studio/terrain-editor.md)).
- **GeometryService on MeshParts.** Union, Subtract and Intersect now work on watertight meshes, along with `FragmentAsync` and `SweepPartAsync` (runtime parts launched 2026-07-07). Caveat: MeshParts created by these tools **don't persist across Studio sessions or publish yet** ([DevForum 4515374](https://devforum.roblox.com/t/4515374)). "CSG on meshes" in Studio is roadmapped Late 2026.
- **Lighting.** `Lighting.LightingStyle` (`Realistic` | `Soft`) plus `PrioritizeLightingQuality` supersede `Technology`, which is deprecated ([Lighting ref](https://create.roblox.com/docs/en-us/reference/engine/classes/Lighting.md)). Many tutorials still say "set Technology to Future". Treat them as outdated.
- **Collision.** `CollisionFidelity = Tunable` with a precision slider, plus better visualizers ([DevForum 4878198](https://devforum.roblox.com/t/collision-geometry-workflow-improvements-tunable-precision-and-better-visualizations/4878198)).
- **Next-Gen Draggers** beta (2026-06-25) and **Auto-Reimport** beta (2026-09-08). Auto-Reimport watches the source file and reimports on change. **Every reimport makes new asset IDs** ([4703155](https://devforum.roblox.com/t/4703155), [4859863](https://devforum.roblox.com/t/4859863)).
- **Roadmap items to watch.** Scene generation (Late 2026), "Unified agentic permission" for Assistant/MCP/Plugins/OCALE (Late 2026), uploading straight into a game's inventory (Late 2026), Open Cloud APIs for AI tools (Late 2026), material layering (Mid 2027) ([roadmap](https://devforum.roblox.com/t/creator-roadmap-2026-fall-update/4880208)).

---

## 3. Blender ↔ Roblox

- **Official Roblox Blender plugin** ([repo](https://github.com/Roblox/roblox-blender-plugin), MIT, 249★, v1.0.5 on 2026-04-20; [docs](https://create.roblox.com/docs/en-us/art/modeling/roblox-blender-plugin.md)). It is a reference implementation of Open Cloud upload. You log in through a **browser OAuth** flow, and each selected object or collection becomes **its own asset, uploaded as a Package**. A re-upload updates the package, and inserted copies auto-update from the stored `Roblox Package ID` custom property. It is GUI- and OAuth-driven with **no headless mode**, so for `blender -b` we call Open Cloud ourselves and only reuse its ideas: package-per-collection and the ID stored on the object.
- **Open Cloud Assets API** ([usage guide](https://create.roblox.com/docs/en-us/cloud/guides/usage-assets.md), updated 2026-10-23):
  - One asset per call, **≤20 MB**.
  - **Decal/Image**: png/jpeg/bmp/tga, **<8000×8000**, cannot be updated.
  - **Model**: fbx/gltf/glb/rbxm/rbxmx, imported as a Model of MeshParts and **uploaded as packages**. Content updates are allowed only for `.fbx`.
  - **Mesh**: "Roblox only", accepts only Asset Delivery downloads ("use Importer").
  - Calls return an **Operation** to poll at `GET /assets/v1/operations/{id}`, which includes a `moderationResult`. API keys need the asset Read/Write scopes.
- **Asset privacy** ([docs](https://create.roblox.com/docs/en-us/projects/assets/privacy.md)). By default Images, Decals and Meshes are **Open Use**. Only if you turn on Asset Privacy are new ones **Restricted**, and then a game needs a grant, which is permanent once given. TabooHarmony's "new accounts default Restricted" contradicts the 2026-10-23 doc. The roadmap lists a "Full asset privacy launch", so re-check this before shipping.
- **Blender export settings (official)** ([Blender doc](https://create.roblox.com/docs/en-us/art/blender.md)): Units = None. FBX: Apply Scalings = **FBX Unit Scale**, Forward Z, Up Y, "Limit to Selected". In Studio's Importer: Scale Unit = **Stud**. Each mesh is capped at **20,000 triangles** ([specs](https://create.roblox.com/docs/en-us/art/modeling/specifications.md)). The Importer can import as Package, "Upload to Roblox", and "Add to Workspace" grants the game permission to restricted assets ([Importer](https://create.roblox.com/docs/en-us/studio/importer.md)). glTF imports nest one Model per mesh primitive, unlike FBX (same page).
- **Modular kit doctrine (official)**:
  - Pick one grid: the Beyond-the-Dark station used **16 studs**. Studio doesn't convert units, it reads them as studs.
  - Keep a few versatile pieces, **package every piece and every material**, and use trim sheets for about 90% of the architecture ([Building architecture](https://create.roblox.com/docs/en-us/resources/beyond-the-dark/building-architecture.md)).
  - Pivot locations must be consistent for snapping. The sample uses Move snap 7.5 and Rotate 45 ([Assemble modular environments](https://create.roblox.com/docs/en-us/tutorials/use-case-tutorials/modeling/assemble-modular-environments.md)).
  - `RenderFidelity=Automatic` makes LODs ([meshes](https://create.roblox.com/docs/en-us/parts/meshes.md)).
- **Community bridges.**
  - [Gametron303/roblox-blender-livelink](https://github.com/Gametron303/roblox-blender-livelink) (GPL-3, beta 1.3.2 from 2026-10-10, Russian docs): Studio → Blender scene sync, including CSG and Roblox materials as procedural shaders.
  - [GabryPol0/RBXmesh-blender](https://github.com/GabryPol0/RBXmesh-blender) (MIT): `.mesh` v2 import/export.
  - [twistedsignal/prism](https://github.com/twistedsignal/prism) (MIT): renders Studio models into icons via Blender.
  - [Cautioned/Blender-Animations-Plugin](https://github.com/Cautioned/Blender-Animations-Plugin): animation only.
  - **None of these automate environment export or upload.**
- **Asset-as-files CLIs** (useful patterns for a manifest and dedup):
  - [jackTabsCode/asphalt](https://github.com/jackTabsCode/asphalt) (164★, MIT, push 2026-07-28)
  - [Roblox/tarmac](https://github.com/Roblox/tarmac) (MIT, push 2025-07)
  - [Sleitnick/rbxcloud](https://github.com/Sleitnick/rbxcloud) (MIT, push 2025-03)
  - [Roblox/rocale-cli](https://github.com/Roblox/rocale-cli) runs Luau against a place via **Open Cloud Luau Execution (OCALE)**, which enables headless validation of a published place version.
- **Blender MCP**: [ahujasid/mcp-for-blender](https://github.com/ahujasid/mcp-for-blender) (32k★, MIT, push 2026-10-24) can import from Poly Haven (CC0, allowed) and Sketchfab/Hyper3D (not allowed).

---

## 4. Builder plugins pros use → operations to rebuild in Luau

| Plugin | What it does | Source / date | Luau op for our helper lib |
|---|---|---|---|
| **F3X Building Tools** | Move/resize/rotate with increments relative to self or last part, paint, material, surface, anchor, collision, weld, lights, decorate | [F3XTeam/RBX-Building-Tools](https://github.com/F3XTeam/RBX-Building-Tools) (push 2025-02) | Mostly native now. Keep `snap(v, inc)` and `rotateAboutLast()` |
| **GapFill & Extrude** (stravant) | Fills the gap between two edges with wedge triangles, with a thickness and force-direction setting. Supports unions and MeshParts since v1.3 | [repo, MIT, 2026-03](https://github.com/stravant/roblox-gapfill); [2017 newsroom](https://about.roblox.com/newsroom/2017/05/3-must-studio-plugins) (pre-2024 for the newsroom piece) | `fillTriangle(a,b,c,thickness)` → 2 WedgeParts. This is the basis of low-poly terrain and roofs |
| **ResizeAlign** (stravant) | Resizes two parts so their selected faces meet flush, with a rounded-join mode | [repo, MIT, 2026-07](https://github.com/stravant/roblox-resizealign) | `resizeToFace(partA, faceA, partB, faceB)` for wall and floor seams |
| **Redupe** (stravant, v1.0 2025-12-29) | Arrays of duplicates by dragging: even resize (stairs), offset, rotation between copies, plus ResizeAlign auto-curve smoothing (Jan 2026) | [DevForum 4194569](https://devforum.roblox.com/t/redupe-v10-studio-plugin-create-arrays-of-duplicates-by-dragging/4194569), [repo](https://github.com/stravant/roblox-redupe) | `array(model, n, stepCFrame, scaleStep)` for fences, stairs, pillars and lamp rows |
| **Model Reflect** (stravant; v2 2026-02) | Mirrors models across a plane | [modelreflect-2](https://github.com/stravant/roblox-modelreflect-2) | `mirror(model, planeCFrame)` with handedness fixes for wedges |
| **roblox-geometry** (stravant) | `getGeometry(part)` gives vertices, edges and faces of primitives, with stable ids | [repo](https://github.com/stravant/roblox-geometry) | Foundation for face, edge and snapping queries |
| **polymap** (stravant, 2026-07) | Heightmap made of thin wedge triangles, with implicit vertices | [repo](https://github.com/stravant/roblox-polymap) | `triTerrain(heights, cell)` for **stylized low-poly ground** without voxel terrain |
| **Archimedes Two/3** | Curves and circles from parts: angle, axis, "Render Once/Circle" | DevForum threads [984996](https://devforum.roblox.com/t/any-plugins-to-make-curves-easy/984996), [528027](https://devforum.roblox.com/t/archimedescurve-creator/528027) (pre-2024) | `arc(part, axis, angleStep, count)`, then GapFill the outer seams |
| **Brushtool 2.0** | Paints model clones onto surfaces: scale, wobble, stamp/erase, ignore water/transparent | [DevForum 255053](https://devforum.roblox.com/t/255053) (2019, pre-2024) | `scatter{...}` (below) |
| **Foliage FX / ScatterForge / EzFoliage** | Brush foliage with density, scale and rotation variance, align-to-normal, min-distance spacing, slope/height masks, exclusion zones. EzFoliage generates part-built trees, mushrooms and flowers with weighted brush presets | [Foliage FX 2025-11](https://devforum.roblox.com/t/4100157), [ScatterForge](https://godberrystudios.com/tools/roblox/scatterforge/index.md), [EzFoliage 2026-10](https://devforum.roblox.com/t/ezfoliage-procedural-trees-mushrooms-flowers-alien-flora-props-early-access/4927145) | **`scatter{assets(weights), region, density, minDist, slope=[a,b], height=[a,b], alignNormal, scaleJitter, yawJitter, exclude=…}`** via raycasts plus Poisson-disk sampling, reusing the same MeshIds |
| **Terrain Studio v2** (2026-07) | Generate presets (hills, mountain, island), **Smart Paint** (biome by height and slope: grass flats, rock steep, sand shore, skip water), Path & Flow, Cave Carver, **Terrain Health scan** | [DevForum 4728181](https://devforum.roblox.com/t/plugin-terrain-studio-v2-generate-paint-and-finish-terrain/4728181) | `paintBySlopeHeight(rules)`, `terrainHealth()` (floating voxels, holes) |
| **PathStudio** (2026-10-18) | One spline makes a road or river, fits terrain, and lines it with props. Width and banking per point. Height modes Exact / **Level (max grade)** / Follow. Rivers always run downhill, the channel is carved and filled with water | [DevForum 4942940](https://devforum.roblox.com/t/plugin-pathstudio-roads-rivers-and-props-from-one-spline/4942940) | `path(points, {width, bank, maxGrade, mode})`, `river(points)`, `propsAlong(path, spacing)` |
| **Contour Terrain** (paid, 2026-09), **Wall Builder** (2024), **Click to Build** (2025) | Streets with sidewalks and curb ramps plus fitting terrain to a build; chained walls and paths from clicks | [4875253](https://devforum.roblox.com/t/4875253), [2940484](https://devforum.roblox.com/t/2940484), [3633000](https://devforum.roblox.com/t/3633000) | `wallChain(points, h, t)`, `fitTerrainUnder(model)` |
| **TerrainSuite / Odyssey** (2026) | Biome presets on a region grid; stylized triangle terrain with raise/lower/smooth/flatten | [4754065](https://devforum.roblox.com/t/4754065), [4646900](https://devforum.roblox.com/t/updated-v3-odyssey-terrain-editor-procedural-triangle-terrain-plugin/4646900) | Biome-cell layout on a 300×300 grid |
| **LODService** (beta 2026-01) | Custom LODs and billboards for part-built models | [4218799](https://devforum.roblox.com/t/4218799) | Optional distant-tree impostors for phones |
| Studio Build Suite, MaterialFlip, Part Picker, Reclass | Build-suite helpers, rotating a texture 90°, property-match select, class swap | [My kits and plugins 2019](https://devforum.roblox.com/t/my-kits-and-plugins/231162) (pre-2024), [Best building plugins](https://devforum.roblox.com/t/best-building-plugins/2572030) | `selectWhere(props)`, `reclass(part, "MeshPart")` |

Note: stravant's plugin repos contain a `CLAUDE.md`, which suggests they are built to be edited by agents ([gapfill](https://github.com/stravant/roblox-gapfill), [polymap ORIGINAL_PROMPT.md](https://github.com/stravant/roblox-polymap)).

---

## 5. How environment builders work in 2025–2026

### Official Roblox doctrine
- **Greybox first.** Spawn zones and primary lanes, playable floors (main, mezzanine, outdoor) and perimeter walls, then extra geometry to "break up sight lines" ([Greybox your environment](https://create.roblox.com/docs/en-us/tutorials/curriculums/environmental-art/greybox-your-environment.md)).
- **Modular kit**: a uniform grid, packages, trim sheets and consistent pivots (§3).
- **Performance**:
  - Prefer built-in materials to custom textures because they use far less memory.
  - **Reuse meshes and textures to cut draw calls.**
  - Avoid partial transparency (overdraw).
  - Use streaming for large places.
  - Pick a **baseline low-end device** and test on it ([Design for performance](https://create.roblox.com/docs/en-us/performance-optimization/design.md)).
  - Scene Analysis shows instance composition and triangle composition ([Scene Analysis](https://create.roblox.com/docs/en-us/performance-optimization/scene-analysis.md)).

### YouTube creators (publish dates read from YouTube metadata)
- **BONES, "Roblox Studio - Building Tutorial | Environmental Art"** (2024-10-05, 403k views; [video](https://youtu.be/-DoOf32pkPo)). Chapters: references → compile assets → studio setup → terrain tools → **terrain blockout** → **greybox** → place rocks → **fix color** → fences → trees → detail the blockouts → plants.
- **DatBoiEle, "How to make ANY game REALISTIC"** (2025-09-26, 206k; [video](https://youtu.be/3bd8b-89GUI)). Chapters: plan → gather assets → texture creation → forest construction → lighting → scripting/polish. His links are Poly Haven textures, Sketchfab, and a WindShake script. Also **"I just figured out how ALL ROBLOX games make their MAPS…"** (2026-04-23; [video](https://youtu.be/wmB8BW4y5EA)): source quality assets → import and speed-build → realistic lighting → pro builds. It is sponsored by an asset marketplace, so there is a bias toward buying kits.
- **Kingkade 3D, "How To Make a Fisch Style Map"** (2026-05-14, 65k; [video](https://youtu.be/wSzIE4NCiSE)). Chapters: base assets → **model low-poly rocks** → import and anchor → materials and colors → map layout → pathways and details → model bushes → model and place trees → terrain and trails → fences and lamp posts. This is the stylized-island recipe: a small custom mesh kit, then layout, then dressing.
- **DeHapy, "How to Build PRO Roblox Maps!"** (2024-05-05, 235k; [video](https://youtu.be/I-AB6pJ-y5g)). Chapters: **foundation and lighting first** → structures → walking paths → environmental details → fill space → **map borders** → interactive assets. This is a simulator-style hub workflow.
- **Hibstheribs, "Realistic Forest Environment + Speedbuild"** (2026-03-24; [video](https://youtu.be/jykvT0JlYw4)). It took 4h46m, used **PBR textures from sharetextures / Poly Haven / ambientCG**, a hand-written script, and a celestial-body-dragger plus skybox plugin.
- **Miruq, "Building a Procedurally Generated Backrooms"** (2026-06-12, 56k; [video](https://youtu.be/JO6qcL4ajIw)): procedural liminal levels are a live trend. **DatBoiEle "Realistic Backrooms"** (4 years old, pre-2024; [video](https://youtu.be/WRL8uBsfhyk)).
- RoBuilder's "How to Plan and Build HUGE Maps" and "How To Make Good Simulator Maps" are 4–5 years old, pre-2024, possibly outdated ([1](https://youtu.be/eRnnjqVOq7c), [2](https://youtu.be/Y3eUDs3FFGQ)).

### DevForum craft notes (2025–2026)
- **Stylized island "lacks life"** ([3539645](https://devforum.roblox.com/t/3539645), 2025-03, 75 likes). Advice: more foliage variety, more than 2 tree types, small grass tufts, **vary leaf colours**, uneven terrain (add MeshPart rocks), sand at shorelines, darker greens, lilypads. Optionally use pre-2022 materials for the stylized look (opinion).
- **Lighting a playable room** ([4793286](https://devforum.roblox.com/t/4793286), 2026-08). One big SurfaceLight "looks tycoon/simulator-like, no shadows on the player". Darkness should keep contrast and some bright colour. This shows that **mood lighting needs placed local lights, not flat fill**.
- **Backrooms and poolrooms**: wet, reflective floors, low light and empty space ([Poolrooms showcase](https://devforum.roblox.com/t/poolrooms-build-showcase/3933191)). Many small lights and objects cause lag, and builders fixed it by **turning off shadows and deleting small props** ([4758691](https://devforum.roblox.com/t/4758691), 2026-07).
- **Natural environments with parts only** ([4616282](https://devforum.roblox.com/t/4616282), 2026-05): reference images first, study blocky games' trees, wedge tricks for hanging plants.
- **Pipeline for large terrain**: Gaea → Blender decimate → OBJ → part-to-voxel, with **slope/altitude material painting** ([TabooHarmony full.md](https://github.com/TabooHarmony/roblox-brain/blob/main/skills/gameplay/roblox-building/references/full.md), which cites [Large-Scale Terrain guide](https://devforum.roblox.com/t/large-scale-roblox-terrain-the-ultimate-guide/405672), 2019, pre-2024).

### Synthesized pipeline (what all of the above agree on)
1. **Brief and references**: style, scale, zones, mood.
2. **Metrics**: player height about 5, doors 4×7, ceilings 10–14, paths 6+, a grid of 4 or 16 studs.
3. **Kit**: a small set of custom pieces (rocks, trees, wall modules) plus a material palette.
4. **Terrain and ground blockout.**
5. **Greybox** zones and landmarks.
6. **Hero landmarks.**
7. **Mid props.**
8. **Foliage and scatter.**
9. **Lighting, atmosphere and sky** (DeHapy does part of this at step 4).
10. **Borders and kill-planes.**
11. **Interactive bits.**
12. **Optimize**: reuse meshes, cut shadows on small stuff, no partial transparency, streaming.
13. **Screenshot and playtest polish.**

---

## 6. Gaps (what no existing tool does well)

1. **Art direction as data.** No skill encodes genre style bibles (palette, materials, kit list, lighting preset, prop density, scale metrics) for abandoned horror house, backrooms/liminal, realistic forest/lake, or blocky simulator. Existing skills say only "use a Design Brief" (ohzw) or "pick colours" (DevlHub).
2. **A CC0 texture pipeline with provenance.** Nobody automates this chain end to end: Poly Haven/ambientCG → resize, tile and pack the maps Roblox wants (color/normal/roughness/metalness) → Open Cloud upload → poll the operation → wire into MaterialVariant, SurfaceAppearance or custom terrain material, keeping a license manifest. WEPPY does images only and is proprietary. EL4CTEO and Chrrxs have generic upload tools.
3. **Headless Blender → Roblox environment kits.** The official plugin is GUI/OAuth only. No tool takes a Blender-built modular kit (grid pivots, trim sheet, collision, <20k tris) to glTF/FBX, then to an Open Cloud **Model** upload (package), `insert_asset` by ID, MeshId-reuse verification and placement by code. WildCake's skill does UV and export QA for props only.
4. **Terrain by code at map scale.** Heightmap import can't be scripted (`HeightmapImporterService` is Studio-only), custom-material slots are UI-only, and splines, scatter and decals are a year away. GUI plugins exist (Terrain Studio v2, PathStudio, TerrainSuite), but **no agent-callable, chunked, seeded heightmap/biome/path/river/water writer** exists.
5. **Rule-based scatter as an agent op**, with phone-aware density caps and mesh reuse. Only brush GUIs exist.
6. **Stylized simulator kits.** There are no blocky-simulator building recipes (chunky bevel stacks, saturated palette, zone gates and pads, terraced islands). Rochipelago and polymap show the techniques, but nothing packages them for an agent.
7. **Visual QA with a shot list and rubric.** `screen_capture` with a camera exists, but no skill defines fixed hero, eye-level and phone-aspect shots and judges them against the style bible and an anti-"AI look" rubric. DevlHub does a screenshot→fix loop but is closed and generic.
8. **Phone budgets with auto-audit.** No skill sets per-map budgets (unique meshes, triangles, texture memory, shadowed lights, transparent overdraw, part count, streaming settings) and checks them via Scene Analysis and Device Simulator before calling a map done.
9. **Automated walkability.** TabooHarmony *describes* route acceptance. Nobody *automates* spawn → every POI with PathfindingService, jump gaps, ceiling clearance, out-of-bounds kill-planes and `character_navigation` spot checks.
10. **Deterministic, resumable builds.** No tool keeps a persisted map spec (JSON, seeded) as the source of truth, with per-phase checkpoints and idempotent rebuilds. Everyone rebuilds from chat memory, and `execute_luau` is stateless.
11. **Mood lighting presets on the 2026 API** (`LightingStyle`, Atmosphere, post-FX, local light plans with a shadow budget) per genre. Tutorials still use the deprecated `Technology`.
12. **Procedural liminal generators** (room graphs, wallpaper and carpet trims, fluorescent light grids, shadow budget). The trend is proven by Miruq (56k views), but no agent tool exists.

---

## Borrow these ideas

1. **Ask before building** (ohzw): require scale, gameplay topology and the zone list. If any is ambiguous, ask one question with concrete options.
2. **Top-down phases** (ohzw, BONES, Kingkade): Layout → Ground/Terrain → Zone shells/greybox → Landmarks → Fill/scatter → Lighting/atmosphere → Borders → QA. Never build everything in one call.
3. **Origin anchor + `MapRoot` folder tree** (`Terrain/`, `Zone_*/`, `Landmarks/`, `Lighting/`, `Spawns/`), re-acquired at the top of every `execute_luau` (ohzw, TabooHarmony).
4. **Build contract** (TabooHarmony): declare root, origin, named dimensions, asset manifest and acceptance gates; read back after each phase; keep a one-line mutation record; never claim "verified" without evidence.
5. **Chunked execution** (official schema): about 1000 instances per chunk, build outside the DataModel, parent once per chunk, `task.wait()` between chunks. **Parent last** (EL4CTEO).
6. **Decorative-part defaults**: `Anchored=true`; `CanCollide/CanTouch/CanQuery=false`; `CastShadow=false` on small detail (EL4CTEO, backrooms lag thread).
7. **Validation script** (ohzw plus extensions): unanchored parts, below-floor parts, default grey plastic, overlaps and z-fighting, floating geometry. Do partitioned large-place readback by zone (TabooHarmony).
8. **Player-scale table and grid** (TabooHarmony, Roblox docs): player about 5 studs, door 4×7, ceiling 10–14, path ≥6 (main roads 10+). Kit grid of 4 studs (stylized) or 16 studs (modular realistic). Consistent pivots.
9. **Port stravant's MIT geometry** with attribution: GapFill triangle fill, ResizeAlign face join, Redupe arrays, ModelReflect, `getGeometry`, polymap wedge-triangle terrain.
10. **Hand-written ProceduralModel generators** for kit pieces (stairs, fences, shelves, road segments as in stravant's roadhelper), then bake by clearing `Generator`.
11. **Scatter rules** from Brushtool, ScatterForge and Foliage FX: density, min-distance (Poisson), slope and height masks, exclusion zones, align to normal, scale and yaw jitter, ignore water. Reuse MeshIds.
12. **Paint terrain by slope and height** (Terrain Studio v2): grass on flats, rock on steep slopes, sand near water.
13. **Spline paths and rivers** (PathStudio): per-point width and banking, a max-grade "Level" mode, rivers forced downhill, a carved channel filled with water, props along the path.
14. **Island silhouette** (Rochipelago): fBm plus domain warping plus **explicit peaks** so the shape reads, beaches classified by slope, terraces.
15. **Blender kit discipline** (WildCake, EL4CTEO, Roblox docs): texel-density gate, merge static pieces per rigid group, ≤20k tris per mesh, FBX Unit Scale or glTF, one package per kit piece, verify MeshId reuse after insert.
16. **Package-per-collection with the asset ID stored on the Blender object** (official Blender plugin), so re-uploads update in place.
17. **Screenshot → fix loop** (DevlHub, Assistant's screen-capture subagent) with fixed camera poses through `screen_capture(camera_position, look_at_position)`.
18. **Device-matrix checks** (Chrrxs `capture_device_matrix`, official `rbx-device-simulator-lua` skill) for the phone requirement, plus `rbx-scene-analysis` for budgets.
19. **Transactional batches** (EL4CTEO rbx-studio-mcp): one logical step equals one undo, all or nothing. In Luau, use one `ChangeHistoryService` recording per phase.
20. **Creator lighting habits**: set lighting early (DeHapy), use placed local lights for mood rather than a single fill light, and keep contrast in the dark.
21. **Also ship as a Studio Assistant skill**: creator-authored skills work through the MCP `skill` tool (DevForum 4728447; EL4CTEO ships a zip).

## Gaps we fill

1. **Genre style bibles as data** for 4 realistic and 1 stylized family: palette, material set, kit list, lighting/atmosphere preset (`LightingStyle`-era), density targets and a reference shot list.
2. **CC0-only texture pipeline with a provenance manifest**: Poly Haven/ambientCG → resize, tile and channel-pack → Open Cloud upload → operation polling → MaterialVariant, SurfaceAppearance or custom-terrain-material wiring. Record the license and source URL for every asset.
3. **Headless Blender kit factory**: `blender -b` Python builds grid-pivoted modular kits and CC0-textured rocks and trees → QA gates (tris, texel density, pivots, collision) → glTF/FBX → Open Cloud **Model** upload → `insert_asset` → MeshId-reuse check.
4. **Terrain-by-code library**: a seeded heightmap/biome writer on `WriteVoxelChannels` (chunked, ≤4.19M voxels per call), slope/height painting, water bodies and lakes, spline roads and rivers, terrain-health scan. It replaces Studio-only heightmap import until the Mid-2027 terrain features ship.
5. **Agent-callable scatter** with Poisson spacing, masks, exclusion around paths and POIs, and per-platform density caps.
6. **Stylized simulator kit**: chunky part, wedge and triangle terrain (polymap-style), terraced islands, zone gates and pads, all part-built and phone-cheap.
7. **Procedural liminal/backrooms and horror-house generators**: room graphs, trim modules, a light-grid plan with a shadow budget, plus wet-floor and dust detailing.
8. **QA harness**: a fixed shot list (hero, eye-level, phone aspect) with a rubric, Scene Analysis budget checks, a device-simulator pass, and automated walkability (PathfindingService from spawn to all POIs, plus `character_navigation` spot walks, jump and ceiling clearance, OOB kill-plane).
9. **Deterministic, resumable builds**: a seeded JSON map spec as the source of truth, idempotent phases, checkpoints and a resume after Studio freezes or disconnects.
10. **Hard compliance with the brief's rules**: no Creator Store, no Roblox AI generators. The skill blocks `search_asset(creator_store)` and `generate_*`. That is a selling point against Assistant's Scene Generation and Roblox's mobile Build app, which are prompt-to-scene tools.
