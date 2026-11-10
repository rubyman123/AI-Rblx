# 05 – Realistic map references: horror house, liminal/backrooms, temperate nature

Research for **Roblox Maps by fwjelaa** (`/make-map`). Collected 2026-10-24. Research only: nothing was built or downloaded. Every claim has a source URL; anything that is my own inference or design recommendation is marked **[rec]**.

**Units.** Roblox defines **1 stud = 28 cm** (official units table, which also says you may pick your own interpretation but must stay consistent) – https://create.roblox.com/docs/physics/units.md . So **m × 3.571 = studs**, **1 ft = 1.09 studs**, **1 in = 0.091 studs**. A 300 × 300 stud map is **84 × 84 m**.
Classic avatars are about 5 studs tall (≈1.4 m), so they are smaller than a real adult (1.75 m ≈ 6.25 studs) **[rec: approximate; measure the rig in Studio]**. Result: **real-world sizes converted at 0.28 m already feel about 20 % roomier for the avatar.** That matches how game engines oversize doors and halls (see §4.1), so build at real metric scale. Roblox's own horror-house team "always built with an avatar both in our 3D application and inside Studio so we could know how big a door or how tall the steps should be". They wanted the interior "spacious, but not absurdly large" – https://create.roblox.com/docs/resources/the-mystery-of-duvall-drive/construct-the-house.md

---

## 0. TL;DR build rules (what makes each map convincing)

| Map | The five things that sell it |
|---|---|
| Horror house | (1) real domestic proportions (2.4–3.0 m ceilings, 0.9 × 2.0 m doors, 196/254 mm stairs); (2) a believable decay stage: water from roof and windows leads to peeling paper, stains, mould, holes in the floor under holes in the roof; (3) story props that "would exist even if the player weren't there"; (4) "Hollywood darkness": feels dark, stays readable, with pools of light, rim-lit silhouettes and some pure-black shadow; (5) sound that always pulls toward the next room. |
| Liminal / backrooms | (1) one module repeated with tiny deviations; (2) no people, no windows, no exits, no furniture; (3) flat, even, slightly green-yellow fluorescent light from a 2×2/2×4 ft grid with a few dead or flickering tubes; (4) mono-yellow patterned wallpaper and damp beige carpet; (5) a constant 100/120 Hz hum. |
| Temperate nature | (1) clustered, not even, scatter, with barren patches; (2) more trunks than canopies, plus dead wood (snags, logs, stumps); (3) layered vertical structure (canopy, sub-canopy, shrub, fern/ground cover, litter, rocks); (4) graded edges (herb fringe, shrub belt, forest mantle; shore stones and reeds; stunted trees near the treeline); (5) atmospheric depth: haze makes distance paler, bluer and lower in contrast, with light shafts through gaps. |

---

## 1. Horror house

### 1.1 What the best-looking Roblox horror games do (2024–2026)

Live stats are from the Roblox games API on 2026-10-24 (`games.roblox.com/v1/games`). The links are game pages only; screenshots are copyrighted.

