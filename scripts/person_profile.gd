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


## L2: this person's affinity toward `other_id` (their PersonProfile.id()),
## -100..100, 0 if they've never interacted. One-directional by design --
## two people's feelings about each other are separate records, not a
## shared value, so a conversation can (and does, deliberately) move both
## by the same amount without them needing to already agree on anything.
func relationship_affinity(other_id: String) -> int:
	return int(data["relationships"].get(other_id, {}).get("affinity", 0))


## Adjusts (not replaces) the affinity record for `other_id`, clamped to
## -100..100 -- the same range personality axes already use. A no-op for
## an empty id so a profile with no id() yet (shouldn't happen in practice
## -- default_data() always assigns one) can never create a garbage key.
func adjust_relationship(other_id: String, delta: int) -> void:
	if other_id.is_empty():
		return
	var rel: Dictionary = data["relationships"].get(other_id, {"affinity": 0})
	rel["affinity"] = clampi(int(rel.get("affinity", 0)) + delta, -100, 100)
	data["relationships"][other_id] = rel


## L3: appends an event to this person's memory (the schema's own
## "memories": [] slot, empty since the very first version of this file).
## `record` should include an "at_minutes" key (DayNight.total_minutes() at
## the time it happened) so it stays meaningfully inspectable long after --
## "important event is inspectable after time advances" is this card's own
## acceptance check. Capped at MAX_MEMORIES, oldest first out, so a long
## save can't grow this section without bound; L4+ (jobs, consequence
## chains) will have real reasons to prune more deliberately than FIFO, but
## a hard cap is the honest v1 boundary, not a promise this is final.
const MAX_MEMORIES := 50

func add_memory(record: Dictionary) -> void:
	data["memories"].append(record)
	while data["memories"].size() > MAX_MEMORIES:
		data["memories"].pop_front()


## Read-only copy of this person's memories, oldest first.
func memories() -> Array:
	return data["memories"].duplicate(true)


## L3's "resident debug inspector": a readable summary of this person's
## full simulation-facing state (identity, needs, routine, relationships,
## memories) -- not a graphical panel (nothing in this project's "debug"
## requirements so far has needed one; every prior card's "debug"/"proof"
## bar has been met with inspectable data plus a real trigger, e.g. S2's
## work/L2's talk print their own outcome the same way), but a real,
## reachable, gameplay-triggered inspection (CityWalker's Inspect key)
## rather than only a test calling this directly.
func debug_summary() -> String:
	var lines: Array[String] = []
	lines.append("%s  (id=%s)" % [display_name(), id()])
	lines.append("  needs: %s" % [data["needs"]])
	lines.append("  routine: home=%s job=%s wake=%d work=%d-%d sleep=%d"
		% [routine("home"), routine("job"), routine("wake_hour"), routine("work_start_hour"),
			routine("work_end_hour"), routine("sleep_hour")])
	if data["relationships"].is_empty():
		lines.append("  relationships: none yet")
	else:
		for other_id in data["relationships"]:
			lines.append("  relationship[%s]: affinity %d" % [other_id, relationship_affinity(other_id)])
	if data["memories"].is_empty():
		lines.append("  memories: none yet")
	else:
		for m in data["memories"]:
			lines.append("  memory: %s" % [m])
	return "\n".join(lines)


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
	# L2: every relationship record's affinity stays in range even after a
	# raw load from disk (adjust_relationship() already clamps its own
	# writes, but load_dict() replaces "relationships" wholesale with
	# whatever the save file had, so a hand-edited or corrupted save could
	# otherwise smuggle a garbage-typed or out-of-range record past it).
	for other_id in data["relationships"].keys():
		var raw: Variant = data["relationships"][other_id]
		var rel: Dictionary = raw if raw is Dictionary else {}
		rel["affinity"] = clampi(int(rel.get("affinity", 0)), -100, 100)
		data["relationships"][other_id] = rel
