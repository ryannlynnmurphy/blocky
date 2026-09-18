extends SceneTree
## Dev tool: finds cave mouths (surface columns carved open) near the
## origin and prints their coordinates, nearest first.
##   godot --headless --path . --script tools/find_cave.gd

const RADIUS_CHUNKS := 4


func _init() -> void:
	var gen := WorldGen.new(1337)
	var found := []
	for cz in range(-RADIUS_CHUNKS, RADIUS_CHUNKS + 1):
		for cx in range(-RADIUS_CHUNKS, RADIUS_CHUNKS + 1):
			var data: PackedByteArray = gen.fill_chunk(Vector2i(cx, cz))[0]
			for lz in 16:
				for lx in 16:
					var wx := cx * 16 + lx
					var wz := cz * 16 + lz
					var h := gen.height_at(wx, wz)
					if h <= WorldGen.SEA_LEVEL + 1:
						continue
					# Surface block carved away = a hole you can see from above.
					if data[lx + 16 * (lz + 16 * h)] == Blocks.AIR:
						found.append([Vector2i(wx, wz).length(), wx, wz, h])
	found.sort_custom(func(a, b): return a[0] < b[0])
	print("cave mouths within %d chunks: %d" % [RADIUS_CHUNKS, found.size()])
	for i in mini(8, found.size()):
		var f: Array = found[i]
		print("  x=%d z=%d (surface y=%d, %.0f blocks from origin)" % [f[1], f[2], f[3], f[0]])
	quit()
