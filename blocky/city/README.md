# Hollowmark — city asset pack

Drop-in extension to `res://blocky/`. Palette-locked to `blocky_palette.gpl`
(32 colours, 8 families × 4 steps). Same rules as the base pack:
1 voxel = 1/16 m, all textures 16×16, skins 64×32, **Nearest** filter,
mipmaps ON for the block atlas, OFF for items/UI/skins.

```
assets/city/
  textures/blocks/   16 tiles + city_blocks_atlas.png (4×4)
  textures/items/    12 icons + city_items_atlas.png  (4×3)
  textures/skins/    12 box-model sheets (64×32)
  city_blocks.gd     registry snippet: names, hardness, tool class, atlas faces
  ATLAS_ORDER.json   tile order in both atlases (row-major, 4 columns)
```

## Blocks (atlas order)

cobblestone, brick, plaster, roof_tile, slate_roof, cobble_road, flagstone,
city_door, shop_window, lantern_post, jail_bars, market_awning, sign_board,
tavern_floor, crate, hay

All are single-texture blocks (same tile on every face) except:
`roof_tile`/`slate_roof` (read best as side/top), `market_awning` (stripes run
along one axis — rotate the mesh, not the UV), `crate` and `hay` (top face is
the same tile, which is intentional for a voxel crate).

`lantern_post` is the only emissive candidate: give it its own material with
`emission_enabled`, emission texture = the same tile, energy ~0.8, so it lights
the street at night. Nothing else needs a second material.

## Items (atlas order)

coin, coin_stack, bread, ledger, key, letter, ballot, purse, lockpick, tonic,
apple, flower — cut out on transparent background, same as base item icons, so
`Blocks.icon(id)` works unchanged.

These are the city-sim economy in object form: coins and purse for the money
loop, ledger/letter/ballot for the government and election loop, key/lockpick
for theft, bread/apple/tonic for hunger and illness.

## Skins

citizen_a/b/c, guard, mayor, merchant, baker, blacksmith, miner, healer,
priest, thief. Classic box layout (head 8×8×8, torso 8×12×4, arms/legs 4×12×4)
— **identical UVs to the base pack's player sheet**, so one rig serves all
twelve: swap the texture, never the model. Faces are pre-shaded (left/back
darker) because the pack has no per-face lighting on characters.

Role reads at a distance: guard = grey-blue with a dark cap band and a gold
badge, mayor = purple coat with a gold sash and white beard, baker = pale
apron, blacksmith = dark leather apron and heavy grime, miner = olive with
grime, healer = white with a violet sash, priest = bald and dark with a cream
sash, thief = all ink tones, no highlights.

## Import checklist

1. Copy `assets/city/textures/*` under `res://blocky/textures/` (same
   subfolders) — nothing here collides with an existing filename.
2. Extend `BlockAtlas`: the city atlas is a **second** atlas, not an extension
   of `blocks_atlas.png`. Either keep it separate with its own material, or
   paste its 16 tiles into a widened sheet and shift the UV rects.
3. Register the blocks from `city_blocks.gd`, continuing your existing ID
   numbering (it uses `START_ID` so it can't clash).
4. Inset UVs by half a texel (`0.5 / atlas_width`) if you see bleeding — the
   atlas has no padding, per the base pack's rule.
