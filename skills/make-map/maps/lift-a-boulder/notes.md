# Lift a Boulder: build notes (method by fwjelaa, FWJ STUDIOS)

## QA round 1 (2026-10-24)

`K.qa`: QA PASS, 3690 parts, 8/8 POIs reachable, no warnings.

| Shot | Problem | Fix |
|---|---|---|
| spawn_view | The giant boulder (the landmark) can't be seen from spawn; the gate chain hides it | Boulder radius 15 → 20, more facets (subdivided icosahedron), plateau 6 → 10 high, gates 18 → 16 tall |
| spawn_view, desert_eye | `rock` reads as flat grey/brown bricks | Rework `Props.rock` into a faceted low-poly rock (jittered octahedron + chip) |
| hero | The island is a flat square board; big empty flat areas | Low hills/drifts/dunes per zone (wide, flat boulders in the ground colour) |
| hero | Water is neon cyan (pool look) | Water #0D69AC, transparency 0.3, reflectance 0.15 |
| meadow/desert/snow_eye | The camera sits beside a gate pillar | Move those cameras off the gates |
| snow_eye | Cyan arrow on light-blue path barely reads | Per-zone arrow colour (`arrow` in map.json) |
| volcano_eye | The plateau is a plain black box; the boulder looks like a d20 die | Basalt sides with a lip and a gold lift ring under the boulder; detailed boulder |
| boulder_low | The sign blocks the boulder | Move the sign to the left front corner, POI off the boulder's footprint |

## QA rounds 2-4

- **The landmark from spawn took three tries.** The detailed boulder (radius 20) on a 10-stud plateau was still
  hidden. Gates 14 tall plus a 16-stud plateau were still hidden, because the MEADOW gate 30 studs in front of
  spawn covered everything up to about 60 studs high at the far end. What worked: **no gate on the spawn plaza**
  (zone `"gate": false`), gates 12 tall, a 16-stud plateau, and the boulder turned **gold** so the visible part
  reads as the prize. Lesson for every linear-route map: keep the first 60 studs in front of spawn free of
  beams, and check the sightline from the spawn camera to the landmark against every gate beam.
- Rocks: tilted blocks, then octahedra, both read as boxes or pyramids. Small icosahedron lumps with a dark chip
  read as rocks (now `Props.rock`).
- Hero: a 10-stud sand beach ring plus a 2000-stud sea made the board read as an island.
- Volcano: dark boulders at the cliff base plus basalt columns along the cliff face replaced the plain box.
- Camera spots next to gate pillars and lift pads crowd shots; put eye-level cameras on the path just past a gate.
- Final: QA PASS, 5816 parts, 8/8 POIs reachable, no warnings.

## Budget (Play mode, Client, shadows excluded)

The first measurement found the opaque parts cost only 11 draw calls (instancing works), while the 2000-stud
terrain sea cost 344-364 draw calls and about 230k triangles per view. Terrain water now covers only 700 studs
around the island, and one flat part carries the sea to the horizon. Result:

| View | Triangles | Draw calls |
|---|---|---|
| spawn_view | 361,943 | 212 |
| hero | 567,249 | 229 |
| meadow_eye | 354,533 | 192 |
| desert_eye | 194,051 | 182 |
| snow_eye | 123,746 | 153 |
| volcano_eye | 103,400 | 136 |
| top_down | 463,530 | 363 |
| boulder_low | 101,220 | 137 |

Every view is inside the PC target (800k / 600). Every player-height view is inside the phone target (500k / 500).
Only the hero overview (a thumbnail camera, not a player view) is over phone triangles.

## After the final review (2026-10-24)

- The base phase now claims its 700-stud terrain box with `K.Root.claimTerrain` (the old code cleared a
  2000-stud slab of whatever place it ran in). Re-runs clear only the recorded box.
- Scatter entries have a `clearance` so wide hills and dunes keep their edges off the path, and the water check
  reads the real water surface (23 beach rocks kept).
- Now: QA PASS, 5364 parts, 8/8 POIs. The budget was not re-measured after these changes; the part count went down
  and the terrain box is the same, so the numbers above are an upper bound.
