# Roblox Maps by fwjelaa: describe a map, Claude builds it in Studio

**Method by fwjelaa (FWJ STUDIOS).** Free to use; please credit fwjelaa. See `CREDITS.md`.

Tell Claude what map you want ("a lift a boulder simulator map") and it builds it in your open Roblox Studio
place: ground, paths, landmarks, props, lighting. Then it checks the map with screenshots, a walk test from spawn
and a performance budget, and fixes it until it passes.

**The full guide** (setup, the four styles with pictures, changing a map, budgets, troubleshooting) is
`GUIDE.html`: open it in your browser. The same text is in `GUIDE.md`. This README is the short version.

## Quick start
1. Install **Python 3** (python.org) and run `python -m pip install pillow numpy`.
2. In Roblox Studio create a **fresh Baseplate place** (File → New → Baseplate), then **Assistant → ... → Manage
   MCP Servers → Enable Studio as MCP server**. The kit never deletes anything (the template Baseplate and
   SpawnLocation are moved to ServerStorage.MapKit_Removed) and refuses to write terrain where your place
   already has some, but a fresh place keeps your other work safe.
3. **Open this folder in Claude Code** and connect the Studio MCP (Studio's MCP page has a Claude Code button).
4. Say **"make me a lift a boulder simulator map"**, or type `/make-map` and your idea.
5. Keep the Studio window **visible** while Claude builds (screenshots need it). Say "go" when it shows the plan.
6. When it's done: **Ctrl+S** to save the place.

Example maps: `maps/lift-a-boulder` ("build the lift a boulder example"), `maps/backrooms-level-0` ("build the
backrooms example"), `maps/farmhouse-night` ("build the farmhouse example") and `maps/forest-lake` ("build the
forest lake example"). One map per place: start a fresh Baseplate place for each.

## Textured maps (backrooms, horror, nature)
These use free CC0 textures from ambientCG and Poly Haven, uploaded to **your** Roblox account (uploads only load
for the account that made them). Two ways:
- **With an Open Cloud API key** (create.roblox.com → Open Cloud → API Keys): give it only **Assets API read +
  write for your own user**, then save the key in `%USERPROFILE%\.fwjelaa\roblox-open-cloud.key` (one line) or
  the `ROBLOX_API_KEY` variable. Claude uploads by itself. Never paste the key into a chat you share or film.
- **Without a key:** Claude uploads each texture through Studio's MCP (`upload_image`) instead.

Realistic props (furniture, lamps, logs, rocks, a pier) are scanned CC0 models from Poly Haven; trees, grass and
reeds are grown in Blender from CC0 bark and leaf textures; skies are CC0 Poly Haven HDRIs. Claude preps them in
**Blender** (free, blender.org, 4.2 or newer; it runs in the background, you never open it) and uploads them
like the textures. Without a key, every model is a `.glb` you import by hand with Studio's File → Import 3D, so
for the realistic examples (the farmhouse has 38 models, the forest lake 15 plus a sky) **set up the key**.

Run `python kit/tools/run.py check` to see what is set up.
