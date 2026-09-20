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

## S3: valid "routine" home/job values -- CityBlock's own named locations
## (scripts/city_block.gd's location_positions/route_markers keys), not a
## separate ID space, so Layer 5+ code can hand a routine's "home"/"job"
## straight to CityBlock.get_route() with no translation step.
const ROUTINE_LOCATIONS := ["apartment", "street", "cafe", "workplace", "park"]
const DEFAULT_ROUTINE_HOME := "apartment"
const DEFAULT_ROUTINE_JOB := "workplace"

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
		# S3: a routine is data, not behavior -- Layer 5's S5 (goal
		# priority/routine loop) and Layer 7's residents read these hours
		# and CityBlock location keys to decide what a person should be
		# doing right now. The player has one too (unused by any code yet,
		# but the same shape means S5 doesn't need a player-vs-resident
		# branch later): a default 9-5 at the Workplace, home at the
		# Apartment, matching this slice's only home/job locations.
		"routine": {
			"home": DEFAULT_ROUTINE_HOME,
			"job": DEFAULT_ROUTINE_JOB,
			"wake_hour": 7,
			"work_start_hour": 9,
			"work_end_hour": 17,
			"sleep_hour": 22,
		},
	}


func load_dict(source: Dictionary) -> void:
	data = default_data()
	# A person's id must survive save/load unchanged -- it's how Layer 6+
	# (relationships, memories naming other people) will refer to them.
	# Only accept one already on disk; a fresh default_data() id is correct
	# for a save written before this field existed.
	if source.get("id") is String and not str(source["id"]).is_empty():
		data["id"] = source["id"]
	for section in ["identity", "appearance", "personality", "needs", "routine"]:
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


## S3: current value of a routine key ("home", "job" -- CityBlock location
## keys; "wake_hour"/"work_start_hour"/"work_end_hour"/"sleep_hour" -- ints
## 0-23). Unknown keys read as "" rather than erroring, matching need()'s
## same "typo-safe read" reasoning.
func routine(key: String) -> Variant:
	return data["routine"].get(key, "")


## L0: re-runs _sanitize() after a caller writes directly into `data`
## (e.g. ResidentRoster's per-resident routine/appearance variation) --
## a small public door to the same validation load_dict() and adjust_need()
## already run through, instead of every caller reaching into a "private"
## method by name.
func revalidate() -> void:
	_sanitize()


## S3: builds one resident's PersonProfile -- the same shape the player
## uses (see the class doc comment), just with a name/home/job appropriate
## to an NPC instead of the player's own default_data() ("New arrival",
## "Looking for work"). Layer 6's L0 ("prepare deterministic data for 20
## residents") is the real content-authoring card; this is the one-record
## proof S3 asks for, not a preview of L0's own scope.
static func new_resident(display_name: String, home: String, job: String) -> PersonProfile:
	var p := PersonProfile.new()
	p.data["identity"]["name"] = display_name
	p.data["identity"]["job"] = job.capitalize()
	p.data["routine"]["home"] = home
	p.data["routine"]["job"] = job
	p._sanitize()
	return p


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
	# S3: home/job must be one of CityBlock's own named locations (an
	# invalid or missing one would silently break any Layer 5+ code that
	# hands it straight to CityBlock.get_route()); hours are wrapped into
	# a real 0-23 day rather than clamped, so e.g. -1 sanely means 23.
	var routine_data: Dictionary = data.get("routine", {})
	if routine_data.get("home") not in ROUTINE_LOCATIONS:
		routine_data["home"] = DEFAULT_ROUTINE_HOME
	if routine_data.get("job") not in ROUTINE_LOCATIONS:
		routine_data["job"] = DEFAULT_ROUTINE_JOB
	for key in ["wake_hour", "work_start_hour", "work_end_hour", "sleep_hour"]:
		routine_data[key] = posmod(int(routine_data.get(key, 0)), 24)
	data["routine"] = routine_data
