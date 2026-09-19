# Art checklist

Everything in the game that could take real graphics, and what's
actually landed. A generated asset pack arrived 2026-09-18 and is
vendored at `res://blocky/` (see `blocky/README.md` for its own notes,
and `PLAN.md` for the full multi-phase integration plan this is
tracking against). Updated 2026-09-18 evening.

## 1. Blocks — 13 ✅ textured

Real 16×16 textures via `BlockAtlas` + `blocky/textures/blocks/` are
live in the chunk mesher (`chunk.gd`/`blocks.gd`). Grass top and
leaves still multiply a biome tint over the (neutral) texture, exactly
as designed. **Water** surface is textured too (tiled on the existing
flat plane — no shoreline/mesh upgrade, that's `blocky/models/water_tile.glb`
territory, deliberately deferred).

| Block | Status |
|---|---|
| Grass, Dirt, Stone, Sand, Log, Leaves, Snow, Planks, Workbench, Coal Ore, Iron Ore | ✅ |
| Water surface | ✅ (flat plane, textured) |
| Torch, Bed | ✅ hand-generated (no source art existed — see M27 in ROADMAP.md); `blocks_atlas.png` extended 4x4→4x5 to fit the 4 new tiles |

## 2. Items — 11 ✅ textured

Meat, Stick, Coal, Iron, Wooden/Stone/Iron Pickaxe, Wooden/Stone/Iron
Axe. `Blocks.icon(id)` (in `blocks.gd`) is the single lookup used by
the hotbar, inventory grid, cursor stack and dropped-item cubes — for
blocks it reuses the same world texture already on the block; for
items it's the item's own 16×16 icon file. No new art was needed.

Sword is the same deal as Torch/Bed (§1): no source art existed, so
`sword.png` is hand-generated (diagonal blade + hilt, transparent
background matching how the other item icons are cut out) — see M28
in ROADMAP.md.

## 3. Characters — 3, mixed

