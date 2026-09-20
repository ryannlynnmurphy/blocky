class_name PersonProfile
extends RefCounted
## The simulation-facing description of a person.  It deliberately contains
## no scene nodes: players and NPCs can use the exact same data shape.

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


func randomize_visuals() -> void:
	for key in APPEARANCE_OPTIONS:
		var options: Array = APPEARANCE_OPTIONS[key]
		data["appearance"][key] = options.pick_random()


func _sanitize() -> void:
	for key in APPEARANCE_OPTIONS:
		if data["appearance"].get(key) not in APPEARANCE_OPTIONS[key]:
			data["appearance"][key] = APPEARANCE_OPTIONS[key][0]
	for key in AXES:
		data["personality"][key] = clampi(int(data["personality"].get(key, 0)), -100, 100)
	while data["values"].size() < 3:
		data["values"].append("Community")
	data["values"] = data["values"].slice(0, 3)
