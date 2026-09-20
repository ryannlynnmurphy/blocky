# Creator Foundation Audit

**Decision:** retain the working creator foundation and extend it in place.
The initial plan called it an uncommitted draft, but it is already committed
and integrated. Rewriting it would create unnecessary risk to the playable
New Game and save path.

## Retained foundation

| Area | Current seam | Decision |
| --- | --- | --- |
| Game flow | `scripts/main.gd` | Keep New Game → creator → play flow. |
| Creator screen | `scripts/screens.gd` | Keep live preview and controls; restyle in C3. |
| Profile data | `scripts/person_profile.gd` | Keep current profile/save bridge; add versioned person schema only in D0. |
| Preview/apply | `scripts/person_appearance.gd`, `scripts/player.gd` | Keep shared blocky rig and recolor proof; extend with apparel slots. |
| References | `designs/`, `CITY_ASSET_PACK.md` | Keep as visual/asset references; verify every claimed runtime asset before use. |

## Replaced incrementally

1. Dark purple creator canvas/panels become the approved light theme with
   light-gray panels (C3).
2. A single color-preset `outfit` and `accent` become a stable wardrobe
   catalog: T-shirt, pants, belt, bracelet, and shoes—one selection per slot
   (C6–C8).
3. Existing early background/neighborhood/job controls stay functional but are
   documented as provisional until the versioned `PersonData` work (D0).

## Guardrail

No card in this phase changes the existing save version or deletes the
creator path. Any schema migration waits for D0–D4.

