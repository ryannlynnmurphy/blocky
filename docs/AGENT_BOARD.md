# Blocky Agent Board

This is the shared, append-only coordination board for humans and agents.
It is intentionally plain Markdown so local Codex, OpenCode, and GitHub
agents can all use it. The detailed requirements live in `WORK_ORDERS.md`.

## Rules

1. Claim one unblocked card before editing it.
2. Put your name/tier and expected files on the card.
3. Do not claim a dependent card until its prerequisites are marked done.
4. If two tasks touch the same core file, the T3 lead decides the order.
5. Never erase another agent's handoff; append a new entry.

## Current queue

| Card | Status | Owner | Tier | Needs | Expected files | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| C0 | DONE | Codex | T3 | — | project config, board only | Godot 4.7.2 baseline and fresh-save self-test completed. |
| C1 | DONE | Codex | T1 | C0 | board/docs only | Inventoried committed creator/city foundation. |
| C2 | DONE | Codex | T3 | C1 | decision docs only | Retain functional creator flow; replace dark presentation and color-preset wardrobe layer. |
| C3 | REVIEW | Codex | T2 | C2 | `scripts/screens.gd`, visual test evidence | Light/light-gray styling is implemented; needs an in-game visual review. |
| C6 | DONE | Codex | T1 | C2 | `scripts/wardrobe_catalog.gd`, catalog docs | Stable item IDs/slots and honest rig/placeholder refs are defined. |
| WATER-03 | DONE | Codex | T3 | — | `docs/lab/WATER_AND_SWIMMING_SPEC.md`, board only | v1 contract/special mechanics approved from the current design request. |
| WATER-04 | READY | unassigned | T2 | WATER-03 | `scripts/world_gen.gd`, `scripts/world.gd`, tests | Deterministic terrain water data/query layer. |
| WATER-05 | BLOCKED | unassigned | T2 | WATER-04 | world visuals/assets/tests | Dedicated transparent water visuals, never opaque blocks. |
| WATER-06 | BLOCKED | unassigned | T3 | WATER-04, WATER-05 | player/world integration/tests | Swimming and special mechanics. |
| WATER-07 | BLOCKED | unassigned | T2 | WATER-06 | HUD/audio/main | Presentation-only water response. |
| WATER-08 | BLOCKED | unassigned | T3 | WATER-07 | review/tests | Edges, save decision, creatures, performance. |
| WATER-09 | BLOCKED | unassigned | T3 | WATER-08 | regression tools/board | Full water release gate. |

## Claim template

```md
### YYYY-MM-DD — [CARD-ID] — claimed
Owner: agent name (T1 / T2 / T3)
Expected files: `path/file.ext`
Plan: one or two sentences
```

## Handoff log

<!-- Append new handoffs below. Do not rewrite history. -->

### 2026-09-19 — PROJECT-SETUP — done
Owner: Codex (T3)
Changed: `README.md`, `AGENTS.md`, `docs/PRODUCTION_BIBLE.md`, `docs/WORK_ORDERS.md`, `docs/AGENT_BOARD.md`
Verified: Documentation cross-links and task dependency order reviewed.
Next: C0 — establish and record the Godot baseline.
Notes: Existing city/creator changes are uncommitted drafts. They require C1/C2 review before becoming the accepted implementation.

### 2026-09-19 — C0 — done
Owner: Codex (T3)
Changed: project import cache only; no source changes for this card
Verified: Godot 4.7.2 headless fresh-save self-test completed successfully.
Next: C1 — inventory the committed city/creator draft before the next implementation card.
Notes: The creator draft had two Godot parse issues (typed color inference and a wrapped format expression); both were corrected before the test run.

### 2026-09-19 — WATER-01 — done
Owner: Codex (T3)
Changed: `scripts/player.gd`, `tools/selftest.gd`
Verified: Godot 4.7.2 fresh-save self-test: normal swimming 3.0, Shift + direction underwater 4.9–5.0, water tiles 0/868 dry-land overlaps.
Next: C1 — inventory the city/creator draft before the next planned implementation card.
Notes: Shift + a direction is now active, camera-directed underwater swimming. Space remains the safe rise-to-surface control.

### 2026-09-19 — WATER-02 — done
Owner: Codex (T3)
Changed: water rendering/generation, player physics, breath HUD, audio filters, saves, and `tools/selftest.gd`
Verified: Godot 4.7.2 fresh-save self-test completed after removal.
Next: C1 — inventory the city/creator draft before the next planned implementation card.
Notes: Water and swimming were intentionally removed. Former sea-level terrain is now walkable sandy lowland; water assets remain in the repository but are unused.

### 2026-09-19 — C1 — done
Owner: Codex (T1)
Changed: `docs/AGENT_BOARD.md`, `docs/WORK_ORDERS.md`, `docs/lab/CREATOR_FOUNDATION_AUDIT.md`
Verified: Read-only inspection of the committed creator, city asset references, and current Git history.
Next: C2 — record the retain/replace decision.
Notes: The creator foundation is committed and integrated; it is not an uncommitted draft. It currently uses dark styling and color presets rather than the approved light-gray, modular wardrobe.

### 2026-09-19 — C2 — done
Owner: Codex (T3)
Changed: `docs/AGENT_BOARD.md`, `docs/WORK_ORDERS.md`, `docs/lab/CREATOR_FOUNDATION_AUDIT.md`
Verified: Existing New Game → creator → play and save/profile seams mapped before backlog re-baseline.
Next: C3 and C6 may proceed in parallel; WATER-03 is ready as a design-only card.
Notes: Retain `PersonProfile`, live preview, player application, and save bridge. Replace dark UI styling and single outfit/accent presets incrementally; no rewrite or save migration is authorized by this decision.

### 2026-09-19 — LAB-01 — done
Owner: Codex (T3)
Changed: `.cursor/rules/`, `.cursor/agents/`, `docs/lab/`
Verified: Constitution, voting protocol, reusable roles, and five-commit batch loop reviewed against the current board.
Next: Claim C3, C6, or WATER-03.
Notes: Pushes remain conditional on configured/authenticated remote access; local commits remain atomic and safe until then.

### 2026-09-19 — C6 — done
Owner: Codex (T1)
Changed: `scripts/wardrobe_catalog.gd`, `docs/lab/WARDROBE_CATALOG.md`
Verified: Godot headless boot/self-test completed without new parse errors; catalog records have stable ID, display name, exclusive slot, and current or future asset reference.
Next: C7 — render one catalog T-shirt choice in the preview.
Notes: Bracelets deliberately use a future wrist attachment rather than falsely claiming a mesh exists.

### 2026-09-19 — C3 — implementation ready for review
Owner: Codex (T2)
Changed: `scripts/screens.gd`
Verified: Godot 4.7.2 headless boot/self-test completed without a parser crash.
Next: Manual New Game → Create a Person visual check, then C4/C5/C7 integration.
Notes: Canvas, primary panel, summary, labels, and preview-stage palette are light/light-gray. Existing unrelated self-test expectation mismatches remain in title/new-game, sleep, furnace, and one durability path.

### 2026-09-19 — WATER-03 — done
Owner: Codex (T3)
Changed: `docs/lab/WATER_AND_SWIMMING_SPEC.md`, `docs/WORK_ORDERS.md`, `docs/AGENT_BOARD.md`
Verified: Contract reviewed against current terrain, player, HUD, audio, and chunk seams.
Next: WATER-04 — deterministic water query data, then transparent visual water before player swimming.
Notes: Shift + direction is reserved for camera-directed sprint swimming with a stamina/cooldown cap; no opaque water blocks or old-code rollback.
