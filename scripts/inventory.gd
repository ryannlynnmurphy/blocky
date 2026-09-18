class_name Inventory
extends RefCounted
## A row of slots, Minecraft-style. Each slot holds one kind of thing
## and how many (up to MAX_STACK). The player's inventory has 36 slots:
## the first 9 are the hotbar. Crafting grids are small Inventories too.

signal changed
signal added(id: int, amount: int)   # something was picked up (for "+1 Dirt" popups)

const MAX_STACK := 64
const HOTBAR := 9
const PLAYER_SIZE := 36

var size := PLAYER_SIZE
var _ids: PackedInt32Array
var _counts: PackedInt32Array


func _init(slot_count: int = PLAYER_SIZE) -> void:
	size = slot_count
	_ids.resize(size)
	_counts.resize(size)
	clear()


# ---------------------------------------------------------------- slots

func id_at(i: int) -> int:
	return _ids[i] if _counts[i] > 0 else Blocks.AIR


func count_at(i: int) -> int:
	return _counts[i]


func set_slot(i: int, id: int, n: int) -> void:
	if n <= 0 or id == Blocks.AIR:
		_ids[i] = Blocks.AIR
		_counts[i] = 0
	else:
		_ids[i] = id
		_counts[i] = mini(n, MAX_STACK)
	changed.emit()


func take_from_slot(i: int, n: int = 1) -> bool:
	if _counts[i] < n:
		return false
	set_slot(i, _ids[i], _counts[i] - n)
	return true


func find_slot(id: int) -> int:
	for i in size:
		if _counts[i] > 0 and _ids[i] == id:
			return i
	return -1


func is_empty() -> bool:
	for i in size:
		if _counts[i] > 0:
			return false
	return true


func clear() -> void:
	_ids.fill(Blocks.AIR)
	_counts.fill(0)
	changed.emit()


# ---------------------------------------------------------------- totals

func count(id: int) -> int:
	var total := 0
	for i in size:
		if _ids[i] == id:
			total += _counts[i]
	return total


## Adds n of an item: tops up existing stacks first, then fills empty
## slots. Returns how many did NOT fit (0 when everything went in).
func add(id: int, n: int = 1) -> int:
	var left := n
	for i in size:
		if left == 0:
			break
		if _counts[i] > 0 and _ids[i] == id and _counts[i] < MAX_STACK:
			var put := mini(MAX_STACK - _counts[i], left)
			_counts[i] += put
			left -= put
	for i in size:
		if left == 0:
			break
		if _counts[i] == 0:
			var put := mini(MAX_STACK, left)
			_ids[i] = id
			_counts[i] = put
			left -= put
	if left < n:
		changed.emit()
		added.emit(id, n - left)
	return left


## Removes n of an item from wherever it is (last slots first).
## Returns false (and takes nothing) if you don't have enough.
func take(id: int, n: int = 1) -> bool:
	if count(id) < n:
		return false
	var left := n
	for i in range(size - 1, -1, -1):
		if left == 0:
			break
		if _counts[i] > 0 and _ids[i] == id:
			var t := mini(_counts[i], left)
			_counts[i] -= t
			left -= t
			if _counts[i] == 0:
				_ids[i] = Blocks.AIR
	changed.emit()
	return true


# ---------------------------------------------------------------- saving

## {"slots": [[slot, id, count], ...]}
func to_dict() -> Dictionary:
	var out := []
	for i in size:
		if _counts[i] > 0:
			out.append([i, _ids[i], _counts[i]])
	return {"slots": out}


func from_dict(d: Dictionary) -> void:
	_ids.fill(Blocks.AIR)
	_counts.fill(0)
	if d.has("slots"):
		for e in d["slots"]:
			var i := int(e[0])
			if i >= 0 and i < size:
				_ids[i] = int(e[1])
				_counts[i] = mini(int(e[2]), MAX_STACK)
	else:
		# Old saves stored {"id": count}; pack them into slots.
		for key in d.keys():
			add(int(key), int(d[key]))
	changed.emit()


## "Dirt x3, Stone x1" — for logs and tests.
func summary() -> String:
	var totals := {}
	for i in size:
		if _counts[i] > 0:
			totals[_ids[i]] = totals.get(_ids[i], 0) + _counts[i]
	var parts: PackedStringArray = []
	for id in totals.keys():
		parts.append("%s x%d" % [Blocks.NAMES[id], totals[id]])
	return ", ".join(parts) if parts.size() > 0 else "(empty)"
