# Blocky — asset drop

Unzip so this folder sits at `res://blocky/`. Nothing here needs a plugin.

```
blocky/
  textures/blocks/     15 faces + blocks_atlas.png
  textures/items/      10 icons + items_atlas.png
  textures/ui/         hotbar, inventory, hearts, hunger, bars, logo
  textures/effects/    break stages, flashes, particles + atlas
  textures/sky/        day/sunset/night strips, sun, moon, cloud
  textures/skins/      box-model sheets: player, critter x4, shade
  models/              21 GLB voxel models
  palette/             blocky_palette.png + .gpl for Aseprite
  scripts/             block_atlas.gd, pixel_material.gd
```

## The system

- **1 voxel = 1/16 m.** One world block = 16 voxels = 1 m. Models are y-up, in metres,
  so a GLB drops in at true scale with no import rescaling.
- **All textures are 16x16** except UI, skin sheets (64x32) and sky strips (16x128).
- **32-colour palette**, 8 families of 4 steps. Every asset here uses only those 32.
  Load `palette/blocky_palette.gpl` in Aseprite before you draw anything new.
- **65 sprites** total.

## Three import settings that matter

1. **Nearest filter.** Project Settings > Rendering > Textures >
   `canvas_textures/default_texture_filter` = **Nearest**. Set it once, project-wide.
2. **Mipmaps on the atlas, off for UI.** The 3D atlas needs mipmaps or distant blocks
   shimmer; UI and item icons must have them off or they blur at small sizes.
3. **Atlas padding.** There is none — tiles are edge to edge. If you see neighbouring
   tiles bleeding in at distance, inset your UVs by half a texel
   (`0.5 / atlas_width`) rather than re-exporting with padding.

## Blocks

The mesher emits UVs and vertex colours, not per-vertex colour alone. Use
`BlockAtlas.FACES[name]` to get `[top, side, bottom]`, then `BlockAtlas.uv(face)`
for the rect. Grass top and leaves are biome-tinted: leave the texture neutral and
multiply the biome colour in through vertex colour, which is why
`vertex_color_use_as_albedo` is on in the material helper.

## Water at scale

Do not build water out of transparent cubes. Emit **one merged surface mesh per chunk**,
single material, depth-write off, drawn after opaques. Cull every face that is not the
top plane or a shoreline. Fake depth with vertex colour from the column depth the mesher
already knows — pale at the edges, dark in the middle. Scroll the UV; never displace
geometry.

## Cutouts

Leaves and grass cards are **alpha scissor, not alpha blend**. Blended cards wash each
other out and z-fight. `make_cutout_material()` sets threshold 0.4 and disables culling.

## Characters

Skin sheets are the classic box-model layout: head 8x8x8, torso 8x12x4, arms and legs
4x12x4, on a 64x32 sheet. The Shade reuses the Player UVs exactly, so one rig serves
both. The four Critter coats are the same UVs with a different texture — swap the
texture, never the model.

## Animation

No skeletons. Animate Node3D rotations directly and set the AnimationPlayer tracks to
**Discrete** for stepped, 8 fps pixel timing. Per-creature frame counts and notes are in
the Blocky Creature Sheets document.
