# Water and Special Swimming — v1 Design Contract

**Status:** design card WATER-03. This document specifies a fresh system; it
does not authorize reintroducing deleted code.

## Goal

Add readable, chunk-stream-safe water and satisfying special swimming while
preserving ordinary land movement, jumping, saves, and voxel collision.

## v1 boundary

- One deterministic global water table, not rivers or editable water blocks.
- Water is a separate transparent visual layer with no physics collision.
- Terrain remains authoritative for the water table; the world exposes queries.
- No block placement/breaking water, current simulation, boats, or creature
  swimming in v1.
- Breath/drowning is optional and explicitly deferred until WATER-08 decides
  whether its save migration cost is worthwhile.

## World contract

`World` owns the single source of truth, populated from generated terrain:

```text
water_surface_y_at(x, z) -> float
is_water_at(world_position) -> bool
water_depth_at(world_position) -> float
```

Flood only terrain columns below the water table. Do not add water to the
opaque block mesh. Generate/recycle chunk-aligned visual surface nodes when
chunks stream, and never draw them above solid terrain.

## Player states and controls

| State | Detection | Movement |
| --- | --- | --- |
| Dry | feet above water | Existing walk/run/jump/gravity unchanged. |
| Wade | feet in shallow water, torso clear | Existing directional movement with a mild speed reduction; normal jump/gravity. |
| Swim | torso in deep water | Directional swim with drag and gentle sinking. Space ascends; Ctrl descends. |
| Sprint swim | Swim + Shift + direction | A controlled burst along camera-forward direction, including pitch, with stamina/cooldown so vertical climbing and infinite speed are impossible. |

Land Shift remains run. In water, Shift plus movement becomes propulsion. The
player controller alone computes state and emits `water_state_changed`; HUD and
audio consume that state and never repeat geometry queries. Entering deep water
resets fall-peak damage only after an intentional shallow-water edge test.

## Presentation

- Calm transparent surface with no opaque tile seams.
- Wading uses splash steps; swimming uses a restrained stroke cadence.
- Underwater tint/fog and low-pass audio follow head-submerged state only.
- Breath UI exists only if drowning is approved later.

## Required gates

1. Deterministic dry/wade/surface/submerged coordinate fixtures.
2. No visual water above solid terrain; correct visual stream/reload counts.
3. Land walking, running, jumping, and fall damage unchanged outside water.
4. Swim speed caps, ascent/descent, special Shift-propel stamina/cooldown,
   surface exit, and deep-water fall protection pass headless tests.
5. Manual fresh-world shore test across at least three streamed chunks.
6. Save/reload succeeds on dry land and at a water boundary. If breath is added,
   include migration/default-breath tests before enabling it.

