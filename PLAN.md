# Blocky — Godot Implementation Plan

Pasted in full on 2026-09-18 alongside the generated asset drop
(`blocky.zip` → vendored at `res://blocky/`). Kept verbatim as the
reference for the remaining asset-integration phases. **Status notes
in blockquotes below are mine, added after each phase is (or isn't)
done — the plan itself is unedited.**

> **Status as of 2026-09-18:** Phase 1 steps 1–8 are done (asset
> import, textured blocks, player.glb model + rig, sword attached to
> a hand socket). Step 8's sword has no swing/attack animation and
> isn't wielded in combat — attach only, per the plan's own Task 1
> scope. Everything from "Add environment spawner" onward (step 9+)
> is not started. See ROADMAP.md for the project's own milestone log,
> which is the source of truth for what's actually done; this file is
> the longer-range map.

## 0. Current State

### Already implemented

The existing Godot prototype has:

* Godot 4.7 / Forward+ project
* 16×64×16 voxel chunks
* Visible-face voxel meshing
* Chunk streaming
* Procedural terrain
* Grass / dirt / stone / sand / log / leaves / snow / planks blocks
* Water plane
* Third-person player
* WASD movement
* Jump / gravity
* Run
* Camera look
* Block targeting
* Block breaking
* Block placement
* 7-slot hotbar
* Crosshair
* Basic lighting / sky

The current code is deliberately simple: blocks are represented by IDs and rendered using flat vertex colors rather than textures. The player is also currently constructed from primitive BoxMesh objects rather than the generated player model.

> This section describes an earlier snapshot of the project. By the
> time this doc arrived, the actual repo already had day/night,
> hunger, a visual (not text) hotbar, Minecraft-style slot inventory
> and grid crafting, caves/ores, tool tiers, a hostile night creature,
> synthesized sound, and title/pause/death screens — none of that is
> reflected above. Reconcile against ROADMAP.md, not this section.

### Generated asset package

The asset drop contains substantially more than the prototype currently uses:

#### Blocks

* grass top
* grass side
* grass bottom
* dirt
* stone
* sand
* log top
* log side
* leaves
* snow
* planks
* workbench
* coal ore
* iron ore
* water surface
* block atlas

#### Items

* meat
* stick
* coal
* iron
* wooden pickaxe
* wooden axe
* stone pickaxe
* stone axe
* iron pickaxe
* iron axe
* items atlas

#### Characters

* player skin
* four critter skin variants
* shade skin

#### Environment

* pine tree
* broadleaf tree
* crooked swamp tree
* small rock
* boulder
* grass tuft
* flower patch
* mushroom cluster
* reeds
* water tile

#### Creatures

* rabbit
* deer
* fox
* boar
* bird
* goblin
* wisp
* witch

#### Effects

* block breaking frames
* hit flash
* hurt vignette
* pickup spark
* footstep puff
* shade ember

#### UI

* hotbar
* selected slot
* inventory panel
* slot frame
* crafting arrow
* hearts
* hunger
* crosshair
* break bar
* buttons
* sound slider
* message text
* logo

#### World / atmosphere

* day sky
* sunset sky
* night sky
* sun
* moon
* cloud

#### Existing helper scripts

* `block_atlas.gd`
* `pixel_material.gd`

> Delivered as PNG textures (16×16 for blocks/items, 64×32 skin sheets,
> 16×128 sky strips) plus 21 GLB models — not flat images for
> characters/creatures/environment/props, those are real low-poly
> meshes with baked-in per-part materials. `pixel_material.gd` was
> missing its `class_name` line; added one (`PixelMaterial`) rather
> than working around it. Full inventory and where each piece landed
> is in `ART.md`.

---

# 1. Do NOT Start With Creatures

The first implementation step should be replacing the prototype's temporary visual systems with the generated visual systems.

The architecture should become:

```text
World
├── Voxel terrain
│   ├── Block IDs
│   ├── Block atlas / UVs
│   └── Chunk meshes
│
├── Environment
│   ├── Trees
│   ├── Rocks
│   ├── Grass
│   ├── Flowers
│   ├── Mushrooms
│   └── Reeds
│
├── Entities
│   ├── Player
│   ├── Wildlife
│   └── Hostile mobs
│
├── Items
│   ├── World drops
│   └── Inventory items
│
├── Combat
│
├── Effects
│
├── UI
│
└── Time / Atmosphere
```

The existing prototype should remain the foundation.

---

# 2. MILESTONE A — Asset Import Foundation

## Goal

Get every generated asset into Godot correctly before making gameplay depend on them.

### Tasks

Create:

```text
res://blocky/
    textures/
    models/
    palette/
    scripts/
```

The supplied package is already structured this way.

### Configure

Project-wide:

* Nearest texture filtering
* Pixel-friendly rendering
* Correct GLB import scale
* Correct texture filtering
* Mipmap handling for 3D atlases
* No mipmaps for UI textures

Use the supplied:

```text
block_atlas.gd
pixel_material.gd
```

rather than rebuilding their functionality unnecessarily.

### Verification

Create a temporary:

```text
scenes/asset_test.tscn
```

containing:

* every block
* player
* rabbit
* deer
* fox
* boar
* bird
* goblin
* wisp
* witch
* trees
* rocks
* props
* sword
* tools

This scene exists purely to answer:

> "Does every generated asset import correctly?"

Do this before gameplay integration.

> Skipped the standalone test scene; verified each asset in place
> instead (headless import log showed 0 errors for all 21 GLBs + all
> textures, then screenshotted the actual result in-game — grass/dirt
> face orientation, the workbench block, tree bark/leaves, and three
> angles on the rigged player + sword). Project-wide nearest filter
> was already set (`textures/canvas_textures/default_texture_filter=0`
> from an earlier milestone); mipmap/3D-detection left at Godot's
> defaults, which handled the atlas correctly with no visible
> shimmering in testing so far.

---

# 3. MILESTONE B — Replace Colored Voxel Blocks With Textured Blocks

This is the biggest immediate upgrade.

## Current system

`blocks.gd` currently defines blocks using:

```text
ID → name → colors
```

and `chunk.gd` generates vertex colors for each visible face.

The current chunk renderer explicitly uses vertex colors to produce the flat-colored cubes.

## New system

Change this to:

```text
Block ID
    ↓
Block definition
    ↓
top / side / bottom texture
    ↓
atlas UV
```

The generated package already provides the atlas system for this.

### New block registry

Expand `blocks.gd` to include:

```text
AIR
GRASS
DIRT
STONE
SAND
LOG
LEAVES
SNOW
PLANKS
WORKBENCH
COAL_ORE
IRON_ORE
```

and eventually:

```text
WATER
```

as a special material rather than an ordinary solid voxel.

### Block definitions

Conceptually:

```gdscript
{
    "grass": {
        "top": ...,
        "side": ...,
        "bottom": ...
    }
}
```

The important change is that `face_color()` becomes something like:

```text
face_uv()
```

### Chunk changes

`chunk.gd` should continue doing exactly what it already does:

```text
iterate blocks
→ skip air
→ test neighboring blocks
→ emit visible faces
```

But each emitted face now gets:

```text
vertex position
normal
UV
```

instead of relying on a vertex color.

Do **not** throw away the current mesher.

You're upgrading its material/UV layer.

> Done. All 11 block IDs already existed (this project had gone well
> past the plan's assumed starting registry); added
> `Blocks.ATLAS_FAMILY` / `atlas_faces()` mapping each to
> `BlockAtlas.FACES`, and `Chunk` now emits a UV per vertex
> (`Mesh.ARRAY_TEX_UV`) alongside the existing position/normal/index
> arrays — the visible-face culling loop itself is untouched. Vertex
> color survives as a *tint* (white everywhere, the real biome color
> only on grass tops and leaves), exactly as `blocky/README.md`
> specifies, and `Blocks.COLORS`/`face_color()` are kept as-is for
> item icons and dropped-item cubes (not reworked this pass). Water:
> applied `water_surface.png` (tiled) to the existing single plane;
> the plan's own asset README explicitly says not to build proper
> water yet, so no shoreline/mesh work was done.

---

# 4. MILESTONE C — Player Replacement

## Current

`player.tscn` currently constructs the player from:

* head BoxMesh
* face BoxMesh
* torso BoxMesh
* two leg BoxMeshes
* primitive materials

The current player scene confirms that the model is entirely procedural/primitive at this stage.

## Replace with

```text
Player
├── CharacterBody3D
├── CollisionShape3D
├── Model
│   └── player.glb
├── Rig / animation nodes
├── CameraPivot
│   └── SpringArm3D
│       └── Camera3D
├── WeaponSocket
│   └── ShortSword
└── Effects
```

Keep:

* CharacterBody3D
* collision
* camera
* spring arm
* movement code
* block targeting
* break/place logic

Replace only the visual model.

## Animation

Use Node3D animation rather than introducing a skeleton system.

Required initial animations:

```text
Idle
Walk
Run
Jump
Attack
Hurt
```

The generated creature documentation specifies stepped/discrete animation and direct Node3D rotation.

> Done, with a twist the plan didn't anticipate: `player.glb` isn't a
> single UV-mapped box-model skin — it's 21 separate named mesh parts
> (leg_L/R, boot_L/R, torso, belt, buckle, arm_L/R, hand_L/R, head, 8
> hair pieces, eye_L/R), each centered on its own local origin with
> the joint position baked into the glTF node's matrix, authored at
> real human scale (~1.85 m to head-top). `player.gd::_build_model()`
> instances it, computes a pivot at the top of each limb from its
> live `MeshInstance3D.get_aabb()` (no hand-copied numbers), reparents
> arm/hand and leg/boot pairs onto those pivots while preserving
> `global_transform`, moves the 13 static parts (torso, belt, buckle,
> head, hair, eyes) onto Model directly, then scales the whole Model
> node so head-top lands at our 1.3-tall collision height. The
> existing walk-cycle code (`_animate_limbs`) didn't change — it still
> just rotates `_arm_l`/`_arm_r`/`_leg_l`/`_leg_r`, which now point at
> the new pivots instead of hand-authored `.tscn` nodes. Idle/Walk/Run
> lean on that existing rotation-based animation; Jump/Attack/Hurt
> poses are not added yet. The short sword is attached to the right
> hand (rotated blade-down, with its own extra 0.42× scale-down — it's
> authored at ~1.7 units, comparable to our whole body height, so it
> needs shrinking past the body's own scale factor or it drives into
> the ground) but isn't wielded in any combat animation.

---

# 5. MILESTONE D — Proper Block Interaction Feedback

The generated package has effects that the current prototype does not use.

Add:

```text
break_0
break_1
break_2
break_3
hit_flash
pickup_spark
footstep_puff
hurt_vignette
```

## Breaking

Current:

```text
LMB
→ immediately remove block
```

New:

```text
LMB held
→ determine target block
→ calculate break duration
→ update break_bar
→ show break_0 → break_1 → break_2 → break_3
→ remove block
→ spawn pickup
```

The `break_bar` UI asset should therefore replace the purely conceptual interaction.

Later:

```text
different tool
→ different mining speed
```

> **Not started.** Hold-to-break with a progress bar, per-tool mining
> speed, drops that fly to the player, and a hit flash / hurt flash
> already exist in this project (built earlier, before this asset
> drop, using plain draw calls and color lerps) — what's missing is
> swapping those hand-drawn effects for the generated sprite frames
> (`break_0..3.png`, `hit_flash.png`, `pickup_spark.png`,
> `footstep_puff.png`, `hurt_vignette.png`).

---

# 6. MILESTONE E — Inventory + Item System

The roadmap already identifies inventory as the next major gameplay step: breaking a block should give the player that block, while placing consumes it.

The generated assets make it possible to implement this properly.

## Create

```text
scripts/item_database.gd
scripts/inventory.gd
scripts/item_drop.gd
scripts/item_defs.gd
```

### Item database

Include:

```text
Grass
Dirt
Stone
Sand
Log
Leaves
Planks
Workbench
Coal
Iron
Stick
Meat
Wooden Pickaxe
Stone Pickaxe
Iron Pickaxe
Wooden Axe
Stone Axe
Iron Axe
Short Sword
```

### Inventory

Start simple:

```text
Inventory
├── 9 hotbar slots
└── 27 inventory slots
```

Do not implement a sophisticated RPG inventory yet.

### Hotbar

Replace the text-based hotbar.

Current HUD literally builds the hotbar out of labels and block names.

New:

```text
Hotbar
├── slot
│   ├── frame
│   ├── item icon
│   └── quantity
└── selected overlay
```

Use:

```text
hotbar_slot.png
slot_selected.png
slot_frame.png
```

> **Already done, before this asset drop existed**, with the exact
> shape this section asks for: `scripts/inventory.gd` is slot-based
> (9 hotbar + 27 main, stacks of 64), `scripts/recipes.gd` covers the
> item list above (plus ores/tools), `scripts/drop.gd` is the world
> drop, and `scripts/inventory_ui.gd` is a real slot-grid HUD with
   drag/drop, split-stacks and shift-craft — not the text hotbar this
> section describes replacing. What's still open: the hotbar/inventory
> slots draw a flat color square per item, not `hotbar_slot.png` /
> `slot_selected.png` / item icon textures — that swap is unstarted.

---

# 7. MILESTONE F — Environment Dressing

Once the terrain works visually, populate it.

## Create an environment spawner

```text
EnvironmentSpawner
```

It receives terrain information and places assets according to rules.

### Forest

```text
pine_tree
broadleaf_tree
grass_tuft
flower_patch
rock_small
boulder
```

### Swamp

```text
crooked_tree
mushroom_cluster
reeds
```

### Water edge

```text
reeds
water_tile
```

### Important

Do NOT turn every environmental prop into a voxel block.

The generated package deliberately separates:

```text
terrain = voxel grid
environment = GLB props
```

This is much cheaper and gives you much more control over silhouettes.

> **Not started.** Trees today are logs+leaves stamped directly into
> the voxel grid by `world_gen.gd` (not GLB props) — matches this
> project's existing biome system (Plains/Forest/Desert/Tundra) but
> not this section's prop-spawner design. Doing this properly means
> deciding whether voxel trees stay (cheap, minable, consistent with
> "everything is a block") or get replaced by the GLB
> pine/broadleaf/crooked trees (better silhouettes, but a second,
> non-block rendering path) — worth a real decision, not a quick
> add-on.

---

# 8. MILESTONE G — Biomes

The existing roadmap already calls for biome variation based on temperature/moisture noise.

Build the biome layer after the visual terrain system works.

Start with only:

```text
MEADOW
FOREST
SWAMP
MOUNTAIN
```

Each biome controls:

```text
surface block
tree types
tree density
grass density
flowers
rocks
water-edge vegetation
creature spawn table
```

Example:

```text
MEADOW
    grass
    broadleaf
    flowers
    rabbit
    deer
    fox
    bird

FOREST
    grass
    pine
    broadleaf
    mushrooms
    rabbit
    deer
    fox
    bird

SWAMP
    dirt/murk palette
    crooked tree
    reeds
    mushrooms
    boar
    wisp
    witch
```

> **Already done, before this asset drop**, though with different
> biome names/count: Plains, Forest, Desert, Tundra (not Meadow/Swamp/
> Mountain), each already controlling surface block, tree density and
> a smooth grass/leaf tint (`world_gen.gd`). No creature spawn table
> per biome yet (critters spawn the same everywhere); mapping the new
> creatures onto biomes is future work once they exist.

---

# 9. MILESTONE H — Wildlife Entity Framework

Do NOT write five completely separate animal systems.

Create:

```text
Creature
├── CreatureBody
├── Detection
├── Movement
├── Animation
├── Health
└── StateMachine
```

Then derive:

```text
Rabbit
Deer
Fox
Boar
Bird
```

## Shared state machine

```text
IDLE
↓
WANDER
↓
DETECT
↓
SPECIAL_BEHAVIOUR
↓
RETURN
```

### Rabbit

```text
wander
→ detect player
→ flee
→ hop
```

### Deer

```text
graze
→ wander
→ detect player
→ alert
→ flee
```

### Fox

```text
wander
→ detect rabbit
→ stalk
→ pounce
→ attack
```

### Boar

```text
wander
→ threatened
→ paw ground
→ charge
→ attack
→ cooldown
```

### Bird

```text
perch
→ peck/hop
→ player detected
→ flush
→ fly to perch
```

The generated creature notes explicitly define these behaviors, so they should become the behavioral specification rather than inventing new behavior during implementation.

> **Partially exists already, differently shaped.** `scripts/creature.gd`
> is a shared base (idle/wander/flee, hop-over-1-block, cliff/water
> avoidance, health, hit flash, knockback) with one concrete critter
> today (generic, 4 biome coat colors — tan/brown/sandy/white, not yet
> named rabbit/deer/fox/boar/bird) and `scripts/hostile.gd` extending
> it for the night-hunting Shade. The five named animals with their
> distinct behaviors (flee, stalk-and-pounce, charge, flush-and-perch)
> and their GLB models are **not started**.

---

# 10. MILESTONE I — Creature Animation System

Create:

```text
CreatureAnimator
```

with an interface like:

```text
play_animation("idle")
play_animation("walk")
play_animation("run")
play_animation("hurt")
```

Each creature can have a different animation library.

The important architectural decision:

**The state machine chooses WHAT animation plays. The creature scene defines HOW it is animated.**

That prevents gameplay code from becoming filled with animation-specific logic.

> **Not started** for the wildlife GLBs. The player's own walk/run
> animation already follows this "state decides what, rig decides how"
> split (`_animate_limbs()` reads state, rotates whatever pivots the
> current model provides) — the same pattern would extend cleanly to
> creatures once their GLBs are rigged the way `player.gd::_build_model()`
> now rigs the player.

---

# 11. MILESTONE J — Combat Framework

Only after wildlife works.

Create:

```text
HealthComponent
Hitbox
Hurtbox
DamageReceiver
AttackComponent
```

Basic flow:

```text
Sword swing
    ↓
Hitbox active
    ↓
Creature Hurtbox
    ↓
Damage
    ↓
Hurt animation
    ↓
Knockback
    ↓
Death / flee / retaliation
```

The player already has an intended sword asset:

```text
short_sword.glb
```

Attach it to:

```text
Player
└── RightHand
    └── ShortSword
```

> **Combat already exists, unarmed.** Punching (no weapon, no
> hitbox/hurtbox components — a direct raycast-and-damage call),
> knockback, hurt animation and death/flee are all already built and
> used by both the player and the Shade. The sword is now attached to
> the right hand (this session) but is cosmetic only — no swing,
> no hitbox, punching still does the damage. Wiring the sword into an
> actual attack would mean adding a swing animation and deciding
> whether it replaces or supplements the punch.

---

# 12. MILESTONE K — Hostile Mobs

Now implement:

```text
Goblin
Wisp
Witch
```

## Goblin

Reuse the humanoid architecture.

States:

```text
IDLE
WANDER
CHASE
ATTACK
HURT
FLEE
DEAD
```

Special:

```text
camp spawning
```

Spawn groups of:

```text
2–4
```

rather than isolated goblins.

## Wisp

This needs its own movement class.

It should:

* float
* bob continuously
* rotate
* orbit motes
* approach player
* maintain ranged distance
* cast
* move laterally
* pass through appropriate thin geometry

Do not force the wisp through the normal quadruped/humanoid movement system.

## Witch

Use the humanoid rig architecture but with:

```text
robe
hat
staff
orb
```

Movement:

```text
glide
strafe
cast
```

No conventional walking animation.

> **Not started** for Goblin/Wisp/Witch specifically. The project's
> own hostile — the Shade (`hostile.gd`) — already has the
> IDLE/WANDER/CHASE/ATTACK/HURT states this section describes (bites
> instead of "attacks," doesn't flee, burns at dawn instead of having
> a DEAD state distinct from the critter base) and single-spawns
> rather than in camps. Goblin could reuse Shade's chase/attack shape
> directly; Wisp and Witch need genuinely new movement, as the plan
> says.

---

# 13. MILESTONE L — Day / Night

The existing roadmap explicitly puts day/night before biomes and creatures.

The asset package gives you:

```text
day
sunset
night
sun
moon
cloud
```

Create:

```text
TimeManager
```

with:

```text
time_of_day
day_length
sun_angle
```

Then drive:

```text
DirectionalLight3D
Sky
Environment
Ambient light
Fog
```

Eventually:

```text
day
→ sunset
→ night
→ sunrise
```

This should be one continuous simulation rather than four disconnected scenes.

> **Already done, before this asset drop**, procedurally rather than
> from the sky-texture strips: `scripts/day_night.gd` is exactly the
> TimeManager this section asks for (time_of_day, day length, sun
> angle) driving a real Sun/Moon DirectionalLight3D pair, sky gradient
> and fog, continuously (day → sunset → night → dawn, no discrete
> scene swaps) — it's also load-bearing (it gates when the Shade
> spawns and burns). The generated `day.png`/`sunset.png`/`night.png`
> sky-strip textures and the `sun.png`/`moon.png`/`cloud.png` sprites
> are unused; swapping the procedural gradient sky for those textures,
> and adding a visible sun/moon disc and clouds, is still open.

---

# 14. MILESTONE M — Water Upgrade

Current water is a single large transparent plane following the player. The main scene currently does exactly that.

The generated assets provide a proper `water_tile`.

Eventually replace:

```text
giant transparent plane
```

with:

```text
WaterSystem
├── water surface mesh
├── shoreline
├── foam
├── lily pads
└── animated UV
```

However:

**Do not do this early.**

The current plane is perfectly adequate while the rest of the game is being built.

> Deliberately not done, per the plan's own advice. This session
> textured the existing plane with `water_surface.png` (tiled) — still
> one flat plane, no shoreline/foam/mesh work, no `water_tile.glb`.

---

# 15. MILESTONE N — UI Overhaul

Replace the developer/debug HUD with the generated UI.

## Current

```text
Crosshair
Text hints
Text hotbar
```

## Final direction

```text
HUD
├── Crosshair
├── Health
├── Hunger
├── Hotbar
├── XP / future
├── Interaction message
└── Break progress
```

Assets:

```text
crosshair.png
heart_full.png
heart_half.png
heart_empty.png

drumstick_full.png
drumstick_half.png
drumstick_empty.png

hotbar_slot.png
slot_selected.png

break_bar.png
message_text.png
```

Remove the permanent:

```text
"WASD move..."
```

instruction once the game is actually playable.

> **The functional shape already exists** (crosshair, health row,
> hunger row, real hotbar with slot contents, break-progress bar,
> centered messages) — built with plain `_draw()` calls (squares,
> rectangles, lines), not the generated PNGs. XP is deliberately
> hidden from the HUD by request (the mechanic runs invisibly). The
> control hint text is still shown permanently, by choice, since this
> is still a beginner's in-development project, not a finished game
> being shipped to strangers — worth revisiting once it feels
> "played," not "developed." Swapping every hand-drawn HUD element for
> `heart_*`/`drumstick_*`/`hotbar_slot`/`slot_selected`/`break_bar`/
> `message_text.png` is the concrete remaining work here.

---

# 16. MILESTONE O — Audio

The generated package contains no finished audio system.

Therefore this remains a code/content gap.

Create an abstraction now:

```text
AudioManager
├── music
├── ambience
├── footsteps
├── block_break
├── block_place
├── creature
├── combat
└── UI
```

But actual sounds can be added later.

The existing roadmap also lists sound as a later feature.

> **Already done, before this asset drop, and differently than
> planned**: `scripts/sfx.gd` *synthesizes* 18 sounds at startup from
> filtered noise and tone sweeps (no audio files at all) — footsteps
> by surface, dig tick/crack, place, hit, hurt, land, bite, groan,
> pickup, eat, died, plus looping day-bird/night-wind ambience
> crossfaded by sun elevation, all through a dedicated SFX bus with a
> master limiter. No music loop yet (still on ROADMAP.md).

---

# 17. MILESTONE P — Saving

No generated asset solves this.

Create:

```text
SaveManager
```

Eventually save:

```text
world seed
changed blocks
player position
player inventory
time of day
creature state if necessary
```

Do NOT save the entire generated world.

Because the world is procedural, save:

```text
seed
+
player modifications
```

> **Already done, before this asset drop, in exactly this shape**:
> one JSON save (seed + a per-chunk block-edit diff, never the whole
> generated world), player position/look/health/level/XP/inventory,
> and time of day. Autosaves every 30 s, on F5, and on window close.
> Creature state is *not* saved (animals/hostiles respawn fresh on
> load) — an intentional simplification, not an oversight, and not
> currently planned to change.

---

# 18. Recommended Final Scene Structure

Eventually:

```text
Main
│
├── WorldEnvironment
├── Sun
├── Moon
│
├── World
│   ├── Chunks
│   ├── Water
│   └── Environment
│
├── Entities
│   ├── Player
│   ├── Wildlife
│   └── Hostiles
│
├── ItemDrops
│
├── Effects
│
├── TimeManager
├── AudioManager
├── SaveManager
│
└── HUD
    ├── Health
    ├── Hunger
    ├── Crosshair
    ├── Hotbar
    ├── BreakBar
    └── Messages
```

---

# 19. Recommended Script Structure

Move toward:

```text
scripts/
│
├── core/
│   ├── game.gd
│   ├── time_manager.gd
│   └── save_manager.gd
│
├── world/
│   ├── blocks.gd
│   ├── block_atlas.gd
│   ├── chunk.gd
│   ├── world.gd
│   ├── world_gen.gd
│   ├── biome.gd
│   └── environment_spawner.gd
│
├── player/
│   ├── player.gd
│   ├── inventory.gd
│   ├── item_drop.gd
│   └── equipment.gd
│
├── creatures/
│   ├── creature.gd
│   ├── creature_state_machine.gd
│   ├── creature_animator.gd
│   ├── rabbit.gd
│   ├── deer.gd
│   ├── fox.gd
│   ├── boar.gd
│   ├── bird.gd
│   ├── goblin.gd
│   ├── wisp.gd
│   └── witch.gd
│
├── combat/
│   ├── health.gd
│   ├── hitbox.gd
│   ├── hurtbox.gd
│   └── damage.gd
│
├── effects/
│   └── effects.gd
│
└── ui/
    └── hud.gd
```

Do not create all of these files immediately.

Create them only when their corresponding system exists.

> This project has kept a flatter `scripts/` folder (no subfolders)
> throughout. Worth revisiting once the creature roster actually grows
> past two (critter + Shade) — not before, per this section's own
> "don't create files before the system exists" rule, and per this
> project's established one-milestone-at-a-time practice.

---

# 20. The Actual Gap Analysis

| System           | Current Code                  | Generated Asset           | Action                        |
| ---------------- | ------------------------------ | -------------------------- | ------------------------------ |
| Voxel terrain    | YES                            | YES                        | Upgrade renderer to atlas — **done** |
| Blocks           | YES                            | YES                        | Add missing blocks + textures — **done** |
| Player           | YES                            | YES                        | Replace primitive model — **done** |
| Player animation | Rotation-based (pre-existing)  | Spec exists (stepped/8fps) | Idle/walk/run reuse existing rig; jump/attack/hurt poses open |
| Sword            | NO                             | YES                        | Attached to hand — **done**, not wielded |
| Trees            | Voxel logs+leaves (pre-existing) | Multiple GLBs             | Prop-vs-block decision open |
| Rocks            | NO                             | YES                        | Add environment spawner |
| Grass            | NO                             | YES                        | Add later |
| Flowers          | NO                             | YES                        | Add later |
| Mushrooms        | NO                             | YES                        | Add swamp dressing |
| Reeds            | NO                             | YES                        | Add water-edge dressing |
| Water            | Textured plane (this session)  | Proper water asset         | Shoreline/mesh upgrade open |
| Rabbit/Deer/Fox/Boar/Bird | NO (generic critter exists) | YES              | Named creatures + behaviors |
| Inventory        | YES (pre-existing, slot-based) | UI asset exists            | Icon textures open |
| Tools            | YES (pre-existing, tiered)     | YES                        | Icon textures open |
| Combat           | YES (unarmed, pre-existing)    | Sword asset (attached)     | Wielded swing/hitbox open |
| Health/Hunger UI | YES (drawn shapes, pre-existing) | YES                       | Icon textures open |
| Break feedback   | YES (progress bar, pre-existing) | YES                      | Sprite frames open |
| Pickup effects   | YES (magnet + popup, pre-existing) | YES                    | Sprite/particle open |
| Day/night        | YES (pre-existing)              | Sky textures unused        | Texture swap + sun/moon/cloud sprites open |
| Biomes           | YES (4 biomes, pre-existing)    | Palette supports more      | Creature spawn table per biome open |
| Audio            | YES (synthesized, pre-existing) | NO                         | Music loop open |
| Saving           | YES (pre-existing)              | NO                         | (complete as scoped) |
| Crafting         | YES (grid-based, pre-existing)  | UI asset exists            | Icon textures open |
| RPG progression  | Hidden XP/levels (pre-existing) | NO                         | Much later |
| Goblin/Wisp/Witch | NO                             | YES                        | New hostiles |

---

# 21. The Correct Implementation Order

Do this in exactly this order:

### Phase 1 — Make the world look like Blocky

1. Import asset package
2. Configure texture/material helpers
3. Upgrade chunk UV generation
4. Replace colored blocks with atlas textures
5. Add workbench / ores
6. Replace player primitive with `player.glb`
7. Add player animations
8. Attach sword

> **Steps 1–6 and 8 done this session.** Step 5 ("add workbench/ores")
> was already done in an earlier milestone, before this asset drop —
> only their *textures* were added now. Step 7 ("add player
> animations") is partial: idle/walk/run reuse the pre-existing
> rotation-based animation now driving the new rig; jump/attack/hurt
> poses aren't added.

### Phase 2 — Make the world feel inhabited

9. Environment spawner
10. Trees
11. Rocks
12. Grass
13. Flowers
14. Mushrooms
15. Reeds
16. Water improvements

### Phase 3 — First gameplay loop

17. Inventory
18. Item definitions
19. Block drops
20. Item drops
21. Real hotbar
22. Tool items
23. Break progress
24. Pickup effects

> **All of Phase 3 was already done before this asset drop arrived**
> (inventory.gd, recipes.gd, drop.gd, inventory_ui.gd, blocks.gd's
> HARDNESS/TOOL_CLASS/TOOLS tables, the break-progress bar, and the
> magnet-pickup + "+1 X" popup). Nothing here to do except the icon
> texture swap noted in the gap table.

### Phase 4 — Wildlife

25. Creature base class
26. Rabbit
27. Deer
28. Fox
29. Boar
30. Bird

> **Step 25 done before this asset drop** (`creature.gd`, generalized
> rather than rabbit-specific). Steps 26–30 (the five named animals
> and their distinct behaviors/models) not started.

### Phase 5 — World simulation

31. Day/night
32. Biomes
33. Biome-specific spawning
34. Creature density
35. Ambient behavior

> **31–32 done before this asset drop.** 33–35 not started (today's
> critter spawn rate/behavior doesn't vary by biome beyond terrain
> shape).

### Phase 6 — Combat

36. Health
37. Hitboxes/hurtboxes
38. Sword attack
39. Damage
40. Knockback
41. Death
42. Drops

> **36, 39, 40, 41 done before this asset drop** (health, damage,
> knockback, death — via direct method calls, not separate
> Hitbox/Hurtbox nodes). 37 (formal hitbox/hurtbox components), 38
> (an actual sword swing) and 42 (combat drops beyond the existing
> Meat-on-kill) not started.

### Phase 7 — Hostiles

43. Goblin
44. Goblin camps
45. Wisp
46. Witch
47. Ranged attacks
48. Projectile effects

> Not started, except that the Shade (this project's own hostile,
> predating this plan) already covers the IDLE/CHASE/ATTACK shape a
> Goblin would reuse.

### Phase 8 — Presentation

49. Final HUD
50. Audio
51. Music
52. Screen effects
53. Main menu
54. Settings
55. Save/load

> **49 (shape, not textures), 50, 53 (title screen), 55 all done
> before this asset drop.** 51 (music) and 52 (screen effects beyond
> the existing hurt-flash/damage-vignette) not started. 54 (settings)
> partial — a sound volume slider exists on the pause screen; no
> settings screen beyond that.

### Phase 9 — RPG layer

56. Crafting
57. Equipment
58. Progression
59. Quests
60. More enemies
61. More biomes
62. More world content

> **56 done before this asset drop** (grid crafting). 58 partial —
> XP/levels exist but are deliberately hidden from the player, so
> there's no visible "progression" to build on top of without first
> deciding whether to surface it. 57, 59–62 not started.

---

# 22. What NOT To Build Yet

Do not let the asset package trick you into implementing everything simultaneously.

For now, ignore:

* crafting
* quests
* RPG stats
* multiplayer
* procedural structures
* advanced water
* greedy meshing
* save/load
* complex combat
* advanced AI
* elaborate UI
* economy
* skill trees

The existing project explicitly follows the principle of one small runnable milestone at a time.

That principle is especially important now because the generated asset package makes the game *look* much further along than the underlying systems actually are.

> Several of these ("crafting," "save/load," "RPG stats") were already
> built, verified and shipped in earlier milestones before this list
> was written — the caution still applies to what's genuinely left:
> multiplayer, procedural structures, advanced water, greedy meshing,
> elaborate UI, economy, skill trees. None of those are started, and
> none should be started as a side effect of an art pass.

---

# 23. The First Coding Sprint

If you are going into Claude/Cursor/etc. with the actual repository, I would make the **first implementation task only this**:

```text
TASK 1

Integrate the generated Blocky asset package into the existing Godot
voxel prototype.

Do NOT implement creatures, inventory, combat, biomes, crafting,
day/night, or new gameplay systems yet.

1. Preserve the existing chunk/world/player architecture.
2. Import block_atlas.gd and pixel_material.gd.
3. Replace the current vertex-color block rendering with atlas UV rendering.
4. Add all currently generated block definitions:
   grass, dirt, stone, sand, log, leaves, snow, planks,
   workbench, coal ore, iron ore.
5. Preserve visible-face culling.
6. Preserve chunk collision.
7. Preserve block breaking and placing.
8. Replace the primitive player model with player.glb.
9. Preserve the existing CharacterBody3D, collision, movement,
   camera, aiming and block interaction.
10. Attach short_sword.glb to a right-hand socket, but do not
    implement sword combat yet.
11. Replace the text hotbar only after the textured blocks work.
12. Do not rewrite working systems unnecessarily.

Acceptance criteria:

- Game launches.
- Terrain still generates.
- Chunks still stream.
- Collision still works.
- Player still moves/jumps/runs.
- Blocks still break/place.
- Blocks display the generated pixel textures.
- Player displays the generated player model.
- Sword appears attached to the player's hand.
- No visible texture bleeding.
- No missing-resource errors.
- No new gameplay systems are introduced.
```

**That is the bridge between the current prototype and the asset package.**

After that works, the next Claude task should be **inventory + real hotbar**, not animals. The generated assets are giving you the content for the game, but the existing code needs a small amount of infrastructure before those assets have somewhere meaningful to live.

> **Task 1 is done.** Points 1, 3–10, 12 as specified; point 2 done
> with a one-line fix (missing `class_name` on `pixel_material.gd`);
> point 11 is moot — the hotbar was already a real slot-based visual
> HUD, not text, from an earlier milestone (see the reconciliation
> note under section 0). All acceptance criteria verified: full
> automated selftest suite passes with identical results to the
> pre-asset baseline, plus screenshots confirming correct face
> orientation (grass_side shows green-on-top, not flipped), the
> rigged player from front/side/in-motion, and the sword sized and
> positioned without ground-clipping. No missing-resource errors in
> any headless import or run log.
>
> The doc's own suggested next task ("inventory + real hotbar") is
> also already done, from before this asset drop — so the genuinely
> next open item, picking up where the gap table (§20) and phase
> breakdown (§21) point, is either **icon textures** (swap the flat-
> color HUD/inventory/hotbar squares for the generated PNGs — small,
> mechanical, low-risk) or **Phase 2, environment dressing** (trees/
> rocks/props as GLBs — bigger, and needs the voxel-tree-vs-GLB-prop
> decision flagged under Milestone F first). Recommend asking which,
> rather than guessing.
