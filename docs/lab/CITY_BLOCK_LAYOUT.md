# Hollowmark — first city block (B0)

Card B0: name and document the first city block's locations, per
`docs/PRODUCTION_BIBLE.md`'s "First shippable city slice" — one dense
block, not a metropolis. The neighborhood is already named in the
creator (`PersonProfile.APPEARANCE_OPTIONS`/identity defaults use
"Hollowmark Central"; the creator's CTA button is "Enter Hollowmark").

## Locations and IDs

| Location ID | Display name | Role |
| --- | --- | --- |
| `apartment` | The player's apartment | Home. Sleep/save point, private, one entrance. |
| `street` | Hollowmark Street | The spine connecting every other location; where residents are seen walking routines. |
| `park` | Hollowmark Park | Small green space; a social/rest location with no economic function in v1. |
| `cafe` | The Corner Café | The one shop/café — food (needs), a job slot, a social hub. |
| `workplace` | Hollowmark Workshop | The one workplace — a generic small workshop/storefront, deliberately not tied to one specific trade so it can host varied jobs later without a redesign. |

Five locations total, matching the bible's list exactly (apartment,
street, park, shop/café, workplace) — no sixth location for v1.

## Population

Twenty or fewer residents (bible's cap). Not sized yet — that's L0/S3+,
after the block itself exists and B5 integrates it with procedural-world
play.

## Vendored asset note — a real content-boundary issue, not nitpicking

`blocky/city/models/` contains `police_car.obj`, `pistol_prop.obj`, and
`rifle_prop.obj`. `docs/PRODUCTION_BIBLE.md` explicitly lists
"police/crime systems" as a non-goal for the first city slice, and
requires "lead review" for "content involving addiction, homelessness,
crime, or violence." Whoever vendored this asset pack included those
three models alongside genuinely appropriate street furniture (bench,
dumpster, fire hydrant, street lamp, traffic light, vending machine, hot
dog cart, market stall, bus stop, taxi/sedan/box van as plain vehicles).

Decision (made here, not deferred): **B1/B2 must not import or place
`police_car.obj`, `pistol_prop.obj`, or `rifle_prop.obj`.** Everything
else in the pack is fine for a street/park backdrop. If a police or
crime system is ever wanted, that's a new pillar decision for Ryann to
make explicitly, not something that should quietly exist because an
asset happened to be in a folder.

## Next

B1 (T2): build the actual city-block scene — terrain, roads, building
shells, collision — using this layout and asset boundary. B2 (T1, can
run in parallel with B1): audit/import the *approved* subset of
`blocky/city/` assets and produce a manifest mapping each asset to a
location use.
