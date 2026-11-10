# Style guide template: a map that fits no family. Method by fwjelaa (FWJ STUDIOS).

Copy this file to `maps/<id>/style.md` and fill every section before writing `map.json`. Start from the nearest
family's guide (`simulator.md`, `backrooms.md`, `horror-house.md`, `nature.md`) and write down only what you
change; leave the rest pointing at that guide. The plan you show the user names the nearest family.

## Nearest family and what changes
- Nearest family: `<simulator | backrooms | horror-house | nature>`, because `<one line>`.
- Changes: `<palette / materials / lighting / layout / scale / sound>`, each with one line of why.

## The look in one line
`<what a player should feel in the first five seconds, in plain words>`

## References (links only, CC0 images only)
- `<2-6 links: real places, photos, games with this look; say what to take from each>`

## Scale and metrics (1 stud = 0.28 m for realistic maps)
- Doors `<4x7 realistic | 8x12 stylized>`, ceilings `<10-14>`, main paths `<12-16 wide>`, gaps on the critical
  path 6 studs or less.
- Map size `<~300x300 showcase>`; spawn on the south side facing north.

## Materials (`run.py material`, studs = real size / 0.28)
| Use | CC0 source | Studs per tile | Base material | Tint |
|---|---|---|---|---|
| `<floor>` | `<polyhaven:id or ambientcg:ID>` | `<n>` | `<Wood>` | `<none or #hex>` |

## Props and plants
- Scans: `run.py model <name> --from polyhaven:<id>` (`<list>`). Generated: `run.py tree / clump` (`<list>`).
- Kit parts: `<K.Geo / K.Props pieces used>`.
- Density: `<how many per 100x100 studs, where clustered, where empty>`.

## Decay or wear
`<none | light | heavy>`: `<what is broken, dirty or missing, and the story that explains it>`

## Lighting
- Preset: `<simulator | liminal | night | golden>` plus changes: `<ClockTime, OutdoorAmbient, Atmosphere>`.
- Local lights: `<how many, where, which cast shadows>`. Sky: `<default | run.py sky ...>`.

## Sound
`<run.py hum / wind / water, or record-sound with a CC0 recording>`; reverb `<kind>`.

## Layout grammar
`<spawn → first view → route → landmark → secondary areas; what you see from spawn>`

## Shots (`qa.md`)
`spawn_view`, `<one eye-level shot per zone>`, `<the landmark from below>`, `top_down`.

## Looks fake when
- `<3-6 tells specific to this look, e.g. everything the same height, one texture everywhere, no wear where hands
  and feet go, lights with no source>`
