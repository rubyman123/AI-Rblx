# Blue Spiral Pillar aura

This is a Roblox Studio rebuild of the blue spiral energy pillar reference picture, made with VFX Studio's library assets.

## Where it lives in the place ("10202026_1")

| Path | What it is |
|---|---|
| `Workspace.BlueSpiralPillar` | Full-size showcase (about 34 studs tall) at (0, 0, -30). |
| `ServerStorage.Auras.BlueSpiralPillar` | Character version at 0.45 scale. The pillar starts above the head. |
| `ServerScriptService.AuraGiver` | Welds the aura to every character on spawn and fires the burst. |
| `StarterPlayerScripts.AuraAnimator` | Client motion for everything tagged `Aura`: spins, orbits, bobs, pulses, twinkles. |

The Lighting `ClockTime` was changed from 14.5 to 0.3 (night) so the glow reads like the reference.

## Layers

- **Pillar.** Beams with FaceCamera on: a core line, a glow layer (VFX Studio "glowbeam" 13576015697) and an outer haze. The showcase also has neon core cylinders, plus 4 thin streak beams around the pillar.
- **Spiral.** Two ribbons, each made of 22 curved beam segments along a 2-turn helix, 180° apart. Each ribbon has a sheet layer, a bright edge and a rim. Width tapers and transparency fades at both ends, and the tail flicks outward.
- **Halo.** VFX Studio Ring mesh 101192430098279 ×2, tilted 6°. The animator precesses the tilt.
- **Ground.**
  - Ring meshes: 4 concentric rings.
  - Pinwheel claws: VFX Studio mesh 4646044301 ×2, spinning in opposite directions.
  - SurfaceGui images: glow 867619398, swirl 86401376598665 and ripple 13322173171.
- **Claws.** 10 billboard crescents (texture 8247973361) that orbit and wiggle.
- **Crystals.** Each crystal is two VFX Studio Cone meshes (13643725519) placed base to base, with a neon core inside.
- **Stars.** Billboard 4-point stars (8120666025) for the ground star, the halo star and 7 floating stars.
- **Particles.**
  - Ambient: sparkles, diamond shards (7245988767) and rising crescent wisps.
  - Ground ripples: VelocityPerpendicular emitter, so they lie flat.
- **Burst.** `Particles.GroundEmitter.Burst` has 4 emitters: Shockwave, Flash, GlowPop and SparkSpray. Their `EmitCount` / `EmitDelay` attributes follow the VFX Studio convention, so VFX Studio's Emit panel can preview them.

## VFX Studio facts (v3.9.3, plugin asset 135581141962270)

- The texture library is about 9,178 entries, fetched from `https://raw.githubusercontent.com/Sytranom/VFXStudio/refs/heads/main/VFXData.json`. Each entry maps an id to a Name, Keywords (category) and optionally Grid/Resolution for flipbooks.
- Default meshes ship inside the plugin rbxm, under `Defaults.Meshes` (about 400 meshes). Useful ones:
  - Whirl2 903178515 and helix 1051557: spiral ribbons.
  - Pinwheel 4646044301.
  - Ring 101192430098279 and EyeRing 4452526014.
  - Cone 13643725519.
  - Slash 4876614851.
  - Tornado 4041733635.
  - Wind meshes.
- Emit attributes on ParticleEmitters: `EmitCount`, `EmitDelay`, `EmitDuration`. A duration enables the emitter for that many seconds; without one it calls `:Emit(count)`.

## Beam gotchas found while building

- With FaceCamera off, the beam's **width runs along the attachment's Y axis**. For a ribbon that wraps a cylinder, build each attachment's CFrame like this: `CFrame.fromMatrix(pos, tangent, tangent:Cross(radial))`.
- Use a **positive CurveSize1** when both attachments' X axes point along the direction of travel. A negative value overshoots each segment and leaves bright creases at the joints.
- `Model:ScaleTo` scales beam widths and curves, particle sizes and speeds, and billboard sizes. It does **not** scale PointLight.Range.
