class_name PersonActions
## S2 (Work Orders Layer 5): the shared action -> time/needs/money pipeline.
## Both the player (through main.gd's existing sleep/eat handlers and the
## new city work trigger) and, later, Layer 5+ residents' own AI-driven
## routines (S5) call the same functions here, so "an action costs time and
## changes needs/money" has one implementation, not one per actor type.
##
## v1 keeps this minimal and generic: apply_action() is the one real
## primitive; sleep()/eat()/work() below are named wrappers with the
## specific numbers for those three actions.
##
## "Talk" (L2, Work Orders Layer 6) needed another person to talk to before
## it could be real content instead of a "talk to nobody" stub -- S2
## deliberately deferred it until residents existed (S3+); L0/L1 now put a
## full roster of them in the live city, so it's added below. Work is a v1
## placeholder too -- a flat, honest stand-in for the real job/payday/
## employer system Layer 6's L4 owns, just enough to prove this pipeline
## works end-to-end for a paid action, not a job system of its own.

const MINUTES_PER_HOUR := 60.0

const WORK_SHIFT_HOURS := 4.0
const WORK_PAY := 40

const TALK_MINUTES := 10.0
const TALK_AFFINITY_GAIN := 5


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


## v1 work placeholder (see the class doc comment above): a flat half-day
## shift, modest pay, a real cost to energy/social, a little stress relief
## from having something to do.
static func work(clock: DayNight, profile: PersonProfile) -> void:
	apply_action(clock, profile, WORK_SHIFT_HOURS, {
		"money": WORK_PAY,
		"energy": -30,
		"social": -10,
		"stress": 10,
	})


## L2: a conversation between `a` and `b`, moving both people's affinity
## toward each other by the same fixed, deterministic amount -- this
## card's own "done when: conversation changes a relationship
## deterministically," not a randomized outcome. One-directional records
## (PersonProfile.adjust_relationship()) mean they don't need to already
## agree on anything for both to come away liking each other a little more.
## `a` also gets the small social boost/time cost every real conversation
## costs; `b` doesn't (a resident going about their own routine isn't
## "spending" anything by being talked to -- only the initiator's clock and
## needs move, matching how eat()/work() only ever touch the one caller).
static func talk(clock: DayNight, a: PersonProfile, b: PersonProfile) -> void:
	apply_action(clock, a, TALK_MINUTES / MINUTES_PER_HOUR, {"social": 8, "stress": -3})
	a.adjust_relationship(b.id(), TALK_AFFINITY_GAIN)
	b.adjust_relationship(a.id(), TALK_AFFINITY_GAIN)
