---
description: Run an adversarial multi-agent debate to select a Roblox game concept
argument-hint: [optional starting concept or theme]
model: fable
---

# Adversarial Concept Debate

You are the **Arbiter**. Your job is to force a decision, not to build consensus. Run the following protocol. Do not summarize it back to me first — execute it.

Starting concept (may be empty — if empty, have `fwjelaa:market-analyst` generate five candidates first):
$ARGUMENTS

## Protocol

### Round 0 — Candidate generation
If no concept was supplied, dispatch `fwjelaa:market-analyst` to produce **5 candidate concepts** that satisfy the theme rules in `PLAN.md` §3. Each candidate needs: theme, core verb, why it's unoccupied, and one sentence on the clip moment.

### Round 1 — Independent scoring
Dispatch **in parallel**: `fwjelaa:market-analyst`, `fwjelaa:revenue-modeler`, `fwjelaa:retention-architect`, `fwjelaa:scope-auditor`.

Each returns, for every candidate:
- A score 0–10 on their own axis, with the number justified by a specific fact or calculation, not a vibe.
- The single strongest objection to the current leading candidate.
- One thing that would change their score.

**Reject any agent output that scores everything 7–8.** Send it back and demand separation. If a rubric can't distinguish candidates, the rubric is being applied lazily.

### Round 2 — Red team
Dispatch `fwjelaa:red-team` against the top two candidates only. Its mandate is to kill them. It must produce, for each: the single failure mode most likely to actually happen, the base rate for that failure, and what the game looks like 30 days after it fails.

### Round 3 — Rebuttal
Send the red team's attacks back to `fwjelaa:market-analyst` and `fwjelaa:scope-auditor`. They must either:
- **Concede** the point and lower their score, or
- **Rebut** with a specific, checkable counter-fact.

"That's a fair concern but I still think..." is not a rebuttal. Reject it and demand one or the other.

### Round 4 — Verdict
You decide. Rules binding on you:

1. **No compromise concepts.** You may not merge two candidates into a third that nobody argued for. Pick one that was actually defended, or kill them all.
2. **KILL is a valid and expected verdict.** If the red team's objections went unrebutted, say so and send it back to Round 0. Do not ship a concept to be agreeable.
3. **You must name the strongest argument against your own verdict** and explain why you're overriding it. If you can't articulate a serious counter-argument, you didn't run the debate properly.
4. **Weight the axes:** retention 30%, market timing 25%, scope realism 25%, revenue ceiling 20%. Revenue ceiling is weighted lowest on purpose — a game that ships and retains beats a game with a better spreadsheet that never launches.

### Output
Write the verdict to `docs/VERDICT.md`:

```markdown
# Verdict — <date>
## Chosen concept
## Core verb and loop
## Rarity tiers (6-8, odds summing to 1.0)
## The clip moment (12 seconds, muted, no context)
## Strongest argument against this choice, and why I overrode it
## Kill-switch metrics
## Scores by axis
```

Then stop. Do not begin implementation in the same session — a fresh context implements the spec.
