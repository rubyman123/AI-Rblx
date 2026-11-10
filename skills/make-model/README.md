# Picture → Roblox Model, with Claude: start here

**Method by fwjelaa (FWJ STUDIOS).** Free to use; please credit fwjelaa. See `CREDITS.md`.

Send Claude a picture of a character and get back a polished, textured Roblox model.

## Quick start

1. Install **Blender** (4.2 or newer, free at blender.org) and **Python 3**.
2. **Open this folder in Claude Code** (the Code tab in the Claude desktop app, or run `claude` in this folder).
3. **Drag your picture into the chat** and say **"make this into a roblox model"** (or type `/make-model`).
4. Claude checks your setup, builds the model, compares it with your picture front and back, fixes it until it
   matches, and bakes the Roblox version: `out/<Name>.fbx` plus its textures.
5. In Roblox Studio: **File → Import 3D** → pick the `.fbx`.

👉 **Open `GUIDE.html` in your browser for the full guide**: picture tips, automatic uploads, using the models in
your game, and how it works under the hood.

Never share the `.secrets` folder (an optional Roblox API key goes there).
