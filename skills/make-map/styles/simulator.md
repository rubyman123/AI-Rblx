# Style guide: blocky simulator ("lift a ___", simulator hubs)

Method by fwjelaa (FWJ STUDIOS). Sources: `research/04-stylized-and-level-design.md`.

**The look:** classic Roblox, revived (2025-26): saturated BrickColor grounds with studs, SmoothPlastic chunky
props, bright cyan sky with puffy clouds, a flat bright Soft light, Neon only where you interact. Readable at a
glance on a phone. Real games sit close to stock BrickColors (Steal a Brainrot grass #46954F vs Bright green #4B974B).

## References (links only)
- Lift a Cube: https://rowatcher.com/games/10759860151/lift-a-cube
- Lift a Building: https://rowatcher.com/games/10765966073/lift-a-building
- More, with notes: `research/04-stylized-and-level-design.md` section 6.

## Layout grammars (pick one, write it in the plan)
| Grammar | Use for | Shape |
|---|---|---|
| Linear route | "lift a ___", obby-likes | spawn on one edge, a straight route through 4-6 biome bands, the biggest object at the far end as the landmark |
| Hub and spoke | pet/collect sims | central spawn hub, gated areas around it, each gate a landmark |
| Symmetric plots | farming/tycoon | 4 plots in the corners, shops on two sides, event hub in the middle |
| Two-row lane | base/steal games | 2 rows of bases facing a central walkway |
| Vertical ascent | climb sims | terraces going up, gates by progress |

## Zone palettes (official BrickColors)
| Zone | Ground | Path | Rock/structure | Foliage | Accent | Neon |
|---|---|---|---|---|---|---|
| Meadow / spawn | #5B9A4C | #F0D5A0 | #A9A8AB | #348E40, trunks #694028 | #0D69AC | #00FFFF |
| Desert | #D7C59A | #958A73 | #CC8E69 | cactus #5B9A4C | #DA8541 | #FFB000 |
| Snow | #F8F8F8 | #80BBDB | #635F62 | pines #27462D | #0989CF | #04AFEC |
| Volcano | #4A4749 | #562424 | #750000 | dead wood #562424 | #FFB000 | #D5733D |
| Candy | #FF98DC | #F8F8F8 | #B1A7FF | #B1E5A6 | #FF00BF | #FF66CC |
| Space | #002060 | #A3A2A5 | #635F62 | crystals #B480FF | #12EED4 | #00FFFF |

## Materials
SmoothPlastic for props. Ground top layers get `TopSurface = Studs` (whole-stud sizes and positions so studs line
up). No Glass, almost no transparency. Neon only on pads, rims, crystals and lava.

## Lighting
Preset `simulator` (`K.Lighting.preset("simulator")`): LightingStyle Soft, Brightness 2.5, ClockTime 13.5, raised
Ambient/OutdoorAmbient, thin Atmosphere, Bloom threshold 1.9, saturation +0.2, light clouds. Terrain water:
WaterColor #0D69AC, transparency 0.3, reflectance 0.15 (the brighter #04AFEC read as a neon pool on screen).

## Metrics
Spawn plaza 40-60 studs square. Main path 14 wide. Gates 12 tall (18 wide) with the zone name on the beam. **No
gate or beam in the first ~60 studs in front of spawn**: measured, it hides the landmark at the far end. POI every
80-130 studs of travel. Zone steps 3 studs high with a 12-stud ramp on the path. Jump gaps ≤ 6. The landmark sits
high (a 16-stud plateau) and in a colour nothing else uses (the example's gold boulder).

## Kit
`K.Props.tree, pine, rock, bush, flower, cactus, deadTree, boulder, cloud, crate, pad, arrow, sign, gate, stall,
fence`. Liftable objects sit on pads and grow in size zone by zone. The landmark is the biggest of them.

## Density
Trees in clusters of 3-5 (cluster spacing about 40), bushes about 18 apart, flowers in clumps, 1 rock per about
45 studs, a few wide flat hills, dunes or drifts per zone (`boulder` with radius 12-15, squash 0.22-0.3) so no band
is a flat board. Keep a 6-stud clear margin either side of the path and give every scatter entry a `clearance`
(the prop's footprint radius) so big props keep their edges off it. A sand beach ring makes the island read as
an island. Total under 10k parts.

## Shots
spawn_view, hero, one eye-level per zone, top_down, landmark from below.

## Looks fake when
Every tree the same size; props in a grid; the path the same brightness as the ground; Neon on scenery; no
landmark visible from spawn; empty flat bands with nothing every 100 studs; grey default parts.
