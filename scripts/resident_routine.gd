class_name ResidentRoutine
## S5: pure goal-selection logic for a resident, given their PersonProfile's
## routine (S3) and the current simulated hour (S0's DayNight.hour()).
## Deliberately separate from the "driving" glue (main.gd's hour_changed
## handler, CityBlock.get_route(), DebugActor.follow_route()) so the
## decision itself is trivially testable without booting the whole city
## scene, the same "pure logic, thin glue" split day_night.gd's own
## hour()/minute()/day() already established.
##
## Priority order (highest first): sleep hours win over work hours (you
## don't skip sleep to go to work), work hours win over free time, and free
## time defaults to food/social at the cafe -- the only other real place to
## be in this slice's five locations.


## Returns the location key ("apartment"/"workplace"/"cafe", the same
## vocabulary CityBlock.get_route() and PersonProfile.ROUTINE_LOCATIONS
## already use) the resident should be heading to/at right now, for `hour`
## (0-23).
static func current_goal(routine: Dictionary, hour: int) -> String:
	var sleep_hour := int(routine.get("sleep_hour", 22))
	var wake_hour := int(routine.get("wake_hour", 7))
	var work_start := int(routine.get("work_start_hour", 9))
	var work_end := int(routine.get("work_end_hour", 17))
	if _hour_in_range(hour, sleep_hour, wake_hour):
		return str(routine.get("home", "apartment"))
	if _hour_in_range(hour, work_start, work_end):
		return str(routine.get("job", "workplace"))
	return "cafe"


## True if `hour` falls in [start, end), wrapping past midnight when
## start > end (e.g. sleep_hour=22, wake_hour=7 spans 22, 23, 0..6).
## start == end means "never" (a zero-length window), not "always."
static func _hour_in_range(hour: int, start: int, end: int) -> bool:
	if start == end:
		return false
	if start < end:
		return hour >= start and hour < end
	return hour >= start or hour < end
