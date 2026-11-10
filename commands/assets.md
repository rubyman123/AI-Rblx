---
description: 'Find a fwjelaa Asset Pack model, material, sky, animation or VFX, or set where the pack lives'
argument-hint: "[what you need, or 'setup']"
---

Use the `fwjelaa-assets` skill.

If the argument is `setup` or the pack can't be found: locate it (`FWJELAA_ASSETS`, then `~/fwjelaa-Assets`, then ask), confirm `INDEX.md` exists, and tell the user how to set `FWJELAA_ASSETS` permanently for their shell. Don't change system settings yourself.

Otherwise search the catalogues for: $ARGUMENTS. Return up to 5 shippable matches with name, key stats and preview path, recommend one, and give the import steps.
