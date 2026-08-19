class_name Barks
extends Object
# Diegetic ship-AI lines used as onboarding. Each fires once ever (persisted in
# the save), so a returning player is never re-taught. There is no tutorial
# mode and no modal — the ship just tells you things.

const LINES := {
	"first_launch": "SURVEY VESSEL ONLINE — TAP A BEARING TO MOVE",
	"first_hostiles": "CONTACTS INBOUND — TAP A CONTACT TO ENGAGE",
	"first_kill": "SALVAGE ADRIFT — FLY THROUGH IT TO COLLECT",
	"refit_available": "SURPLUS SALVAGE — REFIT CONSOLE ONLINE",
	"first_breach_range": "DERELICT IN RANGE — HOLD ON THE BREACH POINT",
	"first_course": "COURSE LAID IN — HANDS OFF. I WILL DROP IT IF ANYTHING FINDS US",
	# v22. THE DEEP TEACHES ITSELF (Horizon 7 commit 5). The tutorial covers the
	# first hour and band 4 is where the interesting game lives; until these,
	# nothing between the two said a word about mechanics. One line per band,
	# once EVER (the bark contract), fired at the same threshold the band's own
	# broadcast fires -- the ship's AI reading the survey advisory over the
	# authority's shoulder. Each teaches exactly one thing the band actually
	# contains, and none names a gesture, so the manual's device sweep stays
	# clean on every input.
	"first_band_3": "THE REACHES — CONVOY LANES BELOW. THEY SHOOT BACK IN ORDER, NOT FIRST",
	"first_band_4": "THE QUIET — NESTS ARM AHEAD OF US NOW. A STRAIGHT LINE IS A CHOICE",
	"first_band_5": "THE FATHOMS — PAST THE COLONY NETWORK. FROM HERE, EVERY RETURN IS FLOWN",
	"first_band_6": "THE UNSOUNDED — NO INSTRUMENT SPAN, NO PATROLS, WEATHER. WE ARE THE RECORD NOW",
	# §92. The one line the ship says about the order, fired the moment
	# the pilot reads Directive 9 and never again. It answers the band-6 line
	# above -- "WE ARE THE RECORD NOW" was a boast about being past the
	# instruments; this is the same sentence after finding out why there are no
	# instruments. Nothing else in the world reacts, which is the point.
	"read_directive": "WE ARE STILL FILING. SOMEBODY SHOULD KNOW THAT WE ARE STILL FILING",
	"chart_unlocked": "NEW BEARING CHARTED — OPEN THE CHART",
	"first_warp": "TRANSIT COMPLETE — UNFAMILIAR SPACE",
	"apex_out_of_range": "SHOTS BREAKING ON THE SURVEY FIELD — CLOSE IN",
	"first_dock_range": "DOCKING CLAMPS AVAILABLE — TAP THE PORT",
	"first_docked": "CLAMPED ON. NOTHING REACHES YOU HERE",
	"first_trade": "CARGO IS WORTH WHAT THE NEXT PORT WILL PAY",
	"first_salvage": "UNREADABLE SALVAGE ABOARD — REFIT CAN READ WHAT YOU KNOW",
	"hold_full": "HOLD AT CAPACITY — CRATES ARE BEING SCRAPPED",
}

# THE SAME LINES, FOR A DEVICE THAT CANNOT TAP. Only the three that name a
# GESTURE differ -- everything else above is device-neutral and stays in one
# place, so this table can never drift into a second copy of the script.
#
# The ship's very first sentence used to tell a desktop player to tap a bearing,
# on a build where mouse-to-touch emulation is deliberately OFF (see
# project.godot) and tapping does nothing at all. Tutorial._touch and
# ManualScreen._build_flying have both branched on the device since they
# shipped; this table is the third and last place that had to.
#
# "HOLD ON THE BREACH POINT" is deliberately NOT here: CameraRig runs
# _try_begin_hold on the mouse path too, so a hold is one verb on both families
# and a second wording would be a lie in the other direction.
#
# THE KEYS ARE TOKENS, not letters. A const cannot call anything, so the two
# lines that name keys carry {MOVE} and {TARGET} and line_for fills them from
# the live InputMap -- the same source the manual and the tutorial read. Spelled
# out here they were false for any player who had used the rebinding page, and
# this is the first sentence the ship ever says.
const DESK_LINES := {
	"first_launch": "SURVEY VESSEL ONLINE — HOLD {MOVE} TO FLY",
	"first_hostiles": "CONTACTS INBOUND — CLICK A CONTACT TO ENGAGE, OR {TARGET}",
	"first_dock_range": "DOCKING CLAMPS AVAILABLE — CLICK THE PORT",
}

const HOLD_TIME := 3.2


static func begin(tree_node: Node) -> void:
	# Slight delay so the line lands after the scene settles in.
	tree_node.get_tree().create_timer(1.2).timeout.connect(func() -> void:
		fire("first_launch")
	)


static func fire(key: String) -> void:
	if not LINES.has(key) or GameState.has_seen_bark(key):
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	# NOT OVER A LIVE DEMAND (v18, playtest round 4). A bark writes straight to
	# the same prompt label the parley uses, so `first_hostiles` firing on the
	# raiders that just arrived replaced the sentence explaining the plates —
	# with the plates still on the screen and nothing left saying what they were.
	# The first raid a player ever meets is exactly when that bark is still
	# unfired, so this landed on the pilot least able to guess.
	#
	# BEFORE mark_bark, which is the whole reason this is not one line higher.
	# Marking and then declining to show it would spend an onboarding line the
	# player never saw — a bark that fires once ever must not be consumed by
	# being suppressed. Deferred, not cancelled: the next hostiles get it.
	var m := tree.get_first_node_in_group("main")
	if m != null and m.has_method("parley_live") and m.parley_live():
		return
	GameState.mark_bark(key)
	var hud := tree.get_first_node_in_group("hud")
	if hud == null or not hud.has_method("prompt"):
		return
	var text := line_for(key)
	hud.prompt(text)
	# `text` is captured by value, which is what makes the clear match the
	# line that was actually shown rather than re-resolving it later.
	tree.create_timer(HOLD_TIME).timeout.connect(func() -> void:
		var h := tree.get_first_node_in_group("hud")
		if h and h.has_method("clear_prompt_if"):
			h.clear_prompt_if(text)
	)


static func line_for(key: String) -> String:
	# The line this DEVICE gets. Public so the harness can sweep every key for
	# a gesture the player cannot perform, rather than testing the one line
	# somebody remembered to check.
	if not DisplayServer.is_touchscreen_available() and DESK_LINES.has(key):
		return _fill_keys(String(DESK_LINES[key]))
	return String(LINES.get(key, ""))


static func _fill_keys(line: String) -> String:
	# Only the desktop table has tokens, and only these two. Kept a plain
	# replace rather than a format map because a missing token must leave the
	# sentence readable rather than throw -- a bark is the one surface with no
	# second chance to say the thing.
	if line.contains("{MOVE}"):
		line = line.replace("{MOVE}", "%s %s %s %s" % [
			GameState.binding_name("move_up"), GameState.binding_name("move_left"),
			GameState.binding_name("move_down"), GameState.binding_name("move_right")])
	if line.contains("{TARGET}"):
		line = line.replace("{TARGET}", GameState.binding_name("cycle_target"))
	return line
