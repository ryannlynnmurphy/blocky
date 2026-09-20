# Wardrobe Catalog v1

`scripts/wardrobe_catalog.gd` is the canonical data source for first-pass
interchangeable clothes. Every record has a stable ID, player-facing name,
exclusive slot, asset reference, and color fallback.

| Slot | v1 choices | Current asset state |
| --- | --- | --- |
| T-shirt | Slate, Cream, Rose, Moss | Existing shared torso/arm rig meshes, recolored. |
| Pants | Charcoal, Denim, Tan, Olive | Existing shared leg rig meshes, recolored. |
| Belt | Brass, Leather, Black | Existing shared belt/buckle rig meshes, recolored. |
| Bracelet | Copper, Silver, Thread | Generated ring mesh at the wrist joint (C8), recolored — not GLB art. |
| Shoes | Black, Canvas, Umber | Existing shared boot rig meshes, recolored. |

This is intentionally not a claim that independent apparel meshes exist for
t-shirt/pants/belt/shoes (those recolor shared rig geometry). The bracelet is
a plain procedural `TorusMesh` sized from the hand's own AABB and parented to
`hand_L` (`PersonAppearance._apply_bracelet`) — a real attachment, but not
authored art; `asset_ref` says `generated:` rather than `rig:` so this stays
honest if dedicated bracelet art replaces it later.

