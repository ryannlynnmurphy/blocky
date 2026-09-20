# Hollowmark city asset manifest (B2)

Audit of every model in `blocky/city/models/` and every block/item declared
in `blocky/city/city_blocks.gd` / `blocky/city/ATLAS_ORDER.json`, mapped to
one of B0's five locations (`docs/lab/CITY_BLOCK_LAYOUT.md`) or
`shared/street` for general dressing. Every path below was checked against
the actual files on disk (see "Verification" at the bottom) — this is B2's
literal acceptance check, not an assumption.

**Excluded per `docs/lab/CITY_BLOCK_LAYOUT.md`'s content-boundary decision:**
`police_car.obj`, `pistol_prop.obj`, `rifle_prop.obj`. None of the three are
listed below, imported, or referenced anywhere in B1's scene.

## Models (`blocky/city/models/`)

13 of the folder's 16 `.obj` models are in scope (3 excluded above). All 13
are registered in `scripts/city_render_pack.gd` (`CityRenderPack.PROP_PATHS`)
and placed at least once in `scenes/city_block.tscn`.

| Model | Path | Location use |
| --- | --- | --- |
| `bench` | `blocky/city/models/bench.obj` | park (x2) + street (x1) — seating |
| `box_van` | `blocky/city/models/box_van.obj` | workplace — curbside delivery vehicle |
| `bus_stop` | `blocky/city/models/bus_stop.obj` | shared/street — transit stop near workplace |
| `dumpster` | `blocky/city/models/dumpster.obj` | workplace — service alley behind the shell |
| `fire_hydrant` | `blocky/city/models/fire_hydrant.obj` | shared/street — sidewalk dressing near the apartment |
| `hot_dog_cart` | `blocky/city/models/hot_dog_cart.obj` | park — food cart |
| `imbiss` | `blocky/city/models/imbiss.obj` | cafe — second food stall beside the café shell |
| `market_stall` | `blocky/city/models/market_stall.obj` | shared/street — café/park boundary |
| `sedan` | `blocky/city/models/sedan.obj` | shared/street — parked curb dressing |
| `street_lamp` | `blocky/city/models/street_lamp.obj` | shared/street — lighting along the spine (x4) |
| `taxi` | `blocky/city/models/taxi.obj` | shared/street — parked curb dressing |
| `traffic_light` | `blocky/city/models/traffic_light.obj` | shared/street — crossing near the park |
| `vending_machine` | `blocky/city/models/vending_machine.obj` | workplace — breakroom-style machine outside the shell |

**Excluded (do not import/place/reference):**

| Model | Path | Reason |
| --- | --- | --- |
| `police_car` | `blocky/city/models/police_car.obj` | B0 decision — conflicts with the bible's "no police/crime systems" non-goal |
| `pistol_prop` | `blocky/city/models/pistol_prop.obj` | B0 decision — violent content needs lead review |
| `rifle_prop` | `blocky/city/models/rifle_prop.obj` | B0 decision — violent content needs lead review |

**Pre-existing bug found and fixed while auditing:** `scripts/city_render_pack.gd`
already existed (committed in the initial city-life-creator-foundation
commit, before B0/B1/B2 were claimed) but pointed at
`res://blocky/models/city/*.obj` — a folder that does not exist; the real
path is `res://blocky/city/models/*.obj`. It also still listed `police_car`
and was missing two legitimate models (`box_van`, `street_lamp`). All fixed
in this pass as part of B2's "no missing paths" check — see that file's
2026-09-20 note.

## Blocks (`blocky/city/city_blocks.gd` vs `blocky/city/ATLAS_ORDER.json`)

