class_name PersonActions
## S2 (Work Orders Layer 5): the shared action -> time/needs/money pipeline.
## The player calls these through main.gd's existing sleep/eat handlers.
##
## v1 keeps this minimal and generic: apply_action() is the one real
## primitive; sleep()/eat() below are named wrappers with the specific
## numbers for those two actions.

const MINUTES_PER_HOUR := 60.0


## The one real primitive: advances `clock` by `hours`, then applies every
## (need_key -> delta) in `need_deltas` to `profile`. Money is just another
## key in the same dictionary -- PersonProfile.adjust_need() already knows
## it's unbounded-above/never-negative instead of the usual 0-100 cap.
static func apply_action(clock: DayNight, profile: PersonProfile, hours: float, need_deltas: Dictionary) -> void:
	clock.advance(hours)
	for key in need_deltas:
		profile.adjust_need(key, int(need_deltas[key]))


## Sleep's time jump already exists as a real player mechanic
## (DayNight.skip_to_morning(), unchanged by this card) -- this only adds
## the needs side S2 asks for, given how many hours were actually asleep
## (the caller measures that from the clock itself, e.g. via
## DayNight.total_minutes() before/after the skip).
static func sleep(profile: PersonProfile, hours_asleep: float) -> void:
	profile.adjust_need("energy", int(clampf(hours_asleep * 12.0, 0.0, 100.0)))
	profile.adjust_need("stress", -int(clampf(hours_asleep * 3.0, 0.0, 40.0)))


## Eating already exists as a real player mechanic (Player.eat(), Meat ->
## +4 survival hunger); this adds the person-need side and a small time
## cost (a real meal takes a few minutes, unlike combat or movement).
static func eat(clock: DayNight, profile: PersonProfile) -> void:
	apply_action(clock, profile, 10.0 / MINUTES_PER_HOUR, {"hunger": 25, "energy": 3})
