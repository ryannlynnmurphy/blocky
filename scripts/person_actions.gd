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

## L4 (Work Orders Layer 6): a real, if still simple, daily economy.
## Residents earn DAILY_WAGE automatically (main.gd ties this to
## day_night.day_changed, S0's real day boundary, not a fake schedule) --
## unlike the player, who has no job yet (their own identity starts
## "Looking for work"; WORK_PAY above, from the workbench, is their income
## until a real employment status exists). DAILY_RENT applies to everyone
## with a home, player included -- "The Player's Apartment" (B3) already
## establishes the player lives there too. SHOP_FOOD_COST/HUNGER give money
## an actual sink (buying food at the cafe), not just a number that only
## ever goes up.
const DAILY_WAGE := 30
const DAILY_RENT := 15
const SHOP_FOOD_COST := 8
const SHOP_FOOD_HUNGER := 20

## L5 (Work Orders Layer 6): a small, simulation-driven consequence chain
## -- too much stress makes a resident miss their shift instead of a coin
## flip; enough missed shifts gets them fired; being fired stops payday()
## from paying them (below), so rent (which keeps charging regardless)
## creates real, ongoing money pressure with no scripted "and now they're
## broke" event needed -- it just falls out of mechanics that already
## exist. Every step is a plain threshold on real state, so the whole
## chain is explainable from a resident's own memories after the fact
## (this card's own "done when").
const MISSED_SHIFT_STRESS_THRESHOLD := 80
const SHIFTS_BEFORE_FIRING := 3
const FIRING_STRESS_SPIKE := 15


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
	# L3: both sides remember it happened -- "at_minutes" is what makes an
	# event still meaningfully inspectable long after (this card's own
	# acceptance), not just at the instant it occurred.
	var at: float = clock.total_minutes()
	a.add_memory({"type": "conversation", "with": b.id(), "with_name": b.display_name(), "at_minutes": at})
	b.add_memory({"type": "conversation", "with": a.id(), "with_name": a.display_name(), "at_minutes": at})


## L4: a resident's automatic daily wage -- called once per resident per
## day_night.day_changed (see main.gd), not a manual action like work().
## Recorded as a memory too: a payday is exactly the kind of "important
## event" L3's inspector should be able to show, and L5's consequence
## chains (a missed shift, a firing) will need a real payday history to
## reference against.
static func payday(clock: DayNight, profile: PersonProfile) -> void:
	if not profile.routine("employed"):
		return   # L5: fired -- no more automatic income; rent still runs, real money pressure
	profile.adjust_need("money", DAILY_WAGE)
	profile.add_memory({"type": "payday", "amount": DAILY_WAGE, "at_minutes": clock.total_minutes()})


## L4: daily rent for having a home -- applies to the player too (they
## live in the same Apartment building B3 named "The Player's Apartment").
## Deliberately does not block or refuse when money is already 0
## (PersonProfile.adjust_need() already keeps money non-negative, never
## letting it go below 0) -- L5's consequence chains are where a real
## "can't pay rent" event belongs, not this card, which only owns the flow
## itself existing and persisting.
static func charge_rent(clock: DayNight, profile: PersonProfile) -> void:
	profile.adjust_need("money", -DAILY_RENT)
	profile.add_memory({"type": "rent", "amount": -DAILY_RENT, "at_minutes": clock.total_minutes()})


## L4: a shop purchase at the cafe -- spends money for a real hunger
## restoration, the first genuine money *sink* (every other action so far
## only ever adds to it). Returns false (and changes nothing) if the buyer
## can't afford it, so a broke player/resident is honestly refused rather
## than going into debt a 0-floor "money" need can't actually represent.
static func buy_food(clock: DayNight, profile: PersonProfile) -> bool:
	if profile.need("money") < SHOP_FOOD_COST:
		return false
	apply_action(clock, profile, 5.0 / MINUTES_PER_HOUR, {"money": -SHOP_FOOD_COST, "hunger": SHOP_FOOD_HUNGER})
	return true


## L5: called instead of dispatching a resident to work (main.gd's
## _drive_all_city_residents(), right when ResidentRoutine.current_goal()
## would send them to their job) -- checks whether their own stress is too
## high to function. Returns true if the shift was actually missed (the
## caller should keep them home instead of routing to work this time);
## false means nothing changed and the normal dispatch should proceed.
## Already-unemployed residents have no shift left to miss.
static func maybe_miss_shift(clock: DayNight, profile: PersonProfile) -> bool:
	if not profile.routine("employed"):
		return false
	if profile.need("stress") < MISSED_SHIFT_STRESS_THRESHOLD:
		return false
	var streak: int = int(profile.routine("missed_shifts")) + 1
	profile.data["routine"]["missed_shifts"] = streak
	profile.add_memory({"type": "missed_shift", "streak": streak, "at_minutes": clock.total_minutes()})
	if streak >= SHIFTS_BEFORE_FIRING:
		_fire(clock, profile)
	return true


## L5: the end of the chain -- employed becomes false (payday() above
## stops paying them from here on), a real stress spike from the shock,
## and a memory recording exactly why (the streak that caused it), so the
## whole chain reads back as one explainable story afterward: missed
## shifts accumulating, then this, then declining money with rent still
## running and no more payday to offset it.
static func _fire(clock: DayNight, profile: PersonProfile) -> void:
	profile.data["routine"]["employed"] = false
	profile.adjust_need("stress", FIRING_STRESS_SPIKE)
	profile.add_memory({"type": "fired", "after_missed_shifts": profile.routine("missed_shifts"), "at_minutes": clock.total_minutes()})