| Game (link) | Stats (2026-10-24) | What the environment does | Source |
|---|---|---|---|
| **DOORS** – https://www.roblox.com/games/6516141723 | LSPLASH, 7.94 B visits, ~125 k playing | The light state is a gameplay signal. In **Dark Rooms** the lights are out and "the buzzing sound of lamps can be heard". Before **Rush** arrives the lights **flicker**; Rush then "rushes through several rooms… breaking all the lights", turning them into dark rooms. The Guiding Light illuminates the door in dark rooms. Floor 2 (The Mines) swaps the hotel for mine tunnels where you need a flashlight. The description says "Headphones & max graphics recommended". | https://doors-game.fandom.com/wiki/The_Hotel , https://www.pockettactics.com/roblox/doors-floor-2-release , API description |
| **Pressure** – https://www.roblox.com/games/12411473842 | Urbanshade: Hadal Division, 493 M visits | Set in a decaying underwater facility (the Hadal Blacksite), with flooded zones such as "The Dredge". An **Emergency Lights** mechanic lets players who have been "in a dark environment for too long" see in the dark, so darkness gets an accessibility fallback. The description says "Headphones & graphics level 8 or above recommended". | https://pressure.fandom.com/wiki/Hadal_Blacksite , https://pressure.fandom.com/wiki/Emergency_Lights |
| **The Mimic** – https://www.roblox.com/games/6243699076 | CTStudio, 1.26 B visits | Japanese history and urban-legend chapters ("books"), with flashing lights, loud noises and jumpscares. | API description |
| **Apeirophobia** – https://www.roblox.com/games/10277607801 | Polaroid Studios, 438 M visits | A Backrooms maze (see §2) with "constantly buzzing fluorescent light sources" and arrows scratched on walls that are fake on hard difficulty. "Turn on max graphics." | https://apeirophobia.fandom.com/wiki/Level_0 |
| **99 Nights in the Forest** – https://www.roblox.com/games/79546208627805 | 2025 release, 30.2 B visits, ~1.86 M playing | A forest survival-horror game ("Something is watching you"). The campfire camp is the safe zone. The **Deep Forest** spawns at the map edge with darker grass, more traps and stronger animals, so danger rises toward the edge. | API description, https://99-nights-in-the-forest.fandom.com/wiki/Biomes |
| **Demonology** – https://www.roblox.com/games/18199615050 · **SPECTER** – https://www.roblox.com/games/8267733039 · **Blair** – https://www.roblox.com/games/6137321701 | 887 M / 240 M / 364 M visits | Ghost hunting in haunted houses and job sites. These are the **closest analogues to an explorable realistic house**: you explore room by room with a flashlight and hide in spots. Demonology says "play with max graphic settings". | API descriptions |
| **The Intruder** – https://www.roblox.com/games/8073154099 | 464 M visits | Home-invasion horror: you are alone in a house, watch cameras and hide in a closet. | API description |
| **Home Alone: Anomalies** – https://www.roblox.com/games/87468080405188 | May 2026 release, 219 M visits | The porch light is a mechanic: "Turn off the porch light if something is off". | API description |
| **THRESHOLD** – https://www.roblox.com/games/78453398695059 | Aug 2026 release, 30 M visits, 97 % liked | A 2026 hit: a story horror game where the monster "can hear YOU" (voice chat). | API description |
| **Dead Silence** – https://www.roblox.com/games/44853933 | 114 M visits | A classic co-op investigation (1–4 players) of the Mary Shaw legend. | API description |
| **The Mystery of Duvall Drive** (Roblox's official horror-house demo) | – | The best documented realistic Roblox house; lessons in §1.6. | https://create.roblox.com/docs/resources/the-mystery-of-duvall-drive.md |

**Patterns across these games (what to copy):**
- **Light is information.** Flickering means a threat is coming, a lit door means the exit, and a dark room is dangerous. The porch light and campfire mark safety. Build 1–2 "light rules" into the map, even for a showcase **[rec]**.
- **Hollywood darkness, not real darkness.** The convention is to "make it feel dark, but don't actually make it dark". Use dim, bluish, shadowless fill lights; let SOME shadows go to 0 % black; use rim light on silhouettes. Don't darken the albedo textures ("let the lights create the sense of darkness"). Avoid plain blue-and-orange grading by adding a third colour such as purple or yellow. Games built around flashlights "may want to selectively let high tension scenes go to pitch black darkness" – https://book.leveldesignbook.com/process/lighting/darkness
- **Fog began as a technical cover.** Silent Hill "used distance fog and darkness to obscure the graphics and omit pop-ins, which, in turn, helped establish the game's atmosphere" – https://en.wikipedia.org/wiki/Silent_Hill_(video_game) . On Roblox the same trick hides the map edge on a small 84 m map **[rec]**.
- **They all assume high graphics settings** ("max graphics", "level 8+", "+6 graphics" in Grace's description). For phone play the map must still read when shadows and post effects drop out: carry the mood with geometry, value contrast and emissive light parts, not only with Future/Realistic shadows **[rec]**. Post-processing visibility depends on quality level – https://create.roblox.com/docs/environment/post-processing-effects.md
- **Sound carries half the fear.** Duvall Drive used a "grass is always greener" approach: "always… a more intriguing sound in the distance no matter where the player is located in the house" (a radio in a bedroom, a dripping sink, rain on the attic roof). It mixed realistic and abstract audio and used volumetric emitters, for example rain over a whole car or window instead of one point – https://create.roblox.com/docs/resources/the-mystery-of-duvall-drive/design-dark-soundscapes.md . DOORS uses lamp buzz as a dark-room tell (above).
- **Lighting divides space.** Light tells the player about the world, the massing and the circulation: "the far wall is dark… probably not a primary exit, which would be lit more prominently" – https://book.leveldesignbook.com/process/lighting

### 1.2 House architecture: real sizes (m and studs)

| Element | Real value | Studs | Source |
|---|---|---|---|
| US standard wall/ceiling height | 96 in = 2.44 m | 8.7 | https://book.leveldesignbook.com/process/blockout/metrics |
| 19th–early-20th c. ceilings (US middle-class and grand homes) | 10–12 ft = 3.05–3.66 m | 10.9–13.1 | https://planetizen.com/node/38894 ; https://engineerfix.com/why-do-old-houses-have-high-ceilings/ |
| Why old ceilings are tall | status, hot air rising above occupants (with transom windows over doors), balloon framing; the 8 ft stud became standard in the early 20th c. | – | https://engineerfix.com/why-do-old-houses-have-high-ceilings/ ; https://www.theexaminernews.com/a-houses-ceiling-height-has-evolved-over-the-years |
| German Gründerzeit Altbau (1850–1900) | 3.20–3.80 m (Berlin often 3.60, south Germany 3.20) | 11.4–13.6 | https://www.jacasa.de/ratgeber/lexikon/deckenhoehe |
| Modern new build (DE) | 2.30–2.50 m | 8.2–8.9 | same |
| US exterior door | 36 × 80 in = 0.91 × 2.03 m | 3.3 × 7.3 | https://book.leveldesignbook.com/process/blockout/metrics |
| German door (DIN 18101), wall opening | 885 × 2010 mm (leaf 860 × 1985); tall variant 2130 mm | 3.2 × 7.2 (7.6) | https://www.baunetzwissen.de/fenster-und-tueren/fachwissen/konstruktion-funktion/wandoeffnungen-und-tuergroessen-nach-din-18101-155227 |
| Minimum hallway (US real) | 48 in = 1.22 m | 4.4 | LDB metrics (above) |
| Stair riser max (IRC R311.7.5.1) | 7¾ in = 196 mm | 0.70 | https://www.tfid.org/DocumentCenter/View/6771/2018-RESIDENTIAL-STAIR-GUIDE |
| Stair tread min (IRC R311.7.5.2) | 10 in = 254 mm | 0.91 | same |
| Stair headroom min (IRC R311.7.2) | 6 ft 8 in = 2.036 m | 7.3 | same |
| Handrail height (IRC R311.7.8.1) | 34–38 in = 0.86–0.97 m | 3.1–3.4 | same |
| Stair width (IRC R311.7.1) | 36 in = 0.91 m | 3.3 | same guide **[verify section in PDF]** |
| Stair feel | "7-11" rule, ~32° slope, landing every 12–16 steps; long or tall stairs feel non-domestic | – | LDB metrics |
| Double-hung window | 24–48 in wide × 36–72 in tall = 0.61–1.22 × 0.91–1.83 m | 2.2–4.4 × 3.3–6.5 | https://hansons.com/blog/standard-window-sizes |
| Bedroom window sill (egress) | max 44 in = 1.12 m above floor; ≥ 5.7 ft² clear opening | 4.0 | https://www.cityofdubuque.org/DocumentCenter/View/327/Emergency-Escape-and-Rescue-Openings |
| Front porch depth | min 6 ft (1.83 m); ideal 8 ft (2.44 m); over ~12 ft (3.66 m) feels too big | 6.5 / 8.7 / 13.1 | https://www.hunker.com/13402405/typical-size-for-a-front-porch ; https://www.houzz.in/magazine/the-right-dimensions-for-your-porch-stsetivw-vs~25889920 |
| Porch guard | required once the floor is ≥ 30 in (0.76 m) above grade; 36 in (0.91 m), 42 in (1.07 m) in many places | 2.7 / 3.3 / 3.8 | https://www.jlconline.com/projects/design-front-porches-that-work_o/ |
| Mailbox (USPS) | bottom of box 41–45 in (1.04–1.14 m) above the road; door 6–8 in (0.15–0.20 m) behind the curb face | 3.7–4.1; 0.5–0.7 | https://about.usps.com/postal-bulletin/2026/pb22702/html/cover.htm |
| Bedroom | 10 × 12 ft (3.05 × 3.66 m); master 14 × 16 ft (4.27 × 4.88 m) | 10.9 × 13.1; 15.2 × 17.4 | https://blog.designfiles.co/average-room-size/ |
| Living room | 12 × 18 ft to 15 × 20 ft (3.66 × 5.49 to 4.57 × 6.10 m) | 13.1 × 19.6 to 16.3 × 21.8 | same |
| Kitchen | 10 × 12 to 12 × 14 ft (3.05 × 3.66 to 3.66 × 4.27 m) | 10.9 × 13.1 to 13.1 × 15.2 | same |
| Dining room | 10 × 12 to 12 × 16 ft (3.05 × 3.66 to 3.66 × 4.88 m) | 10.9 × 13.1 to 13.1 × 17.4 | same |

**Recommended house type: the American Foursquare (c. 1895–1930s).** It is "basically square, boxy… two-and-one-half stories high, usually with four large, boxy rooms to a floor (with the exception of the attic floor, which typically has only one or two rooms), a center dormer, and a large front porch with wide stairs". It also has a hipped roof, arched openings between the common rooms, built-in cabinetry, and living room plus dining room on one side with the entry/stair hall plus kitchen on the other – https://en.wikipedia.org/wiki/American_Foursquare . A boxy plan is easy to build from parts and holds both the interior and exterior inside a 300-stud map.
**[rec] Blockout:** footprint ≈ 9 × 9 m (32 × 32 studs) plus a 2.4 m (8.7 stud) full-width porch. Ground-floor ceiling 3.0 m (10.7 studs), upper floor 2.7 m (9.6 studs), attic under the hip roof, plus a basement. Duvall Drive added "an attic and a basement for both gameplay and thematic reasons" and put the hardest content far from the front door (Duvall construct page above).
**[rec] Third-person camera:** keep the main hallways ≥ 1.5 m (5.4 studs) and doorways ≥ 0.9 m (3.3 studs). Real 1.2 m halls clamp the Roblox camera. Engines use wider metrics for this reason: Unreal 1.5 m halls and 1.1 × 2.2 m doors, Unity 2.0 m halls and 1.25 × 2.5 m doors (LDB metrics).

### 1.3 Materials and decay: what actually happens to an abandoned house

Decay timeline (Science Insights, 8 Mar 2026 – https://scienceinsights.org/what-happens-to-abandoned-buildings-decay-to-collapse/ ):
- **The roof fails first.** Shingles last 20–30 years; after that "water begins pouring into the building's interior". Window caulking also fails (HowStuffWorks: about 25 years – https://home.howstuffworks.com/home-improvement/repair/house-entropy.htm ).
- **Water does the rest.** "Paint blisters and peels. Wallpaper separates from drywall. The drywall… softens, and eventually crumbles. Wooden framing… begins to rot. Mold colonies spread through damp cavities." Floors get "holes… beneath the largest holes in the roof". Insects (termites, carpenter ants) move into the wet wood.
- **Stages:** 0–5 years: cosmetic (peeling paint, broken windows, overgrown landscaping, minor leaks). 5–15 years: structural water damage and mould, and scavengers strip copper pipes and wiring, "leaving open holes in walls and floors". 15–30 years: roof sections collapse and floors become unstable. 30+ years: wood-framed houses are ruins.
- **[rec] Pick stage ~10–15 years.** That gives every visual cue (stains, mould, missing ceiling patches, ripped-out wiring holes, one sagging floor) while staying walkable. Make the decay **directional**: worst under the roof leak and on the weather side, cleanest in the inner rooms. That keeps it from looking uniformly random.

Material checklist (pair with the CC0 textures in §5):
- **Lath and plaster** (pre-1940s walls): wooden laths behind plaster that is forced through the gaps to form "keys", in coats (scratch, brown, finish), often with horsehair – https://en.wikipedia.org/wiki/Lath_and_plaster . Broken walls show horizontal lath strips with lumps of plaster behind them (ref image: Tower of London lath, §5).
- **Wallpaper** peels from the top and the seams where moisture gets in; floral 1960s–70s prints read as "someone lived here" (Flickr ref in §5).
- **Ceilings:** brown ring stains with darker tide-lines; black mould spotting near leaks and corners; sagging or fallen plaster patches showing lath or joists (refs in §5).
- **Floors:** worn or rotted boards, carpet with water stains, debris piles under ceiling holes.
- **Windows:** boarded from outside with plywood, broken panes, curtains in rags.
- **Exterior:** missing shingles, hanging gutters, peeling clapboard (weathered plank siding), overgrowth climbing walls (Vyshniv cottage with wild grape, §5).

Polycount critics note that abandonment reads through "subtle dust and more imperfection" and that you should "stick to reference" – https://polycount.com/discussion/comment/2724764

### 1.4 Furniture and props (real sizes)

| Prop | Real size | Studs | Source |
|---|---|---|---|
| Kitchen base cabinet | 24 in deep, 34½ in high; countertop 36 in (0.61 / 0.88 / 0.91 m) | 2.2 / 3.1 / 3.25 | https://en.wikipedia.org/wiki/Kitchen_cabinet |
| Kitchen wall cabinet | 12 in (0.30 m) deep | 1.1 | same |
| Sofa | typical 84 in long (2.13 m); e.g. 33 in deep, seat 15¾ in (0.84 / 0.40 m), total height 0.70 m | 7.6 × 3.0, seat 1.4, h 2.5 | https://www.dimensions.com/collection/sofas-couches ; https://www.dimensions.com/element/outline-sofa |
| Bed, US queen / full / twin | 60 × 80 / 54 × 75 / 38 × 75 in | 5.4 × 7.3 / 4.9 × 6.8 / 3.4 × 6.8 | https://en.wikipedia.org/wiki/Bed_size |
| Bed, EU single / double | 90 × 200 / 140–160 × 200 cm | 3.2 × 7.1 / 5.0–5.7 × 7.1 | same |
| Upright piano, bathtub, fridge, toilet | **[unverified typical]** piano ≈ 1.5 w × 1.2 h × 0.6 d m; tub ≈ 1.5–1.7 × 0.75 m; fridge ≈ 0.75 × 1.75 m; toilet seat ≈ 0.4 m | 5.4 × 4.3 × 2.1; 5.4–6.1 × 2.7; 2.7 × 6.3; 1.4 | verify at https://www.dimensions.com/collection/pianos and https://www.dimensions.com/collection/bathroom-fixtures |

**Story-prop checklist by room** **[rec]**, built on Duvall's rules. Duvall's first rule is that a visual cue "must have a reason to exist even if players aren't present": they gave a grandfather a compulsion to scribble on everything rather than putting up a sign. Their second rule is that you don't always need to tell players what to do – https://create.roblox.com/docs/resources/the-mystery-of-duvall-drive/immersive-narrative.md . The GDC talk "What Happened Here? Environmental Storytelling" (Smith & Worch, 2010) frames props as clues that let the player infer past events – https://gdcvault.com/play/1012647/What-Happened-Here-Environmental
- *Porch/entry:* a pile of unopened mail under the door slot, a faded notice on the door, coat hooks with one coat, an umbrella stand, a dead potted plant.
- *Living room:* a sheet-covered sofa, a CRT TV, a fallen picture frame with a pale rectangle left on the wallpaper, a rocking chair, a fireplace full of ash, a stopped clock (Poly Haven has `vintage_grandfather_clock_01`, `Rockingchair_01`, `mantel_clock_01`).
- *Kitchen:* open cabinet doors, dishes left in the sink, a calendar stuck on one month, a fridge with its door ajar, a collapsed ceiling patch over the table.
- *Bedrooms:* a stained mattress on the floor, a child's room with toys (the strongest emotional cue), a wardrobe with a hanging door, a scribbled wall.
- *Bathroom:* a clawfoot tub with a rust streak, a cracked mirror, black mould at the ceiling.
- *Attic and basement:* boxes, a dress form, an old bed frame (`old_bed_frame`), water on the basement floor, a boiler.
- **Signs of other visitors** (urbex): graffiti tags in one room, a broken window used as the entry, a candle stub. Use these sparingly, because graffiti flips the mood from haunted to vandalised.

### 1.5 Exterior checklist

From Duvall's exterior design (https://create.roblox.com/docs/resources/the-mystery-of-duvall-drive/construct-the-house.md ):
- **Bend the approach road** so players can't see all the way down it.
- **Use trees to frame and obscure the house,** giving glimpses before the reveal. Plant dense trees where players can't go and thinner trees where you want them to explore.
- **Raise the driveway so the player climbs to the house**, which "gave the house a more intimidating presence".
- **Overgrown yard**, appropriate for the 0–5 year stage (Science Insights above): knee-high grass, saplings in the gutters, a dead tree with a bare silhouette against the sky, a leaning or broken fence, and a rural mailbox at the road (USPS heights above).
- **Sky [rec]:** overcast dusk or moonlit night. Bluish moon fill with silhouettes against a brighter horizon, per the Hollywood-darkness page (§1.1). Use Atmosphere haze to hide the map edge.

### 1.6 Roblox-specific references for the house
- Duvall Drive: a craftsman-style house chosen so that one set of wood-trim textures could cover furniture and architecture, keeping models low-poly. Building it from packages makes rooms easy to update – https://create.roblox.com/docs/resources/the-mystery-of-duvall-drive/materialize-the-world.md
- Indoor realistic lighting tutorial: https://create.roblox.com/docs/tutorials/use-case-tutorials/lighting/enhance-indoor-environments.md ; flickering lights: https://create.roblox.com/docs/tutorials/use-case-tutorials/lighting/create-flickering-lights.md ; light with props: https://create.roblox.com/docs/tutorials/use-case-tutorials/lighting/light-with-props.md
- DevForum 2026: a "Fears to Fathom"-style photoreal house horror game got feedback that its film grain was too heavy and would "hide" good models, so go easy on grain – https://devforum.roblox.com/t/feedback-fears-to-fathom-inspired-roblox-horror-game-wip/4591899

---

## 2. Liminal space / Backrooms

### 2.1 Canonical Level 0

- **Origin photo:** taken in 2002 during the renovation of HobbyTown USA in Oshkosh, Wisconsin, on the second floor of a former furniture store (Rohner's), and posted on the shop's website in March 2003. A Discord group traced it in May 2024. It reached 4chan /x/ on 12–13 May 2019 – https://en.wikipedia.org/wiki/The_Backrooms ; https://www.wpr.org/news/horror-film-backrooms-meme-oshkosh . WPR describes it as "a grim, empty commercial space — windowless, uniformly dull yellow, lit by fluorescent lights". Kane Parsons' feature film *Backrooms* (A24) came out in 2026.
- **What the photo shows** (Wikipedia alt text): "a slightly tilted view into an empty indoor space with a uniform beige carpet. The drop ceiling has a visible column of rectangular light fixtures. The space is partitioned by interior walls. The muted wallpaper has repeating patterns such as dots or chevrons and appears to be light yellow. No doors, windows or furniture of any kind are present."
- **Canonical text:** "the stink of old moist carpet, the madness of mono-yellow, the endless background noise of fluorescent lights at maximum hum-buzz, and approximately six hundred million square miles of randomly segmented empty rooms" (4chan 2019, quoted on Wikipedia). The wiki version adds "mildew-ridden carpets" and calls the level "a labyrinth resembling the back rooms commonly found in offices or retail outlets" – https://backrooms-wiki.wikidot.com/level-0 . Apeirophobia's version adds "worn mono-yellow wallpaper, old moist carpet, scattered electrical outlets, and inconsistently-placed fluorescent lighting" – https://apeirophobia.fandom.com/wiki/Level_0
- **A DevForum builder recreated the real HobbyTown layout** – https://devforum.roblox.com/t/hobbytown-oshkosh-wisconsin-showcase/3659280 ; other Level 0 recreations: https://devforum.roblox.com/t/realistic-backrooms-recreation/3035637 , https://devforum.roblox.com/t/realistic-backrooms/4186208

**Level 0 build spec** (dimensions sourced; the choice of values is **[rec]**):

| Element | Value | Studs | Source / note |
|---|---|---|---|
| Drop-ceiling grid (North America) | 2 × 2 ft (610 mm) or 2 × 4 ft (610 × 1220 mm) cells | 2.18 / 2.18 × 4.36 | https://forums.mikeholt.com/threads/2-x-2-versus-600-x-600.124160/post-1929179 ; https://nown.com/2x4-ceiling-tile-everything-you-need-to-know-before-specifying-a-custom-panel/ |
| Grid (EU / DE) | 600 × 600 mm / 625 × 625 mm | 2.14 / 2.23 | same |
| Light fixtures | 2 × 4 ft troffers dropped into grid cells, in rows ("column of rectangular light fixtures") | 2.2 × 4.4 | Wikipedia alt text; grid sources |
| Ceiling height | **[rec]** 2.6–2.75 m: low enough to feel oppressive under the ~3 m engine norm (LDB metrics) | 9.3–9.8 | design choice |
| Wall thickness | **[rec]** 0.1–0.15 m partitions (office stud walls) | 0.4–0.5 | design choice |
| Openings | doorless gaps, **[rec]** 0.9–1.8 m wide | 3.2–6.4 | the photo shows partitions and openings, no doors |
| Wallpaper | mono-yellow / light yellow with small repeating chevron or dot motif; no bold contrast | – | Wikipedia; ambientCG `Wallpaper001A–002C` as base |
| Carpet | uniform beige/brown loop pile, damp-looking (slightly darker patches) | – | Wikipedia; ambientCG `Carpet0xx`, Poly Haven `dirty_carpet` |
| Sound | constant hum at **twice the mains frequency**: magnetic ballasts deform twice per AC cycle, giving **120 Hz** on 60 Hz (US) power and **100 Hz** on 50 Hz (EU) power, plus buzzing on failing tubes | – | https://hyperphysics.gsu.edu/hbase/Solids/magstrict.html ; https://scienceinsights.org/why-do-fluorescent-lights-hum-causes-fixes/ |

### 2.2 Why liminal spaces unsettle (design rules)
- **Absence of expected people and context.** In empty transitional places "the absence of people, activity, or context normally expected… can make familiar places appear uncanny". Heft (after Mark Fisher) calls an unexpectedly empty schoolhouse a "failure of presence" – https://en.wikipedia.org/wiki/Liminal_space_(aesthetic) . **Rule:** no NPCs and no signs of current use, but plenty of signs of *intended* use (outlets, exit-style signage, carpet wear paths) **[rec]**.
- **Structural deviation causes uncanniness.** Diel & Lewis (2022, *J. Environmental Psychology* 82:101844) found an uncanny valley for built environments driven by "deviations from familiar configural patterns". People present in distorted *public* spaces made them *less* uncanny; people present in *private* rooms made them *more* uncanny – https://orca.cardiff.ac.uk/id/eprint/151790 . **Rules:** start from a convincing real module, then deviate subtly: a hallway slightly too long, a door at the wrong height, a room with no purpose, an outlet at head height **[rec]**.
- **Repetition with anomalies.** *The Exit 8* (2023) is a looping Japanese metro passage where you must spot "anomalies"; its creator drew on "the 'surreal' atmosphere of underground passageways and the concept of liminal spaces" – https://en.wikipedia.org/wiki/The_Exit_8 (Roblox version: https://www.roblox.com/games/16894230496 ).
- **Too pristine and wrong proportions.** Jared Pike's *Dream Pools* (2020, made in Blender) made pools "surreal, discomfiting places" with "dark areas not seen in real indoor swimming pools, tiles which appear too uniform and pristine, clear blue-green waters, and bizarre room proportions" – https://en.wikipedia.org/wiki/Poolrooms
- **No windows, no outside.** DevForum feedback on a liminal build said windows made it "nice" rather than liminal, and that liminal spaces "feel almost confined". If windows exist they should show anything "but the default skybox" – https://devforum.roblox.com/t/liminal-space-build-feedback/3177283
- **Too-even light [rec]:** flat, shadow-light, high-key lighting from a regular grid, with a few dead or flickering fixtures to break the rhythm. This is the opposite of the horror house's pools of light.

### 2.3 Other liminal archetypes (pick one or two side zones)

| Archetype | Key real dimensions | Studs | Source |
|---|---|---|---|
| Poolrooms | white tiles (Poly Haven `long_white_tiles`, ambientCG `Tiles0xx`), shallow and deep basins, arches; light from water caustics | – | Poolrooms (above); DevForum recreation feedback: water colour and transparency, sun rays too strong, add tile detail – https://devforum.roblox.com/t/what-do-you-think-about-my-poolroom-recreation/4297643 |
| Parking garage | stall 9 × 18 ft (2.74 × 5.49 m); two-way aisle at 90° 24 ft (7.32 m); clearance ≥ 7 ft (2.13 m) / 2.1 m | 9.8 × 19.6; 26.1; 7.6 | https://engstandards.lanl.gov/drawings_details/civil_pdf/ST-G2020-1.1-R5.pdf ; https://eaglemountain.gov/building-parking-standards ; https://www.losaltosca.gov/sites/default/files/fileattachments/Public%20Works/page/210/guidance_technical_specification_-_section_18.pdf |
| Empty office / hotel corridor / mall | carpet, evenly spaced doors, recessed lights (refs in §5) | – | Wikipedia liminal lead image (Stanley Hotel corridor) |

### 2.4 Roblox backrooms and liminal games (links only)

| Game | Notes | Source |
|---|---|---|
| Apeirophobia – https://www.roblox.com/games/10277607801 | the best-known Roblox backrooms game, inspired by Kane Pixels and the Backrooms wiki | API |
| [UPDATE] Backrooms – https://www.roblox.com/games/9273658706 | Red Panda Industries, 199 M visits, PC/mobile/console | API |
| The Backrooms – https://www.roblox.com/games/10576142169 | 162 M visits; description: "fluorescent yellow lights buzzing at intervals… moist though not damp brown carpet" | API |
| M.E.G. Endless Reality – https://www.roblox.com/games/98629859043211 | 2024, 230 M visits, 93 % liked | API |
| **Unseen Liminality** – https://www.roblox.com/games/82797688803922 | **March 2026 release, 95 M visits, 94 % liked**: pure exploration of "endless hallways"; "play on max graphics" | API |
| A Broken Dream – https://www.roblox.com/games/96775630583143 | July 2025, 98 % liked: liminal, dreamcore and weirdcore story ("NOT a backrooms game") | API |
| Poolrooms HD – https://www.roblox.com/games/10572093505 | "meant to be played on MAX GRAPHICS… on the lowest setting it will look terrible" | API |
| Another Place – https://www.roblox.com/games/9337187827 | co-op backrooms on PC, mobile, Xbox and PS | API |

---

## 3. Realistic temperate nature (forest, lake, mountain)

### 3.1 Environment-art rules for believable forests
Danny Weinbaum (*Leaving Lyndow*, *Eastshade*), "Art Tips for Building Forests" – https://www.gamedeveloper.com/art/art-tips-for-building-forests :
- **Clustering:** "Resist the urge to scatter foliage and trees evenly… boldly cluster a lot of things together while leaving other parts practically barren." Small shrubs and saplings "grow symbiotically at the base of other plants", which also hides trunk/ground seams. Look for tight clusters of thin trunks.
- **Trunk density beats canopy density:** "Not all of your trees need canopies"; add bare trunks (dead trees) to raise trunk density cheaply.
- **Dead things:** "A large percentage of the trees in a forest are dead with no leaves", in both deciduous and coniferous forests. Add fallen logs, natural broken or rotted stumps, and "unlikely notable sights" such as a tree leaning on another, a log hanging off a boulder or a tree fallen into a river.
- **Trunk bases matter most:** players look at eye level or down, so put detail where the trunk meets the ground. The Level Design Book makes the same point: "don't put canopy on every trunk and make sure there's detail at the base" – https://book.leveldesignbook.com/process/env-art
- **Undergrowth:** the forest floor is almost fully covered, but by "shrubs, ferns, and low lying leafy stuff", not tall green grass.
- **Rocks of all sizes,** mid-size rocks modelled as clusters, pebbles on bare ground.
- **Water first:** "lay in the bodies of water first, and structure the entire biome around them". "Dress the edges of my rivers in lots of rocks."
- **Particles for depth:** butterflies, falling leaves, fluff and dust specks add parallax in visually busy forests.
- **Silhouette is about 90 % of foliage:** iterate on silhouette and coverage, not texture detail. Start with one variant per plant; he got far with "four broadleaf variants (eight including dead versions)".

Ecology facts to encode:
- **Forest edge (ecotone):** an ideal edge runs from outside in through an **herb fringe** (Krautsaum), then a **shrub belt** (Strauchgürtel), then the **forest mantle** (Waldmantel: edge trees whose crowns reach low on the open side) – https://de.wikipedia.org/wiki/Waldrand . **[rec]** Never stop the forest with a vertical wall of identical trees.
- **Clustering in real stands:** one forestry study found trees mostly randomly distributed while "the undergrowth formed clusters, especially due to the seedling regeneration of birch". The canopy drives the understory composition – https://research.science.eus/documentos/6880a3523871d04c4eb46f31?lang=de
- **Dead wood (coarse woody debris)** is a habitat; "up to forty percent of all forest fauna is dependent on CWD" – https://en.wikipedia.org/wiki/Coarse_woody_debris
- **Treeline:** trees grow "sparse, stunted, and deformed by wind and cold" (**krummholz**) and get "shorter and often at lower densities as they approach the tree line" – https://en.wikipedia.org/wiki/Tree_line
- **Scree/talus:** a concave-up slope near the angle of repose, sorted by size (bigger blocks further down), with vegetation slowly encroaching – https://en.wikipedia.org/wiki/Scree
- **Atmospheric (aerial) perspective:** "distant objects appear paler, of lower contrast, and bluer than nearer objects" – https://en.wikipedia.org/wiki/Aerial_perspective . In Roblox this is Atmosphere Density, Offset, Haze and Color (Offset too low lets the sky show through terrain) – https://create.roblox.com/docs/environment/atmosphere.md
- **God rays (crepuscular rays)** are beams "passing through gaps", "especially prominent when the contrast between light and dark is most obvious" – https://en.wikipedia.org/wiki/Crepuscular_rays . **[rec]** You need a bright sun, dark canopy gaps and haze or mist. Roblox SunRays is a screen-space sun halo, so forest shafts may need geometry or particle beams.

### 3.2 Species list (temperate Europe / North America) with heights

| Layer | Species | Height (m) | Studs | Source |
|---|---|---|---|---|
| Canopy (EU) | European beech *Fagus sylvatica* | typically 25–35, up to 50 | 89–125 | https://en.wikipedia.org/wiki/Fagus_sylvatica |
| Canopy (EU) | Norway spruce *Picea abies* | 35–55 | 125–196 | https://en.wikipedia.org/wiki/Picea_abies |
| Canopy (EU) | Scots pine *Pinus sylvestris* | up to 35 | ≤125 | https://en.wikipedia.org/wiki/Pinus_sylvestris |
| Canopy (EU) | Silver fir *Abies alba* | 40–50 | 143–179 | https://en.wikipedia.org/wiki/Abies_alba |
| Canopy (EU) | Pedunculate oak *Quercus robur* | typically up to 20, sometimes 40 | 71 (143) | https://en.wikipedia.org/wiki/Quercus_robur |
| Pioneer / edge | Silver birch *Betula pendula* | 15–25, trunk usually < 40 cm | 54–89, trunk < 1.4 | https://en.wikipedia.org/wiki/Betula_pendula |
| Shore | Black alder *Alnus glutinosa* (moist soils) | 20–30 | 71–107 | https://en.wikipedia.org/wiki/Alnus_glutinosa |
| Shrub | Hazel *Corylus avellana* | 3–8 | 11–29 | https://en.wikipedia.org/wiki/Corylus_avellana |
| Fern | Bracken *Pteridium aquilinum* | fronds 0.3–1 | 1.1–3.6 | https://en.wikipedia.org/wiki/Pteridium_aquilinum |
| Fern | Male fern *Dryopteris filix-mas* | fronds up to 1.5 | ≤ 5.4 | https://en.wikipedia.org/wiki/Dryopteris_filix-mas |
| Ground | Bilberry *Vaccinium myrtillus*, mosses, leaf litter, needle litter | low (ankle to knee) | – | https://en.wikipedia.org/wiki/Vaccinium_myrtillus |
| Shore | Common reed *Phragmites australis* | 2–6, in water up to 1 m deep | 7–21 (water ≤ 3.6) | https://en.wikipedia.org/wiki/Phragmites_australis |
| Shore | Cattail *Typha latifolia* | 1.5–3, in 0.75–1 m of water | 5.4–10.7 | https://en.wikipedia.org/wiki/Typha_latifolia |
| Canopy (NA) | Douglas fir *Pseudotsuga menziesii* | 20–100 (coastal trees only near 100) | 71–357 | https://en.wikipedia.org/wiki/Pseudotsuga_menziesii |
| Canopy (NA) | Sugar maple *Acer saccharum* | 25–35 (10-year tree ≈ 5) | 89–125 (18) | https://en.wikipedia.org/wiki/Acer_saccharum |
| Canopy (NA) | Eastern hemlock *Tsuga canadensis* | ≈ 31 | ≈ 111 | https://en.wikipedia.org/wiki/Tsuga_canadensis |
| Canopy (NA) | Eastern white pine *Pinus strobus* | historically up to 70 | 250 | https://en.wikipedia.org/wiki/Pinus_strobus |
| Pioneer (NA) | Paper birch *Betula papyrifera* | ≈ 20, trunk ≤ 75 cm | 71, trunk 2.7 | https://en.wikipedia.org/wiki/Betula_papyrifera |
| Fern (NA) | Western sword fern *Polystichum munitum* | fronds 0.5–1.8 | 1.8–6.4 | https://en.wikipedia.org/wiki/Polystichum_munitum |

**[rec] Scale on an 84 m (300-stud) map:**
- **Mature trees** of 25–35 m (90–125 studs) put the canopy above the frame, so invest in trunks, bases and the 0–5 m (0–18 stud) understory band. Use mixed ages: saplings at 2–5 m (7–18 studs), young trees at 8–15 m (29–54 studs) and a few veterans.
- **The lake** can take about 25–35 m (90–125 studs), roughly a third of the map, with a reed belt in the shallow 0–1 m margin, alder and willow on the bank, and stones on the waterline.
- **A mountain cannot fit.** Build a walkable ridge or cliff rising 15–25 m (54–90 studs) with scree and stunted conifers. Put real peaks as low-detail backdrop terrain outside the play area, washed pale and blue by Atmosphere haze.

### 3.3 Best realistic-nature showcases on Roblox (links only)

| Showcase | Why look | Source |
|---|---|---|
| Roblox – Realistic Forest Demo – https://www.roblox.com/games/5326950832 | Alpha Strike Group demo combining SurfaceAppearance, cutout transparency, Atmosphere, depth of field and skinned animation | API |
| [RTX] Realistic Landscape – https://www.roblox.com/games/7504841246 | "Next-gen inspired visuals… optimized for… a wide range of devices" | API |
| Cliffside Showcase – https://www.roblox.com/games/91132996757869 | asimo3089, 2025: clouds form, seas churn, storms roll in (weather as drama) | API |
| Scenery Experience – https://www.roblox.com/games/123706682177619 | 2026: grassland, boardwalk, flower clusters, rivers, branching paths | API |
| **Paul's Woods** (part-based, no meshes) – https://devforum.roblox.com/t/pauls-woods-a-part-based-showcase-out-now/3322911 | Proof that a forest-and-lighthouse walk works with Claude-style part geometry. Commenters said it looked like "2016 legacy Roblox", so parts need careful lighting and materials | DevForum |
| Aspen Field / Realistic Autumn Forest (sa_w1, Sep 2026) – https://devforum.roblox.com/t/realistic-autumn-forest/4893479 | aspen and birch "with some spruce mixed in"; the colour variation **between species** sells autumn | DevForum |
| Realistic Forest Scene (sa_w1) – https://devforum.roblox.com/t/realistic-forest-scene/4772086 | screenshots only | DevForum |
| Toyokawa Inari Shrine – https://www.roblox.com/games/3158922185 | Bloxy Award winner for best showcase | API |
| Deepwoken – https://www.roblox.com/games/4111023553 · FRONTLINES – https://www.roblox.com/games/5938036553 · 99 Nights – https://www.roblox.com/games/79546208627805 | large game worlds: Deepwoken's dark fantasy, Frontlines' photoreal shooter, 99 Nights' stylised horror forest | API |

**Platform news:** Roblox announced a **Terrain Scattering System** (rule-based scatter of custom meshes such as shrubs, trees, rocks and custom grass, cheaper than instanced meshes and non-destructive), **Path Splines**, **Projected Decals**, **Virtual Texturing** and **SDF terrain**. They target early access in "late Fall/Winter" 2026 – https://devforum.roblox.com/t/terrain-updates-object-scattering-path-splines-projected-terrain-decals-and-more/4865617 . Check availability before planning around it; until then scatter in code with clustering rules (§4.3). There is also a wind-for-skinned-foliage plugin: https://devforum.roblox.com/t/canopy-flow-realistic-wind-for-skinned-foliage/4693945

---

## 4. General environment-art principles

### 4.1 Scale and metrics
- Engines oversize: Unity uses 3.0 m walls, 2.0 m halls and 1.25 × 2.5 m doors; Unreal 3.0 m walls, 1.5 m halls and 1.1 × 2.2 m doors; real US homes 2.44 m walls, 1.22 m halls and 0.91 × 2.03 m doors. "The minimum hallway width should be at least double the player width" – https://book.leveldesignbook.com/process/blockout/metrics
- Greybox first and playtest the layout before art. Duvall had a playable layout within days – https://create.roblox.com/docs/tutorials/curriculums/environmental-art/greybox-your-environment.md

### 4.2 Composition, focal points, readability
- **One star per view:** "think of one element that draws attention over everything else… with shapes, colours or even lighting". Keep darker values in the foreground and lighter ones on the focus. Repeat elements in foreground and background for depth. "Not everything has to be super detailed. Keep the details in the important areas" – https://www.creativebloq.com/professional-development/artistic-tips-techniques/how-to-create-convincing-environment-art (May 2025)
- **Areas of visual detail versus areas of visual rest:** concentrate detail in a few spots with calm areas between them, because uniform detail overloads the eye (Neil Blevins) – http://www.neilblevins.com/art_lessons/composition_areas_of_visual_rest/composition_areas_of_visual_rest.htm
- **Readability:** "Simplify what the player must see. Make it legible… understand the level as a whole place, not as a pile of random floors and wall segments". Valorant keeps materials "similar in value", without too much contrast or darkness, to cut visual noise, and uses a hero asset only once per map – https://book.leveldesignbook.com/process/env-art
- **Value grouping and the squint test:** limit the background value range, put the highest contrast at the focal point, group similar values, and squint to check that light, mid and dark read clearly – https://blog.milanartinstitute.com/the-secret-to-better-art-mastering-composition-step-by-step/ ; focal hierarchy and no awkward edge crops – https://mages.edu.sg/blog/effective-composition-in-concept-art-environments/
- **"70/20/10 rule" [heuristic; no canonical source found]:** I searched and found no authoritative origin for the exact split. Use it as shorthand for the sourced principles above: ~70 % of the frame is calm large forms (walls, sky, ground, canopy mass), ~20 % medium secondary shapes (furniture, trunks, rocks, trim) and ~10 % dense high-detail focal clusters (story props, a doorway, the dead tree). Detail density should *peak* at focal points and *drop* in between (Blevins, Creative Bloq, LDB).
- **Thumbnail and screenshot test [rec, built on the sources above]:** shrink the shot to ~256 px or blur it. It should still show one clear silhouette (house against sky, doorway against dark), at most 3 value groups, and a single brightest area where the eye should go. If it reads as noise, cut tertiary detail, not primary shapes.
- **Lighting passes:** use light for worldbuilding, massing (washes divide sub-areas) and circulation (exits lit more prominently), then add gameplay lights (foreshadowing, puzzle highlights), and only then detail and mood ("don't spend too long") – https://book.leveldesignbook.com/process/lighting

### 4.3 Avoiding the "evenly spread" procedural look
- Use clusters plus barren patches, shrubs at tree bases, dead trunks to raise density, and rare notable sights (Weinbaum, §3.1).
- Guerrilla called earlier procedural systems "monotonous, bland and robotic". Horizon Zero Dawn's placement is data-driven from density and ecotope maps, deterministic and art-directable – https://www.guerrilla-games.com/media/News/Files/GDC2017_VanMuijden_GPUBasedProceduralPlacementInHorizonZeroDawn.pdf
- Common scatter rules: clustering (group instances), slope, height, density masks and exclusion zones – https://www.strayspark.studio/learn/tutorials/scatter-foliage-by-hand-vs-procedurally
- **[rec] Algorithm for Claude:**
  1. Poisson-disc seed points for cluster *centres*, with density driven by a moisture/light mask (wetter near the lake, sparser on the ridge).
  2. Spawn 3–12 members per cluster with Gaussian falloff.
  3. Add 20–30 % dead or bare trunks.
  4. Put shrubs and ferns in rings at trunk bases.
  5. Leave 15–25 % of the area as open glades.
  6. Vary scale ±25 % and rotation fully, and tilt 0–6°.
  7. Hand-place 3–5 hero sights.

### 4.4 Storytelling
- "What Happened Here?" (Smith & Worch, GDC 2010) – https://gdcvault.com/play/1012647/What-Happened-Here-Environmental . The talk includes Half-Life's bullet-hole smiley next to a dead body as an example of the player assembling a story – https://gamedev.net/blogs/entry/2110758-gdc-2010-day-5
- Duvall's rules (§1.4): cues must exist for in-world reasons; not everything needs explaining.
- Industry articles to read (DevForum recommends 80.lv and gamesartist.co.uk for breakdowns of lighting, props, foliage, composition and storytelling) – https://devforum.roblox.com/t/studying-outside-roblox-industry-art-articles/3666099

---

## 5. Reference image URLs (openly licensed; direct, downloadable)

**Licence notes.** CC0, PD and "Copyrighted free use" images need no attribution. CC BY / BY-SA need attribution if redistributed; they are fine as private build references, but record the credits. The Commons page for any upload URL is `https://commons.wikimedia.org/wiki/File:<filename>`.

**Downloading.** `upload.wikimedia.org` returned HTTP 429 after ~10 rapid requests during verification. Download with ≥ 5 s spacing and a User-Agent that includes contact info. For smaller files use `https://commons.wikimedia.org/wiki/Special:FilePath/<filename>?width=1600`.

**Verification.** All URLs came from the Commons, Openverse and Poly Haven APIs, and **every listed URL (48 Commons, 3 Flickr, 16 Poly Haven) returned image/* on a HEAD check on 2026-10-24.**

**Poly Haven tonemapped HDRI JPGs are real CC0 photos** of the location, which makes them good full-panorama references: `https://dl.polyhaven.org/file/ph-assets/HDRIs/extra/Tonemapped%20JPG/<slug>.jpg` (asset page `https://polyhaven.com/a/<slug>`).

### 5.1 Horror house (19)
| # | What to study | Licence · author | Direct URL |
|---|---|---|---|
| H1 | abandoned house interior, general decay | CC BY 3.0 · Wasteland Wanderer | https://upload.wikimedia.org/wikipedia/commons/c/cf/Abandoned_House_Interior_-_panoramio.jpg |
| H2 | room with boarded windows (Doel, BE), light through boards | CC BY 4.0 · Trougnouf | https://upload.wikimedia.org/wikipedia/commons/3/30/Room_in_an_abandoned_house_with_boarded_up_windows_in_Doel%2C_Belgium_%28DSCF3800-hdr%29.jpg |
| H3 | porch of an abandoned house | CC BY-SA 4.0 · W.carter | https://upload.wikimedia.org/wikipedia/commons/e/ed/Porch_on_abandoned_house_in_Vibble_1.jpg |
| H4 | porch detail of a deserted house (NARA) | Public domain · A. Greenberg | https://upload.wikimedia.org/wikipedia/commons/2/26/INTERESTING_DETAIL_ON_PORCH_OF_DESERTED_HOUSE_-_NARA_-_552492.jpg |
| H5 | ceiling water-damage stain | CC BY 3.0 · Atomicdragon136 | https://upload.wikimedia.org/wikipedia/commons/b/b9/Ceiling_water_damage.jpg |
| H6 | mould on a ceiling (post-Katrina) | CC BY 3.0 · Infrogmation | https://upload.wikimedia.org/wikipedia/commons/0/02/Mold_on_Ceiling_on_House_on_Dublin_Street_New_Orleans_after_Katrina.jpg |
| H7 | exposed lath and plaster | CC0 · McPhail | https://upload.wikimedia.org/wikipedia/commons/7/7c/Lath_and_plaster_in_the_Tower_of_London.jpg |
| H8 | abandoned Victorian house exterior | CC BY 2.0 · Daniel Ramirez | https://upload.wikimedia.org/wikipedia/commons/9/9e/Abandoned_Victorian_House.jpg |
| H9 | abandoned Victorian cottage (New Orleans) | CC BY 4.0 · Gilbert Mercier | https://upload.wikimedia.org/wikipedia/commons/6/65/New-Orleans_post_Katrina_2007-_abandoned_Victorian_cottage%2C_Lower_9th_Ward.jpg |
| H10 | abandoned house, Adelaide Street | Public domain · Nyttend | https://upload.wikimedia.org/wikipedia/commons/f/fe/Adelaide_Street_abandoned_house.jpg |
| H11 | abandoned house, Delray, Detroit | Public domain | https://upload.wikimedia.org/wikipedia/commons/c/cb/AbandonedHouseDelray.jpg |
| H12 | overgrown yard | CC BY-SA 4.0 · Budgawl | https://upload.wikimedia.org/wikipedia/commons/e/e7/Vyazishche_abandoned_house_overgrown_yard.jpg |
| H13 | nature reclaiming an interior | CC0 · Wilfredor | https://upload.wikimedia.org/wikipedia/commons/4/49/Overgrown_interior_of_an_abandoned_house_on_Margarita_Island%2C_Venezuela.jpg |
| H14 | boarded-up house exterior (UK) | CC BY-SA 2.0 · John Slater | https://upload.wikimedia.org/wikipedia/commons/5/57/Boarded_up_house_at_Thornhills_-_geograph.org.uk_-_2849591.jpg |
| H15 | rural mailbox | CC BY-SA 2.0 · Dave Bezaire | https://upload.wikimedia.org/wikipedia/commons/9/91/Rural_Mailbox_%283650092080%29.jpg |
| H16 | dead tree silhouette | CC BY-SA 2.0 · Thomas Hirsch | https://upload.wikimedia.org/wikipedia/commons/5/59/Dead_tree_%2825973591065%29.jpg |
| H17 | peeling 1960s–70s floral wallpaper (Flickr) | CC BY 2.0 · Dominic's pics | https://live.staticflickr.com/4004/4625795485_f5e65df141_b.jpg |
| H18 | abandoned house interior, Mississippi (Flickr) | CC BY-SA 2.0 · ezola | https://live.staticflickr.com/5253/5391407901_aff897efb0_b.jpg |
| H19 | Poly Haven CC0 interiors: abandoned games room, tiled room, creepy bathroom, wooden attic, debris basement corridor | CC0 | …/Tonemapped%20JPG/abandoned_games_room_01.jpg · abandoned_tiled_room.jpg · creepy_bathroom.jpg · industrial_wooden_attic.jpg · debris_basement_corridor.jpg · abandoned_hall_01.jpg |

CC0 materials for the house: Poly Haven `decrepit_wallpaper`, `damaged_plaster`, `peeling_painted_wall`, `worn_cracked_plaster`, `rough_plaster_broken`, `old_wood_floor`, `old_wooden_floor_01–03`, `dirty_carpet`, `old_linoleum_flooring_01`, `weathered_plank_siding`, `weathered_peeling_timber`, `wood_peeling_paint_weathered`, `rusty_metal`, `clay_roof_tiles`/`grey_roof_tiles`. Previews: `https://cdn.polyhaven.com/asset_img/primary/<slug>.png?height=780`. ambientCG: `Wallpaper001A–002C`, `PaintedPlaster0xx`, `WoodFloor0xx`, `WoodSiding001–013`, `RoofingTiles0xx`, `Fence001–008` (`https://ambientcg.com/view?id=<ID>`). CC0 models (Poly Haven): `old_bed_frame`, `wooden_bookshelf_worn`, `vintage_grandfather_clock_01`, `Rockingchair_01`, `vintage_oil_lamp`, `vintage_cabinet_01`, `painted_wooden_chair_01`, `wooden_crate_01`, `cardboard_box_01`, `dead_tree_trunk`.

### 5.2 Liminal / Backrooms (17)
| # | What to study | Licence · author | Direct URL |
|---|---|---|---|
| L1 | **the original Backrooms photo** (HobbyTown Oshkosh, 2002), 640×480 | Copyrighted free use · Bill / Bob Mazza | https://upload.wikimedia.org/wikipedia/commons/b/bb/HobbyTown_USA_Oshkosh_interior_under_construction_2002_%28The_Backrooms%29.jpg |
| L2 | second photo of the same room, same day | Copyrighted free use | https://upload.wikimedia.org/wikipedia/commons/9/93/Dsc00159.jpg_B%E1%BB%A9c_%E1%BA%A3nh_th%E1%BB%A9_2_trong_2_b%E1%BB%A9c_%E1%BA%A3nh_ngu%E1%BB%93n_g%E1%BB%91c_c%E1%BB%A7a_The_Backrooms.jpg |
| L3 | 3D Level 0 model render | CC BY 4.0 · Huuxloc | https://upload.wikimedia.org/wikipedia/commons/d/d9/Backrooms_model.jpg |
| L4 | Backrooms render | CC BY-SA 3.0 · jeanjemini | https://upload.wikimedia.org/wikipedia/commons/1/1d/The_Backrooms_Render_%283-3%29.png |
| L5 | school hallway (Wikipedia Backrooms article image) | CC BY-SA 2.0 · Matt Dempsey | https://upload.wikimedia.org/wikipedia/commons/f/f9/Lorain_High_School_hallway.jpg |
| L6 | empty hotel corridor (Wikipedia "Liminal space" lead) | CC BY 4.0 · Larry D. Moore | https://upload.wikimedia.org/wikipedia/commons/f/fd/Corridor_Stanley_Hotel_Estes_Park_Colorado_2024.jpg |
| L7 | endless stairwell | CC BY 4.0 · PancakeGuy20 | https://upload.wikimedia.org/wikipedia/commons/a/ab/Tall_staircase_in_an_apartment_building.jpg |
| L8 | 1960s office corridor | CC BY-SA 4.0 · Kgbo | https://upload.wikimedia.org/wikipedia/commons/c/c7/Office_corridor%2C_1960s_office_building_in_Mascot%2C_NSW%2C_2022.jpg |
| L9 | dying-mall corridor | CC BY 4.0 · Pokemonprime | https://upload.wikimedia.org/wikipedia/commons/1/10/Mall_Corridor%2C_Titusville_Mall%2C_Titusville%2C_Florida.jpg |
| L10 | empty shopping-centre corridor (Nov 2025) | CC BY-SA 4.0 · JIP | https://upload.wikimedia.org/wikipedia/commons/0/02/Corridor_at_Ruoholahti_shopping_centre_empty_of_people_on_an_evening_in_November_2025.jpg |
| L11 | empty parking garage | CC BY 4.0 · Lee Ann Ratledge | https://upload.wikimedia.org/wikipedia/commons/d/da/Empty_Public_Parking_Garage_-_Knoxville%2C_Tennessee_-_December_27%2C_2014.jpg |
| L12 | empty parking garage deck | CC0 · Ranch9613 | https://upload.wikimedia.org/wikipedia/commons/1/1c/Empty_6th-floor_retail_parking_garage_at_Legacy_West%2C_Plano%2C_TX.jpg |
| L13 | indoor pool (Hallenbad) | CC BY-SA 3.0 · Vanellus Foto | https://upload.wikimedia.org/wikipedia/commons/0/03/Hallenbad_Wolfsburg_Westen.JPG |
| L14 | old indoor pool hall | CC BY 4.0 · Flocci Nivis | https://upload.wikimedia.org/wikipedia/commons/d/d3/20230311_Altes_Hallenbad_St._Ingbert_01.jpg |
| L15 | dim carpeted hotel corridor, evenly spaced doors | CC BY-SA 4.0 · PattayaPatrol | https://upload.wikimedia.org/wikipedia/commons/e/e9/DFC_3491_Dimly_lit_hotel_corridor_with_a_deep_red_carpet_stretching_into_the_distance_flanked_by_warm-toned_walls_and_evenly_spaced_doorways.jpg |
| L16 | "Liminal space" (Flickr) | CC BY-SA 2.0 · Monika Kostera | https://live.staticflickr.com/7474/15917166812_74873b30ff_b.jpg |
| L17 | Poly Haven CC0: indoor pool, large corridor, abandoned parking | CC0 | …/Tonemapped%20JPG/indoor_pool.jpg · large_corridor.jpg · abandoned_parking.jpg |

CC0 materials: ambientCG `OfficeCeiling001–006` (drop-ceiling tiles), `Carpet001–016`, `Wallpaper001A–002C`, `Tiles0xx`; Poly Haven `ceiling_interior`, `dirty_carpet`, `long_white_tiles`, `terrazzo_tiles`, `concrete_floor_worn_001`.

### 5.3 Temperate nature (19)
| # | What to study | Licence · author | Direct URL |
|---|---|---|---|
| N1 | beech plus fern understory | CC0 · W.carter | https://upload.wikimedia.org/wikipedia/commons/b/bb/Beech_and_ferns_in_Gullmarsskogen.jpg |
| N2 | beech forest in winter (trunk rhythm, no leaves) | CC BY-SA 4.0 · Susulyka | https://upload.wikimedia.org/wikipedia/commons/4/47/Beech_forest_M%C3%A1tra_in_winter.jpg |
| N3 | beech in a gorge (terrain plus trees) | CC BY-SA 4.0 · Slaunger | https://upload.wikimedia.org/wikipedia/commons/5/58/M%C3%B8ns_Klint_beech_trees_in_gorge_2015-04-01-4864.jpg |
| N4 | spring fern forest floor | CC BY-SA 3.0 US · ForestWander | https://upload.wikimedia.org/wikipedia/commons/5/58/Forest-floor-spring-ferns_-_West_Virginia_-_ForestWander.jpg |
| N5 | rotting fallen trunk | CC BY-SA 4.0 · Acabashi | https://upload.wikimedia.org/wikipedia/commons/c/c1/Epping_Forest_High_Beach_Essex_England_-_rotting_fallen_tree_trunk.jpg |
| N6 | moss-covered roots (trunk base) | CC0 · Mar Mkrtchyan | https://upload.wikimedia.org/wikipedia/commons/2/2f/Moss-covered_tree_roots.jpg |
| N7 | dead wood (Totholz), Bavarian Forest | CC BY-SA 4.0 · R.-M. Rinkl | https://upload.wikimedia.org/wikipedia/commons/2/23/Totholz_beim_Kleinen_Falkenstein.jpg |
| N8 | dead spruce stand, Harz (snags) | CC BY-SA 4.0 · M. Trusheim | https://upload.wikimedia.org/wikipedia/commons/5/55/Nationalpark_Harz_toter_Fichtenwald_am_Brocken.jpg |
| N9 | spruce forest, Harz | CC BY-SA 4.0 · Puusterke | https://upload.wikimedia.org/wikipedia/commons/7/7d/Fichtenwald_im_Nationalpark_Harz.jpg |
| N10 | mountain forest by a lake (Großer Rachel) | CC BY-SA 4.0 · J. Stroe | https://upload.wikimedia.org/wikipedia/commons/f/fa/Bayerischer_Wald_Gro%C3%9Fer_Rachel%2C_Wald_am_Rachelsee.jpg |
| N11 | reeds and still water (shore) | CC0 · Z3lvs | https://upload.wikimedia.org/wikipedia/commons/c/cb/Reeds_and_still_water_at_Gazzam_Lake%2C_Bainbridge_Island%2C_Washington.jpg |
| N12 | alpine lake, Panixersee (Sep 2025) | CC BY-SA 4.0 · D.J. Bergsma | https://upload.wikimedia.org/wikipedia/commons/b/ba/Panixersee_%28Lag_da_Pigniu%29_boven_Andiast._26-09-2025._%28d.j.b.%29_14.jpg |
| N13 | forest lake with mountain backdrop | CC0 · Paul Stewart | https://upload.wikimedia.org/wikipedia/commons/2/20/Lake_Mapourika1.jpg |
| N14 | crepuscular rays in a forest | CC BY 4.0 · Jakub Hałun | https://upload.wikimedia.org/wikipedia/commons/a/a1/Crepuscular_rays_in_the_forest_near_Przeginia_Duchowna%2C_Lesser_Poland_Voivodeship%2C_20240225_0830_6640.jpg |
| N15 | meadow to forest-edge transition | CC0 · Z3lvs | https://upload.wikimedia.org/wikipedia/commons/8/83/Footpath_through_a_grassy_meadow_toward_the_forest_edge%2C_Potawatomi_State_Park%2C_Wisconsin.jpg |
| N16 | misty winter forest (depth through fog) | CC BY 2.0 · Scott Wylie | https://upload.wikimedia.org/wikipedia/commons/0/03/%28Explored%29_Misty_Winter_morning_in_Stonor_Forest_-_Flickr_-_scotbot.jpg |
| N17 | Hoh rainforest (NA, moss, ferns) | CC BY-SA 2.0 · Doug Kerr | https://upload.wikimedia.org/wikipedia/commons/f/ff/Hoh_Rainforest_-_Olympic_National_Park_-_Washington_State_%289780555723%29_%282%29.jpg |
| N18 | Poly Haven CC0 forests: misty pines, dark autumn forest, Epping forest, forest slope, Hochsal forest | CC0 | …/Tonemapped%20JPG/misty_pines.jpg · dark_autumn_forest.jpg · epping_forest_01.jpg · forest_slope.jpg · hochsal_forest.jpg |
| N19 | Poly Haven CC0 lakes and mist: lakeside, Kloofendal misty morning | CC0 | …/Tonemapped%20JPG/lakeside.jpg · kloofendal_misty_morning.jpg |

CC0 nature assets:
- **Poly Haven `pine_forest` collection:** `fir_tree_01`, `pine_tree_01`, `fir_sapling(_medium)`, `pine_sapling_small/medium`, `dead_tree_trunk`, `tree_stump_01/02`, `pine_roots`, `fern_02`, `moss_01`, `rock_moss_set_01/02`, `dry_branches_medium_01`, `grass_medium_01`.
- **Poly Haven `verdant_trail` collection:** `boulder_01`, `rock_face_01/02`, `root_cluster_01/02`, `shrub_01–04`, `dead_tree_trunk_02`, `mountainside`.
- **Poly Haven textures:** `forest_floor`, `forest_leaves_02–04`, `forest_ground_04–06`, `brown_mud_leaves_01`, `bark_brown_01/02`, `bark_willow`, `lichen_rock`, `dry_riverbed_rock`, `damp_sand`, `gravel_floor`.
- **ambientCG:** `Bark001–015`, `Ground0xx`, `ScatteredLeaves001–009`, `Moss001–004`, `Rock0xx`, `Snow001–015`, `Grass001–008`.

---

## 6. Open questions / caveats
- **The "70/20/10 rule"** has no canonical source that I could find; it is presented as a heuristic over sourced principles.
- **Fridge, tub, piano and toilet sizes** are typical values that I did not verify (§1.4).
- **The IRC stair-width figure** should be confirmed in the cited PDF.
- **Avatar height of ≈5 studs** is approximate; measure the actual rig in Studio before fixing metrics.
- **The Roblox terrain scattering tools** are announced, not shipped (target late 2026).
- **DOORS and Pressure environment details** come from fan wikis (CC BY-SA, community-written).
