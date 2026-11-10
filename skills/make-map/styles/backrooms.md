# Style guide: backrooms / liminal (Level 0 and friends)

Method by fwjelaa (FWJ STUDIOS). Sources: `research/05-realistic-references.md` §2, `research/02` §1.3.

**The look:** an endless, windowless, half-renovated office floor. Mono-yellow wallpaper with a faint repeating
motif, damp beige carpet, a 2x2 drop ceiling with rows of fluorescent troffers, too-even light, a constant
120 Hz hum. Empty of people, full of signs of *intended* use (outlets, baseboards, wear paths). Uncanny comes from
**small deviations in a convincing module**: a hallway that is too long, a room with no purpose, an outlet at head
height, a wing where the lights died.

## References (links only)
- Original Level 0 photo and history: https://en.wikipedia.org/wiki/The_Backrooms
- Roblox: Apeirophobia https://www.roblox.com/games/10277607801 ; Unseen Liminality https://www.roblox.com/games/82797688803922
- More, with notes: `research/05-realistic-references.md` §2.4.

## Metrics
Ceiling 10 studs. Partition walls 0.6 thick, doorless gaps 4-7 wide. Room grid 16 studs (1 cell = 16x16).
Troffers 2.2 x 4.4 in two rows per cell, 0.08 under the ceiling. No windows, no doors, no furniture.

## Materials (CC0, `run.py material`)
| Name | Source | Settings |
|---|---|---|
| backrooms_wallpaper | ambientCG Wallpaper00xx, tinted mono-yellow (#D8C46A range) | Fabric base, StudsPerTile 6, Regular |
| backrooms_carpet | ambientCG Carpet012, tinted damp beige (#B8A27A) | Fabric, 6, Organic |
| backrooms_ceiling | ambientCG OfficeCeiling00x | SmoothPlastic, StudsPerTile = the tile pattern's real size |
Part tints on top of the textures (`K.Materials.apply(part, name, tint)`): carpet #A8946A, ceiling #E8E4DA, wallpaper
#B8B2A6. Baseboards: plain parts #AE7A59. Panels: Neon #FFF6DF. Dead panels: SmoothPlastic #8A8580.

## Lighting
Preset `liminal` (Ambient 135,127,95, exposure 0.45). One SurfaceLight (face Bottom, Range 20, Brightness 2,
Angle 150, warm white, **Shadows off**) per cell; judge it only on `K.shot` screenshots (see `qa.md`). Narrower
angles leave hot spots on the walls;
a few flickering cells; one dark wing with dead panels. Reverb `Hallway`. Ambience: the generated 120 Hz hum
(`python kit/tools/run.py hum <name>`).

## Layout rules
Spanning-tree maze on the cell grid, then open most extra walls so rooms merge; every cell reachable. One pillar
room, one too-long hallway that dead-ends, one dark wing, one head-height outlet. No exits.

## Shots
spawn_view (eye height, looking into the maze), hallway (from its start), pillar_room, dark_wing (from outside),
anomaly (the head-height outlet). No top-down (the ceiling hides everything).

## Looks fake when
Walls are a perfect maze (all corridors 1 cell wide); every light identical and perfect; wallpaper tiling
visible as a grid; carpet too clean; rooms full of props; outdoor light or windows; total silence.
