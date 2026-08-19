class_name Rival
extends RefCounted
# THE OTHER CARTOGRAPHER (v22, Horizon 7 commit 3). Somebody else is working
# the same deep, and the player only ever meets the evidence: a cell already
# filed when they sell, a beacon in a livery that is not theirs. Nothing is
# ever seen moving. Nothing shoots. Nothing is taken that the player HAD —
# only the chance to have been first, which is a reason to fly further out,
# which is the game.
#
# A PURE FUNCTION, AND DELIBERATELY NOT A SAVE. The instinct is a stored
# rival-progress dict; the codebase's own instinct is better. The deep is a
# pure function of (system, cell, seed), and so is its rival: everything here
# derives from (cell key, depth, run_seed, played_seconds). Zero bytes of save,
# §17's "revisiting a sector costs zero bytes" untouched — and because
# played_seconds is the PLAYER'S own accumulated clock, the rival races
# exactly the person playing: pause the game for a month and nothing moves.
#
# A LEAF, like Profiles: this file references no other project class, so it can
# be called from deep_space.gd (which already reaches the GameState autoload)
# without adding any class-name edge at all. Everything it cannot know — depth,
# seed, clock — arrives as an argument, drop_beacon's rule: a function that is
# handed its facts can be handed a test case.

# When the rival starts filing at the charted edge, in played seconds. Half an
# hour: a brand-new pilot's first sortie is never pre-empted, and by the time
# the shallows start going the player has been taught what filing pays.
const BASE_S := 1800.0
# Seconds of rival progress per unit of depth, before jitter. The design bar
# this buys, measured by THE DEEP OUTRUNS THEM: at the band-4 floor (1100u)
# the EARLIEST possible arrival is 1800 + 66,000s ≈ 18.8 hours of play, so the
# deep belongs to a player who flies there for as long as anyone plays a run.
# The shallows go in single sessions, which is the near ring burning with a
# hand attached to it.
const S_PER_U := 60.0
# Jitter bounds. A flat front would let one found cell date every other cell
# at its depth — the same inference hyper_positions denies with independent
# depths — so each cell's arrival is stretched by [1, 3] from its own hash.
const JITTER_MIN := 1.0
const JITTER_MAX := 3.0
# THE STRIDE HOLDS THE WORLD STILL. The clock is quantised to ten-minute steps
# before any comparison, so two cell builds seconds apart — a colour-vision
# rebuild, STREAMTEST's synchronous-versus-amortised pass — cannot disagree
# about whether the rival has arrived. Within a stride the world is stable;
# progress happens between strides, like a tide coming in while you looked
# away, which is also the right fiction for somebody you never see.
const STRIDE_S := 600.0


static func arrival_seconds(key: String, depth: float, run_seed: int) -> float:
	# When the rival files this cell, in played seconds. Pure and total: any
	# key, any depth, one answer forever (given the seed).
	var u := float(absi(hash("rival|%s|%d" % [key, run_seed])) % 100000) / 100000.0
	var jitter := JITTER_MIN + (JITTER_MAX - JITTER_MIN) * u
	return BASE_S + maxf(depth, 0.0) * S_PER_U * jitter


static func filed(key: String, depth: float, run_seed: int, seconds: float) -> bool:
	return floorf(seconds / STRIDE_S) * STRIDE_S >= arrival_seconds(key, depth, run_seed)
