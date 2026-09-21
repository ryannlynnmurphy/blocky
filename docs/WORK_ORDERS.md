# Blocky Work Orders

Work orders are in dependency order. A card may start only after all cards
listed in **Needs** are done. The tier is the minimum recommended capability.

## Layer 0 — baseline and guardrails

| Card | Tier | Task | Needs | Done when |
| --- | --- | --- | --- | --- |
| C0 | T3 | Establish the Godot baseline: import, run, record version and existing self-test result. | — | A reproducible run command and baseline note are on the board. |
| C1 | T1 | Inventory the existing committed city/creator foundation without changing code. | C0 | Board lists each relevant file and whether it is source, generated asset, or unknown. |
| C2 | T3 | Retain the integrated creator foundation, then record exactly which parts are replaced to meet the light-gray modular-wardrobe direction. | C1 | Decision is recorded; no accidental rewrite follows. |

## Layer 1 — Create a Person visual slice

| Card | Tier | Task | Needs | Done when |
| --- | --- | --- | --- | --- |
| C3 | T2 | Restyle the existing creator with a light canvas and light-gray panels. | C2 | It opens without altering normal gameplay. |
| C4 | T2 | Put the current blocky player model in a live 3D preview with reset camera. | C3 | Preview renders and reset works. |
| C5 | T2 | Add name and pronoun controls with temporary in-memory values. | C3 | Inputs are readable and survive creator navigation. |
| C6 | T1 | Define wardrobe catalog data for shirts, pants, belts, bracelets, and shoes. | C2 | Every item has stable ID, display name, slot, and asset reference. |
| C7 | T2 | Implement one visible T-shirt choice end-to-end in the preview. | C4, C6 | Selecting it visibly changes the preview. |
| C8 | T2 | Add pants, belt, bracelet, shoes, and one-per-slot selection. | C7 | One coherent outfit is previewed; changing a slot replaces only that slot. |
| C9 | T2 | Add skin/hair controls, cosmetic randomize, Back, and Continue. | C5, C8 | All controls work; no persistence yet. |
| C10 | T3 | Review the creator against the approved light-theme visual and protect existing game flows. | C9 | Review note and visual capture are posted. |

## Water rebuild — designed from scratch

Water returns only through this sequence. It does not revive old code or make
water a normal opaque block. The precise contract lives in
`lab/WATER_AND_SWIMMING_SPEC.md`.

| Card | Tier | Task | Needs | Done when |
| --- | --- | --- | --- | --- |
| WATER-03 | T3 | Approve the data/query contract and special-swim specification. | — | API, scope, controls, and test gates are recorded; no runtime code is changed. |
| WATER-04 | T2 | Add deterministic water-table queries to terrain/world data. | WATER-03 | Dry, wading, surface, and submerged positions classify deterministically. |
| WATER-05 | T2 | Render chunk-aligned transparent water visuals with no collision. | WATER-04 | Water never renders over solid terrain and remains correct across streamed chunks. |
| WATER-06 | T3 | Integrate player water state, normal swim, and special Shift-propel mechanics. | WATER-04, WATER-05 | Land behavior remains intact; transitions, speeds, and fall rules pass tests. |
| WATER-07 | T2 | Add water presentation: HUD, underwater treatment, splash/stroke audio. | WATER-06 | Presentation follows the single player water-state API and clears on exit. |
| WATER-08 | T3 | Review edges, persistence decision, creature policy, and performance. | WATER-07 | Save/migration decision is recorded and streaming/spawn edge cases pass. |
| WATER-09 | T3 | Complete water regression suite and release review. | WATER-08 | Headless and manual shore/chunk/save checks are recorded. |

## Layer 2 — person data and persistence

| Card | Tier | Task | Needs | Done when |
| --- | --- | --- | --- | --- |
| D0 | T3 | Define versioned `PersonData` fields and defaults. | C10 | Schema includes identity, appearance, values, needs, and stable ID. |
| D1 | T2 | Add personality-axis and deep-value editor data. | D0 | Values validate and have safe defaults. |
| D2 | T2 | Add five basic needs to the data model. | D0 | Need values clamp correctly. |
| D3 | T3 | Save/load a person in a separate test save. | D0–D2 | A saved person reloads identically. |
| D4 | T3 | Integrate person data with the game save format and migration policy. | D3 | Old saves still have a safe path. |

## Layer 3 — player integration

