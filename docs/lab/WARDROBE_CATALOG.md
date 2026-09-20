# Wardrobe Catalog v1

`scripts/wardrobe_catalog.gd` is the canonical data source for first-pass
interchangeable clothes. Every record has a stable ID, player-facing name,
exclusive slot, asset reference, and color fallback.

| Slot | v1 choices | Current asset state |
| --- | --- | --- |
| T-shirt | Slate, Cream, Rose, Moss | Existing shared torso/arm rig meshes, recolored. |
| Pants | Charcoal, Denim, Tan, Olive | Existing shared leg rig meshes, recolored. |
| Belt | Brass, Leather, Black | Existing shared belt/buckle rig meshes, recolored. |
| Bracelet | Copper, Silver, Thread | Placeholder attachment target; requires a wrist mesh in C8. |
| Shoes | Black, Canvas, Umber | Existing shared boot rig meshes, recolored. |

This is intentionally not a claim that independent apparel meshes exist. The
ID/slot contract is ready now; C7/C8 turn it into selectable preview rendering
and replace `asset_ref` values when dedicated art arrives.

