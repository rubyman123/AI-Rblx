# 04 - Stylized / blocky simulator maps + universal level design

Research for "Roblox Maps by fwjelaa" (`/make-map`). Compiled 2026-10-24. Research only: Studio and Blender were not touched.

**Tags used below**
- **[OFFICIAL]**: Roblox Creator Hub docs or the Roblox web API.
- **[WIKI]**: a fan wiki or Wikipedia.
- **[COMMUNITY]**: DevForum, YouTube or a blog. Treat as a starting point.
- **[MEASURED]**: pixel-sampled by me from an official game thumbnail or wiki screenshot, with the method stated.
- **[DERIVED]**: computed or synthesized by me from the cited numbers. It is a recommendation, not a quote.

---

## 0. TL;DR

1. The 2026 "lift a ___" wave (Lift a Cube, Lift a Building!, Lift A Weight, released Aug-Sep 2026) uses one map grammar. It is a **linear route out from spawn** through biome bands (grass, then sand, then ice). Each object to lift is heavier and bigger than the last, upgrade pads sit along the route, white ground arrows point the way, and a SPAWN button teleports you back. Servers hold 6-15 players. [Sources in section 1.1]
2. The big hits use three layouts:
   - **Hub-and-spoke ladder:** Pet Simulator 99 (spawn hub, then paid area gates, 274 areas). Grow a Garden is the symmetric version: 4 fenced plots in the quadrants, shops on two sides, event hub in the centre.
   - **Two-row lane:** Steal a Brainrot puts 8 bases in 2 rows of 4, facing a central conveyor walkway.
   - **Vertical ascent:** Bee Swarm Simulator gates the climb by bee count: 5, 10, 15, 25, 30 and 35.
3. The look is classic Roblox, revived:
   - Studded or SmoothPlastic surfaces in saturated BrickColors. Grow a Garden is described as having "studded textures evocative of old-school Roblox games".
   - Bright cyan sky with cartoon clouds.
   - Real maps sit close to stock BrickColors: Steal a Brainrot's grass measures #46954F, against Bright green #4B974B.
4. Lighting: `Technology` is **deprecated**. Use `Lighting.LightingStyle`:
   - **Soft** is the new-place default and gives the "flat, retro-Roblox look". It is the natural simulator choice.
   - **Realistic** is for horror and nature maps.
   - Set `PrioritizeLightingQuality` as well.
5. Metrics [OFFICIAL]:
   - WalkSpeed 16 studs/s and JumpHeight 7.2 studs (JumpPower 50 if UseJumpPower), with gravity 196.2.
   - MaxSlopeAngle 89 deg, so any wedge is walkable. Vertical FOV is 70 deg.
   - Roblox's own greybox tutorial says doorways and halls should be at least 10 studs wide and walls at least 10 studs tall, with a 5-stud / 90 deg snap.
   - **Maximum flat jump is about 8.7 studs [DERIVED]**, so design gaps of 6 studs or less.
