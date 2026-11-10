# Style guide: realistic nature (forest, lake, hills). Method by fwjelaa (FWJ STUDIOS).

Example: `maps/forest-lake`. Sources: `research/05-realistic-references.md` §3, `research/02-realism.md` §1.3.

## The look in one line
A real place you could walk into: ground that rolls, water that sits in a basin, trees in groups with clearings
between them, rocks where the ground is steep, and one low warm sun pulling everything together.

## Ground (terrain by code, `K.Terrain.heightfield`)
- One height function: gentle rolling base (fbm noise, ±3 studs) + a rim of hills (the map's natural edge) + a
  lake bowl + stream channels. Keep the walkable middle under 18° slope; paths under 10°.
- Paint materials by rule, not by hand: steep (> 36°) → Rock; lake shore band → Mud; stream bed → Sand
  (pebbles); path → Ground; under the forest mask and on the hills → LeafyGrass (forest floor); open ground →
  Grass. Every one of those base materials is overridden with a CC0 MaterialVariant (`K.Materials.override`).
- Water: terrain water (`water` level or a per-column level for streams above the lake). Dark teal (about 30,58,52),
  transparency 0.25, reflectance 0.15, small slow waves: brighter or clearer reads as a pool. Streams at least 10
  wide and 2.8 deep (thinner water vanishes in 4-stud voxels), sinking to the lake's level where they meet it.
- Shape: give the lake's ellipse a noise wobble so the shore wanders, but hold it still near the pier and any prop
  that has to meet the shore. Past the playable area add a higher ring of hills so no terrain edge is ever in view,
  and put invisible walls inside it.

## Plants (Blender, `run.py tree` / `run.py clump`, CC0 atlases)
- Trees are generated: broadleaf crowns of leaf-cluster cards (ambientCG LeafSet → `foliage.compose_cluster`),
  pines with needle cards (`foliage.compose_needles`), bark from Poly Haven bark textures. Make 2-3 seeds per
  species so no two neighbours match; scale them 0.85-1.2.
- Group trees: forest mask for the woods, single trees at the edges, pines on the hills (they sit behind every
  view, so don't leave the hills bare). Leave clearings, and keep trees 20 studs off the path and 30 from spawn
  (crowns are ~17 studs in radius) so the path frames the view to the lake.
- Tint generated grass and reed tufts green (`"t": "#9DB47A"`): the CC0 atlases read as straw under a warm sun.
  Ground cover casts no shadows.
- Ground cover in patches (grass/reed clumps, ferns), denser at forest edges and along water, none on paths.
- Rocks: Poly Haven scans (boulders, mossy rock sets) half-buried, where the ground is steep or by the stream.

## Light
- Preset `golden`, then `K.Sky.apply` (a Poly Haven "puresky" HDRI with a low sun, 10-20° up, turned into six
  512² faces by `run.py sky`) and
  `K.Sky.matchSun` so Roblox's sun sits where the panorama's sun is. Put the sun ahead of the main view (backlit
  leaves, long shadows, sun rays over the water).
- A low sun puts the valley in the hills' shadow; the preset lifts the shade so it stays readable. Judge the light
  (and the terrain) in Play: Studio's Edit view can show stale water after terrain rewrites.
- One warm local light as a focal point at dusk (a campfire on the shore).

## Sound
`run.py wind` (gentle) + `run.py water` (lapping) ambience; reverb `Forest`.

## Layout grammar
Spawn on a path at the low south edge → path winds through the woods → opens onto the lake shore (pier,
campfire) → a stream comes down from the hills on one side → rock face across the water as the far landmark.

## Shots
spawn_view (looking down the path toward the lake), lake_hero (high three-quarter over the water), pier_end,
campfire, stream, forest_path, top_down.
