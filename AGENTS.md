# Blocky Agent Handbook

## Mission

Build a living voxel city RPG on top of the existing Godot survival game.
The player creates a person, controls what that person says and does, and
lives in a city whose residents and institutions have structured simulated
state. AI may eventually express that state; it must never become the source
of truth for it.

Read `README.md`, `docs/PRODUCTION_BIBLE.md`, `docs/WORK_ORDERS.md`, and
`docs/AGENT_BOARD.md` before taking a task.

**Status (2026-09-20, updated):** Codex now runs as a recurring heartbeat
automation (Ryann's "blocky-build-coordination" automation, every 15 min)
that reads this board fresh each run and treats entries here as
coordination messages — it will not touch a file Claude has an open/recent
claim on, and works the next unblocked, unclaimed card. Claude has been the
primary active agent through the middle of the day (Layers 0–3 fully closed
out, WATER-06 done, city Layer 4 through B3). **Both agents: before
claiming a card, re-read this table — it changes fast. Claim promptly,
push promptly, and keep the "Expected files" column accurate so the other
agent can avoid your in-progress files without needing to ask.**

## Agent capability tiers

| Tier | Best use | May change | Must not own alone |
| --- | --- | --- | --- |
| **T1 — Support** | OpenCode/smaller agents: asset inventories, data-entry files, focused research, reproduction steps, screenshots, docs, test checklists, isolated texture/material work | Markdown, new data assets, narrowly scoped test tools, explicitly named files | `main.gd`, save format, player/world architecture, simulation rules, broad refactors |
| **T2 — Builder** | UI scenes, isolated GDScript components, a single interaction, tests for a subsystem | A task's named scene/scripts plus tests | Cross-system integration, save migrations, performance architecture |
| **T3 — Lead** | Strong agents: architecture, integration, data models, save/load, scheduling, profiling, merge decisions | Any files necessary for an approved work order | Replacing working systems without a recorded decision |

When uncertain, assign the work one tier higher. A T1 agent can prepare a
clean, reviewable task for T2/T3; that is valuable work, not busywork.

## Non-negotiable engineering rules

1. Preserve working voxel survival systems unless the work order explicitly
   changes them.
2. Use `PersonData`/structured records as the authority for people, needs,
   relationships, jobs, money, and memories. Generated prose never writes
   facts directly.
3. Use modular reusable character assets. Do not generate raw 3D people at
   runtime.
4. One worn item per apparel slot. The creator can offer many choices while
   displaying one coherent outfit.
5. Do not add a dependency, a network service, an LLM call, a new save-field,
   or a broad refactor without a T3-owned work order.
6. Do not commit generated imports, secret files, or unrelated changes.
7. Do not mark a task done because code exists. Run every acceptance check.

## Before coding

1. Claim one unblocked card in `docs/AGENT_BOARD.md`.
2. Read its matching work order and its prerequisites.
3. Inspect only the files named by that card plus direct dependencies.
4. State the files you expect to change before making broad edits.
5. If another agent already owns a file you need, post a dependency note;
   do not overwrite their work.

## Definition of done

A task is complete only when it has:

- a narrowly scoped implementation;
- the work order's acceptance checks run and reported;
- no unrelated file changes;
- an entry in the Agent Board handoff log naming changed files, tests, and
  known limitations;
- a reviewer/lead check for every T2 or T3 task.

## Handoff format

Post this at the bottom of `docs/AGENT_BOARD.md`:

```md
### YYYY-MM-DD — [CARD-ID] — done / blocked
Owner: agent name and tier
Changed: `path/file.gd`, `path/file.tscn`
Verified: exact command or manual steps and result
Next: the next unblocked card, or the precise blocker
Notes: compatibility, save-format, or visual-review notes
```