**These two sources disagree, and only one of them matches real files.**
`ATLAS_ORDER.json` (16 tiles) matches the actual PNGs shipped in
`blocky/city/textures/blocks/` exactly. `city_blocks.gd`'s `DEFS` array
(also 16 entries, copied from the README's prose block list) references
four `tex` names — `city_door`, `lantern_post`, `jail_bars`,
`market_awning` — that have **no corresponding texture file anywhere in the
pack**. `jail_bars` is also thematically excluded on the same grounds as
the weapon models even if it did have a texture (crime/prison content needs
lead review).

Treating `ATLAS_ORDER.json` + the individual PNG files as ground truth
(they're internally consistent and every path resolves), not
`city_blocks.gd`'s stale `DEFS`:

| Block (`ATLAS_ORDER.json`) | Path | Location use |
| --- | --- | --- |
| `cobble_road` | `blocky/city/textures/blocks/cobble_road.png` | street — road surface |
| `flagstone` | `blocky/city/textures/blocks/flagstone.png` | shared/street — sidewalks |
| `cobblestone` | `blocky/city/textures/blocks/cobblestone.png` | shared/street — base ground/plaza fill |
| `brick` | `blocky/city/textures/blocks/brick.png` | apartment + workplace — wall material |
| `plaster` | `blocky/city/textures/blocks/plaster.png` | cafe — wall material (lighter, distinguishes it from the other two shells) |
| `roof_tile` | `blocky/city/textures/blocks/roof_tile.png` | apartment + cafe — roofs |
| `slate_roof` | `blocky/city/textures/blocks/slate_roof.png` | workplace — roof (reads as a heavier/industrial roof) |
| `shop_window` | `blocky/city/textures/blocks/shop_window.png` | cafe + workplace — front-window insets |
| `door_lower` | `blocky/city/textures/blocks/door_lower.png` | apartment — entrance door (lower half) |
| `door_upper` | `blocky/city/textures/blocks/door_upper.png` | apartment — entrance door (upper half) |
| `door_frame` | `blocky/city/textures/blocks/door_frame.png` | apartment — door frame trim |
| `door_side` | `blocky/city/textures/blocks/door_side.png` | apartment — door side trim |
| `sign_board` | `blocky/city/textures/blocks/sign_board.png` | shared — one location-name sign per building (apartment, cafe, workplace, park) |
| `tavern_floor` | `blocky/city/textures/blocks/tavern_floor.png` | cafe — repurposed as the café's outdoor deck flooring, not a tavern floor (see README mismatch note below) |
| `crate` | `blocky/city/textures/blocks/crate.png` | shared/street — stacked near the market stall |
| `hay` | `blocky/city/textures/blocks/hay.png` | **not placed.** Texture exists and resolves fine, but hay bales don't fit the bible's modern-urban "Hollowmark" street; no location needed it. Left available for future rustic dressing if ever wanted. |

`city_blocks.gd` itself is **not modified** by B1/B2 — fixing its stale
`DEFS` array would mean deciding whether `door_lower/upper/frame/side`
become one composite door block, and whether `lantern_post`/
`market_awning` are dropped or re-textured, which is a real design call for
whoever actually merges city blocks into the voxel `Blocks` registry
(no card currently does this — B1 uses flat, non-voxel geometry instead,
so nothing in this pass depends on `city_blocks.gd` being correct). Flagging
it here so it isn't silently trusted later.

## README vs. actual files — the medieval/modern mismatch

`blocky/city/README.md`'s prose (jail_bars, tavern_floor, mayor,
blacksmith, thief skins) describes a medieval/tavern pack. The actual
`.obj` models are modern-urban (sedan, taxi, box_van, street_lamp,
traffic_light, vending_machine, bus_stop, fire_hydrant). Per this card's
brief, the Production Bible's "Visual language" section (chunky voxel
forms, light/calm) is authoritative, not the README's self-description.
B1's scene uses the modern-urban assets and repurposes a couple of
medieval-flavored textures where they read fine out of context
(`tavern_floor` as café decking, above). It does not attempt to resolve or
hide the mismatch — the skins pack (citizen/guard/mayor/etc.) is out of
scope for B1/B2 entirely (population/residents are Layer 5+, not this
card).

## Items (`blocky/city/textures/items/` / `ATLAS_ORDER.json`)