| Card | Tier | Task | Needs | Done when |
| --- | --- | --- | --- | --- |
| P0 | T3 | Route New Game through the creator. | C10, D4 | Confirming creator reaches play; existing Continue remains safe. |
| P1 | T2 | Apply saved appearance to the actual player actor. | P0 | Spawned player matches preview. |
| P2 | T3 | Verify reload, HUD name, and survival-system regression. | P1 | Save/load and existing self-test pass. |

## Layers 4-7 — SUPERSEDED 2026-09-20, see docs/AGENT_BOARD.md

Ryann discarded the entire Hollowmark Sims-style city (this layer through
Layer 7) and directed a restart as a Minecraft/New-York-inspired city built
from real voxel blocks in the open world instead. Every card below is void
-- left here as a record of what was tried, not a plan to resume. Do not
pick up B0-B5/S3-S5/L0-L5/A0 as if they were still open or still done; the
code behind them has been deleted. See the dated AGENT_BOARD.md entry
"MAJOR DIRECTION CHANGE" for what was removed, what was kept, and where
the new direction (scripts/city_builder.gd) actually stands.

## Layer 4 — city block

| Card | Tier | Task | Needs | Done when |
| --- | --- | --- | --- | --- |
| B0 | T3 | Define the first block's locations and location IDs. | P2 | Apartment, street, park, shop/café, workplace are named and documented. |
| B1 | T2 | Build city-block scene: terrain, roads, shells, collision. | B0 | Player can traverse the block. |
| B2 | T1 | Audit/import approved city assets and map each to a location use. | B0 | No missing paths; asset manifest is posted. |
| B3 | T2 | Add apartment, shop, workplace interiors and entrances. | B1, B2 | Every location is enterable. |
| B4 | T2 | Add route markers/navigation test path. | B3 | A debug actor can travel between locations. |
| B5 | T3 | Integrate city entry without breaking procedural-world play. | B4 | Both modes launch reliably. |

## Layer 5 — time, needs, and one resident

| Card | Tier | Task | Needs | Done when |
| --- | --- | --- | --- | --- |
| S0 | T3 | Add fixed simulation clock and serializable time state. | B5 | Time advances consistently and reloads. |
| S1 | T2 | Add HUD clock and test speed controls. | S0 | Time is legible and testable. |
| S2 | T3 | Make actions change time, needs, and money. | S0, D2 | Sleep/eat/work/talk each affect correct state. |
| S3 | T3 | Create one resident data record with home, job, routine, and appearance. | S2 | Resident has valid structured state. |
| S4 | T2 | Spawn and render that resident in the city. | S3 | Resident appears with modular look. |
| S5 | T3 | Implement goal priority and home/work/food routine. | S4 | Debug panel proves a full routine loop. |

## Layer 6 — population, relationships, institutions

| Card | Tier | Task | Needs | Done when |
| --- | --- | --- | --- | --- |
| L0 | T1 | Prepare deterministic names, appearance presets, and routine data for 20 residents. | S5 | Data passes validation; no runtime spawning changes. |
| L1 | T3 | Scale scheduling from 1 to 3, 5, then 20 residents. | L0 | Each population step is profiled and stable. |
| L2 | T3 | Add relationship records and interaction events. | L1 | Conversation changes a relationship deterministically. |
| L3 | T2 | Add memory records and resident debug inspector. | L2 | Important event is inspectable after time advances. |
| L4 | T3 | Add jobs, paydays, shop purchase, and rent. | L3 | Money flows affect people and persist. |
| L5 | T3 | Add a small consequence chain, such as missed shift → firing → money pressure. | L4 | Chain is simulation-driven and explainable. |

## Layer 7 — agency, scale, and AI presentation

| Card | Tier | Task | Needs | Done when |
| --- | --- | --- | --- | --- |
| A0 | T2 | Add a context interaction menu. | L5 | Player can target a person/place and see valid actions. |
| A1 | T3 | Implement talk, work, buy, sleep, and result log. | A0 | Actions change real state with clear feedback. |
| A2 | T3 | Add near/far simulation tiers and resident performance benchmarks. | A1 | Performance budget is recorded at 50 and 100 residents. |
| A3 | T3 | Add rule-based city events and templated news feed. | A2 | Every headline links to a factual event. |
| A4 | T3 | Design optional AI adapter with constrained inputs/output validation/offline fallback. | A3 | No AI call can alter authoritative simulation state. |

## What smaller agents can take immediately

After C2 is complete, T1/OpenCode agents can safely take **C6**. After B0,
they can take **B2**. After S5, they can take **L0**. They should
not be assigned creator integration, save changes, routine logic, or core
scene changes without a T2/T3 owner.
