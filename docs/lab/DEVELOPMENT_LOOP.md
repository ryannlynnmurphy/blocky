# Blocky Development Lab

This is the repeatable engine for finishing Blocky without turning the project
into an uncontrolled pile of agent edits. The authoritative backlog and shared
message board are in `../AGENT_BOARD.md`; the project-wide rules are in
`../../.cursor/rules/blocky-constitution.mdc`.

## The continuous loop

1. **Triage.** A lead converts the highest-value idea or bug into a small card
   with outcome, scope, dependencies, owner tier, and acceptance checks.
2. **Scout.** A T1 scout maps the real files/assets and calls out risks. This
   is optional only when the integration seam is already obvious.
3. **Build.** One owner claims the card and makes the smallest complete change.
   Parallel work may only touch disjoint files or a declared data contract.
4. **Verify.** Run focused checks, then the Godot headless self-test for shared
   gameplay. For UI/feel work, capture the manual launch and test steps.
5. **Review.** A verifier checks the actual diff against the card. T3 resolves
   cross-system questions.
6. **Commit.** Make one narrow conventional commit, update the board, and move
   the next unblocked card to READY.
7. **Batch release.** At 5 verified local commits (or a user-requested release
   boundary), run the full regression suite, inspect status/diff, and push the
   batch if remote access is already authorized. Otherwise keep the commits
   local and report the precise push-ready state.
8. **Repeat.** Select the next highest-priority READY card. Stop only for a
   human decision, technical blocker, or finished milestone.

## Lab lanes

| Lane | Typical tier | Can run in parallel with | Cannot own alone |
| --- | --- | --- | --- |
| Recon / assets / data | T1 | any disjoint lane | shared runtime files, save format |
| Contained UI / creator | T2 | assets, tests, docs | game-flow integration |
| Tests / QA | T1–T2 | all read-only; isolated test files | approving unrun visual work |
| Core simulation / saves / player-world | T3 | only planned, disjoint support work | — |
| Integration / release | T3 | verification | rewriting another active card |

## Commit and push ledger

Record each verified commit below. Reset the batch count only after a successful
push. A failed or unavailable push does not discard local work.

| Batch | Commits | Regression | Push state |
| --- | --- | --- | --- |
| Next | 0 / 5 | pending | local development |

## Definition of a usable game increment

An increment lets a player see, do, or reliably test one more meaningful thing.
Documentation, asset manifests, and probes are valuable enabling work, but they
do not replace a runnable slice.

