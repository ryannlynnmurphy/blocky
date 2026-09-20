class_name WardrobeCatalog
extends RefCounted
## Stable, reusable wardrobe data. v1 items recolor named meshes on the shared
## player rig; later art can replace `asset_ref` without changing save IDs.

const SLOTS := ["tshirt", "pants", "belt", "bracelet", "shoes"]

const ITEMS := {
	"tshirt_slate": {"slot": "tshirt", "name": "Slate T-Shirt", "asset_ref": "rig:torso,arm_L,arm_R", "color": "587a93"},
	"tshirt_cream": {"slot": "tshirt", "name": "Cream T-Shirt", "asset_ref": "rig:torso,arm_L,arm_R", "color": "ddd3bb"},
	"tshirt_rose": {"slot": "tshirt", "name": "Rose T-Shirt", "asset_ref": "rig:torso,arm_L,arm_R", "color": "c9818c"},
	"tshirt_moss": {"slot": "tshirt", "name": "Moss T-Shirt", "asset_ref": "rig:torso,arm_L,arm_R", "color": "718365"},
	"pants_charcoal": {"slot": "pants", "name": "Charcoal Pants", "asset_ref": "rig:leg_L,leg_R", "color": "353a43"},
	"pants_denim": {"slot": "pants", "name": "Denim Pants", "asset_ref": "rig:leg_L,leg_R", "color": "365d7c"},
	"pants_tan": {"slot": "pants", "name": "Tan Pants", "asset_ref": "rig:leg_L,leg_R", "color": "a98159"},
	"pants_olive": {"slot": "pants", "name": "Olive Pants", "asset_ref": "rig:leg_L,leg_R", "color": "5d6946"},
	"belt_brass": {"slot": "belt", "name": "Brass Belt", "asset_ref": "rig:belt,buckle", "color": "c9a14a"},
	"belt_leather": {"slot": "belt", "name": "Leather Belt", "asset_ref": "rig:belt,buckle", "color": "69442f"},
	"belt_black": {"slot": "belt", "name": "Black Belt", "asset_ref": "rig:belt,buckle", "color": "24252a"},
	"bracelet_copper": {"slot": "bracelet", "name": "Copper Bracelet", "asset_ref": "future:bracelet_wrist", "color": "b66a43"},
	"bracelet_silver": {"slot": "bracelet", "name": "Silver Bracelet", "asset_ref": "future:bracelet_wrist", "color": "b9c0c6"},
	"bracelet_thread": {"slot": "bracelet", "name": "Thread Bracelet", "asset_ref": "future:bracelet_wrist", "color": "8d65b9"},
	"shoes_black": {"slot": "shoes", "name": "Black Shoes", "asset_ref": "rig:boot_L,boot_R", "color": "282a30"},
	"shoes_canvas": {"slot": "shoes", "name": "Canvas Shoes", "asset_ref": "rig:boot_L,boot_R", "color": "d7d0bd"},
	"shoes_umber": {"slot": "shoes", "name": "Umber Boots", "asset_ref": "rig:boot_L,boot_R", "color": "674737"},
}

const DEFAULT_OUTFIT := {
	"tshirt": "tshirt_slate", "pants": "pants_charcoal", "belt": "belt_brass",
	"bracelet": "bracelet_copper", "shoes": "shoes_black",
}


static func item(id: String) -> Dictionary:
	return ITEMS.get(id, {}).duplicate(true)


static func items_for_slot(slot: String) -> Array:
	var found: Array = []
	for id in ITEMS:
		if ITEMS[id]["slot"] == slot:
			found.append({"id": id, "name": ITEMS[id]["name"], "asset_ref": ITEMS[id]["asset_ref"]})
	found.sort_custom(func(a: Dictionary, b: Dictionary): return a["name"] < b["name"])
	return found


static func sanitize(outfit: Dictionary) -> Dictionary:
	var clean := DEFAULT_OUTFIT.duplicate()
	for slot in SLOTS:
		var id := str(outfit.get(slot, clean[slot]))
		if ITEMS.has(id) and ITEMS[id]["slot"] == slot:
			clean[slot] = id
	return clean
