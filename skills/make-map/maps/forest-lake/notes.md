# Forest Lake at Golden Hour: build notes (method by fwjelaa, FWJ STUDIOS)

The creator asked for this map **super realistic** (2026-10-24). The ground is one height function written as terrain by
`K.Terrain.heightfield`; every texture is a CC0 Poly Haven scan, every rock, log, stump, fern, the pier and the fire
pit is a scanned CC0 Poly Haven model; the trees, grass tufts and reeds are grown in Blender from CC0 bark and
ambientCG leaf atlases; the sky is a CC0 Poly Haven HDRI turned into six faces.

## What's in it
- A valley 400 x 400 studs (112 m): a lake (an ellipse with a wandering shore, calm by the pier) with terrain
  water, a stream running down from the north-east hills into it, a meadow, maple and birch woods, pines on a ring
  of hills. Past the playable square a second, higher ring of hills closes the horizon; invisible walls at ±232
  keep players inside.
- The route: spawn on the low south hill, looking north down a dirt path between the maples to the lake → the
  lake shore → an old pier with stairs, a gantry and a broken end → a campfire with two logs → the stream crossing
  → a rock face across the water as the far landmark.
- 90 trees (2 maple seeds, a birch, 2 pine seeds), 139 scattered ferns, grass tufts, reeds, boulders, mossy
  rocks, stumps and logs; 7 Poly Haven materials on the terrain (grass, forest floor, mossy rock, shore mud,
  path, pebbles) through MaterialService overrides; 15 models; wind and lapping water ambience.
- Golden hour: the sky's sun (`hilly_terrain_01_puresky`, 14° up, turned to the north-west) and Roblox's sun
  matched by `K.Sky.matchSun`; the low sun backlights the woods from spawn and lays long tree shadows across the
  path.

## QA rounds
1. **Ground.** The first field (box -60..40) refused to write: the hill rim reaches y 56, and `heightfield` checks
   the whole field against its claimed box before writing anything (as designed). From spawn the terrain's edge
   dropped to void behind the player, so the field grew to ±300 with an outer hill ring and invisible walls. A
   perfect ellipse read as a swimming pool: the shore now wanders (noise), held still near the pier and campfire.
2. **Sky.** The first HDRI's sun stood 32° up (midday); swapped for a 14° one. Then the sky never showed: Studio
   drew Roblox's placeholder (and in Edit, an older skybox it had cached). 1024² faces load as images but never
   render as a skybox; 512² faces do. `run.py sky` now makes 512 faces by default.
3. **Spawn view.** A pine stood on the sightline down the path. Trees now keep 20 studs from the path and 30 from
   spawn, so the path frames the lake.
4. **The gold sheet.** Edit mode showed flat gold sheets over half the lake and the land next to it. No voxels held
   water there and a test part with the same material rendered fine; in Play the ground was textured and the shore
   natural. Studio's Edit view kept old water meshes after the terrain was rewritten several times. **Judge
   terrain maps in Play.**
5. **White props.** Boulders and stumps rendered as smooth white or black blobs, in Edit and Play, although all
   their maps were approved and loaded as images. The boulder rendered once its textures were re-encoded (new
   image assets; Roblox reuses an identical image, including one whose 3D processing failed). `tree_stump_02`
   stayed white across four uploads with fresh mesh and textures; `tree_stump_01` renders, so the lake uses it.
6. **Light.** With the sun at 14° the whole valley lies in the rim's shadow and read near-black; the golden preset
   now lifts the shade (OutdoorAmbient 170,162,156, exposure +0.35) and the haze is grey-warm, so the water doesn't
   mirror an orange band. Ground cover casts no shadows. The stream was 1.4 studs deep, too thin for 4-stud voxels
   to show water; it is now 10 wide and 2.8 deep, sinking to the lake's level at its mouth so the two waters meet.
- Final: QA PASS, 486 parts (480 meshes), 1 light (the campfire, with shadows), 6/6 POIs reachable on foot,
  including the end of the pier deck up its stairs.

## Budget (Play mode, Client, shadows excluded)

| View | Triangles | Draw calls |
|---|---|---|
| spawn_view | 687,649 | 231 |
| lake_hero | 393,736 | 196 |
| pier_end | 596,391 | 216 |
| campfire | 328,556 | 176 |
| stream | 432,274 | 207 |
| forest_path | 555,855 | 235 |
| top_down | 779,301 | 257 |

Every view is inside the PC target (800k / 600). Phones: spawn, pier end and forest path are over 500k triangles.
Roblox's terrain grass blades (on in this place) are a large share and are thinned on low graphics settings, and
MeshParts drop detail with distance. To get under the phone line: turn terrain grass off, or cut the pine counts
in map.json (46 pines, about 3.6k triangles each).

## Rebuild notes
- One map per place: switching to it from another map means releasing the other map's terrain, clearing its
  MaterialService overrides and stashing its model (CLAUDE.md, "One map per place").
- Phase order: materials, models, terrain, lighting, trees, scatter, props, ambience. Trees, scatter and props
  raycast the terrain, so re-run them after the terrain phase.
- The terrain phase also sets the place's water colour and the grass/leaf colours (`terrainColors`); both are
  global, like lighting.
