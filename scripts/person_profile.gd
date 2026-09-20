class_name PersonProfile
extends RefCounted
## The simulation-facing description of a person.  It deliberately contains
## no scene nodes: players and NPCs can use the exact same data shape.

const WARDROBE_CATALOG = preload("res://scripts/wardrobe_catalog.gd")

const APPEARANCE_OPTIONS := {
	"body": ["Balanced", "Tall", "Broad"],
	"skin": ["Porcelain", "Warm", "Umber", "Deep", "Copper"],
	"hair": ["Crop", "Sweep", "Long", "Buzz"],
	"hair_color": ["Ink", "Chestnut", "Honey", "Copper", "Silver"],
	"outfit": ["Casual", "Workwear", "Nightlife", "Utility"],
	"accent": ["Ochre", "Teal", "Violet", "Crimson", "None"],
}

const VALUE_OPTIONS := ["Freedom", "Money", "Status", "Family", "Community",
	"Knowledge", "Art", "Faith", "Power", "Security"]
const AXES := ["ambition", "sociability", "risk", "cooperation", "convention", "empathy"]

var data: Dictionary = default_data()


static func default_data() -> Dictionary:
	return {
		"id": _new_id(),
		"identity": {
			"name": "Alex Rivera",
			"pronouns": "they/them",
			"age": 25,
			"background": "New arrival",
			"neighborhood": "Hollowmark Central",
			"education": "Public school",
			"job": "Looking for work",
			"income_class": "Working class",
		},
		"appearance": {
			"body": "Balanced", "skin": "Warm", "hair": "Sweep",
			"hair_color": "Chestnut", "outfit": "Casual", "accent": "Teal",
			# Item IDs are intentionally separate from the older outfit/accent presets.
			# Missing this field in an older profile is safe: _sanitize supplies defaults.
			"wardrobe": WARDROBE_CATALOG.DEFAULT_OUTFIT.duplicate(),
		},
		"personality": {
			"ambition": 20, "sociability": 15, "risk": 0,
			"cooperation": 30, "convention": -10, "empathy": 25,
		},
		"values": ["Community", "Freedom", "Knowledge"],
		"relationships": {},
		"memories": [],
		"needs": {"hunger": 70, "energy": 80, "social": 60, "stress": 20, "money": 120},
	}


func load_dict(source: Dictionary) -> void:
	data = default_data()
	# A person's id must survive save/load unchanged -- it's how Layer 6+
	# (relationships, memories naming other people) will refer to them.
	# Only accept one already on disk; a fresh default_data() id is correct
	# for a save written before this field existed.
	if source.get("id") is String and not str(source["id"]).is_empty():
		data["id"] = source["id"]
	for section in ["identity", "appearance", "personality", "needs"]:
		if source.get(section) is Dictionary:
			for key in source[section]:
				if data[section].has(key):
					data[section][key] = source[section][key]
	if source.get("values") is Array:
		data["values"] = source["values"].slice(0, 3)
	if source.get("relationships") is Dictionary:
		data["relationships"] = source["relationships"].duplicate(true)
	if source.get("memories") is Array:
		data["memories"] = source["memories"].duplicate(true)
	_sanitize()


func to_dict() -> Dictionary:
	return data.duplicate(true)


func display_name() -> String:
	return str(data["identity"].get("name", "Unnamed Person")).strip_edges()


func appearance(key: String) -> String:
	return str(data["appearance"].get(key, ""))


func set_appearance(key: String, value: String) -> void:
	if APPEARANCE_OPTIONS.has(key) and value in APPEARANCE_OPTIONS[key]:
		data["appearance"][key] = value


func wardrobe_id(slot: String) -> String:
	return str(data["appearance"].get("wardrobe", {}).get(slot, WARDROBE_CATALOG.DEFAULT_OUTFIT.get(slot, "")))


func set_wardrobe(slot: String, item_id: String) -> void:
	if slot not in WARDROBE_CATALOG.SLOTS:
		return
	var item: Dictionary = WARDROBE_CATALOG.item(item_id)
	if item.get("slot", "") == slot:
		data["appearance"]["wardrobe"][slot] = item_id


static func _new_id() -> String:
	return "person_%d_%d" % [Time.get_unix_time_from_system(), randi() % 1000000]


func id() -> String:
	return str(data.get("id", ""))


func axis(key: String) -> int:
	return int(data["personality"].get(key, 0))


func set_axis(key: String, value: float) -> void:
	if key in AXES:
		data["personality"][key] = clampi(roundi(value), -100, 100)


func set_value(slot: int, value: String) -> void:
	if slot >= 0 and slot < 3 and value in VALUE_OPTIONS:
		while data["values"].size() < 3:
			data["values"].append("Community")
		data["values"][slot] = value


## S2: current value of a needs key ("hunger", "energy", "social", "stress",
## "money"). Unknown keys read as 0 rather than erroring -- callers driving
## this from data-defined actions (Layer 5+) shouldn't crash on a typo.
func need(key: String) -> int:
	return int(data["needs"].get(key, 0))


## Applies `delta` to a needs key, then re-clamps through the same
## _sanitize() every load already runs (0-100 for hunger/energy/social/
## stress, non-negative for money) so an action can never leave a need out
## of its valid range. Unknown keys are ignored, not created.
func adjust_need(key: String, delta: int) -> void:
	if not data["needs"].has(key):
		return
	data["needs"][key] = int(data["needs"][key]) + delta
	_sanitize()


func randomize_visuals() -> void:
	for key in APPEARANCE_OPTIONS:
		var options: Array = APPEARANCE_OPTIONS[key]
		data["appearance"][key] = options.pick_random()
	for slot in WARDROBE_CATALOG.SLOTS:
		var choices: Array = WARDROBE_CATALOG.items_for_slot(slot)
		if not choices.is_empty():
			data["appearance"]["wardrobe"][slot] = choices.pick_random()["id"]


func _sanitize() -> void:
	for key in APPEARANCE_OPTIONS:
		if data["appearance"].get(key) not in APPEARANCE_OPTIONS[key]:
			data["appearance"][key] = APPEARANCE_OPTIONS[key][0]
	var raw_wardrobe: Dictionary = data["appearance"].get("wardrobe", {})
	data["appearance"]["wardrobe"] = WARDROBE_CATALOG.sanitize(raw_wardrobe)
	for key in AXES:
		data["personality"][key] = clampi(int(data["personality"].get(key, 0)), -100, 100)
	while data["values"].size() < 3:
		data["values"].append("Community")
	data["values"] = data["values"].slice(0, 3)
	# 0-100 meters, same convention the HUD already uses for player hunger;
	# money is a real currency count, unbounded above but never negative.
	for key in ["hunger", "energy", "social", "stress"]:
		data["needs"][key] = clampi(int(data["needs"].get(key, 0)), 0, 100)
	data["needs"]["money"] = maxi(int(data["needs"].get("money", 0)), 0)
