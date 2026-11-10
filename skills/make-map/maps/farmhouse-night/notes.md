# Abandoned Farmhouse at Night: build notes (method by fwjelaa, FWJ STUDIOS)

The creator asked for this map **super realistic** (2026-10-24). Everything you see is a scanned CC0 Poly Haven model, a
CC0 Poly Haven texture, or built by the kit (walls, roof, trim, debris) and Blender (the dead tree).

## What's in it
- A two-storey farmhouse, 44 x 32 studs (12.3 x 9 m at 1 stud = 0.28 m). Ground floor: hall with stairs, living
  room, storage, parlour, kitchen. Upstairs: bedroom, bedroom 2, storage, landing.
- Porch with posts, railings (one broken run), a missing board and loose boards, a lantern on a chain.
- The decay story: a hole in the roof over bedroom 2 (rotten rafters showing), the ceiling and floor gone below it,
  moonlight falling through to debris on the parlour floor.
- 35 different Poly Haven models placed 55 times plus 42 scattered shrubs and branches (furniture, lamps, crates,
  logs, stump, a masonry stove), one generated dead tree,
  13 Poly Haven materials, generated night wind.
- Yard: muddy road, a rutted drive, picket fence with a fallen run, a leaning mailbox, a dead tree, stump, logs,
  brush, leaf patches.

## QA rounds
1. **Daylight geometry check.** Every MaterialVariant looked white on the first capture: the textures were still
   streaming in after the display woke. A second capture showed them. The roof slate read too pale and the drive
   (a straight mud strip) too artificial.
2. **Walk test.** Storage and bedroom 2 unreachable: the sofa stood in front of the storage door and the bed
   narrowed bedroom 2's door to 1.9 studs. The validator flagged 215 scanned meshes as "default grey Plastic":
   their colour comes from the SurfaceAppearance, so `QA.validate` now skips textured meshes. A freestanding sofa
   then made the pathfinder fail the whole route (every leg passed on its own); against the front wall under the
   window, where a farmhouse would have it, everything passed. Realistic 4-stud doors need `"agent": {"radius":
   1.25}` in map.json (`K.qa` reads it).
3. **Night.** The research's night values were near-black. Tuned on parked-camera shots: moon Brightness 3,
   OutdoorAmbient 110,120,150, exposure +0.5, lighter blue fog. Latitude -40 at 22:30 puts a full moon behind the
   house as seen from spawn (the kit's `night` preset now does this).
4. **Composition.** Spawn moved out onto the road so the fence and mailbox frame the house. Lantern, lamp, bulb and
   candle props cast no shadows (they were shadowing their own lights). Terrain under the house and porch is mud
   (Roblox's grass blades grew through the porch deck). The floor hole got ragged board ends; sagging ceiling flaps
   and hanging laths (with shadows on: `Build.decor` turns small parts' shadows off) break the moonbeam into an
   irregular pool. Glass more transparent so the moonlit yard shows through. Stove and tree tinted
   (`SurfaceAppearance.Color`).
- Final: QA PASS, 941 parts (216 meshes), 6 lights (all with shadows), 9/9 POIs. The stairs show one "jump"
  waypoint to the pathfinder; a real character walks up them in Play without jumping (checked).
- Deliberate WARN (73): hanging laths, ceiling flaps and small prop parts cast shadows because their shadows are
  the point (they shape the moonbeam and the lamp light).

## Budget (Play mode, Client, shadows excluded)

| View | Triangles | Draw calls | of which grass blades |
|---|---|---|---|
| spawn_view | 700,344 | 176 | 312k |
| porch | 497,784 | 133 | 258k |
| hall_stairs | 442,194 | 121 | 271k |
| living_room | 365,670 | 143 | 251k |
| kitchen | 384,235 | 105 | 264k |
| bedroom | 316,787 | 104 | 226k |
| upstairs_hole | 238,627 | 74 | 181k |
| backyard_tree | 376,508 | 111 | 265k |
| top_down | 580,996 | 149 | 252k |

Every view is inside the PC target (800k / 600). Phones: the spawn view is over 500k triangles, almost half of it
terrain grass blades (`Terrain.Decoration`, on in this place; Roblox thins it on low graphics settings). Turning
grass off (Terrain properties) brings every view under the phone target, at the cost of the overgrown look.

## Sound and scripts (Play)
Wind: loaded, playing, looped, 12.00 s, volume 0.5, reverb Plain. Kitchen bulb flicker: 12 toggles in 6 s.

## Switching maps in this place
One map per place. To show another one here (all reversible, nothing deleted):
1. Hand the farmhouse's ground back: `K.Root.releaseTerrain("farmhouse-night")`, then move `Map_farmhouse-night` to
   `ServerStorage.MapKit_Stash`.
2. Clear its global overrides: `MaterialService:SetBaseMaterialOverride(m, "")` for Grass, Mud and LeafyGrass.
3. Move the other map back from the stash and re-run the phases that own global state: Lift a Boulder's `base`
   (rebuilds its terrain sea) and `lighting`; the backrooms' `ambience`.
