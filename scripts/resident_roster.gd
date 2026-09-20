class_name ResidentRoster
## L0 (Work Orders Layer 6): deterministic data for 20 residents -- names,
## appearance presets, and routine data. Pure data + validation, no runtime
## spawning changes: this card's own "done when" says so explicitly, and
## main.gd still only spawns S3/S4's one resident (Priya Nair). Scaling
## from 1 to 3/5/20 residents actually appearing is L1, a separate, later
## card ("profiled and stable" -- a performance/integration concern this
## card doesn't own).
##
## Only two of this slice's five locations are real employers (workplace,
## cafe) -- "one dense block, not a metropolis" per the Production Bible,
## not every resident having a distinct unique workplace. All 20 share the
## one Apartment building as home, the same way a real apartment building
## houses many residents -- the honest read of "one home location" in a
## five-location slice, not a data gap L0 needs to invent buildings to fix.

const NAMES := [
	"Priya Nair", "Theo Okonkwo", "Mireille Duval", "Sana Farooqi", "Jonas Lindgren",
	"Aiyana Whitehorse", "Marcus Belline", "Yuki Tanaka", "Delphine Roux", "Kwame Asante",
	"Ingrid Solberg", "Rafael Mendez", "Chidinma Eze", "Oskar Nowak", "Leilani Kahale",
	"Dimitri Volkov", "Amara Osei", "Fiona McAllister", "Tomasz Kaminski", "Zaria Bello",
]

const SEED := 20260920   # matches scripts/city_block.gd's own fixed seed


## Deterministic (fixed SEED, not re-rolled per call/run) so the roster is
## stable across sessions -- matters once L2+ actually saves relationships/
## memories that reference these people by their PersonProfile id. Index 0
## (Priya Nair) intentionally matches S3/S4's own new_resident() call
## exactly (same name/home/job), so the one resident already live in the
## city is index 0 of this roster, not a second, different Priya.
static func build() -> Array[PersonProfile]:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var roster: Array[PersonProfile] = []
	for i in NAMES.size():
		var job := "workplace" if i % 2 == 0 else "cafe"
		var p := PersonProfile.new_resident(NAMES[i], "apartment", job)
		for key in PersonProfile.APPEARANCE_OPTIONS:
			var options: Array = PersonProfile.APPEARANCE_OPTIONS[key]
			p.set_appearance(key, options[rng.randi() % options.size()])
		# Stagger routines for texture -- not everyone wakes, works, and
		# sleeps at the exact same hour -- without touching the home/job
		# split above.
		p.data["routine"]["wake_hour"] = 6 + rng.randi() % 3          # 6-8
		p.data["routine"]["work_start_hour"] = 8 + rng.randi() % 3    # 8-10
		p.data["routine"]["work_end_hour"] = 16 + rng.randi() % 3     # 16-18
		p.data["routine"]["sleep_hour"] = 21 + rng.randi() % 3        # 21-23
		p.revalidate()   # re-validate after the direct routine writes above
		roster.append(p)
	return roster
