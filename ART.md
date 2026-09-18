# Art checklist

Everything in the game that could take real graphics. Today all of it
is flat colour (per-face block colours, coloured boxes, drawn rectangles).
Counts are exact as of 2026-09-18.

Suggested formats are in brackets. Block and item art at **16×16 px**
keeps the chunky look and matches the 1-block = 1 metre scale.

## 1. Blocks — 11 (16×16 PNG per face)

Most blocks use one texture for all faces; the ones marked *top/side*
want two or three.

| Block | Faces | Notes |
|---|---|---|
| Grass | top / side / bottom | top is tinted by biome (keep it greyscale-green) |
| Dirt | all same | |
| Stone | all same | |
| Sand | all same | |
| Log | top / side | end-grain rings on top |
| Leaves | all same | tinted by biome; could be cut-out transparent |
| Snow | all same | |
| Planks | all same | |
| Workbench | top / side | a tool grid on top would sell it |
| Coal Ore | all same | stone with black flecks |
| Iron Ore | all same | stone with rust flecks |

Also: **Water** surface (currently a translucent blue plane; a scrolling
or animated texture would do a lot).

## 2. Items — 10 (16×16 PNG icons)

Shown in hotbar/inventory slots and as the dropped-item cube.

Meat, Stick, Coal, Iron, Wooden Pickaxe, Wooden Axe, Stone Pickaxe,
Stone Axe, Iron Pickaxe, Iron Axe.

(The 11 blocks above also need an *icon* view — usually just the top or
side texture, no extra work.)

## 3. Characters — 3 (box-model skins, Minecraft-style 64×64)

| Character | Parts | Notes |
|---|---|---|
| Player | head (face, hair), torso, 2 arms (sleeve + hand), 2 legs | 1.3 blocks tall |
| Critter | body, head, 2 eyes, 4 legs | 4 coat colours by biome: tan, brown, sandy, white |
| Shade | body, head, 2 glowing eyes, 2 arms, 2 legs | 1.7 blocks tall, near-black |

## 4. World / environment

- Sky: day, sunset, night gradients (procedural now); optional sun disc
  art, a **moon** (there is moonlight but no visible moon), clouds (none).
- Trees are just log + leaf blocks — covered by block art.
- Cave interiors: no art needed, but darkness/torch light later.

## 5. Effects

- Block break: crack overlay stages (now the highlight box just darkens).
- Hit flash on creatures (now a red tint) and the hurt screen vignette
  (now a flat red overlay).
- Pickup / craft feedback, footstep dust, Shade burning at dawn — none
  exist yet; particles would be new.

## 6. UI (9-slice PNGs or simple sprites)

- Hotbar: slot frame, selected-slot frame, slot numbers.
- Inventory / Workbench screen: panel background, slot frame, crafting
  arrow, result-slot frame, the cursor stack.
- Health: 10–12 **hearts** (currently red squares); Hunger: 10
  **drumsticks** (currently orange squares); empty/full states.
- Crosshair; break-progress bar.
- Buttons (normal / hover / pressed) for title, pause, death screens;
  seed text box; sound slider.
- Title logo **BLOCKY** and subtitle; death-screen tint; "Night falls" /
  "Dawn" / "Saved" message style.
- A pixel font (everything uses Godot's default font now).

## What the code needs before textures can be used

1. **Block textures**: the chunk mesher (`chunk.gd`) emits vertex colours,
   not UVs. Adding a texture atlas means emitting a UV per vertex and
   swapping the material for one with the atlas — about a day's work, and
   it replaces the block colour table with tile indices.
2. **Item icons**: hotbar/inventory slots draw a coloured square; they'd
   draw a texture instead (small change in `hud.gd` / `inventory_ui.gd`).
3. **Character skins**: each box mesh gets a material with a texture and
   UVs mapped to the skin sheet (per-part, moderate work).
4. **UI**: Godot themes can take 9-slice textures with no code changes.

## Suggested order by impact

1. Block textures (changes the whole look)
2. Item icons
3. Player skin
4. Hearts / drumsticks and hotbar frames
5. Critter and Shade skins
6. Title logo and buttons
7. Water, sky, moon, particles