6. A 300x300 map is small: 18.75 s edge to edge and 26.5 s on the diagonal at WalkSpeed 16 [DERIVED]. Use 4-6 zones, and put a POI or "something interesting" every 5-8 s of walking (80-130 studs) [DERIVED from Ruski #5, scaled].
7. Performance on phones [OFFICIAL]:
   - Budget draw calls, not parts: the example baseline is under 1,000 draw calls and 1,000,000 triangles.
   - Turn CastShadow off on small parts. Shadows switch off below graphics quality level 4 anyway.
   - Use CollisionFidelity Box, and set CanCollide, CanTouch and CanQuery to false on decor.
   - Avoid partial transparency.
   - Turn repeated props into MeshParts that share one MeshId, so they instance. Do not use unions for repeated props.
   - Keep StreamingEnabled on.

---

## 1. Reference games and their maps (2025-2026)

Live stats were pulled from the Roblox games API on 2026-10-24 (`apis.roblox.com/universes/v1/places/{id}/universe`, then `games.roblox.com/v1/games`) [OFFICIAL].

| Game (place link) | Creator | Playing on 2026-10-24 | Visits | Created | Max players/server |
|---|---|---|---|---|---|
| [99 Nights in the Forest](https://www.roblox.com/games/79546208627805) | Grandma's Favourite Games | 1,910,562 | 30.2B | 2025-03-04 | - |
| [Steal An Egg](https://www.roblox.com/games/107778070777162) | "and Collect Rare Pets" | 1,490,339 | 9.3B | 2026-07-25 | 7 |
| [Steal a Brainrot](https://www.roblox.com/games/109983668079237) | BRAZILIAN SPYDER | 217,398 | 74.1B | 2025-05-16 | - |
| [Fisch](https://www.roblox.com/games/16732694052) | Fisching | 133,551 | 5.06B | 2024-03-13 | - |
| [Pet Simulator 99](https://www.roblox.com/games/8737899170) | BIG Games Pets | 94,923 | 2.68B | 2022-02-05 | - |
| [Fish It!](https://www.roblox.com/games/121864768012064) | Fish Atelier | 75,739 | 4.80B | 2024-10-21 | - |
| [Bee Swarm Simulator](https://www.roblox.com/games/1537690962) | Onett | 36,665 | 4.62B | 2018-03-21 | - |
| [Ride A Pet](https://www.roblox.com/games/124216119978534) | this game is gud | 28,830 | 426M | 2026-04-14 | 6 |
| [Grow a Garden](https://www.roblox.com/games/126884695634066) | The Garden Game | 26,242 | 36.0B | 2025-03-25 | - |
| [Muscle Legends](https://www.roblox.com/games/3623096087) | Muscle Legends Studio | 10,792 | 2.32B | 2019-08-09 | 20 |
| [+1 Lift Rock for Treasure](https://www.roblox.com/games/102555956950143) | ErEr Games | 3,339 | 11.5M | 2026-09-12 | 6 |
| [Strongman Simulator](https://www.roblox.com/games/6766156863) | The Gang Stockholm | 1,185 | 1.66B | 2021-05-04 | 10 |
| [Lift a Cube](https://www.roblox.com/games/109530157755211/Lift-a-Cube) | Freaky Strong! | 243 | 24.3M | 2026-08-24 | 10 |
| [Lift Everything!](https://www.roblox.com/games/121810702236824) | Strong Ape | 150 | 24.0M | 2025-06-22 | 20 |
| [Lift A Weight](https://www.roblox.com/games/72336033607602) | Never Stop Lifting | 135 | 1.66M | 2026-09-09 | 10 |
| [Lift a Building!](https://www.roblox.com/games/119033351277264) | Frogfish Games | 3 | 230K | 2026-09-11 | 15 |

Other front-page context:
- StudioKrew's 2026-09-30 snapshot puts Steal An Egg first at 1.6M CCU, followed by Brookhaven 329.6K, Blox Fruits, Ride A Pet 208K, MM2, RIVALS and 99 Nights. It says Steal An Egg's world has "biomes with guardian homes, player pens and bases, a treadmill, and rifts with bosses" ([studiokrew.com](https://studiokrew.com/blog/top-roblox-games-september-2026/)) [COMMUNITY].
- Records: Grow a Garden peaked at 22.3M CCU on 2025-08-23 ([Wikipedia](https://en.wikipedia.org/wiki/Grow_a_Garden)) [WIKI]. Steal a Brainrot peaked at 25.4M in Oct 2025 ([Wikipedia](https://en.wikipedia.org/wiki/Steal_a_Brainrot)) [WIKI].

### 1.1 The "lift a ___" genre (Aug-Sep 2026 wave)

**Shared store-page copy.** The genre templates are near-identical [OFFICIAL, game descriptions via API]:
- Lift a Cube: "Do push-ups to gain strength ... Travel further to discover heavier cubes and tougher challenges ... reach the end of the map!"
- Lift A Weight: "Travel further to discover heavier deadlifts ... reach the end of the map!"
- Lift a Building!: "Travel further to discover the biggest buildings! Can you pick up the tallest skyscraper in the world".

**Lift a Cube map** ([allthings.how guide, 2026](https://allthings.how/lift-a-cube-on-roblox-how-to-play-full-guide/)) [COMMUNITY]:
- **Route:** "The map is a linear route out from spawn, moving from grass into sand and ice terrain, with training pads, upgrade pads and chests placed along the way."
- **Getting back:** an on-screen **SPAWN button** returns you instead of walking back.
- **First minute:** you spawn with 0 Strength and pick up **yellow Strength pads scattered on the ground near spawn** for the first "Gain 5 Strength" goal. "**White arrows on the ground** point you toward each objective."
- **Upgrade pads:** they are coloured stand-on pads (the first is a red "Pad To Win"). The first sits **near spawn**, and more are spread across every section. Each prints its price and the before and after stat ("0.85s -> 0.72s").
- **End goal:** the last cube needs about 1.3B Strength. The server caps at 10 players.

**Lift a Cube thumbnail** ([image](https://tr.rbxcdn.com/180DAY-81b8ee2a87ef7fc60c283e7e3c84e25d/768/432/Image/Png/noFilter)) [MEASURED]:
- A classic lime **stud baseplate** (median #99E232) under a saturated cyan sky (#08FBFF) with white cartoon clouds.
- A huge diamond-plate metal cube is labelled "977M/kg". The object is the hero, and the number is the readout.

**Other lift games:**
- **Strongman Simulator:** "Drag items across the line to gain energy ... **Remove the exit to reach new areas**", which is a gate you break with stats [OFFICIAL description].
- **Lift Everything!:** "Everything you see can be lifted!", with crazier objects unlocked as strength grows [OFFICIAL description].
- **Lift Stone Simulator** (Stone Age Studio, released 2024-05-20, about 491K visits) is the older pre-wave version ([game.guide](https://www.game.guide/roblox-codes/lift-stone-simulator)) [COMMUNITY].

**Map takeaways for `/make-map` [DERIVED]:**
- The **liftable object is the weenie**. Put the biggest object (skyscraper or mega-cube) at the far end of the route, tall enough to be seen from spawn.
- Size each object in proportion to its tier, so the route reads as a size ladder.
- Each biome band is one tier. Put a pad cluster (train, upgrade, chest) at the start of each band.
- Ground arrows and the SPAWN-return convention are part of the genre's language.

### 1.2 Pet Simulator 99: spawn hub plus a paid area ladder

Source: [PS99 wiki, List of Areas](https://pet-simulator.fandom.com/wiki/List_of_Areas_(Pet_Simulator_99)) and [Spawn World area template](https://pet-simulator.fandom.com/wiki/Template:PS99SpawnWorldAreaList) [WIKI].

- **Scale:** 274 unlockable areas across 4 worlds and 8 sub-worlds.
- **Area 1 "Spawn"** holds every meta system: Shop, Mailbox, Social Rewards, VIP-only zone, Group Rewards, Pet Box, Index Machine and **Leaderboards**.
- **Cost ladder:** Area 2 costs 900 coins, then 2.5k, 8k, 20k, 60k, 150k and 400k. That is roughly **x2.5-3 per area**, before switching currency to gold bars.
- **Biome sequence (World 1):** Colorful Forest, Castle, Green Forest, Autumn, Cherry Blossom, Farm, Backyard, Misty Falls, Mine, Crystal Caverns, Dead Forest, Dark Forest, Mushroom Field, Enchanted Forest, Crimson Forest, Jungle, Jungle Temple, Oasis, Beach, Coral Reef, Shipwreck, Atlantis, Palm Beach, Tiki, Pirate Cove, ... Wild West, Grand Canyons, Safari, Mountains, Snow Village, Icy Peaks, Ice Rink.
- **Arc:** temperate and bright first, then dark, then tropical and underwater, then arid, then cold. Each area also carries one "facility" (vending machine, minigame or upgrade).

### 1.3 Bee Swarm Simulator: gated mountain ascent

Sources [WIKI]: [Honey Bee Gate](https://bee-swarm-simulator.fandom.com/wiki/Honey_Bee_Gate), [Bear Gate](https://bee-swarm-simulator.fandom.com/wiki/Bear_Gate), [Mountain Top Field](https://bee-swarm-simulator.fandom.com/wiki/Mountain_Top_Field), [Hive](https://bee-swarm-simulator.fandom.com/wiki/Hive), [Fields](https://bee-swarm-simulator.fandom.com/wiki/Fields).

**Gates by bee count:** [Basic Bee Gate (5)](https://bee-swarm-simulator.fandom.com/wiki/Basic_Bee_Gate), then [Brave Bee Gate (10)](https://bee-swarm-simulator.fandom.com/wiki/Brave_Bee_Gate), then the **Honey Bee Gate (15 bees)**, then the Lion Bee Gate (25), then the **Bear Gate (30)**, then the Windy Bee Gate (35, which leads to [Pepper Patch](https://bee-swarm-simulator.fandom.com/wiki/Pepper_Patch) and Coconut Field).
- Gates are named after the **giant statue on top**, for example "the large Honey Bee located on top of it".
- The Bear Gate is "the largest gate in the game".
- **Each gate is a landmark.**

**Layout:**
- The Honey Bee Gate leads to 4 fields (Cactus, Pumpkin, Pine Tree and Rose). It "holds the **ramp** that leads to the Lion Bee Gate".
- Shortcuts use teleporters and cannons (Red Teleporter, Blue Cannon).
- The progression **climbs**: Mountain Top Field (25 bees) is high up, past the Lion Bee Gate. It is 24x28 flowers (672).

**Spawn and guidance:**
- New players "must first claim a hive by **following a red arrow**".
- There are 6 hives per server, so there are 6 player "plots".
- Bypassing a gate early teleports you back to spawn (2019-09-28 update).

**Retention:** 65K-145K daily CCU after 8 years ([RoWatcher 2026](https://rowatcher.com/news/the-simulation-takeover-why-casual-sims-rule-roblox-in-2026)) [COMMUNITY].

### 1.4 Grow a Garden: symmetric plot quadrants

Source: [GAG wiki, Map](https://growagarden.fandom.com/wiki/Map) [WIKI].
- "a large island with **4 Garden Plots** (formerly 6 until the developers changed the server size), **shops at the sides** of the map and an **event hub in the middle**."
- "if players fall down, they will **respawn at their own garden plots**."
- The Garden Ascension shop is on a corner beside the Sell stand. The Seed Shop restocks every 5 minutes.

**Aerial wiki screenshot** ([image](https://static.wikia.nocookie.net/growagarden/images/1/1f/GrowaGardenMap.png)), viewed by me:
- A flat **square** green island.
- 4 identical fenced plots, one per quadrant. Each plot has 2 dirt beds of 4 rows.
- Shop stalls with striped awnings in a column on the left and right edges.
- A small round hub dead centre.
- Large empty grass margins, i.e. **negative space**.

**Measured colours from that screenshot [MEASURED, median of a patch]:**
- Grass #7CBD6A.
- Dirt beds #B57B56, close to BrickColor *Dark nougat* #AE7A59.
- Sky backdrop #B8DADF.

**Style:** "studded textures evocative of old-school Roblox games" ([Wikipedia](https://en.wikipedia.org/wiki/Grow_a_Garden)) [WIKI]. The Halloween thumbnail ([image](https://tr.rbxcdn.com/180DAY-78f2b15356e4ddf02eb8e11dc91c9e5a/768/432/Image/Png/noFilter)) shows a pumpkin built from **stud-covered cubes**, plank fences and a studded green plot (#226D01 under orange event lighting) [MEASURED].

**Onboarding:** "players can plant a seed or cast a line within their first 30 seconds" ([RoWatcher](https://rowatcher.com/news/the-simulation-takeover-why-casual-sims-rule-roblox-in-2026)) [COMMUNITY].

### 1.5 Steal a Brainrot: two-row bases along a central lane

- "A conveyor belt bisects the map". Players buy from it, and each base has a temporary-shield button ([Wikipedia](https://en.wikipedia.org/wiki/Steal_a_Brainrot)) [WIKI].
- Bases grow to "3 floors at max rebirths" ([SAB wiki, Map](https://stealabrainrot.fandom.com/wiki/Map)) [WIKI].
- The interactive map lists Bases 1-8, a "Brainrot Carpet" and a Shop ([Map:Main](https://stealabrainrot.fandom.com/wiki/Map:Main)) [WIKI].

**Wiki aerial image** ([image](https://static.wikia.nocookie.net/stealabr/images/0/07/Imageasd.png)), viewed by me:
- A rectangular walled compound.
- **8 identical base buildings, 4 per side in 2 rows**, all facing a central brown walkway that runs the long axis.
- Each base has a bright green entry pad facing the lane.
- A dark perimeter wall.

**Measured colours [MEASURED]:**
- Grass #46954F, about BrickColor *Bright green* #4B974B.
- Lane #A5755A, about *Dark nougat*.
- Base roofs #ABACB6, about *Medium stone grey* #A3A2A5.
- Wall #47413B.

**Thumbnail** ([image](https://tr.rbxcdn.com/180DAY-cd8594740f0d77e99b77f85a8697658c/768/432/Image/Png/noFilter)): an **orange studded carpet** (#FF9600) through studded green grass (#28B838), and bases with red laser-bar fronts.

**Contrast note [DERIVED]:** the lane and the grass separate by **hue only**, with a WCAG luminance ratio of about 1.07:1. Grow a Garden's dirt against grass is 1.58:1. Real hits get away with this, but see the readability rule in section 3.7.

### 1.6 Ride A Pet and Steal An Egg: movement-stat gating

- **Ride A Pet:** "Find Eggs Around The Map. Hatch Rarer & Faster Pets to Find Rarer Eggs" [OFFICIAL description]. The gate is **speed and reach**, not doors. StudioKrew mentions a later "Volcano Island" area.
- **Steal An Egg:** "Upgrade your treadmill and base. Train on the treadmill to gain Speed" [OFFICIAL description].

**Map implication [DERIVED]:** put the rarer content **farther away or higher up**. Distance becomes the difficulty ladder, with no walls needed.

### 1.7 Other genre data points

- **Commercial templates on BuiltByBit** (reference only; never import) [COMMUNITY]:
  - A "Roblox Simulator Map 375x375" (published Mar 2026, updated May 2026) contains a spawn area, egg models, a shop, leaderboard displays, a mining zone and a woodcutting zone ([listing](https://builtbybit.com/resources/roblox-simulator-map-375x375.97725/)).
  - A Grow a Garden-style map has "6 Garden Plots: Fully fenced areas, each containing 4 sub-plots" ([listing](https://builtbybit.com/resources/grow-a-garden-style-map.102181/)).
  - **About 375x375 studs is the market's standard simulator footprint**, close to our 300x300.
- **creation.dev simulator guide (Feb 2026)** ([link](https://www.creation.dev/blog/roblox-simulator-game-guide)) [COMMUNITY]:
  - Start players in a **central hub with paths leading to areas**, and **show locked areas from the hub** so goals are visible.
  - Use 5-8 areas, each taking 30-60 min. Unlock examples are 1,000, 10,000 and 100,000 currency.
  - Escalate visuals by tier: starter areas simple and clean, mid-game with more detail and FX, endgame with particles, lighting and distinctive architecture.
- **DevForum "How to Make A Simulator Map Part 1"** (ShadowKartX, 2021-07-11) ([link](https://devforum.roblox.com/t/how-to-make-a-simulator-map-part-1/1343396)) [COMMUNITY]:
  - Steps: forest-green baseplate resized to **200x5x200**, then border walls rotated 45 deg, then a shop and sell area with 3D text, then trees, then mushrooms in varied colours, then paths lined with rocks.

### 1.8 Synthesis: the simulator map grammar [DERIVED from 1.1-1.7]

| Pattern | Used by | Spawn | Progression | Guidance |
|---|---|---|---|---|
| **Linear route** | Lift a Cube, Lift A Weight, Lift a Building | One end | Bands along the route (grass, sand, ice) with heavier objects | Ground arrows, pads, giant object at the end, SPAWN-return button |
| **Hub-and-spoke ladder** | PS99, generic sims | Central hub with shop and leaderboards | Paid gates at roughly x2.5-10 cost per area | Locked areas visible from the hub |
| **Symmetric plots** | Grow a Garden | Own plot | Vertical (plants grow), not spatial | Shops on edges, event hub centre |
| **Two-row lane** | Steal a Brainrot | Own base | Base floors (rebirths) | Everything faces one central lane |
| **Vertical ascent** | Bee Swarm | Hive row at the bottom | Gates at 5/10/15/25/30/35 bees, ramps up the mountain | Red arrow to hive, statue-topped gates, peak visible |
| **Distance or speed ladder** | Ride A Pet, Steal An Egg | Hub | Farther or higher means rarer | Visible far content |

---

## 2. Visual language

### 2.1 Official BrickColor palette (hex from the Roblox RGB table)

Source: [BrickColor reference](https://create.roblox.com/docs/reference/engine/datatypes/BrickColor) [OFFICIAL]. Use the name in `BrickColor.new("...")`, or the hex via `Color3.fromHex`.

| Family | BrickColor name: hex |
|---|---|
| Greens | Bright green #4B974B, Shamrock #5B9A4C, Sea green #348E40, Moss #7C9C6B, Earth green #27462D, Slime green #506D54, Grime #7F8E64, Mint #B1E5A6, Light green (Mint) #C2DAB8, Pastel green #CCFFCC, Lime green #00FF00 |
| Earth and wood | Reddish brown #694028, Burnt Sienna #6A3909, Dark nougat #AE7A59, Nougat #CC8E69, Linen #AF9483, Cocoa #562424, Pastel brown #FFCC99 |
| Sand and yellow | Brick yellow #D7C59A, Light brick yellow #F0D5A0, Sand yellow #958A73, Cool yellow #FDEA8D, Daisy orange #F8D96D, Bright yellow #F5CD30, New Yeller #FFFF00, Pastel yellow #FFFFCC |
| Stone and neutral | Institutional white #F8F8F8, White #F2F3F3, Lily white #EDEAEA, Phosph. White #ECE8DE, Medium stone grey #A3A2A5, Dark stone grey #635F62, Really black #111111 |
| Blues | Pastel light blue #AFDDFF, Pastel Blue #80BBDB, Light blue #B4D2E4, Bright blue #0D69AC, Electric blue #0989CF, Cyan #04AFEC, Toothpaste #00FFFF, Teal #12EED4, Pastel blue-green #9FF3E9, Navy blue #002060 |
| Warm accents | Bright orange #DA8541, Neon orange #D5733D, Deep orange #FFB000, Persimmon #FF5959, Salmon #FF9494, Really red #FF0000, Crimson #970000, Maroon #750000 |
| Pinks and purples | Carnation pink #FF98DC, Pink #FF66CC, Hot pink #FF00BF, Light pink #DC9095, Pastel orange #FFC9C9, Pastel violet #B1A7FF, Alder #B480FF, Lavender #8C5B9F, Magenta #AA00AA, Seashell #E9DADA |

### 2.2 Zone palettes [DERIVED]

These are built from the BrickColors above and anchored by the measured real-game colours in section 1. Every hex below is an official BrickColor.

**Roles in each row:**
- **Ground** is the dominant one, covering about 60% of the frame.
- **Path** must differ from Ground in hue, and in luminance as well where you can manage it (aim for 1.5:1 or more).
- **Accent** is for interactables and rewards. Use 1-2 per zone and keep them **only** on interactive things.
- **Neon** is the glow accent, used sparingly.

| Zone | Ground | Path | Rock / structure | Foliage / props | Accent (interactables) | Neon accent | Sky / Atmosphere tint |
|---|---|---|---|---|---|---|---|
| Grass / spawn | Shamrock #5B9A4C or Bright green #4B974B | Light brick yellow #F0D5A0 (2.39:1 vs Shamrock) or Dark nougat #AE7A59 (hue-only) | Medium stone grey #A3A2A5 | Sea green #348E40, Reddish brown #694028 trunks, Bright yellow #F5CD30 flowers | Bright blue #0D69AC, Bright yellow #F5CD30 | Toothpaste #00FFFF (pads) | Pastel light blue #AFDDFF |
| Desert | Brick yellow #D7C59A | Sand yellow #958A73 (2.0:1) | Nougat #CC8E69, Dark nougat #AE7A59 | Shamrock #5B9A4C cacti, Burnt Sienna #6A3909 | Bright orange #DA8541, Persimmon #FF5959 | Deep orange #FFB000 | Cool yellow #FDEA8D (Atmosphere Color) |
| Snow / ice | Institutional white #F8F8F8 | Pastel Blue #80BBDB packed ice | Dark stone grey #635F62 (5.9:1 vs snow) | Earth green #27462D pines, Pastel light blue #AFDDFF ice | Electric blue #0989CF, Really red #FF0000 | Cyan #04AFEC | Light blue #B4D2E4 |
| Lava | Really black #111111 or Dark stone grey #635F62 basalt | Cocoa #562424 crust | Maroon #750000, Crimson #970000 | Burnt Sienna #6A3909 dead wood | Deep orange #FFB000 | Neon orange #D5733D or Really red #FF0000 lava (5.7:1 vs basalt) | Persimmon #FF5959 haze |
| Candy | Carnation pink #FF98DC | Institutional white #F8F8F8 (1.83:1) | Pastel violet #B1A7FF, Pastel blue-green #9FF3E9 | Mint #B1E5A6, Pastel yellow #FFFFCC, Cocoa #562424 "chocolate" | Hot pink #FF00BF, Bright blue #0D69AC | Pink #FF66CC | Pastel orange #FFC9C9 |
| Space | Navy blue #002060 or Really black #111111 | Medium stone grey #A3A2A5 moon rock | Dark stone grey #635F62 | Lavender #8C5B9F, Alder #B480FF crystals | Teal #12EED4, New Yeller #FFFF00 | Toothpaste #00FFFF (12.2:1 vs navy), Magenta #AA00AA | Night ClockTime, dark Atmosphere |

**Palette rules [DERIVED, consistent with sources]:**
- **One hue family per zone.** Ruski: "Assign each location its own color palette" ([Ruski #5, 2025-03-17](https://devforum.roblox.com/t/ruskis-tutorial-5-how-to-design-an-open-world-map/3554962)) [COMMUNITY].
- **Reserve the brightest saturated accent for gameplay objects.**
- Roblox's greybox tutorial colour-codes left and right floors (Persimmon vs Lapis) so "Colors orient players to their position" ([Roblox env-art greybox](https://create.roblox.com/docs/tutorials/curriculums/environmental-art/greybox-your-environment)) [OFFICIAL]. Keep that orientation coding in the art pass.

### 2.3 Materials

**Plastic and SmoothPlastic:**
- Plastic is the default for new Parts. Plastic and SmoothPlastic share default colour [163,162,165] and differ in friction (0.3 vs 0.2) ([Materials](https://create.roblox.com/docs/parts/materials)) [OFFICIAL].
- **SmoothPlastic** is the cartoon or low-poly norm. DevForum builders say cartoon is "mostly associated with smooth textures such as smooth plastic" ([DevForum low-poly thread](https://devforum.roblox.com/t/how-can-i-make-a-low-poly-build/539908)) [COMMUNITY].
- Use **Plastic** when you want a hint of surface noise.

**Neon:**
- Neon renders full-bright. With a BloomEffect, light-coloured parts glow ([Post-processing](https://create.roblox.com/docs/environment/post-processing-effects)) [OFFICIAL].
- Bloom's Threshold "may affect Neon parts" ([Guide to Lighting, 2023-12-26](https://devforum.roblox.com/t/guide-to-lighting/2764787)) [COMMUNITY].
- Use Neon for pad rims, crystals, lava, portal frames and arrows only [DERIVED].

**Glass:** "Refraction of light through the glass material is **not supported on mobile**" ([Materials](https://create.roblox.com/docs/parts/materials)) [OFFICIAL]. Glass is also partial transparency, which means overdraw (section 4). Use it rarely.

**Memory:** "Built-in materials use far less memory than custom textures" ([Design for performance](https://create.roblox.com/docs/performance-optimization/design)) [OFFICIAL].

**Studs:**
- `Enum.SurfaceType.Studs` (value 3) still exists: "Adds square studs across the surface". So do `Inlet` and `Universal` ([SurfaceType](https://create.roblox.com/docs/reference/engine/enums/SurfaceType)) [OFFICIAL].
- Studio's Surface UI was removed, so set it by script, e.g. `part.TopSurface = Enum.SurfaceType.Studs` ([DevForum](https://devforum.roblox.com/t/the-surface-option-is-missing/1230191)) [COMMUNITY]. Because Claude builds via `execute_luau`, this is trivial.
- **Alignment [DERIVED]:** studs tile per stud from the part edge. Keep part sizes and positions on **whole-stud values** so stud rows line up across neighbouring parts.
- **Use case:** studs are the 2025-26 "old-school" signature (Grow a Garden, Steal a Brainrot, Lift a Cube thumbnails). Use them on ground and plots, and keep props SmoothPlastic to avoid visual noise [DERIVED].

### 2.4 Outlines, edges, gradients

**Highlight:**
- Up to **255** simultaneous Highlights per client; any beyond that are silently ignored. Disabled Highlights still use a slot ([Highlight](https://create.roblox.com/docs/reference/engine/classes/Highlight)) [OFFICIAL].
- Each highlighted object is drawn individually, which costs a draw call, and any visible highlight adds a post-process cost ([DevForum "Lights, camera, more highlights"](https://devforum.roblox.com/t/lights-camera-more-highlights/4061534)) [OFFICIAL staff post].
- **Use it for interactables only (pads, gates, eggs), never for scenery** [DERIVED].

**Fake outlines and edges [DERIVED]:**
- Trim edges with 0.2-0.4 stud strips one value step darker, such as Dark stone grey on Medium stone grey, or Reddish brown on Nougat. This gives "cel" edges without post-processing.
- Bevel big blocks with WedgeParts or CornerWedgeParts.
- Give ground plates a darker 1-stud "skirt" or lip so the plateau silhouette reads.

**Gradients:**
- `UIGradient` works on GuiObjects only, so it needs a SurfaceGui Frame on a part face. Avoid more than 6 colour stops ([UIGradient](https://create.roblox.com/docs/reference/engine/classes/UIGradient)) [OFFICIAL].
- Rotated UIGradients inside some SurfaceGui structures render wrongly in the live client ([DevForum bug](https://devforum.roblox.com/t/rotated-uigradients-wrongly-apply-their-gradient-to-objects-inside-surfacegui-if-surfacegui-has-weird-structure-roblox-player-only/4000636)) [COMMUNITY].
- **Prefer** banding the gradient with 3-5 stacked parts in stepped colours, or baking vertex colours on a Blender mesh [DERIVED].

### 2.5 Low-poly props from primitives

Recipes are from [Nilo, "Easy Roblox Environmental Props" (2026-06-20, updated 2026-10-03)](https://www.nilo.io/articles/easy-roblox-environmental-props) [COMMUNITY] unless marked. Sizes in the right-hand column are mine [DERIVED], for a 5-stud-tall character.

| Prop | Construction (source) | Suggested stud sizes and colours [DERIVED] |
|---|---|---|
| Round tree | Trunk is 1 tall thin Cylinder (Wood). Canopy is **3-5 overlapping Spheres**: 1 big centre, 2 medium left and right, 1-2 small front and back. SmoothPlastic or Grass, dark green. Tilt the whole group a few degrees. 4-6 parts. Place in **clusters of 3-5**. | Trunk 2x10x2, Reddish brown #694028. Canopy balls 10, 7, 7 and 5 studs, Shamrock #5B9A4C plus one Sea green #348E40 ball for value variation. Total height about 16-18 (3x the character). |
| Pine (variant) | Not in Nilo. Cone stack, built from 3 shrinking 4-sided wedge pyramids or cylinder-plus-cone meshes. | Trunk 1.5x4. Tiers 10, 7.5 and 5 wide, Earth green #27462D. |
| Rock or boulder | 1 Block scaled unevenly (wider than tall), plus 2-3 smaller Blocks overlapping the edges at slight rotations. Slate or Cobblestone. Tilt so no face is flat. **CanCollide false** if decorative. 3-4 parts. | 6x4x5 base, Medium stone grey with a Dark stone grey chip. SmoothPlastic for stylized. |
| Bush | 3-4 Spheres scaled flat (low Y), offset. Grass, mid-green. | Each about 4x2.5x4, Moss #7C9C6B. |
| Fern | Thin flat Wedges fanned out from a centre. | 0.2x0.5x3 wedges, 6-8 of them. |
| Campfire | 5-6 thin Cylinders in a star, a Cone flame, a PointLight and a ParticleEmitter. Limit to 2-3 per area. | |
| Streetlight or lamp | Pole Cylinder, arm Cylinder rotated 90 deg, Sphere housing, downward SpotLight. **Shadows off** on decorative lights; only 1-2 hero lights cast shadows. | Pole 0.6x10. Neon housing #FDEA8D. |
| Crate | 1 Block (Wood), slightly non-uniform scale. Stack 2-3 at different rotations. | 3x3x3, Nougat #CC8E69 with Reddish brown 0.3-stud edge trims. |
| Sign | 1 flat Block board, 1 thin Cylinder post, SurfaceGui with TextLabel. | Board 8x3x0.4 on a post 0.6x6. Text ≥ 1.5 studs high (section 3.7). |
| Fence [DERIVED] | Posts 1x4x1 every 6-8 studs, two rails 0.5x0.5xL at heights 1.5 and 3. Grow a Garden uses plank fences around plots. | Reddish brown, or Institutional white for a picket look. |
| Cloud [DERIVED] | 4-7 overlapping white Spheres or Balls of mixed size, flattened bottom (one wide flat Cylinder). CanCollide, CanTouch and CanQuery off, CastShadow off. | Institutional white #F8F8F8, 20-40 studs long, 40-80 studs up. Thumbnails of Lift a Cube and Steal a Brainrot show puffy white clouds on cyan. |
| Flower [DERIVED] | Cylinder stem 0.2x1, 4-5 small Balls around a centre Ball. | Bright yellow, Persimmon, Carnation pink, Pastel violet. |
| Mushroom | Built in ShadowKartX's tutorial with varied colours ([DevForum](https://devforum.roblox.com/t/how-to-make-a-simulator-map-part-1/1343396)). Stem Cylinder plus half-Ball cap [DERIVED]. | Cap Persimmon #FF5959 with white dots. |

**Prop rules:**
- **Use MeshParts instead of Unions**, and CollisionFidelity Box for decorative props [Nilo].
- Builders who make trees from parts only fill gaps with Stravant's **GapFill and Extrude** plugin ([DevForum 2020-08-07](https://devforum.roblox.com/t/low-poly-tree-without-blender/712036)) [COMMUNITY]. Claude can compute gap-filling wedges itself [DERIVED].
- **Blender route** ([ShadowKartX 2021](https://devforum.roblox.com/t/how-to-make-a-low-poly-tree/1344712)) [COMMUNITY]: a Skin modifier on extruded vertices for the trunk, a bevelled cube for leaves, export OBJ, then Bulk Import.

### 2.6 Lighting for the clean bright simulator look

**State of the API (2026):**
- `Lighting.Technology` is **deprecated**. It is "superseded by LightingStyle" plus `PrioritizeLightingQuality`, and is read-only and non-scriptable ([Lighting class](https://create.roblox.com/docs/reference/engine/classes/Lighting), [Technology enum](https://create.roblox.com/docs/reference/engine/enums/Technology)) [OFFICIAL].
- **LightingStyle Realistic** gives "the most advanced lighting and shadows". **Soft** gives a "flat, retro-Roblox look with softer lights and shadows" ([Global lighting](https://create.roblox.com/docs/environment/lighting)) [OFFICIAL].
- Studio's default is **Soft**. Roblox's core tutorial changes it "from the default Soft" to Realistic so local lights cast shadows ([Customize global lighting](https://create.roblox.com/docs/tutorials/curriculums/core/building/customize-global-lighting)) [OFFICIAL].
- `PrioritizeLightingQuality`: `true` keeps advanced shadows and shaders when quality scales down, while `false` keeps view distance. "Soft LightingStyle with PrioritizeLightingQuality enabled uses shadow maps instead of voxel lighting" ([Lighting class](https://create.roblox.com/docs/reference/engine/classes/Lighting)) [OFFICIAL].
- **Retro look:** `ColorGradingEffect.TonemapperPreset = Retro` imitates the pre-2019 look (less saturation and contrast). Default is the vivid, high-contrast post-2019 look ([Post-processing](https://create.roblox.com/docs/environment/post-processing-effects)) [OFFICIAL].

**Lighting class defaults** ([Lighting class](https://create.roblox.com/docs/reference/engine/classes/Lighting)) [OFFICIAL]: Ambient [0,0,0], OutdoorAmbient [127,127,127], EnvironmentDiffuseScale 0, EnvironmentSpecularScale 0, ExposureCompensation 0 (range -5 to 5), ShadowSoftness 0.2. Voxel lighting cells are 4x4x4 studs.

**Values seen in the wild:**

| Source | Values |
|---|---|
| Roblox core tutorial, stylized-realistic island ([link](https://create.roblox.com/docs/tutorials/curriculums/core/building/customize-global-lighting)) [OFFICIAL] | Ambient 16,16,16 · ColorShift_Top 196,222,255 · OutdoorAmbient 134,158,190 · LightingStyle Realistic · ShadowSoftness 0 · ClockTime 9 · GeographicLatitude 78 · Atmosphere Density 0.375, Offset 0.17 |
| DevForum "Cartoon lighting settings?", Simulation_Studio, 2019-08-18 ([link](https://devforum.roblox.com/t/cartoon-lighting-settings/333686)) [COMMUNITY] | Ambient 163,163,163 · OutdoorAmbient 128,128,128 · Brightness 2.67 · ShadowMap with Softness 0.27 (or Voxel) · ColorCorrection Contrast 0.1, Saturation 0.3, Tint 241,241,231 · SunRays on · avoid Bloom |
| Same thread, The_Harbinger [COMMUNITY] | Bloom 1 / 25 / 2 (Intensity / Size / Threshold) · Blur 4 (others: "never put Blur higher than 2") · CC Contrast 0.2, Saturation 0.6 |
| [Guide to Lighting (2023-12-26)](https://devforum.roblox.com/t/guide-to-lighting/2764787) [COMMUNITY] | Fog properties are deprecated, so use Atmosphere. CC Contrast > 1 looks "deep-fried". Atmosphere is invisible with the default skybox. Small ColorShift changes only. |

**Atmosphere semantics:** Offset raises a horizon silhouette when increased, and blends distant objects into the sky when decreased. Decay needs Haze and Glare above 0 to show ([Atmospheric effects](https://create.roblox.com/docs/environment/atmosphere)) [OFFICIAL].

**Synthesized "Bright Simulator" preset [DERIVED]** (starting point, tune in Studio):

```lua
local L = game:GetService("Lighting")
L.LightingStyle = Enum.LightingStyle.Soft          -- flat, retro-Roblox look (Studio default)
L.PrioritizeLightingQuality = false                -- keep view distance on low-end phones
L.Brightness = 2.5                                  -- 2-3; DevForum cartoon value 2.67
L.ClockTime = 13.5                                  -- high sun = short shadows, max colour
L.GeographicLatitude = 30
L.Ambient = Color3.fromRGB(140, 140, 150)           -- between 0 default and DevForum 163 grey
L.OutdoorAmbient = Color3.fromRGB(150, 150, 160)    -- lifts shadow sides, cartoon-flat
L.ColorShift_Top = Color3.fromRGB(255, 245, 225)    -- slight warm sun; keep subtle
L.ColorShift_Bottom = Color3.fromRGB(0, 0, 0)
L.EnvironmentDiffuseScale = 1
L.EnvironmentSpecularScale = 0.2                    -- low: SmoothPlastic stays matte
L.GlobalShadows = true
L.ShadowSoftness = 0.3                              -- DevForum 0.27
L.ExposureCompensation = 0
-- Atmosphere: thin, so the far weenie stays readable
-- Density 0.25, Offset 0.1, Color = zone sky tint (2.2), Decay 106,112,125, Haze 0, Glare 0
-- ColorCorrectionEffect: Saturation 0.15-0.3, Contrast 0.05-0.1, TintColor 255,253,245
-- BloomEffect: Intensity 0.5-1, Size 24, Threshold 1.8-2 (only Neon and near-white bloom)
-- SunRaysEffect: Intensity 0.05, Spread 0.5
```

Per-zone overrides [DERIVED]:
- Lava: ClockTime 18-19, Atmosphere Color Persimmon, Density 0.35.
- Snow: ColorShift_Top a cool 225,240,255, Saturation 0.1.
- Space: ClockTime 0, OutdoorAmbient 90,90,130, Neon carries the scene.
- Implement overrides with zone-entry tweens on the client only if the map needs them. A static showcase can pick one global look.

---

## 3. Universal level design principles, applied to Roblox

### 3.1 Character and movement metrics

**Official values:**

| Metric | Value | Source |
|---|---|---|
| Walk speed | **16 studs/s** (StarterPlayer.CharacterWalkSpeed) | [Humanoid](https://create.roblox.com/docs/reference/engine/classes/Humanoid), [StarterPlayer](https://create.roblox.com/docs/reference/engine/classes/StarterPlayer) |
| Jump | JumpHeight **7.2 studs** (when UseJumpPower = false) or JumpPower **50** (CharacterUseJumpPower class default true) | StarterPlayer, Humanoid |
| Gravity | **196.2 studs/s²** | [Workspace](https://create.roblox.com/docs/reference/engine/classes/Workspace) |
| Max walkable slope | MaxSlopeAngle **89 deg** default | Humanoid |
| Climb speed | Ladders and Truss at **70%** of WalkSpeed | Humanoid |
| Camera | FieldOfView **70 deg vertical** (clamped 1-120) | [Camera](https://create.roblox.com/docs/reference/engine/classes/Camera) |
| Scale | **1 stud ≈ 28 cm** | [Core greybox tutorial](https://create.roblox.com/docs/tutorials/curriculums/core/building/greybox-a-playable-area) |
| Spawn | SpawnLocation ForceField `Duration` default **10 s**; random pick among eligible spawns | [SpawnLocation](https://create.roblox.com/docs/reference/engine/classes/SpawnLocation) |
| Part limits | Size up to 2048 per axis; below 0.05 is physically treated as 0.05 | [BasePart](https://create.roblox.com/docs/reference/engine/classes/BasePart) |
| Doorways and hallways | **≥ 10 studs wide** so two users pass, and to stop camera clipping | [Env-art greybox](https://create.roblox.com/docs/tutorials/curriculums/environmental-art/greybox-your-environment) |
| Blocking walls | **≥ 10 studs tall**. The doc says the default jump height is "5 studs", which conflicts with 7.2; 10 still clears both. | same |
| Combat pockets | ≤ 3 entrances or exits; spawn rooms 2 exits | same |
| Greybox snap | **5 studs move, 90 deg rotate** | same |
| Jump-gated platforms | each new height tier ≥ 30 studs above the last; test with JumpPower raised in steps of 30 | [Core greybox](https://create.roblox.com/docs/tutorials/curriculums/core/building/greybox-a-playable-area) |
| Character height | R6 = 5 studs; R15 ≈ **5.12** studs (community measurement) | [DevForum measurement](https://devforum.roblox.com/t/measurement-conversion/137419) [COMMUNITY] |

**Derived jump and travel numbers [DERIVED]:**
- Ballistics use g = 196.2 and run speed 16 studs/s.
- **JumpHeight 7.2:** v0 = 53.2, airtime 0.54 s, **flat gap max ≈ 8.7 studs**. Onto a ledge 2 / 4 / 6 studs higher the max gap is about 8.0 / 7.2 / 6.1 studs. Down 4 / 10 studs it is about 9.7 / 11.0.
- **JumpPower 50:** peak height 6.37, airtime 0.51 s, **flat gap max ≈ 8.2**. Onto a ledge 4 studs higher the max gap is about 6.6.
- **Design limits:**
  - Optional parkour gaps ≤ 6 studs flat and ≤ 4 studs when climbing.
  - Ledges players must climb by jumping ≤ 4 studs.
  - Anything that must *block* a player ≥ 10 studs tall.
  - Mobile players use a touch jump button and auto-jump (`AutoJumpEnabled`, mobile only, per StarterPlayer), so never require precise jumps on the critical path.
- **Travel times on a 300x300 map:** centre to edge 150 studs = 9.4 s; edge to edge 300 = 18.75 s; diagonal 424 = 26.5 s.
- **Visible width on a phone:** vertical FOV 70 gives horizontal FOV ≈ 102 deg at 16:9 and ≈ 113 deg at 19.5:9 (modern phones), versus 86 deg at 4:3 (iPad). **Compose spawn views for the narrowest case: put key landmarks within ±40 deg of the spawn's facing direction.**

**Recommended build metrics for stylized maps [DERIVED]:**

| Element | Value (studs) | Why |
|---|---|---|
| Main path | 12-16 wide | ≥ 10 official minimum, plus crowd room (Ruski: open spawn sized for 12-20 players) |
| Secondary path | 8-10 | Narrower reads as "less important" (Rogers: main artery obvious) |
| Door (stylized) | 8 wide x 12 tall (exaggerated) | Big avatars and camera; real-scale doors look tiny on Roblox characters |
| Interior ceiling | ≥ 14 | The third-person camera needs headroom (official: minimums prevent camera clipping) |
| Stairs | rise 1 x run 2 (or wedge ramps) | MaxSlopeAngle 89 means wedges always work and are cheaper. Real stairs are about 32 deg (LDB "7-11"). |
| Railing / low wall | 3 | Below jump height: decorative, not blocking |
| Gate / blocking wall | ≥ 12 | ≥ 10 official, with margin over 7.2 |
| Zone plateau step | 4-8 per tier | Readable elevation; ramp between tiers |
| Pads (interact) | 8x1x8 (min 6x6) | Big touch target, readable from 30+ studs |
| Spawn plaza | 40x40 to 60x60 | 12-20 players (Ruski) |
| Landmark (weenie) | 40-80 tall | At 150-300 studs, a 30-60 stud object fills about 16% of screen height |

### 3.2 Landmarks, silhouettes and "weenies"

- **Weenie** is Walt Disney's term for a big landmark that pulls guests toward it, after the hot dog he used to lead his poodle. Sleeping Beauty Castle at the hub is the canonical example ([Scott Rogers GDC 2009 notes](https://craphound.com/disneylandleveldesign.txt), [Boing Boing summary](https://boingboing.net/2009/03/27/gamedesign-lessons-f.html)) [COMMUNITY].
- **Rogers' rules:**
  - Place a large landmark visible from a distance.
  - **Reveal new landmarks as players progress** (peaks over the horizon).
  - Use **elevation changes**.
  - Use switchbacks to show new info.
  - Make "picture spots".
  - Use a **linear approach that opens into a hub where several destinations are visible**.
- **Ruski #5 (2025-03-17)** ([link](https://devforum.roblox.com/t/ruskis-tutorial-5-how-to-design-an-open-world-map/3554962)) [COMMUNITY]:
  - Give every POI **one distinct prominent landmark** (tower, statue, bridge, unusual building) and add verticality.
  - Put landmarks at corners where players slow to turn.
  - **Triangle rule:** "populate the horizon line with at least three POIs".
  - Space POIs about 40 s apart in a full open world. **On a 300-stud map scale this down to 5-8 s, or 80-130 studs [DERIVED].**
- **Hide and reveal:** periodically block the landmark, then reveal it from a new angle ([gamedev.net](https://gamedev.net/blogs/entry/2277800-should-players-be-hand-held)) [COMMUNITY].
- **Level Design Book:** "Place a tall landmark in the distance with a wide sightline". Players "look up only when something draws their eye". Contrast in colour, shape, lighting and movement draws attention ([LDB Wayfinding](https://book.leveldesignbook.com/process/blockout/wayfinding)) [COMMUNITY].
- **Simulator applications:**
  - Bee Swarm tops each gate with a giant statue.
  - Lift games use the final object as the weenie.
  - PS99 and creation.dev show **locked areas from the hub**.
  - **Silhouette test [DERIVED]:** each zone's landmark must be identifiable as a flat black shape, so give each a different primary form (spire, dome, arch, giant object).

### 3.3 Leading lines, framing, focal points, composition from the spawn view

**Leading lines:** paths, fences, rows of lamps or trees, river edges and stud-carpet strips that converge on the next goal.
- LDB examples: planks off a ledge, train tracks, scratched ledge markers. "Light placement can imply a path" ([LDB Wayfinding](https://book.leveldesignbook.com/process/blockout/wayfinding)).
- **Breadcrumbs:** lines of collectibles lead the player (Donkey Kong Country). In sims, coins, orbs or pads in a line do this [LDB].
- Lift a Cube uses **white ground arrows** and Bee Swarm a **red arrow** to the hive [section 1].

**Framing:** frame the key view with a window, arch or gate, and point framing elements outward toward the intended view. Keep detail dense where you want inspection and sparse where you don't ([LDB Wayfinding](https://book.leveldesignbook.com/process/blockout/wayfinding)).

**Spawn view composition checklist [DERIVED from all above]:**
1. The SpawnLocation faces the hub's main axis. Characters spawn on the SpawnLocation; set its orientation and verify in a playtest.
2. From the spawn camera, within ±40 deg, the player should see:
   - (a) the first objective, 10-30 studs away;
   - (b) a path leading off;
   - (c) **at least 3 POIs on the horizon** (triangle rule);
   - (d) the end-game weenie, tall and partly occluded (a tease).
3. Use a gate or arch as a frame for the first zone.
4. Leave nothing on screen that is a blank wall: "players should ALWAYS be looking at something intriguing" ([Ruski #1](https://devforum.roblox.com/t/ruskis-tutorial-1-how-to-design-a-map-layout/277853)).
5. Set the ForceField `Duration = 0` on non-combat simulator spawns. The 10 s default exists for anti-spawn-kill only.

### 3.4 Light, value and contrast as guidance

- **Squint test** (Rogers): light the main route brightest, so blurred eyes still find the path. Darken everything except the exit to signal leaving. Keep the exit path lit and unthreatening ([notes](https://craphound.com/disneylandleveldesign.txt)).
- **Robert Yang, GDC 2018** ("Level Design Workshop: Invisible Intuition", with David Shaver of Naughty Dog: [GDC Vault](https://gdcvault.com/play/1025179/Level-Design-Workshop-Invisible-Intuition), [Yang's slides and notes](https://www.blog.radiator.debacle.us/2018/03/gdc-2018-how-to-light-level-slides-and.html)) [COMMUNITY]:
  - Graybox first.
  - Set global light first.
  - Light the critical path and exits.
  - Build a **lighting hierarchy**: main routes brighter than side routes.
  - Rim-light setpieces against the background.
  - Keep the lighting language consistent.
  - **Choose brighter albedos in the upper midtones**, because dark albedos go darker than expected.
- **In a stylized day map [DERIVED]:** guidance comes from **colour and value**, not lamps. Use the zone accent only on interactables, and a Neon rim on pads and gates. A brighter path against the darker ground gives ≥ 1.5:1 luminance where possible.

### 3.5 Negative space and density

- **Always something to look at, no blank walls** ([Ruski #1](https://devforum.roblox.com/t/ruskis-tutorial-1-how-to-design-a-map-layout/277853)). Avoid boxy shapes: curves and jogs help, a horseshoe shows the goal but forces a route, and a circle leads back to start.
- **Detail where players walk.** "Focus detail on main paths ... Decorate with large, bulky props", and recycle meshes by rotating and rescaling them ([Ruski #5](https://devforum.roblox.com/t/ruskis-tutorial-5-how-to-design-an-open-world-map/3554962)).
- **Negative space is real.** Grow a Garden's aerial view is mostly empty grass around 4 plots and 2 shop rows. Open lawn gives crowds room and keeps the phone frame readable.
- **Rule [DERIVED]:** every 30-40 studs of path, place one prop cluster of 3-5 items (Nilo's cluster size). Keep a clear margin of ≥ 4 studs around interactables so they read as figure against ground.

### 3.6 Layout typologies

**Level Design Book typologies** ([LDB Typology](https://book.leveldesignbook.com/process/layout/typology), [LDB Flow](https://book.leveldesignbook.com/process/layout/flow)) [COMMUNITY]:
- **Room typologies:** corridors, switchbacks, combat bowls, arenas and POIs.
- **Level typologies:** loopback, pass-through, branch and bottleneck, **hub-and-spoke**, time cave.
- **Flow:** speed, direction, wayfinding and metrics, designed through desire lines, the critical path and circulation.

**Mapping to `/make-map` stylized presets [DERIVED]:**
- **"Lift" preset:** a pass-through linear route of 3-5 biome bands on a curved S-path. A 300-stud map fits an S of about 600 studs of path; the hero object is at the end.
- **"Sim hub" preset:** hub-and-spoke. A spawn plaza in the centre with 4-6 gated spokes, each a plateau one step higher or deeper.
- **"Plots" preset:** a symmetric quadrant (Grow a Garden) or a two-row lane (Steal a Brainrot).
- **"Mountain" preset:** an ascending spiral (Bee Swarm) with ramps, and the peak as the weenie.

### 3.7 Sightlines and readability on a phone screen

**Audience:** "over half of all Roblox sessions are played on mobile devices" ([Mobile input](https://create.roblox.com/docs/input/mobile)) [OFFICIAL]. Third-party figures run up to about 80% of DAU on mobile, citing the 2024 annual report ([Gameranx](https://gameranx.com/updates/id/536101/article/roblox-has-a-surprising-amount-of-players-on-mobile-platforms/)) [COMMUNITY]. Roblox's cross-platform guide says to design for touch, gamepad and keyboard, and for any screen size ([Cross-platform](https://create.roblox.com/docs/projects/cross-platform)) [OFFICIAL].

**Phone readability rules [DERIVED; angles computed with FOV 70]:**
- **Sign text:**
  - Letters 2 studs high at 40 studs fill only 4.1% of screen height (about 3 mm on a phone).
  - Signs read from far away need **letters ≥ 3 studs** (6.1%).
  - Close signs (≤ 15 studs) need ≥ 1.5 studs.
  - Use a **light-on-dark or dark-on-light plate** with ≥ 4.5:1 contrast, and short words ("SELL", "EGGS", "ZONE 2 · 1K").
- **Prefer shape and colour signals over text.** Arrows, pad colours and giant icons (Lift a Cube prints "0.85s -> 0.72s" on the pad itself).
- **Readable at a glance:**
  - Big primitives, chunky silhouettes and few thin parts. Anything thinner than about 0.3 studs shimmers or vanishes at distance.
  - **Distinct hue per zone, plus a value difference between walkable and non-walkable surfaces.** Real hits rely on hue alone (lane vs grass about 1.07:1), which fails for colour-blind players. LDB recommends designing for colour-blind users via contrast ([LDB Wayfinding](https://book.leveldesignbook.com/process/blockout/wayfinding)).
- **Barriers:**
  - Deep, wide barriers (pits, lava, rivers) block movement but keep sightlines (95% certainty).
  - Hard barriers (walls, fences) block both (98%) ([LDB Wayfinding](https://book.leveldesignbook.com/process/blockout/wayfinding)).
  - Use the **former for gates you want players to see past**: a locked zone visible across a gap.
- **Fog:** Atmosphere Density ≤ 0.3 with a low Offset keeps the far weenie visible at 300 studs. Ruski uses fog deliberately to limit visibility in open worlds, but showcase maps want the opposite.

### 3.8 Blockout-first workflow (greybox, then art pass)

1. **Plan and sketch.** Ruski: "Plan before building", with notes, scribbles or paint-over screenshots, and reference photos. Rogers: design top-down (world, then land, then level, then experience), and give each area one dominant goal.
2. **Greybox in Studio** ([Env-art greybox](https://create.roblox.com/docs/tutorials/curriculums/environmental-art/greybox-your-environment)) [OFFICIAL]:
   - 5-stud and 90 deg snap.
   - Colour-code by function (Deep orange 255,176,0 for walls, Persimmon 255,89,89 and Lapis 16,42,220 for sides, Bright green 75,151,75 for elevation).
   - Meet the dimension minimums (10-stud halls and walls).
   - Use elevation to control sightlines.
3. **Folder discipline** ([Core greybox](https://create.roblox.com/docs/tutorials/curriculums/core/building/greybox-a-playable-area)) [OFFICIAL]:
   - Put blockout under `Workspace.World.Blockout_Parts`. The names are case-sensitive.
   - Anchor everything.
   - Align bases with the Align tool (Min, World Y).
   - Playtest by setting JumpPower to 0 and raising it in steps of 30 to simulate upgrades.
4. **Playtest at nearly every step.** Check that players can orient themselves, that no area offers too many choices, and that no section can be bypassed (env-art doc). Use Test (F5), **Test Here** and Run (F8).
5. **Metrics zoo:** build a dev-only test map with all your door, stair and gap sizes before the real map ([LDB Metrics](https://book.leveldesignbook.com/process/blockout/metrics)).
6. **Art pass:** replace greybox with kit pieces that match the art style. Robert Yang: lighting comes after layout, and the layout constrains the camera, which constrains where lights go.

**For Claude [DERIVED]:**
- After the greybox, take `screen_capture` views from spawn and each zone entrance, and check them against the 3.3 checklist **before** decorating.
- Keep greybox parts in a separate folder so the art pass can hide or delete them.

### 3.9 Modular kits and grid snapping

- **LDB:** "Use a large coarse grid based on module size (e.g. if wall modules are 5 m wide, set grid to 5)". Use vertex snapping. Modular kits bake metrics in, so changing kit grid assumptions later means a rebuild ([LDB Blockout](https://book.leveldesignbook.com/process/blockout), [LDB Metrics](https://book.leveldesignbook.com/process/blockout/metrics)) [COMMUNITY].
- **Bethesda reference:** Joel Burgess and Nathan Purkeypile, "Skyrim's Modular Approach to Level Design", GDC 2013 Level Design in a Day ([Game Developer write-up](https://www.gamedeveloper.com/design/skyrim-s-modular-approach-to-level-design)) [COMMUNITY].
- **Studio snapping** is in studs (move and scale) and degrees (rotate). Hold Shift to toggle it temporarily. Shift+2 jumps to the move increment ([Parts](https://create.roblox.com/docs/parts)) [OFFICIAL].
- **Recommendation for the skill [DERIVED]:**
  - **Blockout on a 4-stud grid** (or Roblox's 5).
  - Kit modules: floor tiles 8x8 or 16x16, wall segments 8 or 16 long x 12 tall, path tiles 16 wide, plateau steps 4.
  - All sizes and positions are whole studs, so SurfaceType.Studs and textures line up.
  - Detailing may drop to 1 or 0.5 studs.
  - Rotate in 90 deg for the kit and 15 deg (or free) for organic props.

---

## 4. Performance for stylized maps on phones

**Official rules** ([Improve performance](https://create.roblox.com/docs/performance-optimization/improve), [Design for performance](https://create.roblox.com/docs/performance-optimization/design), [Streaming](https://create.roblox.com/docs/workspace/streaming)) [OFFICIAL]:

**Budget:** example baseline "below **1,000 draw calls** and **1,000,000 triangles**". The frame budget is 16.67 ms at 60 FPS. Check with Shift+F2 (Render and Summary stats) and F9 memory. The Studio device emulator "isn't accurate for memory usage".

**Instancing:**
- MeshParts with the **same MeshContent** share one draw call when their SurfaceAppearance, or TextureContent, or Material matches.
- Import each mesh **once** and duplicate it in Studio, because the importer doesn't de-duplicate. Packages help.

**Shadows:**
- **Disable CastShadow on small parts**, especially distant ones, and on moving objects.
- Disable `Light.Shadows` where not needed, and use fewer lights with limited range.
- Shadows are disabled at quality levels below 4.

**Transparency:** partial transparency causes overdraw. Use only 0 or 1 where possible, and delete stacked transparent layers.

**Physics and collision:**
- Anchor everything static.
- CollisionFidelity: **Box** for small non-interactive props, **Box or Hull** for small-to-medium ones, custom invisible collider parts for big complex ones. Precise is the most expensive.
- Set CanCollide, CanTouch and CanQuery all to false on pure decor. Collision geometry still uses memory unless it is Box.

**RenderFidelity:** Automatic or Performance; avoid Precise on many meshes.

**Model size:** too many parts in one Model triggers more FastCluster rebuilds, so balance part counts per Model.

**Textures:** keep them ≤ 512x512, and most under 256x256. A 1024² texture uses 4x the memory of 512². Tint one texture rather than uploading colour variants. Use trim sheets.

**Asset reuse:** "By resizing, rotating, and overlapping, you can create rich, varied environments that require very few draw calls."

**Streaming:**
- StreamingEnabled is on by default for new places.
- StreamingMinRadius 64 is recommended as default. StreamingTargetRadius defaults to 1024.
- `ModelStreamingBehavior = Improved` and `StreamOutBehavior = Opportunistic` are recommended.
- `StreamingIntegrityMode = PauseOutsideLoadedArea` is recommended.
- Use `ModelStreamingMode` Atomic for multi-part props, so they never stream in half-built. Use Persistent "rare cases only".
- Set `Model.LevelOfDetail = SLIM` with streaming on.

**Community data:**
- About 20K parts is where issues "might start", in an extreme unanchored and colliding case. Anchored is "pretty much always better". There is no official cap ([DevForum 2018](https://devforum.roblox.com/t/part-count-and-lag/145280)).
- Unions carry unnecessary triangles and aren't batched (10 identical unions are drawn separately). Meshes beat unions for repeated detail ([DevForum](https://devforum.roblox.com/t/should-i-use-meshparts-instead-of-a-bunch-of-parts/295061)) [COMMUNITY].
- Nilo (2026) gives budgets of crates under 500 triangles and signs under 300 triangles.

**Budget for a 300x300 stylized showcase [DERIVED]:**
- **Instanced props:** build each repeated prop (tree, rock, fence segment, lamp) once. If it repeats more than about 10 times, export it via Blender as **one MeshPart** with vertex colours or a single tiny palette texture, then clone it, so every copy shares a MeshId.
- **One-off architecture** stays as Parts.
- **Part budget:**
  - Aim for ≤ 8-12K anchored BaseParts in total.
  - Aim for ≤ 300 draw calls and ≤ 300K triangles on screen, a comfortable margin under the 1,000 and 1M example.
  - Verify with Shift+F2 on a low-end phone, or at minimum with Studio quality level 1-3.
- **Shadows:** CastShadow = false on every part with a largest dimension ≤ 4 studs, all foliage balls, clouds, trims, decals and ground tiles. Keep shadows on landmarks, buildings and large rocks.
- **Ground:** use few large parts, not thousands of small tiles. Studs are a SurfaceType, so they cost no extra parts.
- **Lights:** ≤ 1-2 shadow-casting hero lights per zone. Neon and Bloom give "glow" without lights.
- **Glass and transparency:** avoid them. Glass refraction is off on mobile anyway.

---

## 5. Tutorials, talks and videos

| Resource | Type, date | URL | Actionable rules extracted |
|---|---|---|---|
| Roblox env-art curriculum: Greybox your environment | Official doc, current | https://create.roblox.com/docs/tutorials/curriculums/environmental-art/greybox-your-environment | 5-stud and 90 deg snap; ≥ 10-stud halls and walls; ≤ 3 exits per pocket; colour-code greybox; elevation controls sightlines; playtest every step |
| Roblox core curriculum: Greybox a playable area | Official doc | https://create.roblox.com/docs/tutorials/curriculums/core/building/greybox-a-playable-area | 7 height tiers, each ≥ 30 studs apart for jump upgrades; cylinder platforms; `World/Blockout_Parts`; JumpPower test in steps of 30; 1 stud ≈ 28 cm |
| Roblox core curriculum: Customize global lighting | Official doc | https://create.roblox.com/docs/tutorials/curriculums/core/building/customize-global-lighting | Exact Lighting and Atmosphere values (section 2.6) |
| Roblox: Improve performance / Design for performance / Streaming | Official docs | https://create.roblox.com/docs/performance-optimization/improve · https://create.roblox.com/docs/performance-optimization/design · https://create.roblox.com/docs/workspace/streaming | Section 4 |
| Ruski's Tutorial #1: How to design a map layout | DevForum, 2019 (updated 2022) | https://devforum.roblox.com/t/ruskis-tutorial-1-how-to-design-a-map-layout/277853 | Avoid boxy; horseshoe or circle shapes; spawn for 12-20 players; always something intriguing; clear boundaries; test the layout before detail |
| Ruski's Tutorial #5: How to design an open-world map | DevForum, 2025-03-17 | https://devforum.roblox.com/t/ruskis-tutorial-5-how-to-design-an-open-world-map/3554962 | One landmark per POI; triangle rule; POI spacing; biome palettes; soft and hard barriers; detail on main paths; recycle and rescale props; block out first |
| How to Make A Simulator Map Part 1 (ShadowKartX) | DevForum, 2021-07-11 | https://devforum.roblox.com/t/how-to-make-a-simulator-map-part-1/1343396 | Baseplate 200x5x200; 45 deg border walls; shop and sell with 3D text; tree, mushroom and rock dressing along paths |
| Cartoon lighting settings? | DevForum, 2019 | https://devforum.roblox.com/t/cartoon-lighting-settings/333686 | Numeric cartoon lighting values (section 2.6) |
| Guide to Lighting | DevForum, 2023-12-26 | https://devforum.roblox.com/t/guide-to-lighting/2764787 | Property semantics; Fog deprecated in favour of Atmosphere; CC limits |
| Easy Roblox Environmental Props (Nilo) | Blog, 2026-06-20, updated 2026-10-03 | https://www.nilo.io/articles/easy-roblox-environmental-props | Primitive prop recipes; MeshParts over Unions; Box collision; triangle budgets |
| Roblox simulator game guide (creation.dev) | Blog, 2026-02-16 | https://www.creation.dev/blog/roblox-simulator-game-guide | Central hub; show locked areas; 5-8 areas of 30-60 min; tiered visual escalation |
| The Level Design Book (Blockout, Metrics, Wayfinding, Flow, Typology, Massing) | Online book | https://book.leveldesignbook.com/process/blockout · /process/blockout/metrics · /process/blockout/wayfinding · /process/layout/flow · /process/layout/typology · /process/blockout/massing | Coarse grid equal to module size; metrics zoo; hall ≥ 2x player width; stairs about 32 deg with landings every 12-16 steps; landmarks, framing, breadcrumbs, barriers; additive massing and human-scale articulation |
| Scott Rogers, "Everything I learned about level design I learned from Disneyland" | GDC 2009 notes | https://craphound.com/disneylandleveldesign.txt · https://boingboing.net/2009/03/27/gamedesign-lessons-f.html | Weenies; reveal landmarks progressively; squint test; main artery plus side paths; hub reveal; picture spots; re-orientation points |
| David Shaver and Robert Yang, "Level Design Workshop: Invisible Intuition: Blockmesh and Lighting Tips to Guide Players and Set the Mood" | GDC 2018 | https://gdcvault.com/play/1025179/Level-Design-Workshop-Invisible-Intuition · notes: https://www.blog.radiator.debacle.us/2018/03/gdc-2018-how-to-light-level-slides-and.html | Graybox first; global light first; light the critical path; lighting hierarchy; consistent lighting language; brighter albedos |
| Steve Lee (Arkane), "An Approach to Holistic Level Design" | GDC 2017 | https://gdcvault.com/play/1024301 | Treat gameplay, presentation and story as one system |
| Joel Burgess and Nathan Purkeypile, "Skyrim's Modular Approach to Level Design" | GDC 2013 | https://www.gamedeveloper.com/design/skyrim-s-modular-approach-to-level-design | Modular kits; grid discipline |
| DatBoiEle, "I just figured out how ALL ROBLOX games make their MAPS..." | YouTube, 2026-04-23 | https://www.youtube.com/watch?v=wmB8BW4y5EA | (No transcript available; current-gen stylized map workflow) |
| DatBoiEle, "How to Make Stylized Trees & Assets [NEWEST METHOD]" | YouTube, about 2025 | https://www.youtube.com/watch?v=0_lkryX-CgM | (Stylized foliage in Studio) |
| DatBoiEle, "The RIGHT way in making Stylized Trees & Plants" | YouTube, about 2026 | https://www.youtube.com/watch?v=LrHxzOvF0kc | |
| Kingkade 3D, "How To Make a Fisch Style Map In Roblox Studio" | YouTube, about 2026 | https://www.youtube.com/watch?v=wSzIE4NCiSE | (Stylized open-world island) |
| RoBuilder, "How To Make Good Simulator Maps... (Roblox Studio)" | YouTube, 2021-10-05 (176K views) | https://www.youtube.com/watch?v=Y3eUDs3FFGQ | |
| DeHapy, "How to Build PRO Roblox Maps!" | YouTube, 2024-05-05 (234K views) | https://www.youtube.com/watch?v=I-AB6pJ-y5g | Lighting values only as screenshots at shopdehapy.com |
| Gamer M8, "How to make CARTOON LIGHTING in Roblox Studio" | YouTube, 2023-02-11 (285K views) | https://www.youtube.com/watch?v=YIyir52FiYo | Cartoony low-poly lighting |
| Gamer M8, "How to make AMAZING Low Poly Roblox Models" | YouTube, about 2023 | https://www.youtube.com/watch?v=HCdEbF0f02A | |
| BONES, "Roblox Studio - Building Tutorial / Environmental Art" | YouTube, about 2024 (403K views) | https://www.youtube.com/watch?v=-DoOf32pkPo | |
| Develuper, "Make Your Roblox Game Look 10x Better With Lighting" | YouTube, about 2026 (225K views) | https://www.youtube.com/watch?v=vkEXLmRAQgs | |
| Apox Fox, "5 Tips for Great Level Design" | YouTube, about 2024 | https://www.youtube.com/watch?v=LBtucVc8l0M | General level design |

YouTube transcripts could not be retrieved, because the caption endpoints returned nothing. The video rows above are curated pointers only, and the "rules" column is filled only where text sources existed. Upload ages are relative to 2026-10-24.

---

## 6. Reference images and game pages

The `tr.rbxcdn.com/180DAY-...` thumbnail URLs come from Roblox's thumbnails API and **expire about 180 days after issue** (around April 2027). If one fails, re-pull it via `thumbnails.roblox.com/v1/games/multiget/thumbnails?universeIds=...`.

1. **Lift a Cube**, [game page](https://www.roblox.com/games/109530157755211/Lift-a-Cube) and [thumbnail](https://tr.rbxcdn.com/180DAY-81b8ee2a87ef7fc60c283e7e3c84e25d/768/432/Image/Png/noFilter). Classic lime stud baseplate (#99E232), cyan sky, cartoon clouds, a giant labelled cube as the hero object.
2. **Lift a Cube**, [second thumbnail](https://tr.rbxcdn.com/180DAY-06aba5125cfaeaef09d718820a1e438c/768/432/Image/Png/noFilter). Smooth grass field to the horizon. Tiny cube against a huge weight number shows scale exaggeration as the joke.
3. **Lift a Building!**, [game page](https://www.roblox.com/games/119033351277264) and [thumbnail](https://tr.rbxcdn.com/180DAY-6f6fc38d1916dde9b245360b1dc6d9e1/768/432/Image/Png/noFilter). Building-as-weight concept.
4. **Lift A Weight**, [game page](https://www.roblox.com/games/72336033607602). The same "reach the end of the map" template.
5. **Grow a Garden**, [aerial map (wiki)](https://static.wikia.nocookie.net/growagarden/images/1/1f/GrowaGardenMap.png). Square island, 4 quadrant plots, shop columns on two edges, central hub, generous negative space.
6. **Grow a Garden**, [Halloween thumbnail](https://tr.rbxcdn.com/180DAY-78f2b15356e4ddf02eb8e11dc91c9e5a/768/432/Image/Png/noFilter). Stud-cube voxel pumpkin, plank fences, studded plot.
7. **Steal a Brainrot**, [aerial map (wiki)](https://static.wikia.nocookie.net/stealabr/images/0/07/Imageasd.png). 2x4 bases flanking a central lane in a walled rectangle.
8. **Steal a Brainrot**, [thumbnail](https://tr.rbxcdn.com/180DAY-cd8594740f0d77e99b77f85a8697658c/768/432/Image/Png/noFilter). Orange stud carpet through studded grass; laser-barred base fronts.
9. **Steal An Egg**, [game page](https://www.roblox.com/games/107778070777162) and [thumbnail](https://tr.rbxcdn.com/180DAY-79e666901b2c722b06310d267bc6c152/768/432/Image/Png/noFilter). Saturated green hills against deep blue (#1574FF) sky; low-poly snake as a "guardian".
10. **Bee Swarm Simulator**, [game page](https://www.roblox.com/games/1537690962) and [Mountain Top Field image (wiki)](https://static.wikia.nocookie.net/bee-swarm-simulator/images/e/e1/MountainTopField2024.png). Summit field as the end-of-ascent landmark.
11. **Pet Simulator 99**, [game page](https://www.roblox.com/games/8737899170) and [List of Areas](https://pet-simulator.fandom.com/wiki/List_of_Areas_(Pet_Simulator_99)). Area images show the biome ladder.
12. **Ride A Pet**, [game page](https://www.roblox.com/games/124216119978534). Open map with eggs gated by mount speed.
13. **Strongman Simulator**, [game page](https://www.roblox.com/games/6766156863) and [thumbnail](https://tr.rbxcdn.com/180DAY-2a05a4eb85791b120cd6aae26dac0724/768/432/Image/Png/noFilter). "Remove the exit to reach new areas" gate design.
14. **Fisch**, [game page](https://www.roblox.com/games/16732694052). The stylized open-world island benchmark; see also the Kingkade 3D tutorial above.
15. **BuiltByBit "Roblox Simulator Map 375x375"**, [listing](https://builtbybit.com/resources/roblox-simulator-map-375x375.97725/). Screenshots of a standard sim layout: spawn, eggs, shop, leaderboards, mining and wood zones. Reference only.
16. **BuiltByBit "Stud-Style Roblox Map"**, [listing](https://builtbybit.com/resources/stud-style-roblox-map.102440/). Symmetric fenced water and land plots in stud style, with large landmarks. Reference only.
17. **BuiltByBit "Grow a Garden Style Map"**, [listing](https://builtbybit.com/resources/grow-a-garden-style-map.102181/). 6 fenced plots of 4 sub-plots each. Reference only.
18. **BuiltByBit "Low-Poly Mining Camp Map"**, [listing](https://builtbybit.com/resources/low-poly-mining-camp-map-roblox.110053/). A readable themed zone with quests, upgrades and progression gates.

---

## 7. Rules for the skill (checklist)

**Layout and progression**
- [ ] Pick one grammar before building: linear route, hub-and-spoke, symmetric plots, two-row lane or vertical ascent (section 1.8). Write it in the plan.
- [ ] On a 300x300 map, use 4-6 zones. Put a POI every 80-130 studs of travel (5-8 s at WalkSpeed 16). Keep the critical path ≤ about 600 studs.
- [ ] Order zones from familiar to exotic, and from bright to dramatic (PS99 arc; Lift a Cube runs grass, then sand, then ice). Escalate detail and FX per tier (creation.dev).
- [ ] Every gate is a landmark: a giant statue, arch or object on top (Bee Swarm). Show locked areas **from the hub** across a pit, river or fence (sightline kept).
- [ ] For "lift" maps, the hero object at the end is the weenie, visible from spawn. Objects grow in size per band.
- [ ] Put meta stations at spawn (shop, leaderboard, rewards): PS99's Area 1 pattern.

**Spawn**
- [ ] Spawn plaza 40-60 studs square, open, for 12-20 players. SpawnLocation faces the main axis. ForceField Duration 0 for non-combat sims.
- [ ] From the spawn camera (check ±40 deg for 4:3 safety): first objective 10-30 studs away, a path leading off, ≥ 3 POIs on the horizon, and the weenie partly visible.
- [ ] Guide the first minute with ground arrows, a coloured pad trail or a Beam (Lift a Cube white arrows; Bee Swarm red arrow).

**Metrics** (5-stud character, WalkSpeed 16, jump 7.2)
- [ ] Main paths 12-16 wide; secondary 8-10; doors and halls ≥ 10 (stylized door 8x12 is fine for decor); interior ceilings ≥ 14.
- [ ] Blocking walls and gates ≥ 12 tall. Decorative railings ≤ 3.
- [ ] Jump gaps ≤ 6 flat and ≤ 4 when climbing; the hard limit is about 8.7. Never put a required precise jump on the critical path (mobile).
- [ ] Use wedge ramps or 1x2 steps (any slope ≤ 89 deg is walkable). Plateau tiers 4-8 studs high.
- [ ] Blockout on a 4-stud grid (or 5-stud per Roblox), with whole-stud sizes. Rotate kit pieces in 90 deg steps, props freely.

**Visual language**
- [ ] One palette per zone from the BrickColor table (section 2.2). Brightest saturated accent **only** on interactables. Neon only on pads, gates, crystals and lava.
- [ ] Path vs ground: different hue **and** ≥ 1.5:1 luminance where possible (colour-blind and phone readability).
- [ ] SmoothPlastic for props. `SurfaceType.Studs` on ground and plots for the 2025-26 retro look (set by script). No Glass; minimal transparency.
- [ ] Props from primitive recipes (section 2.5): trees of 3-5 balls, rocks of 3-4 tilted blocks, bushes of 3-4 flattened balls. Place them in clusters of 3-5, slightly tilted, every 30-40 studs of path.
- [ ] Edges: darker 0.2-0.4 trim strips or wedge bevels. Highlight only for interactables (≤ a few dozen, hard cap 255).
- [ ] Sign letters ≥ 3 studs if read from ≥ 40 studs, ≥ 1.5 studs up close. High-contrast plate, ≤ 2 words.

**Lighting**
- [ ] Stylized: `LightingStyle = Soft`, `PrioritizeLightingQuality = false`, plus the 2.6 preset (Brightness about 2.5, ClockTime about 13.5, raised Ambient and OutdoorAmbient, ShadowSoftness about 0.3, thin Atmosphere, Bloom Threshold about 2, CC Saturation 0.15-0.3).
- [ ] Never set `Technology` (deprecated). Realistic style is for horror and nature maps.
- [ ] Squint test: the critical path and exits are the brightest and most contrasted things in frame.

**Workflow**
- [ ] Greybox first in `Workspace.World.Blockout_Parts`, colour-coded. Playtest (Test, Test Here) and `screen_capture` from spawn and each zone entrance **before** the art pass.
- [ ] Art pass replaces greybox with kit pieces and props. Lighting goes last.
- [ ] Never import Creator Store models or AI generators. Build everything with Parts, Wedges, Cylinders, Balls, or Blender meshes made by Claude.

**Performance** (phones first)
- [ ] Anchor everything. Decor gets CanCollide, CanTouch and CanQuery false, and CollisionFidelity Box.
- [ ] CastShadow = false on parts ≤ 4 studs, foliage, clouds, trims and ground tiles.
- [ ] A prop repeated more than about 10 times becomes one Blender MeshPart (single MeshId, imported once, cloned), not a Union.
- [ ] Budget ≤ 8-12K parts total, and ≤ 300 draw calls / 300K triangles on screen. Verify with Shift+F2 at low quality. Textures ≤ 512² (most ≤ 256²).
- [ ] StreamingEnabled on, MinRadius 64, ModelStreamingBehavior Improved, StreamOutBehavior Opportunistic. Atomic streaming for multi-part props; LevelOfDetail SLIM on big models.
- [ ] ≤ 1-2 shadow-casting lights per zone; use Neon plus Bloom for glow instead of lights.
