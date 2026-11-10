# Office Floor 14: build notes (method by fwjelaa, FWJ STUDIOS)

Asked for (2026-10-25): an ultra-realistic horror map of a nice office, lots of props, realistic lighting and
sound effects, no music, creepy. Built with MapKit in the open Studio place (Untitled Experience).

## What's in it
- The 14th floor of a law firm ("Halloway & Kane") at 2 a.m. in a thunderstorm, 112 x 80 studs (31 x 22 m).
  Elevator lobby (spawn) → glass entry → reception with a walnut logo wall → cubicle maze (west, 16 cubicles),
  open-plan desk pods (east, 32 desks), manager's office and glass conference room on the north windows,
  core: print room, server room (12 racks), stair B (down to a locked 13, up to a blocked 15), break room,
  storage. A rain-swept city 14 floors down outside three curtain walls with venetian blinds.
- Assets: 20 ambientCG CC0 materials, 41 Poly Haven CC0 scans, 25 office props modelled for this map in Blender
  (`blender/office_props.py` via `props.py`: task chair, monitor, keyboard, mouse, PC, desk phone, desk, pedestal,
  filing cabinets, MFP printer, water cooler, vending machine, server racks, troffer, diffuser, bin, extinguisher,
  microwave, fridge, coffee machine, mug, conference table, emergency light), generated sky, facades, rain-on-glass,
  stains and TV static (`images.py`), and generated sound (`sounds.py`): 5 loops + one 26-sound SFX atlas played
  with `Sound.PlaybackRegion` (one audio upload instead of 26: Roblox's audio quota).
- Scripts (`scripts/`): server (doors with E prompts, door 13 that knocks back, the stair door slam), player
  (first person, walk 9 / Shift 15, flashlight on F or the Light button with a dying battery, footsteps chosen by
  the floor's MaterialVariant: carpet / stone / concrete / metal), director (lightning: moon + window lights spike
  then thunder after 0.3-3.5 s; flickering tubes; a desk phone that rings until you get close; an empty elevator
  that dings open when you come back to the lobby; the printer starting by itself and printing "STAIR B"; lights in
  the cubicles going out behind you; the manager's chair turning to the door; footsteps in the ceiling; a figure
  only visible during a flash; someone standing in the lit window across the street who is sometimes gone).

## QA rounds
1. **Shell in daylight.** Read fine. Carpet tile scale, lobby marble and raised floor rescaled to real 60 cm tiles.
2. **Night.** Near-black and the skyline invisible: Atmosphere density 0.34 swallowed the city (now 0.12), Ambient
   raised to 30,32,40 and exposure +0.6. Roblox `Glass` reads as milky grey from inside at night (and drew a hard
   vertical split through the open glass door): every big pane is now SmoothPlastic at 0.9 transparency.
3. **Grey props.** Blender suffixes repeated object names (`base.plastic_black.001`), so `dress` missed their
   material key; it now strips the suffix. Lit troffers hid their tubes behind the parabolic louvres: the reflector
   cavity glows when the fixture is on. The CRT scan's screen faces -Z (checked in Blender); the photo-frame scan's
   picture faces +X; the desk lamp's shade hangs over its +Z side.
4. **Walk test.** Unreachable at first: the reception desk left 3.4 studs to the glass, cubicle aisles were 4,
   ajar doors blocked their own openings, a box sat in front of the stair door, the conference door's leaf walled
   off the room, stair mid-landings were 3.9 deep, and the slabs above and below the floor ran straight through the
   stair shaft. Fixed: desk moved 3 north, cubicles 7 studs (2 m) with 6-stud aisles, doors 4.6 wide and opened
   70-100°, landings 5.35 deep, shaft holes in both slabs. Final: **QA PASS**, 0 errors, 13/13 POIs, 0 jumps.
   - `stair_15` (the dead-end landing up to 15) is play-verified instead: Edit-mode PathfindingService returns
     NoPath on that one flight from both ends with nothing in its volume (tested: no tape, no bands, no slab, short
     agent); a character walks it in Play with `Humanoid:MoveTo`. It is listed under `playVerified` in map.json.
   - Deliberate WARN (716): monitors, keyboards and phones keep their small shadows (tiny clutter does not).
5. **Play.** No script errors; all 24 map sounds and the SFX atlas load; first person, flashlight, footsteps,
   lightning (blind shadows across the floor) checked on screenshots.

## Budget (Play, Client, shadows excluded)
| View | Triangles | Draw calls |
|---|---|---|
| spawn_view | 331,465 | 181 |
| reception | 159,683 | 151 |
| cubicles | 81,567 | 80 |
| open_plan | 381,276 | 155 |
| manager | 83,439 | 128 |
| conference | 550,858 | 175 |
| break_room | 56,863 | 73 |
| server | 75,722 | 42 |
| stairwell | 8,230 | 29 |
| copy_room | 106,298 | 92 |
| storage | 140,771 | 48 |
| window_ne | 24,395 | 45 |
| corridor_west | 122,725 | 97 |

Every view is inside the PC target (800k / 600); all but the conference view (551k triangles, it looks across
the whole open plan) are inside the phone target (500k / 500). 7,332 parts (3,671 meshes), 51 lights (11 shadowed).

## Gotchas found here
- This session served the pack on port 8778 (another session already held 8777); the installer and `Http.BASE`
  were pointed there at install time. A normal session uses `run.py serve` on 8777.
- Parallel `run.py model` jobs hit Open Cloud's key-introspection rate limit (HTTP 429): cache `run.introspect`.
- `decorative_book_set_01` has no glTF on Poly Haven.
- The Roblox importer turns Blender +Y into Roblox +Z: props modelled facing +Y are turned 180° before export.
