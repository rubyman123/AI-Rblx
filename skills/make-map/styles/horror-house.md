# Style guide: abandoned horror house (realistic). Method by fwjelaa (FWJ STUDIOS).

Example: `maps/farmhouse-night`. Sources: `research/05-realistic-references.md` §1, `research/02-realism.md` §1.3.

## The look in one line
A real house, really abandoned: true-to-scale rooms, scanned furniture, peeling wallpaper and stained plaster, the
night outside pressing in through boarded windows, and a few warm pools of lamp light you walk between.

## Scale (1 stud = 0.28 m)
- Ceilings 10 studs (2.8 m). Doors 4 x 7.5. Windows 3.2 wide x 4.6 tall, sill 3 above the floor.
- Stairs: rise 0.7, going 0.9, width 4, at least 9 studs of headroom over every step.
- Rooms 12-20 studs across; halls 5-6 wide. A 5-stud avatar should feel slightly small, never cramped.
- Walls 0.8 thick (exterior), 0.5 (interior). Foundation 2 studs above the ground.

## Materials (CC0, `run.py material`, studs = real size / 0.28)
| Use | Pick | Base |
|---|---|---|
| Siding | Poly Haven `weathered_plank_siding` (5.6) | Wood |
| Roof | `roof_slates_02` (10.7) | Slate |
| Wallpaper (inside) | `decrepit_wallpaper` (8.9) | Plaster |
| Ceilings, bare walls | `worn_cracked_plaster` (6.4) | Plaster |
| Floors | `old_wood_floor` (10.7); kitchen `dirty_tiles` (8.1) | WoodPlanks / CeramicTiles |
| Foundation, chimney | `rustic_stone_wall` (5.4) | Cobblestone |
| Porch, boards, fence | `weathered_planks`, `old_planks_02` (7.1) | WoodPlanks |
| Yard (terrain overrides) | `withered_grass` → Grass, `muddy_tracks` → Mud, `dry_decay_leaves` → LeafyGrass | |

Trim (frames, baseboards, posts) uses the plank materials, never plain colours. No Neon anywhere except lamp
glass and bulbs.

## Props
Scanned CC0 models from Poly Haven through `run.py model` (Blender preps them to studs and under 20k triangles).
Pick period furniture (painted wood, worn upholstery, metal bed frames, oil lamps); avoid anything modern (plastic,
aluminium, teal or chrome). Every room gets: one big piece that says what the room was, two or three smaller ones,
and one thing out of place (an overturned chair, a mirror on the floor, a suitcase left open).

## Decay (a believable stage, not random mess)
- Water comes from the roof and the windows: stains and the worst damage sit under holes in the roof and below
  windows. One hole in the upper floor under a roof leak; a missing porch board.
- Boarded windows: two or three boards at slight angles, not every window. Some glass panes still there.
- Debris: loose planks and plaster chunks near the damage, not spread evenly. Leave walking lines clear.
- Outside: dead tree (`run.py tree`), stumps, fallen logs, a broken picket fence, a leaning mailbox, a muddy track.

## Lighting
- Preset `night` (moonlit fog, near-black rooms). Ambient is never 0: phones fall back to Soft.
- Pools of warm light (PointLight 2600-3000 K look: 255,190,130; Range 12-16; Brightness 1-2; **Shadows on** for
  the 3-4 that matter). One flickering bare bulb. A lantern on the porch so the door reads from the road.
- The route is the brightest thing in frame: porch lamp → hall → stairs. Dark corners are fine; dark doorways on
  the route are not.
- Judge lights only on `K.shot` screenshots (screen_capture's own camera shows lit rooms dark).

## Sound
`run.py wind <name>` (generated night wind, loops cleanly) as the ambience; reverb `LivingRoom`.

## Layout grammar
Road at the south edge → muddy drive → porch (spawn looks at it) → hall with the stairs → living room, kitchen →
upstairs bedrooms. Backyard behind with the dead tree. Every room has a reason to enter it and a light to walk to.

## Shots (`qa.md`)
spawn_view (the house across the yard), porch, hall_stairs, living_room, kitchen, bedroom, upstairs_hole,
backyard_tree, top_down (roof off is not possible: top-down judges the lot only).
