class_name Inventory
extends RefCounted
## What the player is carrying: a count per block ID.
## Emits `changed` whenever a count moves so the HUD can redraw.

signal changed
signal added(id: int, amount: int)   # something was picked up (for "+1 Dirt" popups)

var _counts := {}   # block id -> int


func count(id: int) -> int:
	return _counts.get(id, 0)


func add(id: int, n: int = 1) -> void:
	_counts[id] = count(id) + n
	changed.emit()
	added.emit(id, n)


## Removes n of a block. Returns false (and takes nothing) if you don't
## have enough.
func take(id: int, n: int = 1) -> bool:
	if count(id) < n:
		return false
	_counts[id] = count(id) - n
	changed.emit()
	return true


## For saving: {"1": 3, "3": 1}. JSON keys have to be strings.
func to_dict() -> Dictionary:
	var out := {}
	for id in _counts.keys():
		if _counts[id] > 0:
			out[str(id)] = _counts[id]
	return out


func from_dict(d: Dictionary) -> void:
	_counts.clear()
	for key in d.keys():
		_counts[int(key)] = int(d[key])
	changed.emit()


## "Dirt x3, Stone x1" — for logs and tests.
func summary() -> String:
	var parts: PackedStringArray = []
	for id in _counts.keys():
		if _counts[id] > 0:
			parts.append("%s x%d" % [Blocks.NAMES[id], _counts[id]])
	return ", ".join(parts) if parts.size() > 0 else "(empty)"
