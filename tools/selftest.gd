extends Node
## Dev tool: exercises break -> inventory -> place through the player's
## real code, printing the inventory as it goes. Added by main.gd when
## the game is run with `-- --selftest`.

var player: Player
var _frame := 0


func _physics_process(_delta: float) -> void:
	_frame += 1
	if _frame == 1:
		player.set_look(0.0, -0.8)   # look down at the ground ahead
	elif _frame == 40:
		print("selftest: inventory before break: %s" % player.inventory.summary())
		player._break_block()
		print("selftest: inventory after break:  %s" % player.inventory.summary())
	elif _frame == 80:
		# Select whatever we picked up, then put it back down.
		for i in Blocks.HOTBAR.size():
			if player.inventory.count(Blocks.HOTBAR[i]) > 0:
				player.selected = i
				player.hotbar_changed.emit(i)
				break
		player._place_block()
		print("selftest: inventory after place:  %s" % player.inventory.summary())
