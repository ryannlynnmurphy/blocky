extends SceneTree
## Throwaway dev tool: finds a shoreline column (water column with dry land
## next door) near the origin and prints its coordinates.
##   godot --headless --path . --script tools/find_water.gd

const RADIUS := 400


func _init() -> void:
	var gen := WorldGen.new(1337)
	for r in range(0, RADIUS, 2):
		for d in [Vector2i(r, 0), Vector2i(-r, 0), Vector2i(0, r), Vector2i(0, -r)]:
			var wx: int = d.x
			var wz: int = d.y
			var h := gen.height_at(wx, wz)
			if h > WorldGen.SEA_LEVEL - 1:   # real water tiles start here now
				continue
			var land_near := false
			for n in [Vector2i(4, 0), Vector2i(-4, 0), Vector2i(0, 4), Vector2i(0, -4)]:
				if gen.height_at(wx + n.x, wz + n.y) > WorldGen.SEA_LEVEL + 1:
					land_near = true
					break
			if land_near:
				print("shoreline water at x=%d z=%d (h=%d)" % [wx, wz, h])
				quit()
				return
	print("none found")
	quit()
