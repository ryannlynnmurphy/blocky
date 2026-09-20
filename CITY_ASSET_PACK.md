# Hollowmark city rendering pack

This is the reusable art layer for the future city slice. It is deliberately
separate from the simulation: people and institutions decide *what* a city
state is; these assets decide how that state appears in 3D.

## What is in the project now

- `blocky/city/` — source pack, atlas order, the block registry data, 32 OBJ/MTL props and its original notes.
- `blocky/models/city/` — Godot-importable copies of the city props, referenced through `scripts/city_render_pack.gd`.
- `blocky/textures/blocks/` — 16 city block tiles plus the 4×4 atlas.
- `blocky/textures/items/` — city/economy icons: money, food, ballot, ledger, letter, key and lockpick.
- `blocky/textures/skins/` — 12 role skins for future residents (citizen, guard, mayor, merchant, baker, blacksmith, miner, healer, priest and thief).
- `scripts/person_appearance.gd` — the shared 3D human appearance system used by the player creator today and intended for NPCs tomorrow.

## Rendering contract

All human variants use the same source rig. A `PersonProfile` selects body
shape, skin, hair silhouette, hair colour, outfit and accent; the renderer
assembles those reusable components. It never asks an AI to make a fresh mesh.

City props are instantiated by ID, for example:

```gdscript
var bench := CityRenderPack.instantiate_prop("bench")
bench.position = Vector3(8, 1, 4)
add_child(bench)
```

This lets the neighborhood generator place a consistent visual object for a
shop, street corner, vehicle or public service without knowing asset paths.

## Next integration boundary

`blocky/city/city_blocks.gd` is registry data, not yet added to the existing
`Blocks` atlas. Register it only when the first street map exists, so the
survival-world block IDs and the city-world block IDs stay intentional rather
than being merged just because assets exist.
