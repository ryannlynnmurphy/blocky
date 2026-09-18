# Art checklist

Everything in the game that could take real graphics, and what's
actually landed. A generated asset pack arrived 2026-09-18 and is
vendored at `res://blocky/` (see `blocky/README.md` for its own notes,
and `PLAN.md` for the full multi-phase integration plan this is
tracking against). Updated 2026-09-18 evening.

## 1. Blocks — 11 ✅ textured

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

## 2. Items — 10 ✅ textured

Meat, Stick, Coal, Iron, Wooden/Stone/Iron Pickaxe, Wooden/Stone/Iron
Axe. `Blocks.icon(id)` (in `blocks.gd`) is the single lookup used by
the hotbar, inventory grid, cursor stack and dropped-item cubes — for
blocks it reuses the same world texture already on the block; for
items it's the item's own 16×16 icon file. No new art was needed.

## 3. Characters — 3, mixed

| Character | Asset | Status |
|---|---|---|
| Player | `blocky/models/player.glb` — 21 separate part meshes (leg/boot/torso/belt/buckle/arm/hand ×L,R, head, 8 hair pieces, 2 eyes), each with its own baked texture | ✅ rigged at runtime (`player.gd::_build_model()`); scaled from real-human-scale to our 1.3-tall body; short sword attached to the right hand (cosmetic, no swing yet) |
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
- Trees are voxel logs+leaves (world_gen.gd), not the GLB
  pine/broadleaf/crooked trees — an explicit fork in the road (see
  Milestone F in PLAN.md): keep minable voxel trees, switch to
  GLB props for silhouette, or split by biome.
- Rocks, grass tufts, flower patches, mushroom clusters, reeds:
  GLBs exist (`blocky/models/`), nothing spawns them yet.
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

## 6. UI — hearts/hunger/hotbar ✅ textured, rest still shapes

Health row (`heart_full/half/empty.png`) and hunger row
(`drumstick_full/half/empty.png`) are `hud.gd`'s `IconBar` class, 2
points per icon with a real half state. The hotbar draws
`hotbar_slot.png` per slot (its border is baked into the texture's own
edge shading) and `slot_selected.png` — a hollow-centre frame, drawn
a bit oversized — over whichever slot is selected. `slot_frame.png`
turned out to be fully opaque with no transparent hole at all (not a
border despite the name), so it's unused for now; it likely belongs on
the inventory/workbench grid instead, whenever that gets its pass.

Still plain `_draw()` calls (rectangles, lines, `Label`s): the
inventory/workbench panel, crosshair, break-progress bar, title/pause/
death screens and buttons, the sound slider, and message text — vs the
generated `inventory_panel.png` / `crosshair.png` / `break_bar.png` /
`button*.png` / `sound_slider.png` / `message_text.png` / `logo.png`.
Same deal as the hotbar was: low-risk, swap what a
`draw_rect`/`draw_texture` call points at, no gameplay logic changes.

## Suggested order by impact, updated

1. ~~Block textures~~ ✅ done
2. ~~Item icons~~ ✅ done
3. ~~UI chrome, part 1 (hearts, hunger, hotbar frames)~~ ✅ done
4. Rest of UI chrome (inventory/workbench panel, crosshair, break bar,
   buttons, logo, sound slider, message text) — biggest visible jump
   left
5. ~~Player skin~~ ✅ done (sword is cosmetic-only for now)
6. ~~Named wildlife/hostile GLBs~~ ✅ done (rabbit/deer/fox/boar/bird,
   goblin/wisp/witch) — wildlife no longer spawns the old box
   placeholder at all; the box "Shade" is now just one of four hostile
   skins, the other three (goblin/wisp/witch) textured
7. Environment props (trees/rocks/flowers/mushrooms/reeds) — pick
   voxel-vs-GLB for trees first
8. Water shoreline/mesh, sky textures, visible sun/moon/clouds, effect
   sprites
</content>
