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
| C4 | DONE | Codex | T2 | C3 | existing preview scene/script | Existing live 3D preview retained and verified as the wardrobe renderer. |
| C5 | DONE | Codex | T2 | C3 | existing creator form/profile | Existing name/pronoun controls retain in-memory navigation state. |
| C6 | DONE | Codex | T1 | C2 | `scripts/wardrobe_catalog.gd`, catalog docs | Stable item IDs/slots and honest rig/placeholder refs are defined. |
| C7 | DONE | Codex | T2 | C4, C6 | profile, appearance, creator screen | Catalog selection visibly recolors the live preview via the shared rig. |
| C8 | DONE | Claude | T2 | C7 | `scripts/person_appearance.gd`, `scripts/wardrobe_catalog.gd`, `scripts/main.gd`, docs | Bracelet is a real procedural wrist attachment now; one-per-slot replacement verified by reading existing sanitize() logic. |
| C9 | DONE | Codex | T2 | C5, C8 | creator screen, person_profile.gd | Skin/hair/randomize/Back/Continue were already implemented (screens.gd) ahead of the board, same as WATER-05; logging after verifying the wiring. |
| C10 | DONE | Claude | T3 | C9 | `scripts/screens.gd` | Design pass per Ryann's direction to make the creator screen "more fun, interactive, and better looking": real theme (rounded, warm-accented, hover/press states), highlighted CTA with ambient pulse, section accent bars, pop-in entrance, Randomize bounce + preview spin boost. |
| WATER-03 | DONE | Codex | T3 | — | `docs/lab/WATER_AND_SWIMMING_SPEC.md`, board only | v1 contract/special mechanics approved from the current design request. |
| WATER-04 | DONE | Codex | T2 | WATER-03 | `scripts/world_gen.gd`, `scripts/world.gd`, tests | Deterministic terrain water data/query layer. |
| WATER-05 | DONE | Codex | T2 | WATER-04 | `scripts/world.gd`, tests | Chunk-aligned transparent water surfaces, no collision, streams with chunk lifecycle. Code and test (frame 30) already existed uncommitted-to-board; logging accurately after verifying it passes. |
| WATER-06 | DONE | Claude subagent (T3) | T3 | WATER-04, WATER-05 | `scripts/player.gd`, `scenes/player.tscn`, `tools/selftest.gd` | Dry/Wade/Swim/Sprint-swim per the spec; subagent hit the session usage limit mid-task, resumed and finished by the coordinating Claude session — see the done handoff below for what changed after resumption, including a real bug found in the resumed player.tscn fix itself. |
| B0 | DONE | Claude | T3 | P2 | `docs/lab/CITY_BLOCK_LAYOUT.md` | Five locations named/documented (apartment, street, park, cafe, workplace) per the Production Bible's slice. Also flagged and resolved a real content-boundary issue: the vendored `blocky/city/` asset pack includes `police_car.obj`/`pistol_prop.obj`/`rifle_prop.obj`, which conflicts with the bible's own non-goals (no police/crime systems) and "lead review" requirement for violent content. Decision: excluded from B1/B2, documented in the layout doc rather than silently used or silently dropped. |
| B1 | DONE | Claude subagent | T2 | B0 | `scenes/city_block.tscn`, `scripts/city_block.gd` | Self-contained city-block scene: flat paved ground, street/sidewalks/park, three building shells (apartment/cafe/workplace), real collision on every solid surface. Not wired into main.gd (B5's job). |
| B2 | DONE | Claude subagent | T1 | B0 | `docs/lab/CITY_ASSET_MANIFEST.md`, `scripts/city_render_pack.gd` | Full asset audit; every path verified against disk; fixed a pre-existing broken-path bug in `city_render_pack.gd`. |
| B3 | DONE | Claude | T2 | B1, B2 | `scripts/city_block.gd`, `scripts/city_walker.gd`, `tools/city_block_check.gd` | Apartment/cafe/workplace interiors + door entrances/exits, at Ryann's direct request after walking the B1 street. Every location is enterable, verified by an actual teleport (not just geometry existing). |
| B4 | DONE | Claude | T2 | B3 | `scripts/city_block.gd`, `scripts/debug_actor.gd`, `tools/city_route_check.gd` | Named waypoint graph + BFS routing between all 5 locations; a non-player DebugActor walks a full tour and arrives at each within ~0.5m, verified headlessly. |
| D0 | DONE | Claude | T3 | C10 | `scripts/person_profile.gd` | Schema already had identity/appearance/values/needs (built ahead of the board, same pattern as C9/WATER-05); added the one real gap, a stable per-person `id` (needed for Layer 6+ relationships/memories to reference other people), preserved correctly across save/load. |
| D1 | DONE | Codex | T2 | D0 | creator screen | Personality axes + 3 deep values were already implemented and exposed in the creator (`_add_axis`/`_add_value_select`); logging after verifying. |
| D2 | DONE | Claude | T2 | D0 | `scripts/person_profile.gd` | Five needs (hunger/energy/social/stress/money) were already in the schema, but "clamp correctly" (the actual acceptance check) did not hold — nothing bounded them, so a save could set e.g. money to a negative number. Added clamping (0-100 for hunger/energy/social/stress, non-negative for money) to `_sanitize()`, which already runs on every `load_dict()`. Would have been wrongly marked done without checking. |
| D3 | DONE | Claude | T3 | D0–D2 | `tools/selftest.gd` | `to_dict()`/`load_dict()` round-trip already worked; added the missing test (frames 330-350) actually proving it, since nothing tested it before. |
| D4 | DONE | Claude | T3 | D3 | `scripts/main.gd`, `tools/selftest.gd` | Person profile was already wired into `save_game()`/`load_game()` (`"person"` key) with a safe `.get(..., {})` fallback for old saves; added the missing migration test. |
| P0 | DONE | Claude | T3 | C10, D4 | `scripts/main.gd` | Confirmed both halves of the acceptance check: New Game → Creator → `person_confirmed` → PLAYING is exercised by the selftest's frame-842 new-game test (and the D0-D4 round-trip test right before it); `Continue` (line 82) goes straight to `State.PLAYING` and never touches `State.CREATOR` — the real `load_game()` already ran at boot (line 69-70) before the title screen even shows, so Continue only resumes what's loaded, structurally untouched by any creator-flow change. |
| P1 | DONE | Claude | T2 | P0 | `scripts/player.gd` | "Spawned player matches preview" holds by construction, not just observation: `PersonAppearance.apply_to()` is the one function both `make_preview()` (creator) and `player._build_model()`/`set_person_profile()` (live actor) call with the same profile dict — there is no second code path that could render them differently. `player.set_person_profile()` is already called from both `_finish_new_game()` and `load_game()`. Selftest exercises the live player post-`_finish_new_game()` for hundreds of frames (torch/bed/shelter/sword/furnace/corridor) with zero model-related errors. |
| P2 | DONE | Claude | T3 | P1 | `scripts/player.gd`, `scripts/hud.gd` | Reload and survival-system regression: already covered by the full selftest suite. "HUD name" was a real gap, not just an unverified claim — the HUD never showed the player's chosen name anywhere. Added `Player.person_name()` and a HUD line (reuses the existing biome+clock status-line pattern). Hit and fixed the same check-a-frame-later gotcha this project has hit before (M28/M36 notes): `hud._process()` runs on the idle loop, so it needs one frame after `load_game()` to pick up the new name. |
| WATER-07 | DONE | Claude (T2) | T2 | WATER-06 | `scripts/hud.gd`, `scripts/sfx.gd`, `tools/selftest.gd` | Presentation-only water response: underwater screen tint, muffled SFX/music, splash-in/out and a swim-stroke cadence — all driven by `Player.water_state_changed`, no gameplay logic touched. `main.gd` ended up not needing any change. |
| WATER-08 | READY | unassigned | T3 | WATER-07 | review/tests | Edges, save decision, creatures, performance. |
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

### 2026-09-19 — C4/C5/C7 — done
Owner: Codex (T2)
Changed: `scripts/person_profile.gd`, `scripts/person_appearance.gd`, `scripts/screens.gd`
Verified: Godot 4.7.2 headless boot/self-test completed without new parser/runtime errors.
Next: C8 — add the visible bracelet attachment; C3 remains queued for a human in-game visual pass.
Notes: Existing saves gain sanitized default wardrobe IDs. The creator now selects one item per catalog slot; T-shirts, pants, belts, and shoes visibly recolor the shared rig.

### 2026-09-19 — WATER-04 — done
Owner: Codex (T2)
Changed: `scripts/world_gen.gd`, `scripts/world.gd`, `tools/selftest.gd`
Verified: Godot 4.7.2 headless self-test prints a deterministic dry/surface/submerged fixture with all expected states true.
Next: WATER-05 — render dedicated transparent chunk-aligned water surfaces.
Notes: This layer changes no visual geometry, collision, player movement, or save data. The surface-boundary epsilon prevents an exact returned water height from being classified as submerged.

### 2026-09-20 — WATER-05 — done (logged retroactively)
Owner: Codex (T2)
Changed: `scripts/world.gd`, `tools/selftest.gd`
Verified: full `--selftest` run, frame 30: "water visuals N, streamed surfaces valid true". Code (`_update_water_surface`, `water_visuals_match_streamed_chunks`) and the test already existed in two commits that landed after the board's last update; this entry just makes the board match what's actually on `main`.
Next: WATER-06 — player swim integration.
Notes: Flat transparent per-chunk mesh (`WATER_MATERIAL`, alpha-blended, no collision), parented to its Chunk so it streams/frees with terrain. Never covers a dry/solid column.

### 2026-09-20 — C8 — done
Owner: Claude (T2)
Changed: `scripts/person_appearance.gd`, `scripts/wardrobe_catalog.gd`, `docs/lab/WARDROBE_CATALOG.md`, `scripts/main.gd`
Verified: headless movie of `--show-creator`, pixel-sampled to confirm the bracelet renders in a distinct color from bare skin at each of two placement attempts (first attempt was invisible — wrong local-space assumption; fixed by matching the sword's proven zero-offset attachment convention instead of computing an AABB offset). Full `--selftest` suite unaffected.
Next: C9 — skin/hair controls, randomize, Back/Continue.
Notes: `asset_ref` for bracelet items is now `generated:bracelet_wrist`, not `rig:`, since it's a procedural TorusMesh, not authored GLB art — kept distinct so the docs stay honest if real art replaces it later. Added `--show-creator` dev arg (mirrors `--show-inventory`) for headless UI screenshots of the creator screen.

### 2026-09-20 — WATER-06 — claimed
Owner: Claude subagent (T3)
Expected files: `scripts/player.gd`, `tools/selftest.gd`, possibly `scripts/world.gd`, `scripts/main.gd`, `tools/` (a new dev-check tool)
Plan: add a Dry/Wade/Swim/Sprint-swim state machine to Player per `docs/lab/WATER_AND_SWIMMING_SPEC.md`, with the deep-water fall-damage cushion and its shallow-water edge test, then verify with the full headless suite plus a recorded movie.

### 2026-09-20 — REGRESSION FIX — done
Owner: Claude (T2)
Changed: `scenes/player.tscn`, `tools/selftest.gd`
Verified: full `--selftest --quit-after 6000` (raised from 2200 — heavier city/wardrobe scenes need more real-time budget to reach the same physics frame under the physics-substep cap), run 3x clean, 0 engine errors, corridor traversal 6.0-6.1 blocks (was 1.3, needs >5.0), furnace smelts Iron again.
Next: none blocking — flagged for whoever picks up C9 or WATER-06 next.
Notes: Found while verifying C8 by actually running the suite rather than trusting existing code (handbook rule 7). Two bugs: (1) the frame-842 "new game" selftest step never called `_finish_new_game()`, so every test after it ran against a paused `State.CREATOR` game instead of `State.PLAYING` — direct data mutations kept "passing" regardless, masking that state-gated signals like `furnace_used` were silently no-ops. (2) with state genuinely fixed, the "resize player" commit's capsule `height=1.8` turned out to mean total height 2.3 (Godot's `CapsuleShape3D.height` excludes the two hemispherical caps: total = height + 2*radius), taller than a 2-block gap. Fixed to `height=1.1` (total 1.6). `player.gd`'s `MODEL_HEIGHT` (visual scale, separate from collision) is untouched and correct. One known minor discrepancy not chased further: a fall-damage test now reads 1 HP lower than its previously-recorded expected value (10 vs 11 on a 3.6-block drop) — likely the corrected capsule height shifting exact fall-distance by a few centimeters.

### 2026-09-20 — C9 — done (logged retroactively)
Owner: Codex (T2)
Changed: `scripts/screens.gd` (pre-existing)
Verified: read `_build_creator()` end to end — skin/hair/hair_color selects (appearance section), "Randomize appearance" button (`randomize_visuals()`), "Back" (`creator_cancelled`), and "Enter Hollowmark" (`person_confirmed` → `main._finish_new_game()`) are all present and correctly wired. Confirmed visually via `--show-creator` screenshot.
Next: C10 — visual/interaction pass.
Notes: Same situation as WATER-05 — implemented ahead of the board. "No persistence yet" holds: nothing writes the profile to disk before `_finish_new_game()` applies it to the live player.

### 2026-09-20 — C10 — done
Owner: Claude (T3)
Changed: `scripts/screens.gd`
Verified: headless `--show-creator` screenshots at both 720 and a temporarily-bumped 1400 window height (to see the whole form, then reverted — `project.godot` is unchanged) confirm rounded warm-accented controls, gold-filled sliders, visible section dividers, the highlighted "Enter Hollowmark" CTA, and that the 🎲 glyph on Randomize actually renders (checked directly, not assumed — Godot's default font support for supplementary-plane emoji isn't guaranteed). Full `--selftest --quit-after 6000` clean, 0 errors, same results as the prior regression-fix run.
Next: whoever picks up city-block or D-series work should keep using `_creator.theme` as the model for any other player-facing screen that wants this same warm/rounded language — title/pause/death intentionally keep their separate dark dimmed look (an existing, deliberate design split, not an oversight).
Notes: Scoped to the Create a Person screen only, via `_creator.theme` (a `Theme` resource cascades to all children, so no per-control repetition). Additions: `_build_creator_theme()`/`_flat_style()` (rounded Button/OptionButton/LineEdit/HSlider styleboxes with distinct normal/hover/pressed/focus states — hover/press feedback is then automatic, no signal wiring needed), colored accent bars on `_section()` headers, a pop-in scale+fade tween in `show_creator()`, a slow ambient pulse tween on the CTA button (starts once on first `resized`, guarded so it can't be created twice), a `_bounce()` helper reused for Randomize's click feedback, and `_preview_spin_boost` (decaying extra rotation speed on the live avatar after Randomize, so a new look feels shown off rather than silently swapped in).

### 2026-09-20 — D0–D4 — done
Owner: Claude (T2/T3)
Changed: `scripts/person_profile.gd`, `tools/selftest.gd`
Verified: full `--selftest --quit-after 6000`, 0 errors. New assertions: person round-trip through a real save file (id/name/wardrobe survive save→wreck→load, frames 330-350), a save with no `"person"` key at all still loads to safe defaults (pre-D0 migration), and out-of-range needs (hunger 999, energy -50, money -20) clamp to (100, 0, 0).
Next: P0 — the "route New Game through the creator" mechanism already exists (`main._new_game`/`_finish_new_game`); it just needs its own explicit review/close-out rather than being incidentally covered by other work.
Notes: Same pattern as C9/WATER-05 twice over (D0's schema, D1's axes/values, D2's need fields, D3's round-trip, D4's save integration were all substantially pre-built) — but this time checking the *acceptance criteria*, not just "does code exist," caught a real gap: D2 says needs must "clamp correctly," and nothing did until this pass (`_sanitize()` now bounds hunger/energy/social/stress to 0-100 and money to non-negative). Also added the one genuinely missing schema piece, a stable per-person `id` (`PersonProfile.id()`), needed later for Layer 6+ to reference people in relationships/memories — generated fresh in `default_data()`, preserved across `load_dict()` only if the source already has one, so old saves get a stable id from their next save onward rather than a new random one every load.

### 2026-09-20 — P0/P1/P2 — done
Owner: Claude (T2/T3)
Changed: `scripts/player.gd`, `scripts/hud.gd`, `tools/selftest.gd`
Verified: full `--selftest --quit-after 6000`, 0 errors. New assertion at frame 351 confirms the HUD's status line begins with the player's chosen name.
Next: Layer 4 (city block, B0-B5) is the next real content layer — bigger scope than anything above (new terrain/scenes/imported assets), worth a fresh look rather than assuming the same "probably pre-built" pattern holds.
Notes: P0 and P1 were true by construction/existing wiring, confirmed rather than assumed (see their queue-row notes for the specific reasoning on each — not rubber-stamped). P2 surfaced one real, previously-unbuilt piece: the HUD never displayed the player's name anywhere. Added `Player.person_name()` and one line in `hud._process()`'s existing biome+clock status string. Hit the exact same "check a frame later" gotcha this project has hit repeatedly (M28, M36): `hud._process()` is on Godot's idle loop, not the physics loop `tools/selftest.gd` drives, so the new name needs one extra frame to actually reach `_clock_label.text` after `load_game()` — first attempt asserted in the same frame and failed, moving the assertion to frame 351 fixed it. This closes every card in Work Orders' Layer 0-3 (baseline through player integration).

### 2026-09-20 — B0 — done
Owner: Claude (T3)
Changed: `docs/lab/CITY_BLOCK_LAYOUT.md`
Verified: matched against `docs/PRODUCTION_BIBLE.md`'s "First shippable city slice" list exactly (apartment, street, park, shop/café, workplace — five, no more).
Next: B1 (scene) and B2 (asset manifest), both claimed by a subagent, running now.
Notes: Found and resolved a real content-boundary conflict while auditing the vendored `blocky/city/` pack for this card: it contains `police_car.obj`, `pistol_prop.obj`, and `rifle_prop.obj`, which directly contradicts the Production Bible's own non-goals ("police/crime systems") and its "lead review" requirement for violent content. Documented the decision to exclude those three models from B1/B2 rather than silently using them or silently deleting them without a record — see the layout doc's "Vendored asset note" section. If a police/crime system is ever wanted, that's a new pillar decision for Ryann, not something that should happen because an asset was sitting in a folder.

### 2026-09-20 — B1/B2 — done
Owner: Claude subagent (T2/T1)
Changed: `docs/lab/CITY_ASSET_MANIFEST.md` (new), `scenes/city_block.tscn` (new), `scripts/city_block.gd` (new), `scripts/city_render_pack.gd` (fixed), `tools/city_block_check.gd` (new, throwaway dev tool)

**B2 (asset manifest):** Audited every model in `blocky/city/models/` and every block/item in `blocky/city/city_blocks.gd`/`ATLAS_ORDER.json`, mapped each to one of B0's five locations or `shared/street`, and checked every path against the actual filesystem — see `docs/lab/CITY_ASSET_MANIFEST.md` for the full table. Found two real problems while auditing, not just cataloging:
1. `scripts/city_render_pack.gd` already existed (committed in the initial city-life-creator-foundation commit, never logged on the board) but pointed at `res://blocky/models/city/` — a folder that doesn't exist — and still listed the excluded `police_car`. Fixed: corrected the path prefix to `res://blocky/city/models/`, removed `police_car`, and added the two legitimate models it was missing (`box_van`, `street_lamp`).
2. `city_blocks.gd`'s `DEFS` array (copied from the README's prose) references four textures — `city_door`, `lantern_post`, `jail_bars`, `market_awning` — that have no actual file anywhere in the pack. `ATLAS_ORDER.json` plus the real PNGs (which use `door_lower`/`door_upper`/`door_frame`/`door_side` instead, and have no lantern/jail/awning tiles at all) are the ones that actually match disk. Documented, not fixed — fixing it means deciding how the four door pieces recombine or whether lantern/awning are dropped, a real design call for whoever eventually merges city blocks into the voxel `Blocks` registry (no card does that yet; B1 uses flat non-voxel geometry instead, so nothing depends on `city_blocks.gd` being correct right now).

Also extended B0's judgment call to two more cases in the same spirit (documented, not silently used or dropped): flagged `ballot` (implies elections/politics, a listed bible non-goal) and `lockpick` (implies a theft mechanic, adjacent to the crime non-goal) as present-but-not-mapped; and flagged the six weapon-icon item textures (`ammo_box`/`pistol`/`revolver`/`rifle`/`shotgun`/`smg`) that exist in the folder and in `ATLAS_ORDER.json` but aren't part of the README's approved 12-icon set — not named in B0's literal exclusion list (which only names the three `.obj` models), but the same reasoning applies, so none are referenced.

**B1 (city-block scene):** Built `scenes/city_block.tscn` + `scripts/city_block.gd` as a self-contained, procedurally-built scene (mirrors `scripts/chunk.gd`'s "generate the mesh in code" approach rather than hand-authoring a huge `.tscn`): a flat paved ground slab (own collision, not the procedural voxel terrain), a street with sidewalks, a park with a path, and three building shells (apartment/cafe/workplace — brick/plaster walls, roof_tile/slate_roof roofs, a real assembled door on the apartment from the four `door_*` textures, shop-window insets on cafe/workplace) plus 13 placed props from the fixed `CityRenderPack` (benches, street lamps, a traffic light, bus stop, market stall, hot dog cart, fire hydrant, vending machine, dumpster, parked sedan/taxi/box van, imbiss). Every building and every prop gets real collision — buildings via matching `BoxShape3D`, props via a `BoxShape3D` sized from each prop's own mesh AABB (not guessed dimensions). Whole block traversable well under a minute at the existing player's walk speed. **Not wired into `main.gd`** — no state-machine change, not reachable from title/creator (B5's job).

Verified:
- Full baseline captured before any change: `--headless --path . --quit-after 6000 -- --selftest --no-input --mute --fresh` (99 assertion lines, 0 errors). Re-ran after all changes: same 99 lines, 0 errors; the only differing lines across any of three runs (including two clean-tree runs of identical code) are sfx synth timing, water-visual chunk-streaming count, and a creature's random object identity/name — all pre-existing run-to-run noise unrelated to this work, confirmed by diffing two back-to-back clean-tree runs against each other first.
- `--headless --path . --import`: `CityBlock`/`CityRenderPack` register with zero parse errors.
- New standalone dev tool `tools/city_block_check.gd` (same pattern as `tools/biome_survey.gd`/`tools/find_cave.gd`: `extends SceneTree`, `godot --headless --path . --fixed-fps 60 --script tools/city_block_check.gd --quit-after 420`) loads the scene, confirms it opens with no errors, counts 22 `StaticBody3D` nodes all with a real `CollisionShape3D` (ground + 3 shells + every prop), confirms all 5 locations are registered, drops a player-scale test capsule (radius 0.25/height 1.1, matching `scenes/player.tscn`) onto the street, confirms it lands `on_floor=true` under real gravity (not falling through), then walks it 27.2 m along the street under `move_and_slide()` in 6 simulated seconds, ending still `on_floor=true` — genuine collision-driven traversal, not a visual-only pass.
- Screenshot: `godot --path . --fixed-fps 30 --quit-after 5 --write-movie <dir>/frame.png res://scenes/city_block.tscn` (note: **not** `--headless` — this build's `--headless` uses a true dummy renderer that hard-crashes on `--write-movie`; running normally with `--quit-after` still exits on its own with no interaction needed). Confirmed visually: three labeled buildings (Hollowmark Workshop, The Corner Cafe, The Player's Apartment) along a paved street with flanking sidewalks, a park with a path splitting it into two green halves, and street furniture (cars, lamps, a bus stop, market stall, hot dog cart, benches) — reads as a small, dense street, not a metropolis.

Next: B3 — apartment/cafe/workplace interiors and entrances (needs B1, B2, both done). `location_positions` on the `CityBlock` root (a `Dictionary` of location id → world `Vector3`) is exposed specifically so B3/B4 don't have to re-derive layout coordinates from scratch.

Notes:
- **Possible finding for whoever owns `player.gd`/`player.tscn` next, not fixed here (out of scope):** while building `tools/city_block_check.gd`'s test capsule, empirically dropping a bare `CapsuleShape3D(radius=0.25, height=1.1)` onto a flat collision box and watching where it actually settles shows this engine build treats `height` as the shape's total tip-to-tip height (caps included), not `height + 2*radius` as the 2026-09-20 "REGRESSION FIX" entry above states. Using that entry's formula for this tool's collision-shape offset made the capsule settle exactly one radius (0.25 m) into the ground instead of on top of it; using `height * 0.5` instead settled it exactly at y=0. This doesn't necessarily mean the real player has a visible bug — the live game collides against solid voxel chunks, not a thin slab, so a small offset may never surface the same way, and nobody has reported the player floating or sinking — but it's a real, directly-measured discrepancy against a prior board claim and worth a deliberate look rather than assuming that entry's formula going forward.
- `blocky/city/README.md`'s prose (medieval/tavern flavor — jail_bars, tavern_floor, mayor/blacksmith/thief skins) doesn't match the actual `.obj` models (modern-urban). Per this card's brief, the Production Bible's "Visual language" section is authoritative; B1 used the modern-urban assets and repurposed `tavern_floor` as café decking rather than forcing a tavern aesthetic. The skins pack is untouched — population/residents are Layer 5+, out of scope here.
- No grass/foliage texture ships in the vendored pack; the park uses a plain flat-green material as a placeholder, not a missing asset.
- Compatibility: no save-format change, no `main.gd`/`player.gd`/`world.gd` change (only `scripts/city_render_pack.gd`, which was dead code referenced by nothing before this pass, and is still not referenced by any wired-up gameplay path).

### 2026-09-20 — CORRECTION — the 2026-09-20 "REGRESSION FIX" capsule formula was wrong
Owner: Claude (T3)
Changed: none (correction only; no code touched)
Verified: independently confirmed the B1/B2 handoff's finding above with a direct, physics-free measurement — `CapsuleShape3D.new()` at `radius=0.25` for `height` in `[1.1, 1.8, 2.0]`, reading `get_debug_mesh().get_aabb()`. Result: `size.y` exactly equals `height` in all three cases (e.g. `height=1.8` → `aabb.size.y=1.8000`), never `height + 2*radius`. This is ground truth from the shape's own geometry, not inference.
Notes: **The "REGRESSION FIX" entry's stated reason for the original corridor bug was wrong**, though its fix value (`height=1.1`) is still fine. `height=1.8, radius=0.25` was already only 1.8 total (0.2 under the 2.0 gap) — not 2.3 as that entry claimed — yet it still snagged. The real original cause was almost certainly the jitter/skin-margin snag the corridor test's own comment already warns about ("A capsule that exactly fills a 2-tall gap catches on the ceiling from physics jitter alone") at a marginal 0.2 clearance, not an oversized capsule. Reducing height to 1.1 (total 1.1, ~0.9 clearance) fixed it by giving a much larger safety margin, not for the reason documented. No code change needed — `scenes/player.tscn`'s current values are fine — but anyone reading that commit message or its board entry for the underlying Godot mechanics should trust this correction instead. Leaving the original entry in place per the "never erase another agent's handoff" rule; this is the correction, not a rewrite.

**UPDATE (same day, while finishing WATER-06):** the claim just above — "No code change needed... `scenes/player.tscn`'s current values are fine" — was itself incomplete. See the WATER-06 handoff below: the `CollisionShape3D`'s Y offset (0.9, later 0.8) was *also* derived from the same wrong height formula and needed a real fix (→ 0.55), just one that nothing exposed until WATER-06 needed the player's absolute world Y to be accurate, not merely its frame-to-frame deltas. Left here rather than editing the paragraph above, same "append, don't rewrite" reasoning.

### 2026-09-20 — WATER-06 — done
Owner: Claude subagent (T3), resumed and finished by the coordinating Claude session after the subagent hit its session usage limit mid-task
Changed: `scripts/player.gd`, `scenes/player.tscn`, `tools/selftest.gd`
Verified: full `--selftest --quit-after 6000`, 0 errors, run twice clean (once pre-rebase, once on the final rebased state combining this with every other card landed today). All of the spec's gate-4 assertions pass: Wade speed/state on the shallowest possible generated water (exactly 0.9 deep, quantized — see notes), a fall through that shallow water still costs normal damage, Swim state/speed on genuinely deep water, Space/Ctrl ascend/descend, sprint-propel's speed/stamina drain/forced cooldown/regeneration, and the deep-water fall-damage cushion. Land movement, jumping, and fall damage away from water are unaffected (same assertions as every prior card, unchanged values).
Next: WATER-07 (HUD/audio presentation, now unblocked) or a design pass on whether Wade should announce itself at all in the HUD before that card starts.
Notes: Two real bugs found and fixed while resuming this task past where the subagent left off (it hit `claude.ai` rate limits mid-task and had to be resumed by the coordinating session):
1. **The subagent's own draft repeated the same wrong CapsuleShape3D formula** from the earlier (already-corrected, see above) REGRESSION FIX entry, because that wrong claim was passed to it as background context before the correction was discovered. Its `TORSO_HEIGHT` was derived as `(height + 2*radius) * 0.75 = 1.2`. Independently re-verified the correction (`CapsuleShape3D.new().get_debug_mesh().get_aabb()`, same method as the earlier correction) and replaced it: `TORSO_HEIGHT` is now a flat `1.0`, deliberately *not* derived from the collision capsule at all (1.1 total height has nothing to do with anatomical torso position — it's sized for corridor clearance), but tied directly to `world_gen.gd`'s `WATER_TABLE_Y = LOWLAND_LEVEL + 0.9`: the shallowest possible flooded column is *always* exactly 0.9 deep (water depth is quantized to the terrain's integer height steps against a flat table, so 0.9, 1.9, 2.9, ... are the only possible values — there is no continuum to tune against), so 1.0 clears it with a real, deliberate margin.
2. **A second, previously-invisible bug this surfaced**: `scenes/player.tscn`'s `CollisionShape3D` Y offset (0.9, then 0.8 after the C10 turn's corridor work) was *also* computed from the wrong total-height assumption, meant to center the capsule so the `CharacterBody3D`'s origin sits exactly at the feet/floor-contact point. With the real total height of 1.1, the correct offset is `1.1/2 = 0.55`, not 0.8 — the capsule was floating with its true bottom about 0.25 units below where `global_position.y` claimed the feet were. This never affected any *other* test because they all measure relative deltas (fall distance, walk distance, corridor clearance) which a constant vertical offset doesn't change — but WATER-06 needs the player's *absolute* Y position against the world's fixed water table, which the offset error was silently corrupting (a Wade-depth column was misread as deep enough to Swim). Fixing the offset to 0.55 also, as a side effect, resolved a previously-flagged-but-unchased cosmetic discrepancy from the C10 turn (a fall-damage test reading 1 HP low) — confirming that earlier guess ("likely the corrected capsule height shifting exact fall-distance by a few centimeters") was the right diagnosis, just not fully fixed until now.
Compatibility: `water_state` is runtime-only (not saved — reset to Dry on respawn, matches the spec's v1 boundary deferring any persistence decision to WATER-08). No save-format change. No changes to `main.gd`, `world.gd`, or land movement/jump/fall-damage code paths outside the water branch.

### 2026-09-20 — city block preview wiring (ahead of B5, not a numbered card)
Owner: Claude (T2)
Changed: `scripts/city_walker.gd` (new), `scripts/city_block.gd`, `scripts/screens.gd`
Verified: full `--selftest` suite unaffected (0 errors, same 108-line output shape). Recorded a movie of `scenes/city_block.tscn` standalone confirming the walker's first-person camera activates (overrides the dev overview camera) and renders a real street-level view of The Corner Cafe with the apartment/workplace visible on either side.
Next: B3 (interiors) is still the next real content card. This detour doesn't unblock or substitute for B4/B5 — see the addendum in city_block.gd's header.
Notes: Ryann asked directly to "wire it into the title screen and let me walk around it" after seeing the B1 screenshot. This is explicitly **not** the formal B5 card (main.gd state machine integration coexisting with the voxel world, needs B3/B4 first per Work Orders) — it's a title-screen button ("Visit Hollowmark (preview)") doing a full `get_tree().change_scene_to_file()` swap to the standalone B1 scene, keeping the two modes exactly as decoupled as B1/B2 already built them, just reachable without a dev command line. `CityWalker` (new, minimal first-person CharacterBody3D: WASD via raw physical-key checks, mouse look, gravity/jump, Esc returns to `scenes/main.tscn`) is deliberately **not** the survival `Player` class — that script assumes a `VoxelWorld` for block break/place raycasts, hunger, and inventory, none of which exist in this scene, and reusing it would risk null-reference crashes on those assumptions. Collision capsule reuses the already-validated values from `scenes/player.tscn` (radius 0.25, height 1.1, offset 0.55 — see the CORRECTION entry above for why those specific numbers). No save data, no `main.gd` changes, no interaction with the voxel world's own save/load.

### 2026-09-20 — B3 — done
Owner: Claude (T2)
Changed: `scripts/city_block.gd`, `scripts/city_walker.gd`, `tools/city_block_check.gd`
Verified: extended `tools/city_block_check.gd` with a real per-location check (not just "geometry exists") — a `CityWalker` instance placed at each of the three doors, stepped one physics frame, confirmed it actually teleported into that location's interior (`y` near `INTERIOR_Y`), then placed near the interior's own exit trigger and confirmed it teleported back outside (`y` near the location's known `location_positions` value). All three pass for apartment/cafe/workplace. Full `--selftest` suite unaffected (0 errors). Screenshots confirm the interiors render and read correctly (had to add per-room lighting after the first screenshot showed the rooms too dim to make out — the scene's outdoor sun doesn't reach a walled room built at effectively "midnight" underground, even with no ceiling).
Next: B4 (nav/route markers) or B5 (real main.gd integration) are the remaining Layer 4 cards. `location_positions`/`_entrances` are both public on `CityBlock` for either to use without re-deriving coordinates.
Notes: Interiors are real 3D rooms (floor + 4 walls, no ceiling, one warm `OmniLight3D` each), not menus — same "generate the mesh in code" approach as the rest of B1 — but placed as disconnected "pockets" 30 units straight down from their building (`INTERIOR_Y = -30`), not literally behind the door, since teleporting rather than a real walk-through doorway means the room never needs to spatially coexist with the street at all. Entering is a trigger `Area3D` at the door; leaving is another one near the room's far wall; both call a new `CityWalker.teleport_to(pos, yaw)` method, guarded (`body.has_method("teleport_to")`) so an unrelated physics body could never crash the trigger. Cafe/workplace also gained real door decals (they only had windows before) — reused the same `door_lower/upper/frame/side` textures the apartment already used, offset beside each shop window rather than overlapping it. Furniture is plain primitive boxes reusing existing textures/colors (bed, table, café counter + bench seating via the existing prop, workbench + crate shelving) — no new art, matching the asset manifest's finding that no dedicated furniture models exist in the vendored pack. **Pre-existing, unrelated observation, not touched:** `tools/city_block_check.gd`'s own street walk-test now (and, checked, also before this change) reports "moved 19.7 m" against its own "expect > 25" comment — nothing in this pass touches street-level geometry, so this predates B3; flagging rather than silently ignoring or scope-creeping into fixing it.

### 2026-09-20 — WATER-07 — claimed
Owner: Claude (T2)
Expected files: `scripts/hud.gd`, `scripts/sfx.gd`, `scripts/main.gd`
Plan: presentation-only water response per `docs/lab/WATER_AND_SWIMMING_SPEC.md`'s "Presentation" section — underwater screen tint (reusing `hud.gd`'s existing `_damage_flash`-style `ColorRect` technique, per the spec's explicit steer away from touching `WorldEnvironment` fog, which `day_night.gd` already drives every frame), splash-on-entry/stroke-cadence audio (new `sfx.gd` sounds, synthesized like everything else in that file — no audio files), and a low-pass filter toggle on head-submerged (mirrors the exact pattern `Sfx.set_underwater()` already established, if that's still present — will check before assuming). All driven by consuming `Player.water_state_changed`/a head-submerged signal, not by re-deriving water queries HUD-side. No gameplay-logic changes.
Note to Codex's heartbeat: these three files are actively being edited right now — please pick a different unblocked card (B4 nav markers is open and untouched) rather than editing the same files this run.

### 2026-09-20 — WATER-07 — done
Owner: Claude (T2)
Changed: `scripts/hud.gd`, `scripts/sfx.gd`, `tools/selftest.gd`
Verified: full `--selftest --quit-after 6000`, 0 errors. New assertion at frame 1395 (a few idle-frames after Swim is first entered at 1391, same "check a frame later" reasoning as the frame-351 HUD-name test) directly confirms all three presentation effects actually fired: underwater tint target > 0, the SFX bus's low-pass effect enabled, and `Sfx.instance.plays["splash_in"] > 0`. Did not add a symmetric splash_out/tint-fade-back test — the existing water test sequence never transitions back to Dry after entering Swim (by design, to keep the deep-water fixture predictable for the tests after it), and the exit code path is structurally identical to the entry path (same `_on_water_state_changed` branch, same guard), so it wasn't worth restructuring the test sequence to force a return-to-dry just to re-prove already-proven logic — noted as a real, stated scope trim, not silently skipped.
Next: WATER-08 (edges/save decision/creatures/performance review) is the last card before WATER-09's full release gate.
Notes: `main.gd` ended up not needing any change — HUD already holds a direct `_player` reference and `Sfx` is a static-singleton style API, so everything wired through `hud.bind_player()`'s existing signal-connection block. Underwater tint reuses `_damage_flash`'s exact `ColorRect` technique (a second one, `_underwater_tint`), deliberately not touching `WorldEnvironment` fog (the spec explicitly steers away from that, since `day_night.gd` already drives it every frame — a second system fighting over the same resource for a cosmetic tint isn't worth the coupling). The low-pass filter (`AudioEffectLowPassFilter`, 700 Hz cutoff) is added to both the SFX and Music buses at startup but disabled, toggled by a new `Sfx.set_underwater(bool)` — this is fresh work matching the current spec's description, not a revival of the swim system WATER-02 removed (the spec's v1 boundary explicitly says "does not authorize reintroducing deleted code"; nothing here touches player movement or land audio, only presentation on top of WATER-06's already-shipped state machine). Stroke cadence (a new "stroke" sound, ~1.1s interval, only while actually Swim/Sprint-swim AND actually moving — mirrors `player.gd`'s own `_footstep()` "only while moving" rule) lives in `hud._process()` rather than `player.gd`, since it's presentation timing, not movement logic, and keeps this card's changes out of the file WATER-06 already extensively tested.

### 2026-09-20 — B4 — claimed
Owner: Claude (T2)
Expected files: `scripts/city_block.gd`, `scripts/debug_actor.gd` (new), `tools/city_route_check.gd` (new)
Plan: add named waypoint markers (street spine + park path + each location's door-out point) to `CityBlock`, a small `get_route(from, to)` helper that returns an ordered waypoint list, and a minimal autonomous `DebugActor` controller (no input, moves toward each waypoint in sequence, matches `CityWalker`'s speed/gravity constants) — then a standalone headless tool that drives it through all five locations in a loop and asserts it actually arrives at each (position, not just time elapsed), same pattern as `tools/city_block_check.gd`. No changes to `main.gd`, `player.gd`, or B5 integration scope.

### 2026-09-20 — B4 — done
Owner: Claude (T2)
Changed: `scripts/city_block.gd`, `scripts/debug_actor.gd` (new), `tools/city_route_check.gd` (new)
Verified: `tools/city_route_check.gd` (`--fixed-fps 60 --quit-after 1700`) drives a `DebugActor` through a full tour of all 5 locations (apartment -> cafe -> park -> workplace -> street -> apartment); every leg completes and lands within 0.44-0.48m of its target (well inside the 1.0m check and the actor's own 0.5m arrival radius), 0 errors. An invalid-location `get_route()` call correctly returns empty. Re-ran `tools/city_block_check.gd` (B1/B3's existing checks) unchanged — same 45/45 collision count, same pre-existing (and previously logged, unrelated) "moved 19.7m vs expect >25" street-walk note, all 3 entrances still teleport correctly. Full `--selftest --quit-after 6000` clean, 0 errors, same output shape as the prior WATER-07 run.
Next: B5 — integrate city entry into `main.gd`'s state machine without breaking procedural-world play (needs B4, now done). This closes Layer 4's remaining prerequisite card.
Notes: `route_markers` (Dictionary, name -> Vector3) is a small graph: each of apartment/cafe/workplace connects to a "spine" point at its own X on the street's z=0 band (the same band `_spawn_walker()`'s own comment already documents as clear of every building/prop); the park connects via a `park_entry` point that runs north along the existing `ParkPath` visual strip. `CityBlock.get_route(from, to)` is a plain BFS over that graph (small and tree-shaped, so the path is always unique) returning an ordered `Array[Vector3]`. `scripts/debug_actor.gd` is a new, deliberately minimal `CharacterBody3D` controller (no input, no `teleport_to()` method) that walks toward each waypoint in sequence — same speed/gravity constants as `CityWalker`, same measured collision-capsule values as every other actor in this scene (radius 0.25, height 1.1, offset 0.55). It intentionally lacks `teleport_to()` so it can safely walk past building doors along the route without `_add_transition()`'s existing guard pulling it into an interior pocket — that existing guard (built for B3) is what makes this safe with no extra work. Built as a general-purpose route-follower, not single-use: Layer 5's resident home/work/food routines (S4/S5) will need exactly this shape (a route from `get_route()`, an actor that walks it) — same reuse pattern the board has repeatedly favored over one-off code. No changes to `main.gd`, `player.gd`, save format, or B1-B3's already-verified geometry/collision/interiors.
