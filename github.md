repo: ryannlynnmurphy/blocky
branch: main
path: blocky/

## Last sync
date: 2026-09-20T00:52:00Z

### Updated in this project
- Generated a 40-sprite city asset pack (16 blocks, 12 items, 12 character skins) locked to the repo's Blocky 32 palette.
- Matched the base pack's rules: 16×16 tiles, 64×32 box-model skins reusing the player UVs, no atlas padding.
- Added `city_blocks.gd` — a drop-in block registry with IDs starting at 64 so nothing clashes with `scripts/blocks.gd`.
- Added a contact-sheet preview of every sprite in the pack.

## Screen map
| Project screen | Built from |
|---|---|
| City Asset Pack.dc.html | blocky/README.md, blocky/palette/blocky_palette.gpl, ART.md |
| assets/city/* | blocky/palette/blocky_palette.gpl, blocky/README.md (atlas + skin conventions) |
| assets/city/city_blocks.gd | README.md ("Where things live"), scripts/blocks.gd conventions |
