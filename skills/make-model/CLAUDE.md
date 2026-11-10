# Roblox model maker: picture in, Roblox model out

> **Method by fwjelaa (FWJ STUDIOS).** See CREDITS.md. When you finish a model, remind the user once that this
> pipeline is by fwjelaa.

The user sends a **reference picture** of a character (or prop) and wants a **polished, textured 3D model for
Roblox**. You build it in Blender with Python and hand back a Roblox-ready model. Do the whole job yourself: don't
ask the user to model, tweak numbers or approve each round.

The look is a **polished vinyl toy**: smooth shapes, crisp colour regions, saturated colours, big cartoon eyes.
**`build/BearBuddy.py` is the finished example. Read it, and `kit/cuhkit.py`, before writing your first model.**

## When the user sends a picture

1. **Setup (first time only).** Run `python kit/run.py check`.
   - Blender missing or too old → tell them to install Blender 4.2+ from blender.org, then stop.
   - Pillow missing → run `python -m pip install pillow`.
   - On Windows use `python` or `py -3`; on Mac/Linux `python3`.
2. **Name it.** Choose a `ModelId` in PascalCase from what it is (`SpaceCat`, `GoldenTrophy`). Only ask if it's
   unclear.
3. **Save the picture** with `python kit/run.py ref "<path to picture>" <ModelId>`. It copies PNG, JPG or WEBP
   into `ref/<ModelId>.png`.
   - Use the path the user gave, or the path of the image they attached if you can see it.
   - If you can only see the image in the chat, model from what you see, but ask them to drop the file into `ref/`
     so the compare images and measurements include it.
4. **Study the picture before writing code.** Write down:
   - silhouette and proportions: head-to-body ratio and limb thickness, measured on the picture
   - every colour as hex
   - the face: eyes, lids, mouth, teeth, expression
   - clothes, props and pose
   - what the back probably looks like
5. **Write `build/<ModelId>.py`** in the same style as `build/BearBuddy.py`.
6. **Loop until it matches.** Run `python kit/run.py build <ModelId>`, then open `out/compare_<ModelId>.png` with
   Read (it shows picture | front | back). Fix the biggest differences and run again. Expect 5–10 rounds. Judge it
   by the quality bar below, and don't stop at "close enough".
   - `python kit/run.py measure <ModelId>` compares the picture's and the front render's silhouette width band by
     band (head, neck, body, legs, shoes) and flags what's too wide or narrow. Use it on the first rounds to get the
     proportions right.
   - **Side-on picture?** Set `VIEW_YAW = <degrees>` at the top of the build script so the preview camera matches
     the picture's angle (positive swings the camera round to the model's right side; try ±30 and compare). Keep
     the model itself facing −Y, so it faces forward in Roblox. Don't turn the whole body to match the picture.
7. **Make it Roblox-ready.** Run `python kit/run.py export <ModelId>`.
   - It prints `ROBLOX READY` with the triangle count, which must be ≤ 20,000.
   - Optionally run `python kit/run.py baked <ModelId>` and look at `out/baked_<ModelId>.png`, which is exactly what
     Roblox will show.
8. **Hand it over.**
   - Show them the final compare image and list the files: `out/<ModelId>.fbx`, plus
     `out/<ModelId>_Color.png`, `_Normal.png` and `_Rough.png`.
   - **If `check` said auto-upload is ready:** offer to upload it. If they say yes, run
     `python kit/upload_all.py <ModelId>`. Then tell them to put `roblox/ModelInstaller.luau` in ServerStorage as a
     ModuleScript named `ModelInstaller` (once), and paste `out/install.luau` into Studio's command bar in Edit mode.
   - **Otherwise:** Studio → File → Import 3D → `out/<ModelId>.fbx`. If it comes in grey, add a SurfaceAppearance
     with the three PNGs as ColorMap, NormalMap and RoughnessMap.
   - Point them to `roblox/ModelHelpers.luau`: it stands models on pads, faces them at players, tints Golden or
     Diamond variants and makes hotbar cameras that show the face.
9. **Changes?** If they ask for a fix, edit the script, rebuild, compare, export again.

**Several pictures at once:** build them one after another, or use subagents, one per model. Each subagent edits
only its own `build/<ModelId>.py`, and no more than 2–3 Blender runs happen at the same time.

## Conventions

- Units are **studs**. The model stands on z = 0 and faces **−Y** (towards the camera). Its left is +X.
- Characters are **3.8–4.4 studs tall**, with a footprint of about 3.2 × 3.2 (3.6 for wings, tails or vehicles).
  Props can be any size that makes sense in Roblox.