| Character | Asset | Status |
|---|---|---|
| Player | `blocky/models/player.glb` — 21 separate part meshes (leg/boot/torso/belt/buckle/arm/hand ×L,R, head, 8 hair pieces, 2 eyes), each with its own baked texture | ✅ rigged at runtime (`player.gd::_build_model()`); scaled from real-human-scale to our 1.3-tall body; short sword attached to the right hand, visible only while `Blocks.SWORD` is the held item (see M28 in ROADMAP.md — it's a real craftable weapon now, not cosmetic) |
| Critter | `blocky/textures/skins/critter_{tan,brown,sandy,white}.png` — **skin sheets only, no GLB** | ⬜ still flat-color boxes. Needs custom per-part UVs matching the sheet's box layout (head 8×8×8, torso 8×12×4, limbs 4×12×4 on a 64×32 sheet) — Godot's default BoxMesh UV won't sample the right sub-region per part, so this isn't a quick texture swap like the player was. |
| Shade | `blocky/textures/skins/shade.png` — same story as Critter | ⬜ same work needed |

The 8 new creatures from the asset drop (rabbit, deer, fox, boar,
bird, goblin, wisp, witch) **do** come as full GLBs like the player,
each with its own baked textures — no custom UV work needed for
those, just rigging (once they exist as gameplay entities at all;
today only the generic Critter and the Shade exist, and neither
matches these new species).

## 4. World / environment

- Sky: day, sunset, night gradients are still procedural (`day_night.gd`);
  the generated `day.png`/`sunset.png`/`night.png` strip textures,
  `sun.png`, `moon.png`, `cloud.png` are unused. There's moonlight but
  no visible sun/moon disc or clouds.
- Trees are voxel logs+leaves (`world_gen.gd`), not the GLB
  pine/broadleaf/crooked trees. This was an explicit fork in the road
  (see Milestone F in PLAN.md) — Ryann chose to keep voxel trees
  (minable, feeds the Log → Planks → Sticks → tools chain) over the
  GLB trees' nicer silhouette, since switching would mean designing a
  new way to gather wood. Revisit only if that redesign happens.
- ✅ **Rocks, grass tufts, flower patches, mushroom clusters, reeds**:
  spawning as GLB decoration, deterministic per column like trees
  (`WorldGen.PROPS`/`REEDS_*` in `fill_chunk()`, `world.gd` instantiates
  them as chunk children once the mesh lands). PLAN.md's own
  Forest/Swamp/Water-edge split assumes a Swamp biome that doesn't
  exist in this project (Plains/Forest/Desert/Tundra), so it's
  adapted: grass/flowers favor Plains, mushrooms join the mix in
  Forest, Desert/Tundra get sparse rock only, reeds grow at the
  waterline on the two temperate biomes. No collision (pure
  decoration) — cheap, and matches PLAN.md's own "terrain = voxel
  grid, environment = GLB props" split. Density is deliberately
  conservative (roughly tree-like rarity, not lawn-dense); a `--perf`
  check confirmed instantiating them (queued/budgeted like collision
  shapes) costs ~1-2 ms worst-case, not the dominant load-time cost.
- Cave interiors: no art needed yet, darkness/torch light is future.

## 5. Effects — sprites exist, not wired in

`blocky/textures/effects/`: break_0..3 (crack stages), hit_flash,
hurt_vignette, pickup_spark, footstep_puff, shade_ember, + an atlas.
The *mechanics* they'd decorate already exist and use plain draw
calls / color lerps instead: hold-to-break has a progress bar (not
crack-stage sprites), hits flash creatures red (not `hit_flash.png`),
taking damage flat-red-overlays the screen (not `hurt_vignette.png`),
picking things up shows a magnet + text popup (not `pickup_spark.png`).
Swapping in the real sprites is cosmetic, not new mechanics.

## 6. UI — ✅ textured where the art actually fits; 4 assets skipped

Health/hunger rows, hotbar frame, crosshair, break-progress bar, the
title-screen logo, and the inventory/workbench slot backgrounds are
all textured now:

- Health row (`heart_full/half/empty.png`) and hunger row
  (`drumstick_full/half/empty.png`) are `hud.gd`'s `IconBar` class, 2
  points per icon with a real half state.
- The hotbar draws `hotbar_slot.png` per slot (its border is baked
  into the texture's own edge shading) and `slot_selected.png` — a
  hollow-centre frame, drawn a bit oversized — over the selected slot.
- `Crosshair` draws `crosshair.png`; its break bar sources
  `break_bar.png` in two pieces, since that texture is one 64×8
  snapshot baked at a fixed ~60% fill (not a width-clippable
  template) — the filled and empty segments are sourced separately
  via `draw_texture_rect_region` and recomposed at any real progress.
- The title screen shows `logo.png` instead of a "BLOCKY" text label
  (pause/death keep plain text titles — only the game's own name is
  constant enough to bake).
- `inventory_ui.gd`'s `SlotView` backgrounds are `slot_frame.png`
  (turns out that's exactly where it belongs — see below), with
  `slot_selected.png` marking the result slot.

**Deliberately skipped — checked by inspecting actual pixel data, not
just filenames**, and confirmed with Ryann rather than guessed:
- `button.png`/`button_hover.png`: literally say "PLAY" in the art.
  Fine for one title-screen action, wrong under "Quit"/"Resume"/
  "Save"/"Respawn"/"Quit to Title" — not worth it for a single button.
- `sound_slider.png`: one snapshot, grabber + fill baked at a fixed
  ~70% position, no separate track/grabber layers — can't represent a
  real dynamic volume value.
- `message_text.png`: baked with the example text "IRON PICKAXE", not
  a blank backdrop.
- `inventory_panel.png`: bakes in "INVENTORY"/"CRAFTING" headings and
  a fixed-size grid that won't line up with our dynamically-sized slot
  layout (2×2 vs 3×3 crafting, 27+9 inventory slots).

These four are the reason `slot_frame.png` "unused for now" in an
earlier version of this doc turned out to be wrong — it just wasn't
the hotbar's frame, it's the inventory grid's.

## Suggested order by impact, updated

1. ~~Block textures~~ ✅ done
2. ~~Item icons~~ ✅ done
3. ~~UI chrome~~ ✅ done (hearts/hunger/hotbar, then crosshair/break
   bar/logo/inventory slots — buttons/slider/message/panel skipped,
   see §6)
4. ~~Player skin~~ ✅ done (sword is a real weapon now, see M28)
5. ~~Named wildlife/hostile GLBs~~ ✅ done (rabbit/deer/fox/boar/bird,
   goblin/wisp/witch) — wildlife no longer spawns the old box
   placeholder at all; the box "Shade" is now just one of four hostile
   skins, the other three (goblin/wisp/witch) textured
6. ~~Environment props~~ ✅ done (rocks/grass tufts/flower patches/
   mushroom clusters/reeds) — trees stay voxel/minable, see §4
7. Water shoreline/mesh, sky textures, visible sun/moon/clouds, effect
   sprites
8. Generic-label button/slider/message/panel art, if that ever gets
   generated (see §6's skip list)
</content>
