# Hollowmark city blocks — registry data only.
# Merge into scripts/blocks.gd (or autoload alongside it).
# IDs continue from START_ID so they can't clash with the base registry.
extends RefCounted
class_name CityBlocks

const START_ID := 64          # bump to (last base id + 1)
const ATLAS := "res://blocky/textures/blocks/city_blocks_atlas.png"
const ATLAS_COLS := 4
const TILE := 16

# name, hardness (seconds by hand), tool class, solid
const DEFS := [
	{"name": "Cobblestone",   "tex": "cobblestone",   "hard": 2.0, "tool": "pick", "solid": true},
	{"name": "Brick",         "tex": "brick",         "hard": 2.2, "tool": "pick", "solid": true},
	{"name": "Plaster",       "tex": "plaster",       "hard": 0.9, "tool": "pick", "solid": true},
	{"name": "Roof Tile",     "tex": "roof_tile",     "hard": 1.2, "tool": "pick", "solid": true},
	{"name": "Slate Roof",    "tex": "slate_roof",    "hard": 1.6, "tool": "pick", "solid": true},
	{"name": "Cobble Road",   "tex": "cobble_road",   "hard": 1.8, "tool": "pick", "solid": true},
	{"name": "Flagstone",     "tex": "flagstone",     "hard": 1.8, "tool": "pick", "solid": true},
	{"name": "Door",          "tex": "city_door",     "hard": 0.8, "tool": "axe",  "solid": true},
	{"name": "Shop Window",   "tex": "shop_window",   "hard": 0.5, "tool": "",     "solid": true},
	{"name": "Lantern Post",  "tex": "lantern_post",  "hard": 0.6, "tool": "",     "solid": true},
	{"name": "Jail Bars",     "tex": "jail_bars",     "hard": 4.0, "tool": "pick", "solid": true},
	{"name": "Awning",        "tex": "market_awning", "hard": 0.4, "tool": "",     "solid": true},
	{"name": "Sign Board",    "tex": "sign_board",    "hard": 0.6, "tool": "axe",  "solid": true},
	{"name": "Tavern Floor",  "tex": "tavern_floor",  "hard": 0.9, "tool": "axe",  "solid": true},
	{"name": "Crate",         "tex": "crate",         "hard": 0.7, "tool": "axe",  "solid": true},
	{"name": "Hay",           "tex": "hay",           "hard": 0.3, "tool": "",     "solid": true},
]

# Blocks that want their own emissive material instead of the shared atlas one.
const EMISSIVE := {"lantern_post": 0.8}

static func id_of(tex: String) -> int:
	for i in DEFS.size():
		if DEFS[i]["tex"] == tex:
			return START_ID + i
	return -1

# Atlas rect for a tile index, in 0..1 UV space (row-major, 4 columns).
static func uv(index: int) -> Rect2:
	var rows := int(ceil(float(DEFS.size()) / ATLAS_COLS))
	var cx := index % ATLAS_COLS
	var cy := index / ATLAS_COLS
	var w := 1.0 / ATLAS_COLS
	var h := 1.0 / rows
	var inset := 0.5 / (ATLAS_COLS * TILE)   # half-texel, kills bleeding
	return Rect2(cx * w + inset, cy * h + inset, w - inset * 2.0, h - inset * 2.0)

static func faces(index: int) -> Array:
	# [top, side, bottom] — every city block is single-texture for now
	return [index, index, index]