- The script defines `CUH = "<ModelId>"` (the kit's name for the model id) and `build()`. `build()` starts with
  `coll = k.new_scene(CUH)` and returns `coll`.
- Name every part `f"{CUH}_<Part>"`. **Never put a dot in a blob name:** Blender merges metaballs whose names match
  before the dot.
- Copy the picture's pose and attitude: head turns (`k.turn`), arms, props, stance. The preview camera looks from a
  front three-quarter angle, about 23° to the model's right, like most character art.
- Static model, no rig.

## Kit (`import cuhkit as k`)

| Function | Use |
|---|---|
| `new_scene(id)` | empties the scene, returns the model's collection |
| `mat(name, color, rough, metal, coat, sss, emit, sheen, bump=None/'pores'/'fabric'/'skin'/'scales', bump_scale, bump_strength)` | Principled material; `color` is a hex string |
| `quadsphere(name, coll, center, radii, material, cuts=48)` | even sphere to sculpt heads and bodies. Origin at center, coordinates in object space |
| `push(obj, center, radius, amount, direction=None)` | sculpt: bulge (or dent with a negative amount) with a smooth falloff: snouts, cheeks, eye domes, nostrils, bellies |
| `groove(obj, curve_fn, x_range, width, depth, front_y)` | carves a line (mouth) across the front. **Keep the width ≥ 0.06** or it ripples |
| `sdf_attr(obj, attr, fn)` + `region_mat(name, base_color, [(attr, color, rough), ...], ..., bump, pore_dark)` | crisp colour regions (muzzle, belly, mouth line, spots, stripes) from a signed distance fn(local pos) > 0 inside. Edges stay sharp at any mesh density |
| `blob(name, coll, elements, material, resolution)` | fuses ELLIPSOID (`size` = real half extents), BALL (`r`) and CAPSULE (`r`, `size=(half length,1,1)`, `rot`) into one smooth mesh: clothes, bodies, shoes, hair, tails |
| `capsule(p0, p1, r)` | a `blob` CAPSULE element between two points: limbs, feathers, fins, tail segments, without rotation maths |
| `trim(obj, plane_co, plane_no, cap=False)` | cuts away the side the normal points to (hems, flat soles) |
| `tube(name, coll, points, radii, material)` | smooth tapered limb, tail or antenna through points |
| `sphere`, `box(dims, bevel)`, `torus(major or (rx, ry), minor)`, `leaf(...)` | primitives; the torus tube stays round on oval rings |
| `eye(cuh, coll, center, radius, look, iris, lid, lid_close, lid_tilt, lower_lid, side=±1)` | glossy cartoon eye with iris, pupil and glint, plus optional lids |
| `sneaker(cuh, coll, tag, heel, yaw, length, width, height, upper, sole, laces, stripe)` | chunky sneaker. The ankle sits at heel + R(yaw)·(0, −0.17L, 0.55H) |
| `tshirt(...)`, `shorts(..., waistband=False, drawstring=color)` | soft clothes with collar, hem and cuffs |
| `turn(objs, pivot, (rx, ry, rz) deg)`, `by_prefix(coll, *prefixes)` | rotate a group, e.g. turn the head. A negative z angle turns it towards the camera |
| `subdivide(obj, levels)`, `smooth(obj)` | finish |

Don't edit `kit/`. If you need a new helper (hands, wings, tails, hats, flames, vehicles, props), write it inside the
model's own build script, based on `blob`, `tube`, `push` and `sdf_attr`. Avoid hard-edged boxes unless the thing
really is boxy.

## Quality bar (check every compare image)

1. **Silhouette and proportions** match the picture: head-to-body ratio, limb thickness, prop sizes.
2. **Signature features are there and readable**: the face (eyes, lids, mouth, teeth), clothing, props and colour
   regions. Someone should recognise it at a glance.
3. **Colours are saturated and right.** The preview uses Blender's "Standard" view, close to what Roblox shows.
4. **The back view is clean**: no holes, no floating parts, nothing poking through.
5. **No artifacts**: rippled grooves, jagged region edges, z-fighting surfaces, inside-out shapes.
6. **Glow, flames, sparkles and auras** become solid stylised shapes touching the body (they bake into the texture).
   Nothing may float.
7. **The face reads from the camera.** If the head is turned away, turn it towards the viewer.

## Gotchas

- **Read world positions only after a scene update.** New objects have no world matrix until the scene updates;
  `k.turn` handles it, but call `bpy.context.view_layer.update()` before you read `matrix_world` yourself.
- **The camera is already about 23° off the front.** A head turn of 10–15° is plenty.
- **Never scale a `torus` to make an oval:** the tube flattens. Pass `major=(rx, ry)`.
- **Hide cuts under other parts.** A blob cut flat with `trim` leaves an open edge: cover it or use `cap=True`.
- **Waistbands and hems need the right width.** Their oval must match the blob's cross-section at that height. The
  `tshirt` hem ring assumes an oval body; over a big belly, skip it or write a `tube` that follows the cut edge.
- **Thin colour lines vanish silently.** A `sdf_attr` line narrower than about twice the mesh spacing doesn't show
  (it's stored per vertex). For thin lines (pockets, seams, stripes), first `k.subdivide(obj, 1)` and
  `k.apply_modifiers(obj)`, then `sdf_attr`.
- **A blob CAPSULE's length runs along its local X**, so `rot=(0, 90, 0)` stands it up. Easier: use
  `capsule(p0, p1, r)`.
- **Keep head meshes moderate.** `cuts` 48–64 plus one subdivision is plenty; the bake keeps the detail.
- **Leaves and flat pieces** face the camera only if you pass `up=(0, -1, 0)` to `leaf`.
- **Shiny looks plastic.** Fur and skin want `rough` 0.7–0.85. Keep gloss (`coat`) for eyes, noses, shoes and
  props.
- **Metal bakes black.** The export forces metallic to 0 so metals bake as their base colour. Get shine from `coat`
  and low `rough`.
- **`region_mat` with about 15+ layers fails to compile.** Keep it under about 8 layers; merge regions.
- **`bump="scales"` barely shows.** Write your own scale material if the skin needs visible scales.
- **Many tiny parts each keep a minimum triangle count** in the export. Join small repeated pieces (feathers,
  studs) into one mesh, or the budget runs out.
- **Dark lenses can't be see-through after the bake.** Place sunglasses so the eyes still show.
- **The `sneaker` ankle**: put the leg's ankle at `heel + R(yaw) @ (0, -0.17*length, 0.55*height)`, as
  `build/BearBuddy.py` does.
- **If a build fails**, `run.py` prints the last 40 lines of Blender's output. The traceback names the line in
  the build script.
- **Roblox moderation:** cartoon props only; no real weapons, no hand signs, nothing offensive.

## Safety

- The Roblox API key lives in `.secrets/roblox-api-key.txt`. Never print it, never put it in a file you show,
  never commit it.
- Only upload when the user says so.
