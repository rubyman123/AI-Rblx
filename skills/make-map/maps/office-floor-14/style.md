# Style: Office Floor 14 (realistic night-horror office). Method by fwjelaa (FWJ STUDIOS).

## Nearest family and what changes
- Nearest family: `horror-house`, because it is a realistic interior at night built from CC0 scans and PBR
  materials, explored between pools of light. Office metrics (drop ceiling, troffers) come from `backrooms.md`.
- Changes: a modern corporate floor instead of a decayed house (decay is light: the building is maintained, the
  wrongness is in what is left behind); a city in a storm outside instead of a moonlit yard; first person with a
  flashlight, because almost every light on the floor is off.

## The look in one line
The 14th floor of a law/consulting firm at 2 a.m. in a thunderstorm: everyone left in a hurry, a few
fluorescents still hum, monitors glow in empty chairs, and each lightning flash throws blind-slat shadows across
the carpet.

## Scale and metrics (1 stud = 0.28 m)
- Ceiling 10 (drop ceiling, 2.8 m). Doors 4 x 7.5. Partitions 0.5, core walls 1. Cubicle panels 5.5 tall (1.54 m:
  they block the view of a 5-stud avatar, so the cubicle farm reads as a maze). Desk tops 2.68 (0.75 m).
- Floor plate 112 x 80 studs (31 x 22 m). Main aisles 4-6 wide, spawn in the elevator lobby on the south side
  facing north through the glass doors.

## Materials (ambientCG CC0, `run.py material`)
| Use | Source | Studs | Base |
|---|---|---|---|
| Office carpet tiles | Carpet004 | 3.5 | Carpet |
| Drop ceiling | OfficeCeiling001 | 13.75 | Plaster |
| Drywall / damaged drywall | PaintedPlaster017 / 015 | 8 / 9 | Plaster |
| Cubicle fabric / chair upholstery | Fabric030 / Fabric039 | 2.5 / 1.6 | Fabric |
| Lobby floor (dark marble tiles) / marble cladding | Tiles075 / Marble016 | 8.6 / 7 | Marble |
| Walnut / oak veneer | Wood060 / Wood049 | 4 / 2.86 | Wood |
| Brushed steel / painted metal / aluminium | Metal009 / 030 / 011 | 4 | Metal |
| Break-room terrazzo, stair concrete, server raised floor | Terrazzo005, Concrete031, Tiles052 | 4, 9, 12.9 | |

## Props
- Poly Haven scans (`run.py model`): metal office desk, classic laptop, stapler, notepads, clipboard, stationery,
  binder, office armchair, dining chairs (conference), plants, boxes, wall clock, fire alarm, projector screen,
  coffee cart, wet-floor sign, kettle, steel shelves, drawer cabinet, CCTV camera, credenza, books, frames, CRT,
  desk lamp, sofa, coffee table, power box, first-aid box, crates, stacking chairs, fluorescent strip, wall lamp.
- Procedural office kit made in Blender (`maps/office-floor-14/props.py`): task chair, monitor, keyboard, mouse,
  PC tower, desk phone, desk, pedestal, filing cabinets (one open), MFP printer, water cooler, vending machine,
  server racks, 2x4 troffer, ceiling diffuser, bin, extinguisher, microwave, fridge, coffee machine, mug,
  conference table, emergency light. Parts are named `<part>.<mat>`; the build maps mat keys to materials.
- Every room: one big piece that says what it was, two or three smaller ones, one thing out of place (a chair
  turned to the window, an open filing drawer, a phone off the hook, papers on the floor).

## Decay or wear
Light. A roof leak by the break room (stained ceiling tile, bucket, wet-floor sign), two missing ceiling tiles,
a damaged wall in storage, scattered papers on the route to the stairwell. Nothing burnt or broken on purpose.

## Lighting
- `night` preset, darker (Ambient 18,20,26, moon dim behind storm cloud), sky `ofc_sky` (light-polluted overcast).
- Local: ~12 lit troffers (cool 4000K, 3 flickering), warm reception and manager desk lamps, logo uplight, red
  EXIT signs, monitor glow, vending machine, server LEDs, an elevator car light. Shadows only on 6 lights.
- Lightning (client): moon brightness spikes 2-3 times, then thunder 0.3-3 s later.

## Sound
No music. Generated (`maps/office-floor-14/sounds.py`): rain on glass (3D along the facade + quiet 2D bed),
HVAC room tone (2D), fluorescent hum (3D at lit fixtures), server fans, vending compressor, TV static. One-shots
in one atlas (`ofc_sfx`): thunder x3, desk phone ring, elevator ding and doors, door slam, knocks, distant
footsteps, printer, buzz and click, flashlight click, chair creak, footsteps on carpet/stone/concrete/metal.
Reverb `Room`.

## Layout grammar
Elevator lobby (spawn, looks through glass doors at the reception desk lamp and the logo wall, windows flashing
beyond) → reception → west: cubicle maze, manager office, conference room; east: open-plan desk pods to the
windows; core (south): copy room, server room, stairwell (down to a locked 13, up to a blocked 15), break room,
storage.

## Shots
spawn_view, reception, cubicles, open_plan, manager, conference, break_room, server, stairwell, copy_room,
storage, window_ne.

## Looks fake when
Every light identical and on; carpet with no wear or stains; every desk the same (no personal items); empty
ceilings (no sprinklers, diffusers, detectors); silent rooms; windows that show nothing outside.
