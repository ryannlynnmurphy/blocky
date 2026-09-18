# Voxel RPG

An original voxel RPG built in **Godot 4** (GDScript). Inspired by the
exploration, chunky aesthetic, and sense of adventure of Cube World and
Minecraft — but its own game.

## Running it

1. Install Godot 4.7+ (standard build, not .NET): `winget install GodotEngine.GodotEngine`
2. Open Godot, click **Import**, pick this folder's `project.godot`.
3. Press **F5** (Run Project).

From a terminal, without the editor:

```
godot --path . 
```

## Controls

| Input | Action |
|-------|--------|
| W A S D | Move (relative to the camera) |
| Mouse | Look |
| Space | Jump |
| Shift | Run |
| Left click | Break the highlighted block |
| Right click | Place the selected block |
| 1–7 | Pick which block to place |
| T (hold) | Fast-forward time (watch the sun set) |
| Esc | Free / re-capture the mouse |

## Dev switches

Anything after `--` on the command line is for our scripts, not Godot:

```
godot --path . -- --day-length=5       a day lasts 5 seconds instead of 10 minutes
godot --path . -- --spawn=-300,-20     spawn at that x,z column
godot --path . -- --critter            put one animal right in front of you
godot --headless --path . --script tools/biome_survey.gd   print a biome map
```

## Where things live

```
project.godot        engine settings (window size, main scene, crisp-pixel rendering)
scenes/main.tscn     the level: sky, sun, world, water, player, HUD
scenes/player.tscn   the character's body, collision capsule and camera rig
scenes/creature.tscn a critter's body and collision box
scripts/main.gd      wires everything together, picks a spawn point
scripts/blocks.gd    block registry: IDs, names, colors
scripts/world_gen.gd noise terrain, biomes, grass tint, trees -> fills a chunk
tools/               headless dev scripts (not part of the game)
scripts/chunk.gd     turns one chunk's block IDs into a mesh (visible faces only)
scripts/world.gd     owns all chunks, streams them around the player, get/set block,
                     spawns/despawns creatures
scripts/creature.gd  critter brain: idle / wander, hop steps, avoid cliffs + water
scripts/player.gd    movement, camera, aiming, break/place
scripts/day_night.gd sun/moon orbit, sky + light color over the day
scripts/hud.gd       crosshair, hotbar, clock, hints
```

## Physics layers

| Layer | Who | Notes |
|-------|-----|-------|
| 1 | terrain chunks | camera arm and block-aiming rays only look here |
| 2 | creatures | player collides with 1+2, creatures with 1+2 |

## How the world is stored

The world is a grid of **chunks**, each 16 wide x 64 tall x 16 deep. A chunk
is just a `PackedByteArray` of 16,384 numbers — each number is a block ID
from `blocks.gd` (0 = air). To draw a chunk we don't draw 16,384 cubes; we
only emit the cube faces that touch air, and glue them into one mesh.

See `ROADMAP.md` for what is done and what comes next.