Items are 2D icons for a future economy/needs UI (Layer 5+ money, jobs,
shops). **None are rendered in B1's scene** — B1 is terrain/roads/shells/
collision only, no economy systems yet. This section maps them to their
eventual location for whoever builds that layer.

| Item | Path | Eventual location use |
| --- | --- | --- |
| `coin` | `blocky/city/textures/items/coin.png` | shared — money (Layer 6+) |
| `coin_stack` | `blocky/city/textures/items/coin_stack.png` | shared — money (Layer 6+) |
| `purse` | `blocky/city/textures/items/purse.png` | shared — money (Layer 6+) |
| `bread` | `blocky/city/textures/items/bread.png` | cafe — hunger need |
| `apple` | `blocky/city/textures/items/apple.png` | cafe — hunger need |
| `tonic` | `blocky/city/textures/items/tonic.png` | shared — a future health/illness need (none exists yet) |
| `ledger` | `blocky/city/textures/items/ledger.png` | workplace — jobs/bookkeeping |
| `key` | `blocky/city/textures/items/key.png` | apartment — future door/entrance system (B3) |
| `letter` | `blocky/city/textures/items/letter.png` | shared/street — social flavor (mail) |
| `flower` | `blocky/city/textures/items/flower.png` | park — decorative/gift flavor |
| `ballot` | `blocky/city/textures/items/ballot.png` | **flagged, not mapped.** Implies elections/government, which the bible explicitly lists as a non-goal ("politics, unions, and resistance systems") for the first slice. Not referenced anywhere; would need its own pillar decision like the weapon models, if ever wanted. |
| `lockpick` | `blocky/city/textures/items/lockpick.png` | **flagged, not mapped.** Implies a theft mechanic, which sits right next to the bible's "police/crime systems" non-goal and its lead-review requirement for crime content. Not referenced anywhere. |

**Present in the folder but excluded from the item atlas / not part of the
approved set:** `ammo_box.png`, `pistol.png`, `revolver.png`, `rifle.png`,
`shotgun.png`, `smg.png`. These aren't named in B0's literal exclusion list
(which only names the three `.obj` models), but they are weapon icons that
would reintroduce the exact same content-boundary issue for the same
reason. Extending the same judgment call B0 made, in the same spirit
(documented, not silently used or silently deleted): **not mapped to any
location, not referenced anywhere in this pass.** They do exist in
`ATLAS_ORDER.json`'s `items` list and their files do exist on disk (checked
below), so this is a documentation flag, not a missing-path problem. If an
economy/inventory system is ever built, whoever builds it should treat
these the same as `police_car`/`pistol_prop`/`rifle_prop` unless a lead
decides otherwise.

## Verification (no missing paths)

Checked every path referenced above (and every path in `ATLAS_ORDER.json`,
including the excluded/flagged ones, to confirm they're real files and not
also broken) directly against the filesystem:

- All 16 models in `ATLAS_ORDER.json.models` resolve to a real `.obj` file
  in `blocky/city/models/` (13 used, 3 excluded above).
- All 16 blocks in `ATLAS_ORDER.json.blocks` resolve to a real `.png` file
  in `blocky/city/textures/blocks/`.
- All 18 items in `ATLAS_ORDER.json.items` resolve to a real `.png` file in
  `blocky/city/textures/items/` (12 used/flagged-for-future, 6 flagged
  weapon icons above).
- `city_blocks.gd`'s four broken `tex` references (`city_door`,
  `lantern_post`, `jail_bars`, `market_awning`) do **not** resolve to any
  file — documented above as a known gap in that file, not fixed (see
  rationale above), and not used by B1's scene, which doesn't read
  `city_blocks.gd` at all.
- `scripts/city_render_pack.gd`'s paths were broken before this pass
  (wrong folder) and are fixed now; all 13 now resolve.

## Next

B1 uses this manifest directly: `scenes/city_block.tscn` /
`scripts/city_block.gd` place every "used" model and block above at least
once, textured/instanced from the exact paths in this document.
