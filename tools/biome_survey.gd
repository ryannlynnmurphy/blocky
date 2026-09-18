extends SceneTree
## Dev tool: prints how the biomes are spread out, without opening a window.
##   godot --headless --path . --script tools/biome_survey.gd

const AREA := 1000      # sample a square this many blocks across, centred on 0
const STEP := 10        # sample every N blocks
const MAP_STEP := 40    # ASCII map cell size in blocks
const GLYPH := ["p", "F", ".", "*"]   # Plains, Forest, Desert, Tundra


func _init() -> void:
	var gen := WorldGen.new(1337)
	var counts := [0, 0, 0, 0]
	var total := 0
	for z in range(-AREA / 2, AREA / 2, STEP):
		for x in range(-AREA / 2, AREA / 2, STEP):
			counts[gen.biome_at(x, z)] += 1
			total += 1
	for i in 4:
		print("%-7s %5.1f%%" % [WorldGen.BIOMES[i]["name"], 100.0 * counts[i] / total])

	print("\nMap (%d blocks per cell), spawn is near the centre:" % MAP_STEP)
	for z in range(-AREA / 2, AREA / 2, MAP_STEP):
		var row := ""
		for x in range(-AREA / 2, AREA / 2, MAP_STEP):
			row += GLYPH[gen.biome_at(x, z)]
		print(row)
	quit()
