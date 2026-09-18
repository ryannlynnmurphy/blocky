class_name SaveGame
extends RefCounted
## Reads and writes a save file. The save is plain JSON so you can open
## it in a text editor and see exactly what was stored.
##
## "user://" is Godot's per-app data folder; on Windows that's
## %APPDATA%\Godot\app_userdata\Voxel RPG\


static func write(path: String, data: Dictionary) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("Could not write save file %s (%s)" % [path, FileAccess.get_open_error()])
		return false
	f.store_string(JSON.stringify(data, "\t"))
	return true


static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Could not read save file %s" % path)
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}


static func exists(path: String) -> bool:
	return FileAccess.file_exists(path)
