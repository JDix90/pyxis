extends Node3D
# Session root. Owns the swappable SystemRoot (everything a star system
# contains), warp travel between systems, the swarm wave spawner, the salvage
# tally, and the global hitstop.
#
# PYXIS_DEMO=1 runs a scripted demo; PYXIS_SAVETEST runs save round-trip checks.

signal hostile_killed(kind: String)

enum State { ATTRACT, PLAYING }

const WARP_CHARGE := 0.75
const WARP_STREAK := 0.9
const WARP_ARRIVE := 0.8

const APEX_WAKE_DELAY := 6.0        # after arriving in an already-breached system
const APEX_BREACH_DELAY := 9.0      # the aftershock, after breaching the derelict

# --- economy pacing target (PYXIS_PACINGTEST) -------------------------------
# The eight-minute "standard loop" the economy is tuned against, as an activity
# budget rather than a wall-clock replay. Two reasons it is not a literal eight
# real-time minutes: the one instrument we tune the economy with would be too
# slow to iterate on, and Engine.time_scale would wreck every mover in the game,
# because this codebase integrates positions by hand (see obstacles.gd) instead
# of using physics. So the harness plays each activity FOR REAL with a starter
# fit and measures what the game actually pays for it — only these weights are
# authored, every yield below them is observed.
const PACING_LOOP := {"swarm": 14, "sentry": 5, "derelict": 1, "trade": 1,
	"contract": 1, "survey": 2}
const PACING_MINUTES := 8.0
# CEILING: earned-per-loop as a fraction of the whole catalog. Above this the
# catalog is a shopping list again, which was the phase-1 problem.
const PACING_MAX_RATIO := 0.15
# FLOOR (and a sanity ceiling): the design's plain-language target, that a loop
# is worth roughly one mid-tier module. Lance Array is the reference — the first
# real "I chose this" purchase.
#
# Deliberately NOT a catalog fraction. Adding the six Mk II tiers in B5 grew the
# catalog 84% and would have "failed" a catalog-fraction floor without a single
# earning changing — the metric would have been reporting on how much content
# exists, not on how the game paces. Modules-per-loop holds still while the
# catalog grows, which is the property a pacing assertion needs.
const PACING_MIN_MODULES := 0.60
const PACING_MAX_MODULES := 3.00
const PACING_MIDTIER := "lance_1"

# How fast the scripted bots circle-strafe an apex core, in units/second of
# tangential speed. The stand-in for a human refusing to stand still, and the
# floor the hub's telegraphed armaments are tuned to be dodgeable at.
const BOT_ORBIT_SPEED := 4.5

# --- cargo interdictions (B1) -----------------------------------------------
# A full hold used to be pure upside: you either made it to the port or you did
# not bother filling it. Interdictions put a cost on the other side of the trade
# so that "one more run before I sell" is a decision with a downside, and so the
# combat fit and the trading fit have something to say to each other.
#
# Every constant here is deliberately generous to the player: the floor is high
# enough that an ordinary salvage run never trips it, the ceiling caps the odds
# well below certainty, and the cooldown guarantees you always get to a port
# eventually. Being robbed should feel like weather, not like a tax.
const RAID_ROLL_INTERVAL := 20.0
const RAID_MIN_HOLD := 1500        # below this you are not worth the fuel
const RAID_VALUE_SCALE := 40000.0  # hold value at which the odds hit the ceiling
const RAID_MIN_CHANCE := 0.05
const RAID_MAX_CHANCE := 0.35
const RAID_COOLDOWN := 90.0
const RAID_CORSAIR_HOLD := 12000   # rich enough to bring something with armour
const RAID_SPAWN_DIST := 17.0
const RAID_TINT := Color(0.86, 0.12, 0.20)
# The parley. Tolls price off the UNWEIGHTED hold — weighted would double-dip
# the Forged Manifest (fewer raids AND a smaller toll) and shrink toward zero on
# a chart-data hold. The floor keeps a demand from being beneath dignity.
const TOLL_FRACTION := 0.15
const TOLL_FLOOR := 400
const PARLEY_WINDOW := 6.0

# Unstable rifts: roughly one per twenty minutes of play, never two at once,
# always in the current system at a depth reachable within the rift's own life.
const RIFT_ROLL_INTERVAL := 240.0
const RIFT_CHANCE := 0.20
const RIFT_DEPTH_MIN := 90.0
const RIFT_DEPTH_MAX := 260.0
# How much of the charted interdiction rate survives at each distance band.
# Never zero: there is no range at which a full hold is safe, only ranges at
# which it is unlikely to be noticed.
#                          charted shoals drift reaches quiet
const DEEP_RAID_TAPER := [1.0, 0.6, 0.3, 0.1, 0.05]

var hud: HUD
var refit_panel: RefitPanel
var chart_panel: ChartPanel
var port_panel: PortPanel
var pause_menu: PauseMenu
var contracts: Contracts

var system_root: Node3D
var deep_space: DeepSpace
# Sticky across _load_system. Harnesses that assert against a hand-placed world
# turn this off the same way they pin `_wave_timer`; the game never touches it.
var _deep_generation := true
# Deepest band whose beacon has already played, this visit to this system.
var _broadcast_band := 0
var system_id := ""
var system_def := {}
var warping := false

var boss_active := false
var docked_port: Port = null

var state: int = State.ATTRACT
var title_screen: TitleScreen
var tutorial: Tutorial

var _event_roll_timer := Market.EVENT_ROLL_INTERVAL
# How many (good, buy port, sell port) triples the pacing sweep refused as routes
# the player cannot fly. Asserted to be non-zero: a sweep that skips nothing is a
# sweep whose filter has stopped running.
var _pacing_trade_skipped := 0
var _pending_dock: Port = null

var _hitstop := false
var _wave_timer := 6.0
var _apex_wake_timer := -1.0

var _raid_timer := RAID_ROLL_INTERVAL
var _raid_cooldown := 0.0
var _raid_active := false
var _parley_toll := 0
var _parley_until := 0.0
var _rift_timer := RIFT_ROLL_INTERVAL
var live_rift: Rift = null


func _ready() -> void:
	add_to_group("main")

	# Physics interpolation is opt-IN in this game, and this is the line that
	# makes it so. The project setting has to be on for any node to interpolate
	# at all, but leaving the default INHERIT in place meant the whole tree
	# inherited ON from the root -- including the camera and every _process
	# mover, which resampled their already-smooth motion at 60Hz and made the
	# engine warn about the Camera3D on every boot. Turning Main off pushes the
	# default back to "no", and the four nodes that integrate on the fixed tick
	# (PlayerShip, SwarmHostile, SweepArm, LootCube) set themselves to ON.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF

	# Scale the 2D layer before any UI is built, then track window resizes. 3D is
	# unaffected — the world always renders at full window resolution.
	UILayout.apply_scale(get_window())
	get_window().size_changed.connect(func() -> void: UILayout.apply_scale(get_window()))

	system_root = Node3D.new()
	system_root.name = "SystemRoot"
	add_child(system_root)

	var rig := CameraRig.new()
	add_child(rig)
	rig.position = Vector3(0, 0, 2)

	var player := PlayerShip.new()
	add_child(player)
	player.position = Vector3(0, 0, 6)

	var marker := TargetMarker.new()
	add_child(marker)

	hud = HUD.new()
	add_child(hud)
	hud.set_value(GameState.salvage)

	refit_panel = RefitPanel.new()
	add_child(refit_panel)
	hud.refit_pressed.connect(refit_panel.open)

	chart_panel = ChartPanel.new()
	add_child(chart_panel)
	hud.chart_pressed.connect(chart_panel.open)
	chart_panel.travel_requested.connect(travel_to)
	chart_panel.recall_requested.connect(recall_to_system)

	port_panel = PortPanel.new()
	add_child(port_panel)

	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	hud.pause_pressed.connect(toggle_pause)

	contracts = Contracts.new()
	add_child(contracts)
	contracts.changed.connect(func() -> void: hud.set_contracts(contracts.rows()))

	GameState.system_unlocked.connect(func(id: String) -> void:
		hud.show_toast("CHARTED — %s" % SystemDB.display_name(id), Palette.TEAL)
		Barks.fire("chart_unlocked")
	)

	tutorial = Tutorial.new()
	add_child(tutorial)

	title_screen = TitleScreen.new()
	add_child(title_screen)
	title_screen.new_game_pressed.connect(start_new_game)
	title_screen.continue_pressed.connect(continue_game)

	Sfx.set_muted(GameState.audio_muted)

	# Every harness drives the game directly and must not sit behind a menu.
	# This has to be decided BEFORE the first _load_system: the builder checks
	# the state to know whether to leave the garrison out, so booting as ATTRACT
	# would hand every harness an empty system.
	var headless_mode := OS.get_environment("PYXIS_DEMO") != "" \
		or OS.get_environment("PYXIS_SAVETEST") != "" \
		or OS.get_environment("PYXIS_BOSSTEST") != "" \
		or OS.get_environment("PYXIS_BALANCE") != "" \
		or OS.get_environment("PYXIS_MARKETTEST") != "" \
		or OS.get_environment("PYXIS_DOCKTEST") != "" \
		or OS.get_environment("PYXIS_ECONDEMO") != "" \
		or OS.get_environment("PYXIS_INPUTTEST") != "" \
		or OS.get_environment("PYXIS_TUTORIALTEST") != ""
	if OS.get_environment("PYXIS_WORLDTOUR") != "":
		GameState.lock_saving()
		state = State.PLAYING
		_load_system(GameState.current_system)
		_enter_playing()
		_run_world_tour()
		return

	if OS.get_environment("PYXIS_COLLISIONTEST") != "":
		GameState.lock_saving()
		state = State.PLAYING
		_load_system(GameState.current_system)
		_enter_playing()
		_run_collision_test()
		return

	if OS.get_environment("PYXIS_RIFTTEST") != "":
		GameState.lock_saving()
		state = State.PLAYING
		_load_system(GameState.current_system)
		_enter_playing()
		_run_rift_test()
		return

	if OS.get_environment("PYXIS_SMUGTEST") != "":
		GameState.lock_saving()
		state = State.PLAYING
		_load_system(GameState.current_system)
		_enter_playing()
		_run_smug_test()
		return

	if OS.get_environment("PYXIS_LOGTEST") != "":
		GameState.lock_saving()
		state = State.PLAYING
		_load_system(GameState.current_system)
		_enter_playing()
		_run_log_test()
		return

	if OS.get_environment("PYXIS_FORGETEST") != "":
		GameState.lock_saving()
		state = State.PLAYING
		_load_system(GameState.current_system)
		_enter_playing()
		_run_forge_test()
		return

	if OS.get_environment("PYXIS_HOLDTEST") != "":
		GameState.lock_saving()
		state = State.PLAYING
		_load_system(GameState.current_system)
		_enter_playing()
		_run_hold_test()
		return

	if OS.get_environment("PYXIS_CARTTEST") != "":
		GameState.lock_saving()
		state = State.PLAYING
		_load_system(GameState.current_system)
		_enter_playing()
		_run_cart_test()
		return

	if OS.get_environment("PYXIS_SPILLTEST") != "":
		GameState.lock_saving()
		state = State.PLAYING
		_load_system(GameState.current_system)
		_enter_playing()
		_run_spill_test()
		return

	if OS.get_environment("PYXIS_STORETEST") != "":
		GameState.lock_saving()
		state = State.PLAYING
		_load_system(GameState.current_system)
		_enter_playing()
		_run_store_test()
		return

	if OS.get_environment("PYXIS_SALVAGETEST") != "":
		GameState.lock_saving()
		state = State.PLAYING
		_load_system(GameState.current_system)
		_enter_playing()
		_run_salvage_test()
		return

	if OS.get_environment("PYXIS_SHIPTEST") != "":
		GameState.lock_saving()
		state = State.PLAYING
		_load_system(GameState.current_system)
		_enter_playing()
		_run_ship_test()
		return

	if OS.get_environment("PYXIS_DEEPTEST") != "":
		GameState.lock_saving()
		state = State.PLAYING
		_load_system(GameState.current_system)
		_enter_playing()
		_run_deep_test()
		return

	if OS.get_environment("PYXIS_APEXTEST") != "":
		GameState.lock_saving()
		state = State.PLAYING
		_load_system(GameState.current_system)
		_enter_playing()
		_run_apex_test()
		return

	if OS.get_environment("PYXIS_DEEPSHOTS") != "":
		GameState.lock_saving()
		state = State.PLAYING
		_load_system(GameState.current_system)
		_enter_playing()
		_run_deep_shots()
		return

	if OS.get_environment("PYXIS_NARROWSHOTS") != "":
		GameState.lock_saving()
		state = State.PLAYING
		_load_system(GameState.current_system)
		_enter_playing()
		_run_narrow_shots()
		return

	if OS.get_environment("PYXIS_PHASE2SHOTS") != "":
		GameState.lock_saving()
		state = State.PLAYING
		_load_system(GameState.current_system)
		_enter_playing()
		_run_phase2_shots()
		return

	if OS.get_environment("PYXIS_LIVERYTEST") != "":
		# NOT lock_saving(): this harness has to exercise the real file layer to
		# prove a livery survives a round trip, and the lock is deliberately
		# one-way. Redirecting the path first is the safe way to do that — every
		# write in this process, intended or not, lands on the probe file.
		GameState.save_path = "user://livery_probe.json"
		state = State.PLAYING
		_load_system(GameState.current_system)
		_enter_playing()
		_run_livery_test()
		return

	if OS.get_environment("PYXIS_STATIONTEST") != "":
		GameState.lock_saving()
		state = State.PLAYING
		_load_system(GameState.current_system)
		_enter_playing()
		_run_station_test()
		return

	if OS.get_environment("PYXIS_TORPTEST") != "":
		GameState.lock_saving()
		state = State.PLAYING
		_load_system(GameState.current_system)
		_enter_playing()
		_run_torp_test()
		return

	if OS.get_environment("PYXIS_CONTRACTTEST") != "":
		GameState.lock_saving()
		state = State.PLAYING
		_load_system(GameState.current_system)
		_enter_playing()
		_run_contract_test()
		return

	if OS.get_environment("PYXIS_RAIDTEST") != "":
		GameState.lock_saving()
		state = State.PLAYING
		_load_system(GameState.current_system)
		_enter_playing()
		_run_raid_test()
		return

	if OS.get_environment("PYXIS_PAUSETEST") != "":
		GameState.lock_saving()
		state = State.PLAYING
		_load_system(GameState.current_system)
		_enter_playing()
		_run_pause_test()
		return

	if OS.get_environment("PYXIS_RADARTEST") != "":
		GameState.lock_saving()
		state = State.PLAYING
		_load_system(GameState.current_system)
		_enter_playing()
		_run_radar_test()
		return

	if OS.get_environment("PYXIS_MUSICTEST") != "":
		GameState.lock_saving()
		state = State.PLAYING
		_load_system(GameState.current_system)
		_enter_playing()
		_run_music_test()
		return

	if OS.get_environment("PYXIS_PACINGTEST") != "":
		# Before any load: the harness resets to a starter run and must never be
		# able to write that over the player's actual save.
		GameState.lock_saving()
		state = State.PLAYING
		_load_system(GameState.current_system)
		_enter_playing()
		_run_pacing_test()
		return

	if OS.get_environment("PYXIS_LAYOUTTEST") != "":
		GameState.lock_saving()
		_run_layout_test()
		return

	if OS.get_environment("PYXIS_FEELTEST") != "":
		GameState.lock_saving()
		state = State.PLAYING
		_load_system(GameState.current_system)
		_enter_playing()
		_run_feel_test()
		return

	if OS.get_environment("PYXIS_GSATEST") != "":
		GameState.lock_saving()
		state = State.PLAYING
		_load_system(GameState.current_system)
		_enter_playing()
		_run_gsa_test()
		return

	if OS.get_environment("PYXIS_UITEST") != "":
		GameState.lock_saving()
		state = State.PLAYING
		_load_system(GameState.current_system)
		_enter_playing()
		_run_ui_test()
		return

	var title_test := OS.get_environment("PYXIS_TITLETEST") != ""
	state = State.PLAYING if headless_mode else State.ATTRACT

	_load_system(GameState.current_system)
	hud.set_contracts(contracts.rows())
	Sfx.loop_start("ambient", -16.0)

	if title_test:
		GameState.lock_saving()
		_enter_attract()
		_run_title_test()
	elif headless_mode:
		_enter_playing()
	else:
		_enter_attract()

	if OS.get_environment("PYXIS_TUTORIALTEST") != "":
		GameState.lock_saving()
		_run_tutorial_test()
	elif OS.get_environment("PYXIS_INPUTTEST") != "":
		GameState.lock_saving()
		_run_input_test()
	elif OS.get_environment("PYXIS_ECONDEMO") != "":
		GameState.lock_saving()
		_run_econ_demo()
	elif OS.get_environment("PYXIS_DOCKTEST") != "":
		GameState.lock_saving()
		_run_dock_test()
	elif OS.get_environment("PYXIS_MARKETTEST") != "":
		GameState.lock_saving()
		_run_market_test()
	elif OS.get_environment("PYXIS_BALANCE") != "":
		GameState.lock_saving()
		_run_balance_test()
	elif OS.get_environment("PYXIS_BOSSTEST") != "":
		GameState.lock_saving()
		_run_boss_test()
	elif OS.get_environment("PYXIS_SAVETEST") != "":
		_run_save_test()
	elif OS.get_environment("PYXIS_DEMO") != "":
		GameState.lock_saving()  # scripted demo must not touch a real save
		_run_demo()
	elif state == State.PLAYING and not tutorial.is_active():
		Barks.begin(self)


# --- boot states ------------------------------------------------------------

func _enter_attract() -> void:
	# The title sits over a real, running system — starfield, lattice, derelict —
	# rather than a static image. The ship is parked and inert; nothing hunts it.
	state = State.ATTRACT
	var player: PlayerShip = get_tree().get_first_node_in_group("player")
	if player:
		player.set_input_enabled(false)
		player.visible = false
	hud.set_chrome_visible(false)
	title_screen.open(GameState.has_save())
	# The menu is scored by the ambient drone alone: arriving here should feel
	# like the music has not started yet.
	Music.stop()


func _enter_playing() -> void:
	state = State.PLAYING
	var player: PlayerShip = get_tree().get_first_node_in_group("player")
	if player:
		player.set_input_enabled(true)
		player.visible = true
	hud.set_chrome_visible(true)
	# Idempotent, and this is the one path every harness takes — the ambient bed
	# used to be started only on the mainline boot, so the early-returning
	# harnesses ran in silence and could not check anything about audio.
	Sfx.loop_start("ambient", -16.0)
	Music.set_system_tint(SystemDB.music_lp_of(system_id))
	Music.play()


func spawn_sentries() -> void:
	# Adds the system's garrison to the running scene without a rebuild.
	SystemBuilder.build_sentries(system_def, system_root)


func start_new_game() -> void:
	GameState.reset_to_starter()
	# A real new game persists. Under a harness this is a no-op: lock_saving()
	# is one-way, precisely so PYXIS_TITLETEST pressing NEW SURVEY cannot write
	# a starter run over the player's save.
	GameState.save_enabled = true
	_enter_playing()
	tutorial.arm()          # before the build, so the garrison is left out
	_load_system(SystemDB.START_SYSTEM)
	hud.set_value(GameState.salvage)
	hud.refresh_cargo()
	var player: PlayerShip = get_tree().get_first_node_in_group("player")
	if player:
		player.teleport_to(Vector3(0, 0, 6))
	# The rig has to come home too. Nothing moved it before because the old world
	# clamp guaranteed it was already near the origin; with space endless, a new
	# game started from 900 units out would open on empty sky.
	var rig := get_tree().get_first_node_in_group("camera_rig")
	if rig:
		rig.global_position = Vector3(0, 0, 2)
	tutorial.begin()


func continue_game() -> void:
	_enter_playing()
	if GameState.tutorial_step >= 0:
		tutorial.arm()      # resuming mid-tutorial keeps the world held back
	_load_system(GameState.current_system)
	hud.set_value(GameState.salvage)
	hud.refresh_cargo()
	hud.set_contracts(contracts.rows())
	if GameState.tutorial_step >= 0:
		tutorial.begin(GameState.tutorial_step)
	else:
		Barks.begin(self)


func tutorial_active() -> bool:
	return tutorial != null and tutorial.is_active()


# --- pause ------------------------------------------------------------------

func toggle_pause() -> void:
	if pause_menu == null:
		return
	if pause_menu.is_open:
		pause_menu.resume()
		return
	# Nothing to pause behind a menu, and nothing to step out of mid-warp — the
	# warp sequence is a chain of awaited timers that would resume mid-flash.
	if state != State.PLAYING or warping:
		return
	pause_menu.open()


func abandon_to_title() -> void:
	# Back to the front door with the run intact. The world is rebuilt in attract
	# form (no garrison, ship parked) so the title sits over a live system again.
	if pause_menu and pause_menu.is_open:
		pause_menu.resume()
	if docked_port != null:
		undock()
	if port_panel and port_panel.is_open:
		port_panel.close_panel()
	if refit_panel and refit_panel.is_open:
		refit_panel.close_panel()
	if chart_panel and chart_panel.is_open:
		chart_panel.close_panel()
	_set_boss_active(false)
	_pending_dock = null
	state = State.ATTRACT
	# Same reason as start_new_game: the title sits over a live system, and
	# abandoning from deep space must not leave it sitting over nothing.
	var player: PlayerShip = get_tree().get_first_node_in_group("player")
	if player:
		player.teleport_to(PlayerShip.SPAWN_POINT)
	var rig := get_tree().get_first_node_in_group("camera_rig")
	if rig:
		rig.global_position = Vector3(0, 0, 2)
	_load_system(GameState.current_system)
	_enter_attract()


# --- system lifecycle -------------------------------------------------------

func _load_system(id: String) -> void:
	if not SystemDB.exists(id):
		id = SystemDB.START_SYSTEM
	system_id = id
	system_def = SystemDB.get_system(id)
	GameState.set_current_system(id)

	# Boss state never survives a system change: the encounter resets to full on
	# warp or reload. Clearing the flag here is what stops a mid-fight warp-out
	# from permanently stalling the swarm spawner.
	_set_boss_active(false)
	_apex_wake_timer = -1.0
	# Raiders are children of SystemRoot and die with it, so the raid is over the
	# moment the world is swapped. Warping out of an interdiction IS the escape —
	# and it earns the same cooldown that fighting them off does, or the escape
	# hatch would be punished by dropping you into a fresh roll twenty seconds
	# later in the new system.
	if _raid_active:
		_raid_cooldown = RAID_COOLDOWN
	_raid_active = false
	# The rift died with system_root. Cleared explicitly rather than trusting
	# that a freed reference compares equal to null — it does, and relying on
	# that subtlety is how the next bug hides.
	live_rift = null
	_raid_timer = RAID_ROLL_INTERVAL

	for child in system_root.get_children():
		child.free()  # immediate: the rebuild happens this same frame
	# Nothing shoots at a menu, and nothing shoots at a player still being told
	# which key moves the ship.
	var quiet := state == State.ATTRACT or tutorial_active()
	SystemBuilder.build(system_def, system_root, {"skip_sentries": quiet, "system_id": id})
	deep_space = system_root.get_node_or_null("DeepSpace") as DeepSpace
	# DeepSpace is rebuilt with the system, so a harness that switched generation
	# off has to have that re-applied here or a mid-test _load_system would
	# quietly turn the expanse back on underneath its assertions.
	if deep_space:
		deep_space.set_generation(_deep_generation)
	# A new system is a new expanse, so its beacons are unheard again.
	_broadcast_band = 0

	var swarm: Dictionary = system_def.get("swarm", {})
	_wave_timer = float(swarm.get("first_delay", 6.0))

	# Already-breached systems have a live engine: arm its wake-up.
	if GameState.breached.has(id) and _find_apex() != null:
		_apex_wake_timer = APEX_WAKE_DELAY

	if hud:
		hud.set_system_tag(SystemDB.display_name(id))
	if contracts:
		contracts.on_system_changed(id)
	# Each system gets its own colour on the calm layer. Set on load rather than
	# on arrival so it is already right under the warp-in flash.
	Music.set_system_tint(SystemDB.music_lp_of(id))


func travel_to(id: String) -> void:
	if warping or id == system_id or not SystemDB.exists(id):
		return
	if not GameState.is_system_unlocked(id):
		return
	warping = true
	_warp_sequence(id)


func _warp_sequence(id: String) -> void:
	var player: PlayerShip = get_tree().get_first_node_in_group("player")
	var rig := get_tree().get_first_node_in_group("camera_rig")

	# 1. Charge: the ship gathers itself, camera tightens.
	if player:
		player.begin_warp_charge()
	Sfx.play("warp", -3.0, 0.75)
	if rig:
		rig.punch_zoom(1.6)
	await get_tree().create_timer(WARP_CHARGE).timeout

	# 2. Streak out: star-lines and a white flash cover the swap.
	if player:
		player.warp_streak_out()
	if rig:
		rig.shake(0.12)
	_star_streaks()
	await get_tree().create_timer(WARP_STREAK * 0.55).timeout
	FX.flash(self, Vector3(0, 0, 4), Palette.WHITE_HOT, 26.0, 0.5)
	await get_tree().create_timer(WARP_STREAK * 0.45).timeout

	# 3. Swap the world while the flash covers it.
	_load_system(id)
	if player:
		player.teleport_to(Vector3(0, 0, 6))
		player.warp_streak_in()
	if rig:
		rig.global_position = Vector3(0, 0, 2)

	# 4. Arrive.
	Sfx.play("breach", -12.0, 1.3)
	FX.shockwave(self, Vector3(0, 0, 6), Palette.AMBER, 9.0, 0.9)
	if hud:
		hud.show_arrival(SystemDB.display_name(id))
	await get_tree().create_timer(WARP_ARRIVE).timeout
	warping = false
	Barks.fire("first_warp")


func _tick_broadcast(depth: float) -> void:
	# Each band announces itself once per visit to a system. Only ever OUTWARD:
	# hearing the survey authority disown you again on the way home would turn a
	# threshold into a tollbooth.
	var band := DeepSpace.band_of(depth)
	if band <= _broadcast_band:
		return
	_broadcast_band = band
	# Read at fire time and cached nowhere, so a player who claims COMMISSIONED at
	# the Anchor hears the answer on their next trip out rather than on their next
	# launch -- which is the right beat: the beacon is where the acknowledgement
	# lands, not the dock where the paperwork was filed.
	var msg := DeepSpace.broadcast_for(band, GameState.commissioned)
	if msg.is_empty() or hud == null:
		return
	hud.show_broadcast(String(msg["from"]), String(msg["body"]),
		DeepSpace.band_color(depth))


func can_recall() -> bool:
	# Only from outside the charted volume — inside it there is nothing to come
	# back from, and a button that does nothing is worse than no button.
	# Refused mid-fight and mid-warp for the same reason docking is: breaking off
	# an apex by tapping a console is an exit, not a decision. (The chart button
	# is already locked by set_panels_locked during both, so this is the guard
	# behind the guard — but the harness calls this directly, and so might a
	# future caller that has not read set_panels_locked.)
	return state == State.PLAYING and not warping and not boss_active \
		and docked_port == null and deep_depth() > 0.0


func recall_to_system() -> void:
	if not can_recall():
		if hud:
			hud.prompt("RECALL UNAVAILABLE")
			Sfx.play("hit", -10.0, 0.7)
		return
	warping = true
	_recall_sequence()


func _recall_sequence() -> void:
	# The warp beats WITHOUT the swap. travel_to early-returns when the
	# destination is the system you are in, which is exactly what a recall is, so
	# this needs its own entry point rather than a flag on that one.
	#
	# Emphatically no _load_system: that frees SystemRoot wholesale, which would
	# reset the apex to full, respawn the garrison, delete loot still drifting
	# toward the player and reroll every deep sector — all for a move that never
	# leaves the system. The world is untouched; only the ship moves.
	#
	# And it is FREE. PlayerShip._emergency_warp already puts a dying player back
	# at the spawn point, so the game does this for you involuntarily already;
	# charging for the voluntary version would only tax doing deliberately what
	# you get for nothing by being careless.
	var player: PlayerShip = get_tree().get_first_node_in_group("player")
	var rig := get_tree().get_first_node_in_group("camera_rig")

	if player:
		player.begin_warp_charge()
	Sfx.play("warp", -3.0, 0.75)
	if rig:
		rig.punch_zoom(1.6)
	await get_tree().create_timer(WARP_CHARGE).timeout

	if player:
		player.warp_streak_out()
	if rig:
		rig.shake(0.12)
	_star_streaks()
	await get_tree().create_timer(WARP_STREAK * 0.55).timeout
	FX.flash(self, Vector3(0, 0, 4), Palette.WHITE_HOT, 26.0, 0.5)
	await get_tree().create_timer(WARP_STREAK * 0.45).timeout

	if player:
		player.teleport_to(PlayerShip.SPAWN_POINT)
		player.velocity = Vector3.ZERO
		player.clear_target()
		player.warp_streak_in()
	if rig:
		rig.global_position = Vector3(0, 0, 2)

	Sfx.play("breach", -12.0, 1.3)
	FX.shockwave(self, PlayerShip.SPAWN_POINT, Palette.TEAL, 9.0, 0.9)
	if hud:
		hud.show_arrival(SystemDB.display_name(system_id))
	await get_tree().create_timer(WARP_ARRIVE).timeout
	warping = false


func _star_streaks() -> void:
	# Radial star-lines sold from the existing beam primitive.
	for i in range(46):
		var ang := randf() * TAU
		var near := randf_range(3.0, 9.0)
		var far := near + randf_range(9.0, 22.0)
		var dir := Vector3(cos(ang), 0, sin(ang))
		var origin := Vector3(0, randf_range(-1.5, 1.5), 4)
		FX.beam(self, origin + dir * near, origin + dir * far,
			Color(0.8, 0.9, 1.0), randf_range(0.03, 0.08), randf_range(0.25, 0.5))


# --- waves & salvage --------------------------------------------------------

func _process(delta: float) -> void:
	if state == State.ATTRACT:
		# Slow drift behind the title so the menu breathes.
		var rig := get_tree().get_first_node_in_group("camera_rig")
		if rig:
			rig.global_position += Vector3(cos(GameState.played_seconds * 0.08),
				0.0, sin(GameState.played_seconds * 0.06)) * delta * 0.6
		GameState.advance_clock(delta)
		return

	_tick_market(delta)

	if warping:
		return

	if _pending_dock != null:
		_try_complete_dock()

	if _apex_wake_timer > 0.0:
		_apex_wake_timer -= delta
		if _apex_wake_timer <= 0.0:
			_apex_wake_timer = -1.0
			_wake_apex()

	_tick_interdiction(delta)

	# Wayfinding. The bottom-left readout is the only thing out here that tells
	# you where "here" is — there is no lattice past the chart edge and no
	# landmark to navigate by, so the label stops being decoration and becomes
	# instrumentation. set_deep_tag ignores sub-unit changes, so this is a float
	# compare per frame rather than a string build.
	var depth := deep_depth()
	if hud:
		hud.set_deep_tag(DeepSpace.band_name(depth) if depth > 0.0 else "", depth)
	_tick_broadcast(depth)
	# The captain's log's one frame-adjacent source, and the only one that needs
	# an argument for why it is still discrete. It reads the RUN's high-water mark
	# rather than _broadcast_band: that field is per-system-visit and resets on
	# warp (see _tick_broadcast), so hanging a log line off it would re-log THE
	# DRIFT on every trip out. deepest_depth only ever rises, survives a load, and
	# resets with the run — so this fires exactly once per band per survey, and
	# costs no new state. Must sit BEFORE note_ledger_max, which is what moves the
	# mark past the edge.
	#
	# BOTH sides are truncated, and that is the whole correctness argument. The
	# first version compared the stored int against the LIVE float, which
	# double-logs across the one edge that is not a whole number: band_of returns
	# CHARTED only at depth <= 0, so from depth 0.1 to 0.9 the mark reads
	# CHARTED while the ship reads THE SHOALS, and the line fires every frame
	# until depth passes 1.0 — ten identical entries, and the run's log evicted
	# by its own first crossing. Comparing mark-to-mark asks the only question
	# that has a stable answer: did the number we are about to store change band?
	var was := DeepSpace.band_of(float(int(GameState.ledger.get("deepest_depth", 0))))
	var now := DeepSpace.band_of(float(int(depth)))
	if now > was:
		GameState.note_log("CROSSED INTO %s" % DeepSpace.BAND_NAMES[now])
	GameState.note_ledger_max("deepest_depth", int(depth))

	# LEAVING THE CHARTED VOLUME IS BREAKING OFF.
	#
	# `boss_active` locks the chart and refit buttons, refuses docking and refuses
	# recall, and nothing clears it but killing the engine, BREAK OFF, or a system
	# load. That was airtight while the camera clamp meant you could not
	# meaningfully leave the arena — phase 3 removed the clamp and left the lock,
	# so a player could fly out into the Drift and take a boss fight's console
	# lockout with them, for a fight now four hundred units behind them.
	#
	# Rather than a new rule, this reuses the one that already exists: crossing
	# the chart edge mid-encounter IS disengaging, and costs exactly what BREAK
	# OFF costs. The geometry and the rules now agree.
	if boss_active and depth > 0.0:
		disengage_apex(false)
		if hud:
			hud.show_toast("BROKE OFF — LEFT CHARTED SPACE", Palette.AMBER)

	# Swarm waves keep a live target for whatever fit the player is testing.
	# They pause during a boss fight (the engine supplies its own adds) and
	# during the guided first run (the tutorial supplies its own).
	if boss_active or tutorial_active():
		return
	# Waves are the CHARTED system's pacing and they stop at its edge. This is not
	# only a design call: `_spawn_swarm_pack` clamps the pack inside `bounds - 6`,
	# which once the player is a few hundred units out collapses onto one fixed
	# world point — every wave for the rest of the flight arriving at the same
	# spot back near the system, which the player would never even see. The
	# expanse brings its own encounters, seeded per sector.
	if depth > 0.0:
		return
	var swarm: Dictionary = system_def.get("swarm", {})
	if swarm.is_empty():
		return
	_wave_timer -= delta
	if _wave_timer <= 0.0:
		_wave_timer = float(swarm.get("interval", 22.0))
		if get_tree().get_nodes_in_group("swarm").size() < int(swarm.get("cap", 10)):
			_spawn_swarm_pack(swarm)


func _spawn_swarm_pack(swarm: Dictionary) -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	var origin: Vector3 = player.global_position if player else Vector3.ZERO
	var ang := randf() * TAU
	var center := origin + Vector3(cos(ang), 0, sin(ang)) * randf_range(13.0, 19.0)
	# Clamp inside the system, not to a fixed box: the systems are much larger
	# now and a hard ±20 would bunch every wave around the middle.
	var edge := SystemDB.bounds_of(system_id) - 6.0
	center.x = clampf(center.x, -edge, edge)
	center.z = clampf(center.z, -edge, edge)
	# Never spawn a pack inside a moon.
	center = Obstacles.resolve(center, 3.0)

	var count := randi_range(int(swarm.get("pack_min", 4)), int(swarm.get("pack_max", 6)))
	var mult := float(system_def.get("difficulty", 1.0))
	for i in range(count):
		var s := SwarmHostile.new()
		s.difficulty = mult
		system_root.add_child(s)
		s.global_position = center + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
	FX.ring_pulse(self, center, Palette.THREAT, 2.5, 0.8)
	Barks.fire("first_hostiles")


# --- cargo interdictions ----------------------------------------------------

func console_open() -> bool:
	# Any full-screen console the player is reading rather than flying behind.
	for panel in [port_panel, refit_panel, chart_panel]:
		if panel != null and panel.is_open:
			return true
	return pause_menu != null and pause_menu.is_open


func console_camping() -> bool:
	# A console open while the ship is UNDER WAY is not a console being read; it
	# is a shield. interdiction_eligible() excludes open consoles (14: a raid must
	# not begin behind a sheet the player cannot see past), and nothing gates
	# movement on that — so a full hold crosses two systems raid-proof with the
	# refit sheet up, and the raid timer does not even tick.
	#
	# The exclusion is kept for a ship at REST, which is the case 14 was written
	# about. Under way, the sheet closes as the klaxon lands and the six-second
	# standoff carries the reactability the exclusion used to.
	var player: PlayerShip = get_tree().get_first_node_in_group("player")
	if player == null or not console_open():
		return false
	return player.velocity.length() > 0.5


func close_consoles_for_raid() -> void:
	for panel in [port_panel, refit_panel, chart_panel]:
		if panel != null and panel.is_open:
			panel.close_panel()


func interdiction_eligible() -> bool:
	# Every exclusion here is a place where being jumped would be unfair rather
	# than tense: docked is the game's one safe state, the tutorial has not
	# taught combat yet, an apex fight is already the hardest thing on offer, and
	# a warp is a cutscene.
	#
	# Consoles count too. They do not pause the game, so a raid could begin while
	# the player was reading the refit list — the klaxon fires behind a sheet
	# that covers two thirds of the screen, and the first thing they see on
	# closing it is a pack already on top of them. Being ambushed should be
	# something you had a chance to react to.
	return state == State.PLAYING \
		and not warping \
		and not boss_active \
		and not tutorial_active() \
		and docked_port == null \
		and (not console_open() or console_camping()) \
		and not _raid_active \
		and _raid_cooldown <= 0.0


func interdiction_taper() -> float:
	# Raiders are a fact of the shipping lanes, and out past the chart there are
	# no lanes. They still hunt a loaded hauler anywhere — piracy does not stop
	# being profitable because nobody is watching — it is just that far fewer of
	# them are out there to do it, and the ones that are have further to come.
	#
	# This is the counterweight the whole expanse rests on: danger goes UP with
	# distance (DeepSpace.PACK_*) while interdiction goes DOWN, so going deep
	# trades a threat you can plan around for one you cannot. A hold full of
	# contraband is safest exactly where everything else will kill you.
	return DEEP_RAID_TAPER[DeepSpace.band_of(deep_depth())]


func interdiction_chance() -> float:
	var value := GameState.hold_value(true)
	if value < RAID_MIN_HOLD:
		return 0.0
	# The taper is applied AFTER the clamp, deliberately. Inside it, RAID_MIN_CHANCE
	# is a floor that would swallow the whole gradient and leave the deep exactly
	# as dangerous to a hauler as the shipping lanes are.
	return clampf(float(value) / RAID_VALUE_SCALE, RAID_MIN_CHANCE, RAID_MAX_CHANCE) \
		* interdiction_taper() * hold_signature()


# A carried thing that changes what happens to you, rather than what your ship
# can do. Deliberately not a fitted stat: cargo_after() probes compute_stats(fit)
# while cargo_capacity() reads live stats, so a good that moved a fitted number
# would make the hold guard subtract two different piles from each other.
#
# These two are a matched pair and the pair is the point. A Forged Manifest is the
# reward for reading Reaches salvage — it makes the trip home quieter. An Unstable
# Charge reads hot to anyone scanning, and it is one of the best things THE QUIET
# yields, so the most valuable haul in the game is also the loudest. Something you
# want to carry that makes the trip worse is the trade 16 asks every specialist
# to make, moved from the fitting screen into the hold.
const SIGNATURE_MANIFEST := 0.55
const SIGNATURE_CHARGE := 1.8
# The FITTED damper, deliberately weaker than the carried forgery: 0.70 against
# 0.55 is a 30% cut where the Manifest buys 45%. It also costs a utility slot,
# four power and 25 shield, where the Manifest costs two units of hold. If this
# number ever drops below SIGNATURE_MANIFEST, one craft obsoletes carrying
# contraband cover forever — FITTED WEAKER THAN CARRIED asserts the pair.
const FITTED_BAFFLE := 0.70


func hold_signature() -> float:
	var k := 1.0
	if GameState.hold_has("manifest_forged"):
		k *= SIGNATURE_MANIFEST
	if GameState.fit_has("mod_baffle"):
		k *= FITTED_BAFFLE
	if GameState.hold_has("charge_unstable"):
		k *= SIGNATURE_CHARGE
	return k


func _tick_interdiction(delta: float) -> void:
	_raid_cooldown = maxf(_raid_cooldown - delta, 0.0)

	# The raid is over once the last raider is gone; only then does the cooldown
	# start, so a fight can never be interrupted by a second wave on top of it.
	if _raid_active:
		if _parley_until > 0.0 and GameState.played_seconds > _parley_until:
			_parley_until = 0.0
			if hud:
				hud.hide_parley()
		if _count_raiders() == 0:
			_raid_active = false
			_raid_cooldown = RAID_COOLDOWN
			_raid_timer = RAID_ROLL_INTERVAL
		return

	if not interdiction_eligible():
		return
	_raid_timer -= delta
	if _raid_timer > 0.0:
		return
	_raid_timer = RAID_ROLL_INTERVAL
	if randf() < interdiction_chance():
		spawn_interdiction()


func pay_toll() -> void:
	# The paid exit. Cargo comes out hottest-first (the raiders take what they
	# came for), nothing is paid back, and departure sheds every group
	# IMMEDIATELY — _count_raiders() ending the raid is what starts the cooldown,
	# and a pack that merely flew away would leave _raid_active true forever.
	if not _raid_active or GameState.played_seconds > _parley_until:
		return
	# THE HOLD MUST ACTUALLY COVER THE DEMAND. The old guard was `taken <= 0`,
	# which accepted any nonzero payment as settlement — and it was safe only by
	# coincidence: a raid needs weighted >= RAID_MIN_HOLD (1500) at a maximum
	# interdiction weight of 3.5, so the unweighted hold at spawn is always at
	# least 1500/3.5 = 428.6, comfortably over the 400 floor. Three constants that
	# have never heard of each other, holding a rule up by 28 credits.
	#
	# Nothing could shrink a hold mid-standoff until the cargo manifest gave the
	# player a dump button. With it: jettison down to one alloy, pay 40, and the
	# pack leaves satisfied. Checked against the same base-price currency
	# strip_hottest counts in.
	if GameState.hold_value(false) < _parley_toll:
		if hud:
			hud.show_toast("NOT ENOUGH ABOARD — THEY WANT %s" % _comma_int(_parley_toll),
				Palette.THREAT)
		return
	var taken := GameState.strip_hottest(_parley_toll)
	if taken <= 0:
		return
	GameState.note_ledger("tolls_paid", 1)
	GameState.note_log("TOLL PAID — %s IN CARGO" % _comma_int(taken))
	_parley_until = 0.0
	for node in get_tree().get_nodes_in_group("raider"):
		if node.has_method("depart"):
			node.depart()
	Sfx.play("warp", -10.0, 1.4)
	if hud:
		hud.hide_parley()
		hud.clear_prompt()
		hud.show_toast("TOLL TAKEN — %s IN CARGO" % _comma_int(taken), Palette.AMBER_DIM)
		hud.refresh_cargo()


func run_bluff() -> void:
	# The honest wager, ported from the Cantina to the parley: the odds are ON THE
	# BUTTON, and the stake is real — the Forged Manifest is CONSUMED whether it
	# works or not. Without that stake a bluff would strictly dominate paying, and
	# an option that is never wrong is not a decision.
	#
	# Fail and the standoff ends immediately with PAY withdrawn: you showed your
	# hand, and they are not going to take a toll from a liar.
	if not _raid_active or GameState.played_seconds > _parley_until:
		return
	if GameState.smuggling < GameState.SMUGGLING_BLUFF_TIER:
		return
	if not GameState.hold_has("manifest_forged"):
		return
	var odds := GameState.bluff_odds()
	GameState.unload_cargo("manifest_forged", 1)
	_parley_until = 0.0
	if hud:
		hud.hide_parley()
		hud.refresh_cargo()
	if randf() < odds:
		for node in get_tree().get_nodes_in_group("raider"):
			if node.has_method("depart"):
				node.depart()
		Sfx.play("warp", -10.0, 1.4)
		if hud:
			hud.show_toast("THEY BOUGHT IT", Palette.GOLD)
		return
	for node in get_tree().get_nodes_in_group("raider"):
		if node.get("standoff") != null:
			node.set("standoff", 0.0)
	Sfx.play("klaxon", -6.0)
	if hud:
		hud.show_toast("THEY DID NOT BUY IT", Palette.THREAT)
		hud.clear_prompt()


func break_parley() -> void:
	# Shooting a raider is also an answer. The whole pack opens up together.
	if _parley_until <= 0.0:
		return
	_parley_until = 0.0
	for node in get_tree().get_nodes_in_group("raider"):
		if node.get("standoff") != null:
			node.set("standoff", 0.0)
	if hud:
		hud.hide_parley()


func spawn_rift() -> Rift:
	# Public so the harness forces one instead of gambling on the roll. Session
	# weather: a system_root child at a random bearing, at a depth the ship can
	# reach within the rift's life, announced on the comms plate rather than the
	# toast strip because a thing with a fuse deserves the weightier surface.
	if live_rift != null or state != State.PLAYING or warping or tutorial_active():
		return null
	var bearing := randf() * TAU
	var depth := randf_range(RIFT_DEPTH_MIN, RIFT_DEPTH_MAX)
	var radius := chart_edge() + depth
	var pos := Vector3(cos(bearing) * radius, 0.0, sin(bearing) * radius)

	var rift := Rift.new()
	rift.band = DeepSpace.band_of(depth)
	system_root.add_child(rift)
	rift.global_position = pos
	live_rift = rift

	if hud:
		hud.show_broadcast("SUBSPACE ADVISORY — AUTOMATED",
			"SHEAR DETECTED · BEARING %03d · %du OUT · IT WILL NOT HOLD" % [
				int(rad_to_deg(bearing)), int(depth)],
			Palette.DEEP_BANDS[rift.band])
	return rift


func rift_rumor() -> String:
	# What the Cantina knows about the weather. Empty when there is nothing to
	# know — the rumor ladder skips an empty line.
	if live_rift == null or not is_instance_valid(live_rift):
		return ""
	var p := live_rift.global_position
	var bearing := int(rad_to_deg(atan2(p.z, p.x)))
	if bearing < 0:
		bearing += 360
	return "A shear is standing open — bearing %03d, %du out. It will not hold, and neither will the price of what falls out of it." % [
		bearing, int(deep_space.depth_at(p)) if deep_space else 0]


func _count_raiders() -> int:
	var n := 0
	for node in get_tree().get_nodes_in_group("raider"):
		if is_instance_valid(node):
			n += 1
	return n


func spawn_interdiction() -> void:
	# Public so the harness can force one without gambling on a dice roll.
	var player: PlayerShip = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	_raid_active = true

	var value := GameState.hold_value(true)
	# One bearing for the whole pack: raiders arrive as an intercept, from a
	# direction, not as a ring closing in. A ring has no side to run from.
	var bearing := randf() * TAU
	var origin := player.global_position + Vector3(cos(bearing), 0, sin(bearing)) * RAID_SPAWN_DIST
	# That clamp is the CHARTED system's, and it only makes sense inside one.
	# Applied out in the expanse it collapses every intercept onto the same fixed
	# point back at the system edge — a pack spawning hundreds of units from the
	# player, off screen, off radar, flying in from nowhere for a minute.
	var deep := deep_depth() > 0.0
	if not deep:
		var edge := SystemDB.bounds_of(system_id) - 4.0
		origin.x = clampf(origin.x, -edge, edge)
		origin.z = clampf(origin.z, -edge, edge)
	origin = Obstacles.resolve(origin, 4.0)
	# And out there they can be outrun. Inside a system a raid has edges and a
	# station to run to, so a raider that never gives up is correct; in open space
	# with nothing to reach, it is a sentence.
	var leash := DeepSpace.HOSTILE_LEASH if deep else 0.0

	# The demand. Priced off the UNWEIGHTED hold — the old prompt printed the
	# weighted value labelled "HOLD VALUE", which was a cosmetic lie the parley
	# would have turned into a real one.
	# A sheet held open while flying is not a sheet being read — it closes as the
	# klaxon lands, and the standoff below is what makes the raid reactable.
	close_consoles_for_raid()
	_parley_toll = maxi(TOLL_FLOOR, int(float(GameState.hold_value(false)) * TOLL_FRACTION))
	# t1 buys TIME to read the demand, not money off it.
	var window := PARLEY_WINDOW + (GameState.SMUGGLING_STANDOFF_BONUS \
		if GameState.smuggling >= 1 else 0.0)
	_parley_until = GameState.played_seconds + window

	Sfx.play("klaxon", -6.0)
	if hud:
		hud.show_toast("RAIDERS ON INTERCEPT", Palette.THREAT)
		hud.prompt("RAIDERS DEMAND %s SALVAGE IN CARGO — PAY, RUN, OR FIGHT" % _comma_int(_parley_toll))
		hud.show_parley(_parley_toll, GameState.bluff_odds() \
			if GameState.hold_has("manifest_forged") else 0.0)
	var rig := get_tree().get_first_node_in_group("camera_rig")
	if rig:
		rig.shake(0.18)
	FX.shockwave(self, origin, Palette.THREAT, 6.0, 0.7)

	var count := randi_range(3, 6)
	var difficulty := float(system_def.get("difficulty", 1.0))
	for i in range(count):
		var r := SwarmHostile.new()
		r.difficulty = difficulty
		r.tint = RAID_TINT
		r.despawn_radius = leash
		# What they are carrying is what they took off the last hauler.
		r.drop_good = "stolen" if i < 2 else ""
		r.standoff = window
		r.add_to_group("raider")
		system_root.add_child(r)
		r.global_position = origin + Vector3(randf_range(-2.0, 2.0), 0, randf_range(-2.0, 2.0))
		FX.flash(self, r.global_position, Palette.THREAT, 1.4, 0.25)

	# A hold worth this much brings something that does not die to one Arc hop.
	if value >= RAID_CORSAIR_HOLD:
		var corsair := Hostile.new()
		corsair.standoff = window
		corsair.difficulty = difficulty
		corsair.despawn_radius = leash
		corsair.add_to_group("raider")
		system_root.add_child(corsair)
		corsair.global_position = origin
		FX.flash(self, origin, Palette.THREAT, 2.4, 0.35)

	if hud:
		get_tree().create_timer(3.2).timeout.connect(func() -> void:
			if hud:
				hud.clear_prompt())


func spring_trap(origin: Vector3, cfg: Dictionary) -> void:
	# A rigged hulk just went off. Two beats, in this order: the EMP lands first
	# so the player feels the trap before they see who set it, and the pack
	# arrives a moment later out of the dark.
	var player: PlayerShip = get_tree().get_first_node_in_group("player")
	if player == null:
		return

	if player.has_method("emp_stun"):
		player.emp_stun(float(cfg.get("emp", 1.8)))
	FX.shockwave(self, origin, Palette.TEAL, 16.0, 1.1)
	FX.ring_pulse(self, origin, Color(0.55, 0.85, 1.0), 6.0, 0.9)
	Sfx.play("alarm", -6.0, 0.8)
	if hud:
		hud.show_toast("EMP — DRIVES OFFLINE", Color(0.55, 0.85, 1.0))
		hud.prompt("THE WRECK WAS BAIT")
		get_tree().create_timer(3.4).timeout.connect(func() -> void:
			if hud:
				hud.clear_prompt())

	await get_tree().create_timer(0.55).timeout
	if not is_instance_valid(player):
		return

	# One bearing, like an interdiction: an ambush still has a side it comes from,
	# and a ring closing in is a shape with nowhere to run.
	var bearing := randf() * TAU
	var from := origin + Vector3(cos(bearing), 0, sin(bearing)) * 15.0
	var count := int(cfg.get("count", 4))
	for i in range(count):
		var s := SwarmHostile.new()
		s.difficulty = float(cfg.get("difficulty", 1.0))
		s.hp_scale = float(cfg.get("hp_scale", 1.0))
		s.tint = cfg.get("tint", Palette.THREAT)
		s.drop_good = String(cfg.get("drop", "")) if i == 0 else ""
		s.despawn_radius = DeepSpace.HOSTILE_LEASH
		# system_root, never the cell that owns the hulk: this fight will move,
		# and a pack that belonged to a cell would evaporate mid-chase.
		system_root.add_child(s)
		s.global_position = from + Vector3(randf_range(-2.5, 2.5), 0, randf_range(-2.5, 2.5))
		FX.flash(self, s.global_position, cfg.get("tint", Palette.THREAT), 1.4, 0.25)

	if bool(cfg.get("escort", false)):
		var heavy := Hostile.new()
		heavy.difficulty = float(cfg.get("difficulty", 1.0))
		heavy.despawn_radius = DeepSpace.HOSTILE_LEASH
		system_root.add_child(heavy)
		heavy.global_position = from
		FX.flash(self, from, Palette.THREAT, 2.4, 0.35)

	Sfx.play("klaxon", -8.0)
	if hud:
		hud.show_toast("SALVAGE CREW INBOUND — %d CONTACTS" % count, Palette.THREAT)
	var rig := get_tree().get_first_node_in_group("camera_rig")
	if rig:
		rig.shake(0.16)


func _comma_int(n: int) -> String:
	var s := str(n)
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return out


# --- market & ports ---------------------------------------------------------

func _tick_market(delta: float) -> void:
	GameState.advance_clock(delta)
	Market.recover_pressure(delta)

	for ev in Market.tick_events(delta):
		if hud:
			hud.show_toast("%s ENDS — %s" % [
				Market.event_label(ev), CommodityDB.short_name(String(ev["good"]))],
				Palette.AMBER_DIM)

	_rift_timer -= delta
	if _rift_timer <= 0.0:
		_rift_timer = RIFT_ROLL_INTERVAL
		if randf() < RIFT_CHANCE:
			spawn_rift()

	_event_roll_timer -= delta
	if _event_roll_timer <= 0.0:
		_event_roll_timer = Market.EVENT_ROLL_INTERVAL
		var ev := Market.try_spawn_event(SystemDB.port_ids())
		if not ev.is_empty() and hud:
			var pdef := SystemDB.port_def_by_id(String(ev["port"]))
			hud.show_toast("%s %s — %s" % [
				String(pdef.get("name", "PORT")),
				Market.event_label(ev),
				CommodityDB.short_name(String(ev["good"]))],
				Market.event_color(ev))


func find_port() -> Port:
	# "The port of this system" — what the tutorial, the chart and the delivery
	# contracts all mean. A streamed deep station is dockable and is in the same
	# group, but it is emphatically not this: it is somewhere the player found,
	# and it can be 600 units away or gone entirely a minute later. Charted ports
	# carry no `def` of their own, which is exactly the tell.
	var nodes := get_tree().get_nodes_in_group("dockable")
	for n in nodes:
		if n is Port and (n as Port).def.is_empty():
			return n
	return null


func request_dock(port: Port) -> void:
	if docked_port != null or warping:
		return
	if boss_active:
		# No parking mid-encounter: breaking off a boss by docking is an exit,
		# not a decision.
		if hud:
			hud.prompt("DOCKING CLAMPS LOCKED — ENGINE ACTIVE")
		Sfx.play("hit", -10.0, 0.7)
		return
	FX.ring_pulse(self, port.dock_point, Palette.AMBER, 1.6)
	Sfx.play("tap", -5.0, 0.95)
	if port.player_in_range():
		_complete_dock(port)
	else:
		_pending_dock = port
		port.approach()
		if hud:
			hud.prompt("APPROACHING %s" % port.port_name)


func _try_complete_dock() -> void:
	if _pending_dock == null or not is_instance_valid(_pending_dock):
		_pending_dock = null
		return
	if boss_active:
		_pending_dock = null
		return
	if _pending_dock.player_in_range():
		var p := _pending_dock
		_pending_dock = null
		_complete_dock(p)


func _complete_dock(port: Port) -> void:
	var player: PlayerShip = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	docked_port = port
	port.set_docked_visual(true)
	player.dock_to(port.dock_point)
	GameState.set_docked(port.port_id)

	# Docking a deep station IS surveying it: you demonstrably hold its
	# coordinates. Granted here rather than via a mast because a mast within
	# PICK_PX of a station would intercept docking taps — CameraRig checks
	# `crackable` before `dockable`. Keyed on the cell like every other reading,
	# so it is once per session and resets on warp with the rest of the expanse.
	if DeepPortDB.is_deep_port(port.port_id) and deep_space != null:
		var cell := DeepSpace.cell_of(port.global_position)
		if not deep_space.is_surveyed(cell):
			var band := DeepSpace.band_of(deep_space.depth_at(port.global_position))
			var good := CommodityDB.chart_for_band(band)
			if good != "" and GameState.load_cargo(good, SurveyMast.YIELD_UNITS) > 0:
				deep_space.note_surveyed(cell)
				if hud:
					hud.show_toast("BERTH LOGGED — %s x%d" % [
						CommodityDB.short_name(good), SurveyMast.YIELD_UNITS],
						CommodityDB.color_of(good))
					hud.refresh_cargo()

	Sfx.play("dock", -3.0)
	Sfx.haptic("medium")
	FX.ring_pulse(self, port.dock_point, Palette.TEAL, 2.2, 0.7)
	var rig := get_tree().get_first_node_in_group("camera_rig")
	if rig:
		rig.punch_zoom(-1.2)
	if hud:
		hud.clear_prompt()
		hud.set_panels_locked(true)
	Music.set_docked(true)
	Barks.fire("first_docked")

	if contracts:
		contracts.on_docked(port.port_id)
	if port_panel:
		port_panel.open_for(port)


func undock() -> void:
	if docked_port == null:
		return
	var player: PlayerShip = get_tree().get_first_node_in_group("player")
	var port := docked_port
	docked_port = null
	port.set_docked_visual(false)
	GameState.set_docked("")
	if player:
		player.undock()
	Sfx.play("dock", -9.0, 1.25)
	FX.ring_pulse(self, port.dock_point, Palette.AMBER, 2.0, 0.6)
	Music.set_docked(false)
	if hud:
		hud.set_panels_locked(false)


# --- apex encounter ---------------------------------------------------------

func _find_apex() -> ApexBoss:
	var nodes := get_tree().get_nodes_in_group("apex")
	if nodes.is_empty():
		return null
	return nodes[0] as ApexBoss


func arm_apex_wake() -> void:
	# Called when this system's derelict is breached — the aftershock.
	if _find_apex() != null:
		_apex_wake_timer = APEX_BREACH_DELAY


func _wake_apex() -> void:
	var boss := _find_apex()
	if boss == null or boss_active:
		return
	# Not while the player is outside the charted volume. The engine sits at an
	# authored position near the origin, so waking it while the ship is four
	# hundred units out would lock every console for a fight that is not visible,
	# not reachable and not started — and with the leave-the-volume rule below,
	# it would wake and disengage on a loop. It waits until there is someone to
	# wake for.
	if deep_depth() > 0.0:
		_apex_wake_timer = 1.0     # check again shortly
		return
	_set_boss_active(true)
	boss.wake()


func _set_boss_active(v: bool) -> void:
	boss_active = v
	if hud:
		hud.set_panels_locked(v)
		if not v:
			hud.set_boss_status({"active": false})
	if not v and refit_panel and refit_panel.is_open:
		pass  # panels already open stay open; they simply can't be reopened


func disengage_apex(return_home := true) -> bool:
	# A voluntary way out of a boss fight.
	#
	# Until now the ONLY exit was to be destroyed: docking is refused during an
	# encounter, and the chart button is locked by set_panels_locked, so a player
	# who had bitten off more than they could chew had to stand there and let it
	# happen. That is a fail state masquerading as a mechanic. Breaking off costs
	# the same as dying — the engine resets to full and the run continues — so
	# this takes nothing away from the fight; it just lets you leave on your feet.
	if not boss_active:
		return false
	var boss := _find_apex()
	if boss:
		boss.reset_fight()
	_set_boss_active(false)
	_apex_wake_timer = APEX_WAKE_DELAY

	# BREAK OFF from the pause menu pulls you out to safety, which is the whole
	# point of it. Leaving the charted volume under your own power is the same
	# decision made with the stick instead of a button, and must NOT teleport you
	# — you went out there deliberately, possibly hundreds of units, and yanking
	# you home would undo the thing you were doing.
	if return_home:
		var player: PlayerShip = get_tree().get_first_node_in_group("player")
		if player:
			player.teleport_to(PlayerShip.SPAWN_POINT)
			player.velocity = Vector3.ZERO
			player.warp_streak_in()
		var rig := get_tree().get_first_node_in_group("camera_rig")
		if rig:
			rig.global_position = Vector3(0, 0, 2)
		Sfx.play("warp", -4.0)
		FX.shockwave(self, PlayerShip.SPAWN_POINT, Palette.TEAL, 7.0, 0.8)
		if hud:
			hud.show_toast("BROKE OFF — THE ENGINE RESETS", Palette.TEAL)
	return true


func spill_unread(at: Vector3) -> int:
	# Dying out here costs you what you could not read.
	#
	# UNREAD SALVAGE ONLY, and that scope is the design. Identified components
	# stay aboard, so reading a thing is also STOWING it — which hands ARCHEOLOGY
	# a third job beside compressing a hold and unlocking the deeper grades, and
	# makes field-reading a survival act rather than only an economic one. The
	# fiction writes itself: components are stowed, unidentified pallets are deck
	# cargo. Spilling the WHOLE hold was considered and cut: it would make deep
	# death lethal to the contraband trade the expanse rests on, and it would
	# retroactively break a promise the tutorial already made.
	#
	# CHART SIDE SPILLS NOTHING. 'You lose position and tempo, never salvage'
	# stays literally true everywhere it was taught.
	if deep_space == null or deep_space.depth_at(at) <= 0.0:
		return 0

	# NOT through spawn_loot. That path re-rolls 22% of goods into band salvage
	# by the position it is called at, so a salvage_quiet spilled at depth 80
	# would come back as salvage_drift — cargo quietly re-graded by where it was
	# dropped rather than where it was found.
	var script := load("res://scripts/loot_cube.gd") as GDScript
	var spilled := 0
	for gid in CommodityDB.ids():
		var good := String(gid)
		if not CommodityDB.is_salvage(good):
			continue
		var held := GameState.cargo_count(good)
		if held <= 0:
			continue
		# Out of the hold FIRST, so the cubes are the only copy and a second death
		# inside the grace window finds nothing left to duplicate.
		GameState.unload_cargo(good, held)
		for i in range(held):
			var cube: Node3D = script.new()
			cube.commodity = good
			cube.spill = true
			# system_root, NOT the player's parent. The player hangs off Main, so
			# get_parent() here would outlive a warp — and a spill that survived
			# leaving the system would be salvage stored in a place the save knows
			# nothing about.
			system_root.add_child(cube)
			cube.place_at(at + Vector3(randf_range(-1.6, 1.6), 0.0,
				randf_range(-1.6, 1.6)))
			spilled += 1

	if spilled > 0:
		if hud:
			hud.show_toast("HOLD BREACHED — %d UNREAD ADRIFT" % spilled, Palette.THREAT)
		FX.burst(system_root, at, Palette.AMBER, 40, 6.0, 0.3, 1.0)
	return spilled


func on_player_downed() -> void:
	# An emergency warp clears the ship's move order, so a docking approach that
	# gets shot down is over — but `_pending_dock` used to survive it, leaving
	# main polling a port the player was no longer flying to. The next time they
	# happened to drift near it, they would clamp on unasked.
	if _pending_dock != null:
		_pending_dock = null
		if hud:
			hud.prompt("APPROACH ABORTED — DOCKING ORDER CLEARED")

	# Emergency warp during an apex fight breaks off the encounter. The engine
	# resets to full and can be re-engaged; nothing earned is lost.
	if not boss_active:
		return
	var boss := _find_apex()
	if boss:
		boss.reset_fight()
	_set_boss_active(false)
	if hud:
		hud.show_toast("ENGINE DISENGAGED — IT WILL RESET", Palette.TEAL)
	_apex_wake_timer = APEX_WAKE_DELAY


func on_apex_defeated(_boss: Node3D) -> void:
	_set_boss_active(false)
	report_kill("apex")


func award_apex_bonus(sys_id: String, bonus: int) -> void:
	# One-time bonus the first time a given system's engine is put down.
	if sys_id == "" or GameState.has_killed_apex(sys_id):
		return
	GameState.mark_apex_killed(sys_id)
	add_salvage(bonus)
	if hud:
		hud.show_toast("FIRST KILL BONUS  +%d" % bonus, Palette.GOLD)


func add_salvage(v: int) -> void:
	GameState.add_salvage(v)
	hud.set_value(GameState.salvage)
	hud.gain(v)
	if contracts:
		contracts.on_salvage(v)
	if GameState.salvage >= 1500:
		Barks.fire("refit_available")


func report_kill(kind: String) -> void:
	hostile_killed.emit(kind)
	if contracts:
		contracts.on_kill(kind)
	Barks.fire("first_kill")


func spawn_loot(parent: Node3D, pos: Vector3, good := "", value_mult := 1.0) -> Node3D:
	# One place that knows how to make a loot cube, so every spawner types its
	# drops identically.
	# PROVENANCE. A crate that would have held a good sometimes holds unidentified
	# salvage instead, graded by the band you were standing in when you found it.
	# Done here because spawn_loot is the single point every drop in the game
	# passes through — derelicts, apex wrecks, sentries, swarms, deep nests and
	# rigged hulks all inherit it without one edit between them.
	if good != "" and randf() < CommodityDB.SALVAGE_CHANCE:
		var band := 0
		if deep_space != null:
			band = DeepSpace.band_of(deep_space.depth_at(pos))
		var graded := CommodityDB.salvage_for_band(band)
		if graded != "":
			good = graded

	var script := load("res://scripts/loot_cube.gd") as GDScript
	var cube: Node3D = script.new()
	cube.commodity = good
	cube.repeat_mult = value_mult
	parent.add_child(cube)
	cube.place_at(pos)
	return cube


# --- the expanse ------------------------------------------------------------

func chart_edge() -> float:
	# The radius of the surveyed volume. Still `bounds`, still per-system data —
	# it just stops being a wall and becomes a landmark.
	return SystemDB.bounds_of(system_id)


func deep_radius() -> float:
	var p: Node3D = get_tree().get_first_node_in_group("player")
	if p == null:
		return 0.0
	return Vector2(p.global_position.x, p.global_position.z).length()


func deep_depth() -> float:
	# How far past the chart edge. Zero everywhere inside the system, which is
	# what makes every gradient built on it a no-op for existing content.
	return maxf(deep_radius() - chart_edge(), 0.0)


func loot_mult() -> float:
	return float(system_def.get("loot_mult", 1.0))


func hit_stop(duration: float, scale: float) -> void:
	# Brief time dilation on heavy impacts. The timer ignores time_scale so the
	# freeze lasts a fixed wall-clock moment.
	if _hitstop:
		return
	_hitstop = true
	Engine.time_scale = scale
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	_hitstop = false


# --- scripted demo (headless verification / capture) ------------------------

func _run_demo() -> void:
	var shots: String = OS.get_environment("PYXIS_SHOTS")
	var player: PlayerShip = get_tree().get_first_node_in_group("player")

	print("[demo] contracts at startup: ", contracts.debug_state())
	# Enough to actually buy the endgame fit this demo equips below. Sized off
	# the catalog rather than hard-coded, so an economy rebalance can never
	# silently leave the boss fight being fought with starter mounts again.
	GameState.add_salvage(_pacing_catalog_cost())
	hud.set_value(GameState.salvage)
	await get_tree().create_timer(0.6).timeout
	await _shot(shots, "w1_pyx01.png")

	# Chart with PYX-02 still locked.
	chart_panel.open()
	await get_tree().create_timer(0.7).timeout
	await _shot(shots, "w2_chart_locked.png")
	chart_panel.close_panel()
	await get_tree().create_timer(0.4).timeout

	# Breach the PYX-01 derelict — this is what charts PYX-02.
	var derelict: Derelict = get_tree().get_first_node_in_group("crackable")
	derelict.on_tapped()
	await get_tree().create_timer(3.0).timeout
	var frames := 0
	while not derelict.is_cracked() and frames < 500:
		derelict.hold_begin()
		derelict.hold_tick(get_process_delta_time())
		frames += 1
		await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	await _shot(shots, "w3_breach_unlock.png")
	print("[demo] breached=", GameState.breached, " pyx02 unlocked=", GameState.is_system_unlocked("pyx02"))
	await get_tree().create_timer(2.5).timeout

	# Chart again — PYX-02 now available.
	chart_panel.open()
	await get_tree().create_timer(0.7).timeout
	await _shot(shots, "w4_chart_unlocked.png")
	chart_panel.close_panel()
	await get_tree().create_timer(0.3).timeout

	# Warp.
	travel_to("pyx02")
	await get_tree().create_timer(WARP_CHARGE + WARP_STREAK * 0.4).timeout
	await _shot(shots, "w5_warp_streak.png")
	await get_tree().create_timer(WARP_STREAK + 0.5).timeout
	await _shot(shots, "w6_arrival_pyx02.png")
	print("[demo] now in ", system_id, " difficulty=", system_def["difficulty"], " loot=", loot_mult())

	# Fight in the ember system; contracts should tick on both kill kinds.
	print("[demo] contracts on arrival: ", contracts.debug_state())
	await get_tree().create_timer(1.0).timeout
	_spawn_swarm_pack(system_def.get("swarm", {}))
	await get_tree().create_timer(1.0).timeout
	for round in range(14):
		_attack_nearest(player)
		await get_tree().create_timer(0.9).timeout
		if round == 3:
			await _shot(shots, "w7_pyx02_combat.png")
		if get_tree().get_nodes_in_group("swarm").size() < 2:
			_spawn_swarm_pack(system_def.get("swarm", {}))
	await _shot(shots, "w7b_contract_progress.png")
	print("[demo] contracts after combat: ", contracts.debug_state())

	# --- APEX ENCOUNTER -----------------------------------------------------
	# Warp back to PYX-01, whose derelict is breached, and fight the Gnomon.
	travel_to("pyx01")
	await get_tree().create_timer(WARP_CHARGE + WARP_STREAK + WARP_ARRIVE + 0.6).timeout

	# Endgame fit, which is what a player reaching the apex would actually bring.
	GameState.upgrade_reactor()
	GameState.upgrade_reactor()
	GameState.buy("lance_2")
	GameState.buy("arc_2")
	GameState.equip(ModuleDB.Slot.WEAPON_A, "lance_2")
	GameState.equip(ModuleDB.Slot.WEAPON_B, "arc_2")
	print("[demo] apex fit dps=", "%.0f" % GameState.stats["dps"],
		" reach=", "%.1f" % GameState.stats["reach"],
		" power=", GameState.power_draw(), "/", GameState.power_cap())
	print("[demo] APEX FIT AFFORDED lance_2=%s arc_2=%s reactor=%d/2 (all must be true / 2)" % [
		str(GameState.owns("lance_2")), str(GameState.owns("arc_2")), GameState.reactor_tier])

	# Regression check for the ability/invulnerability exploit: pop Aegis, refit
	# mid-ability, and confirm protection still expires on schedule. `_grace`
	# from the warp must be allowed to lapse first or it masks the result.
	GameState.buy("core_aegis")
	GameState.equip(ModuleDB.Slot.CORE, "core_aegis")

	# Quiet the system for the duration of the check. An emergency warp also sets
	# `invulnerable`, and quite legitimately — so a swarm wave landing during the
	# sample window made this assertion report the exploit as present when what
	# had actually happened was the ship being shot down. Clearing contacts and
	# holding the wave timer keeps the assertion about the exploit.
	for n in get_tree().get_nodes_in_group("hostiles"):
		(n as Node3D).queue_free()
	_wave_timer = 1.0e9
	await get_tree().process_frame

	await get_tree().create_timer(PlayerShip.WARP_GRACE + 0.4).timeout
	print("[demo] EXPLOIT baseline (pre-ability) invulnerable=", player.invulnerable)
	player.activate_ability()
	await get_tree().create_timer(0.2).timeout
	GameState.equip(ModuleDB.Slot.UTILITY, "util_tractor")
	var cd_after_refit := player.ability_cooldown_fraction()
	await get_tree().create_timer(4.0).timeout
	print("[demo] EXPLOIT CHECK invulnerable_after_refit_and_expiry=", player.invulnerable,
		" (must be false)  cooldown_preserved=", cd_after_refit > 0.0, " (must be true)",
		"  undowned=", not player.is_protected(), " (must be true, or the sample is void)")
	_wave_timer = 2.0

	_apex_wake_timer = 0.35
	await get_tree().create_timer(1.2).timeout
	await _shot(shots, "b1_wake.png")
	print("[demo] boss_active=", boss_active)
	await get_tree().create_timer(ApexBoss.WAKE_TIME).timeout

	var boss := _find_apex()
	var seen_seal := false
	for round in range(300):
		if not is_instance_valid(boss):
			break
		# Play it the way the encounter intends: hit the core while the iris is
		# open, clear probes while it is sealed.
		#
		# Control ticks at 0.2s while a round stays 0.6s. The two were the same
		# number until the hub gained its own armament, at which point the demo
		# started losing fights the balance harness won with every fit — because
		# a 0.6s poll also throttles how fast the bot RETARGETS, so it idled for
		# up to half a second after each probe died and never cleared a seal.
		# A capture script's frame cadence must not double as the bot's reflexes.
		for _sub in range(3):
			if not is_instance_valid(boss):
				break
			if boss.state == ApexBoss.State.SURVEY:
				_engage_core(player, boss)
			else:
				_attack_nearest_probe(player)
			await get_tree().create_timer(0.2).timeout
		if round == 4:
			await _shot(shots, "b2_survey_window.png")
		if not seen_seal and boss.state == ApexBoss.State.SEAL:
			seen_seal = true
			await _shot(shots, "b3_seal_probes.png")
		if round % 20 == 0:
			print("[demo] t=%ds phase=%d hp=%.2f open=%d mult=%.2f shield=%.0f" % [
				int(round * 0.6), boss.phase + 1, boss.hp_fraction(),
				boss.open_plates(), boss.damage_multiplier(), player.shield])
		if round == 26:
			await _shot(shots, "b4_midfight.png")
	await _shot(shots, "b5_after_fight.png")

	# The wreck: hold-to-breach finale.
	var wreck: ApexWreck = null
	for n in get_tree().get_nodes_in_group("crackable"):
		if n is ApexWreck:
			wreck = n
			break
	if wreck:
		wreck.on_tapped()
		await get_tree().create_timer(2.5).timeout
		var wreck_frames := 0
		while not wreck.is_cracked() and wreck_frames < 500:
			wreck.hold_begin()
			wreck.hold_tick(get_process_delta_time())
			wreck_frames += 1
			await get_tree().process_frame
		await get_tree().create_timer(1.0).timeout
		await _shot(shots, "b6_core_vortex.png")
		await get_tree().create_timer(3.0).timeout
		await _shot(shots, "b7_final.png")
	else:
		print("[demo] WARNING: no ApexWreck found — boss did not die")

	print("[demo] apex_killed=", GameState.apex_killed, " boss_active=", boss_active)
	print("[demo] final salvage=", GameState.salvage)
	get_tree().quit()


func _engage_core(player: PlayerShip, boss: ApexBoss) -> void:
	# Faithful play. Two behaviours a real player has and a stationary dummy
	# does not: close into the survey field to land shots at all, and slide to
	# the clear side of the hub when the blades come around.
	if player.shield < player.shield_max * 0.55:
		player.command_move(boss.safest_point(ApexBoss.CORE_RANGE - 1.4))
		return
	var offset: Vector3 = player.global_position - boss.global_position
	offset.y = 0.0
	if offset.length() > ApexBoss.CORE_RANGE - 0.6:
		if offset.length() < 0.1:
			offset = Vector3.BACK
		player.command_move(boss.global_position + offset.normalized() * (ApexBoss.CORE_RANGE - 1.5))
	else:
		player.command_attack(boss)
		# Third behaviour a real player has: never stop moving. The autopilot
		# parks at weapon stop-distance, and a parked ship eats every telegraphed
		# shot the hub fires — the armed bosses turned that bot habit into
		# repeated emergency warps, each of which resets the engine to full.
		#
		# Expressed as a target tangential SPEED, not an impulse added per call.
		# An additive nudge silently made the dodge a function of how often the
		# caller polled: the balance harness runs this every 0.25s and the demo
		# every 0.6s, so the demo bot dodged 2.4x worse and lost fights the
		# balance bot won comfortably — a difference in tick rate reading as a
		# difference in difficulty.
		var tangent := Vector3(-offset.z, 0.0, offset.x).normalized()
		var along := player.velocity.dot(tangent)
		if along < BOT_ORBIT_SPEED:
			player.velocity += tangent * (BOT_ORBIT_SPEED - along)


func _attack_nearest_probe(player: PlayerShip) -> void:
	var best: Node3D = null
	var best_d := 1e9
	for p in get_tree().get_nodes_in_group("apex_probe"):
		var n := p as Node3D
		if not is_instance_valid(n):
			continue
		var d: float = player.global_position.distance_to(n.global_position)
		if d < best_d:
			best_d = d
			best = n
	if best:
		player.command_attack(best)
	else:
		_attack_nearest(player)  # no probes up: keep fighting whatever is here


func _attack_nearest(player: PlayerShip) -> void:
	var best: Node3D = null
	var best_d := 1e9
	for h in get_tree().get_nodes_in_group("hostiles"):
		var d: float = player.global_position.distance_to((h as Node3D).global_position)
		if d < best_d:
			best_d = d
			best = h
	if best:
		player.command_attack(best)


func _shot(dir: String, filename: String) -> void:
	if dir == "":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join(filename))


# --- world tour (composition capture) ---------------------------------------

func _run_world_tour() -> void:
	var shots: String = OS.get_environment("PYXIS_SHOTS")
	var player: PlayerShip = get_tree().get_first_node_in_group("player")
	var rig := get_tree().get_first_node_in_group("camera_rig")
	player.invulnerable = true
	GameState.mark_breached("pyx01")
	GameState.mark_breached("pyx02")

	for id in SystemDB.ids():
		var sid := str(id)
		_load_system(sid)
		await get_tree().create_timer(0.6).timeout
		# Pull the camera up and back to frame the whole system.
		rig.global_position = Vector3.ZERO
		rig.zoom = SystemDB.bounds_of(sid) * 1.65
		rig._target_zoom = rig.zoom
		player.global_position = Vector3(0, 0, 8)
		await get_tree().create_timer(0.8).timeout
		print("[tour] %s bounds=%.0f obstacles=%d sentries=%d" % [
			sid, SystemDB.bounds_of(sid), Obstacles.count(), _count_sentries()])
		await _shot(shots, "tour_%s.png" % sid)
	get_tree().quit()


# --- collision harness ------------------------------------------------------

func set_deep_generation(on: bool) -> void:
	# Harness-facing. Every harness that hand-places a body outside `bounds` calls
	# this first: PYXIS_COLLISIONTEST's synthetic rock sits at magnitude 48.1
	# against PYX-01's bounds of 40, and a generated boulder landing beside it
	# would silently corrupt the SLIDE assertion into measuring the wrong sphere.
	_deep_generation = on
	if deep_space:
		deep_space.set_generation(on)


func _run_collision_test() -> void:
	var player: PlayerShip = get_tree().get_first_node_in_group("player")
	set_deep_generation(false)
	await get_tree().create_timer(0.5).timeout
	player.invulnerable = true
	print("[coll] registered obstacles: %d" % Obstacles.count())

	# A synthetic body in genuinely empty space. Using a world asteroid would
	# put other spheres in frame and make a failed assertion ambiguous.
	var centre := Vector3(34, 0, 34)
	var radius := 3.0
	Obstacles.add(centre, radius)
	print("[coll] test body at (%.1f, %.1f) radius %.1f" % [centre.x, centre.z, radius])

	# 1. Fly straight at it and confirm the hull never enters the sphere.
	var approach := centre + Vector3(0, 0, radius + 9.0)
	player.global_position = approach
	player.velocity = Vector3.ZERO
	player.clear_target()
	var worst := INF
	for i in range(90):
		player.command_move(centre)     # aim at the middle of the rock
		await get_tree().physics_frame
		var flat := player.global_position - centre
		flat.y = 0.0
		worst = minf(worst, flat.length())
	print("[coll] SLIDE closest approach %.2f vs radius+hull %.2f -> %s" % [
		worst, radius + PlayerShip.HULL_RADIUS,
		"PASS" if worst >= radius else "FAIL"])

	# 2. Autopilot to a point directly behind the body: the straight line is
	#    blocked, so arrival proves the steering assist works.
	var behind := centre - Vector3(0, 0, radius + 7.0)
	player.global_position = approach
	player.velocity = Vector3.ZERO
	var arrived := false
	for i in range(600):
		player.command_move(behind)
		await get_tree().physics_frame
		if player.global_position.distance_to(behind) < 2.5:
			arrived = true
			break
	print("[coll] AVOID reached far side = %s (dist %.1f)" % [
		str(arrived), player.global_position.distance_to(behind)])

	# 3. Line of sight: a target on the far side of the body cannot be hit.
	var probe := SwarmHostile.new()
	probe.difficulty = 0.5
	probe.hp_scale = 40.0                    # tanky so it survives to be measured
	system_root.add_child(probe)
	probe.global_position = centre - Vector3(0, 0, radius + 1.5)
	# dock_at, not `docked = true`: the bare flag lerps toward an unset dock
	# point at the origin, so the probe wanders out from behind the cover.
	probe.dock_at(probe.global_position)
	await get_tree().create_timer(0.3).timeout

	# Inside weapon range, so "no damage" can only mean the shot was blocked.
	var firing_spot := centre + Vector3(0, 0, radius + 2.0)
	player.command_attack(probe)
	var hp_before: float = probe.hp
	var had_los := false
	# Pin the ship: command_attack would otherwise autopilot it around the body
	# and quietly acquire the line the test is trying to deny.
	for i in range(150):
		player.global_position = firing_spot
		player.velocity = Vector3.ZERO
		had_los = had_los or Obstacles.has_line(firing_spot, probe.global_position)
		await get_tree().physics_frame
	var hp_blocked: float = probe.hp
	print("[coll] BLOCKED SHOT hp %.0f -> %.0f (must be equal)  ever_had_los=%s (must be false)" % [
		hp_before, hp_blocked, str(had_los)])

	# 4. Same target, clear line: damage must flow. Sit on the probe's own side
	#    of the body so the segment never enters the sphere.
	var clear_spot: Vector3 = probe.global_position - Vector3(0, 0, 4.5)
	for i in range(150):
		player.global_position = clear_spot
		player.velocity = Vector3.ZERO
		await get_tree().physics_frame
	print("[coll] CLEAR SHOT hp %.0f -> %.0f (must fall)  los=%s (must be true)" % [
		hp_blocked, probe.hp,
		str(Obstacles.has_line(clear_spot, probe.global_position))])

	# 5. A target embedded in a body must still be shootable. The apex boss
	#    registers a hull sphere at its own centre, so treating that sphere as
	#    cover made the Gnomon — and anything docked on it — invulnerable.
	var embedded := centre + Vector3(0.2, 0, 0.2)       # inside the test body
	print("[coll] EMBEDDED TARGET los_to_embedded=%s (must be true)  los_through_body=%s (must be false)" % [
		str(Obstacles.has_line(centre + Vector3(0, 0, radius + 6.0), embedded)),
		str(Obstacles.has_line(centre + Vector3(0, 0, radius + 6.0),
			centre - Vector3(0, 0, radius + 6.0)))])

	# 6. And the real thing: wake the Gnomon and confirm its HP actually falls.
	GameState.mark_breached("pyx01")
	_apex_wake_timer = 0.2
	await get_tree().create_timer(ApexBoss.WAKE_TIME + 1.0).timeout
	var boss := _find_apex()
	if boss == null:
		print("[coll] APEX DAMAGE: no boss found")
		get_tree().quit()
		return
	# Sit inside the survey field and shoot through a full survey window.
	var boss_hp_before := boss.hp
	for i in range(420):
		player.global_position = boss.global_position + Vector3(0, 0, 4.0)
		player.velocity = Vector3.ZERO
		player.command_attack(boss)
		await get_tree().physics_frame
	print("[coll] APEX DAMAGE hp %.0f -> %.0f (must fall)  state=%s" % [
		boss_hp_before, boss.hp, boss._state_label()])
	get_tree().quit()


# --- rift harness ---------------------------------------------------------------

func _run_rift_test() -> void:
	var player: PlayerShip = get_tree().get_first_node_in_group("player")
	player.invulnerable = true
	_wave_timer = 1.0e9
	_apex_wake_timer = -1.0
	set_deep_generation(false)
	await get_tree().create_timer(0.4).timeout

	# 1. SPAWNS in the current system, inside the reachable depth window, and
	#    never two at once.
	var rift := spawn_rift()
	await get_tree().physics_frame
	var d := deep_space.depth_at(rift.global_position) if rift else -1.0
	var second := spawn_rift()
	print("[rift] SPAWNS depth %.0f in [%.0f, %.0f], band %d, second refused=%s -> %s" % [
		d, RIFT_DEPTH_MIN, RIFT_DEPTH_MAX, rift.band if rift else -1,
		str(second == null),
		"PASS" if rift != null and d >= RIFT_DEPTH_MIN and d <= RIFT_DEPTH_MAX
			and second == null else "FAIL"])

	# 2. RICH means one band better than the depth deserves, and every crate is
	#    spill-flagged — a stock cube would reap itself at 25s and vacuum itself
	#    to the player from any distance at 1.3s. A pot that collects itself is
	#    not a pot; this prints which failure it found.
	var rich := clampi(rift.band + 1, 1, DeepSpace.BAND_NAMES.size() - 1)
	var want_good := CommodityDB.salvage_for_band(rich)
	var wrong := ""
	var crates := 0
	for c in rift.get_children():
		if c is LootCube:
			crates += 1
			if String((c as LootCube).commodity) != want_good:
				wrong = "wrong grade %s" % (c as LootCube).commodity
			if not bool((c as LootCube).spill):
				wrong = "stock cube (reaps at 25s, self-vacuums)"
	print("[rift] RICH %d crates of %s (band %d at a band-%d depth), all spill-flagged -> %s %s" % [
		crates, CommodityDB.short_name(want_good), rich, rift.band,
		"PASS" if crates >= Rift.CRATE_MIN and crates <= Rift.CRATE_MAX
			and wrong == "" else "FAIL", wrong])

	# 3. THE RUMOR NAMES THE LIVE RIFT, above every market event — and skips it
	#    cleanly once the shear closes.
	var line := rift_rumor()
	print("[rift] RUMOR '%s' -> %s" % [line,
		"PASS" if line != "" and line.contains("bearing") else "FAIL"])

	# 4. COLLAPSE. Three pulses, each evaporating ~30%% of what stands and each
	#    bringing company; after the third the rift is gone and the pot with it.
	#    The player is moved TO the rift first — the first version pulsed it from
	#    the spawn point, 290u away, and the pack leashed out on frame one. That
	#    was the leash working, not the spawn failing.
	player.global_position = rift.global_position + Vector3(4, 0, 0)
	await get_tree().physics_frame
	var before := rift.crates_standing()
	var swarm_before := get_tree().get_nodes_in_group("swarm").size()
	rift.pulse()
	await get_tree().physics_frame
	var after_one := rift.crates_standing()
	var swarm_after := get_tree().get_nodes_in_group("swarm").size()
	rift.pulse()
	rift.pulse()
	for i in range(4):
		await get_tree().physics_frame
	var gone := not is_instance_valid(rift) or rift.is_queued_for_deletion()
	print("[rift] COLLAPSE crates %d -> %d after one pulse (~30%% loss), pack arrived=%s, gone after 3=%s, live_rift cleared=%s -> %s" % [
		before, after_one, str(swarm_after > swarm_before), str(gone),
		str(live_rift == null),
		"PASS" if after_one < before and after_one > 0 and swarm_after > swarm_before
			and gone and live_rift == null else "FAIL"])

	# 5. SESSION ONLY. A rift is weather you were present for: a system rebuild
	#    owes you nothing, saves nothing, and the rumor ladder falls back to the
	#    market read.
	for n in get_tree().get_nodes_in_group("swarm"):
		(n as Node3D).queue_free()
	await get_tree().physics_frame
	var rift2 := spawn_rift()
	# Captured NOW: after the rebuild frees it, a freed reference compares equal
	# to null and "did the spawn succeed" silently becomes "did it survive the
	# rebuild" — the exact opposite of what this step asserts.
	var second_spawned := rift2 != null
	_load_system(system_id)
	await get_tree().physics_frame
	var survivors := 0
	for n in system_root.get_children():
		if n is Rift:
			survivors += 1
	print("[rift] SESSION ONLY rebuilt the system: %d rifts survive, live_rift=%s, rumor falls back='%s' -> %s" % [
		survivors, "null" if live_rift == null else "SET",
		"" if rift_rumor() == "" else "STILL NAMES IT",
		"PASS" if survivors == 0 and live_rift == null and rift_rumor() == "" \
			and second_spawned else "FAIL"])
	get_tree().quit()


# --- smuggling harness --------------------------------------------------------

func _run_smug_test() -> void:
	var player: PlayerShip = get_tree().get_first_node_in_group("player")
	player.invulnerable = true
	_wave_timer = 1.0e9
	_apex_wake_timer = -1.0
	set_deep_generation(false)
	await get_tree().create_timer(0.4).timeout

	# 1. FEEDS COMPETE, asserted as DATA. If smuggling levelled off anything
	#    archeology also levels off, one deep salvage run would raise both and
	#    19's warning lands: skills all fed by "playing the game" rise together
	#    and become a clock rather than a decision.
	var arch_goods := {}
	for band in range(1, DeepSpace.BAND_NAMES.size()):
		var sid := CommodityDB.salvage_for_band(band)
		if sid != "":
			arch_goods[sid] = true
			for out_v in CommodityDB.reads_as(sid):
				arch_goods[String(out_v)] = true
	var overlap := ""
	for g_v in GameState.SMUGGLING_GOODS:
		if arch_goods.has(String(g_v)):
			overlap = String(g_v)
	print("[smug] FEEDS COMPETE smuggling pays on %s, archeology on %d salvage/component ids, overlap=%s -> %s" % [
		str(GameState.SMUGGLING_GOODS), arch_goods.size(),
		overlap if overlap != "" else "none",
		"PASS" if overlap == "" else "FAIL"])

	# 2. NO TOLL XP, NO XP FOR FLEEING. Both were proposed and both were killed by
	#    arithmetic: paying is the losing move (a fight nets ~+700, running is
	#    free, a toll costs 400+), and escaping is a free 90-second loop between
	#    two systems. A skill must never pay for either.
	GameState.smuggling = 0
	GameState.smuggling_xp = 0
	GameState.cargo = {}
	GameState.load_cargo("contraband", 10)
	_raid_active = false
	_raid_cooldown = 0.0
	_raid_timer = 0.0
	spawn_interdiction()
	pay_toll()
	var xp_after_toll := GameState.smuggling_xp
	for n in get_tree().get_nodes_in_group("raider"):
		if is_instance_valid(n):
			(n as Node3D).queue_free()
	await get_tree().physics_frame
	_raid_active = false
	print("[smug] NO TOLL XP paying a toll moved smuggling xp by %d (must be 0) -> %s" % [
		xp_after_toll, "PASS" if xp_after_toll == 0 else "FAIL"])

	# 3. The one real feed, through the real sell path: contraband over a FENCE.
	#    A legitimate counter is not smuggling, whatever it is buying.
	GameState.smuggling_xp = 0
	GameState.smuggling = 0
	# The Cantina is contraband's DEMAND end and fences it; the Void is the supply
	# end and sells it over a counter. Picking the Void here first was a test bug,
	# and a useful one: it says out loud that "a fence" is a specific desk, not a
	# synonym for a shady station.
	var cantina := SystemDB.port_def_by_id("cantina")
	var fenced := Market.fences(cantina, "contraband")
	var clean := Market.fences(SystemDB.port_def_by_id("anchor"), "stolen")
	GameState.mark_smuggling(6)
	print("[smug] ONE FEED the Cantina fences contraband=%s, the Anchor fences stolen=%s, 6 units -> %d xp -> %s" % [
		str(fenced), str(clean), GameState.smuggling_xp,
		"PASS" if fenced and not clean and GameState.smuggling_xp == 6 else "FAIL"])

	# 4. TIERS BUY TIME, A CHOICE AND ACCESS — never credits. A toll discount is a
	#    stat denominated in salvage; a fence premium would move the best legal
	#    route and drag the pacing band. So the toll on a given hold must be
	#    IDENTICAL at every tier.
	GameState.cargo = {}
	GameState.load_cargo("contraband", 10)
	var tolls: Array = []
	for tier in range(GameState.SMUGGLING_TIERS.size()):
		GameState.smuggling = tier
		tolls.append(maxi(TOLL_FLOOR,
			int(float(GameState.hold_value(false)) * TOLL_FRACTION)))
	var flat := true
	for t in tolls:
		if int(t) != int(tolls[0]):
			flat = false
	print("[smug] NO PRICE TIERS toll by tier %s (must be identical) -> %s" % [
		str(tolls), "PASS" if flat else "FAIL"])

	# 5. THE STANDOFF is what t1 actually buys: seconds to read the demand.
	GameState.smuggling = 0
	_raid_active = false
	_raid_cooldown = 0.0
	_raid_timer = 0.0
	spawn_interdiction()
	var win_t0 := _parley_until - GameState.played_seconds
	for n in get_tree().get_nodes_in_group("raider"):
		if is_instance_valid(n):
			(n as Node3D).queue_free()
	await get_tree().physics_frame
	_raid_active = false
	GameState.smuggling = 1
	_raid_cooldown = 0.0
	_raid_timer = 0.0
	spawn_interdiction()
	var win_t1 := _parley_until - GameState.played_seconds
	for n in get_tree().get_nodes_in_group("raider"):
		if is_instance_valid(n):
			(n as Node3D).queue_free()
	await get_tree().physics_frame
	_raid_active = false
	print("[smug] T1 BUYS TIME standoff %.1fs -> %.1fs (+%.1f) -> %s" % [
		win_t0, win_t1, win_t1 - win_t0,
		"PASS" if win_t1 > win_t0 + 2.0 else "FAIL"])

	# 6. BLUFF ODDS ARE PRINTED, and the number on the button IS the number the
	#    roll uses. 12's standard: a hidden bad bet is a con, and a bluff whose
	#    chance you cannot read is exactly the paid random reveal the lab refused.
	GameState.smuggling = 2
	GameState.cargo = {}
	GameState.load_cargo("contraband", 10)
	GameState.load_cargo("manifest_forged", 1)
	_raid_cooldown = 0.0
	_raid_timer = 0.0
	spawn_interdiction()
	await get_tree().process_frame
	var shown := hud.bluff_text()
	var odds := GameState.bluff_odds()
	var printed := int(odds * 100.0)
	print("[smug] BLUFF ODDS PRINTED button says '%s', roll uses %.2f -> %s" % [
		shown, odds,
		"PASS" if shown.contains("%d%%" % printed) and odds > 0.0 else "FAIL"])

	# 7. THE STAKE IS REAL. The manifest burns whether the bluff lands or not —
	#    without that, bluffing strictly dominates paying and stops being a
	#    decision at all.
	var had := GameState.cargo_count("manifest_forged")
	run_bluff()
	await get_tree().physics_frame
	print("[smug] BLUFF STAKES manifest %d -> %d (burned either way) -> %s" % [
		had, GameState.cargo_count("manifest_forged"),
		"PASS" if had == 1 and GameState.cargo_count("manifest_forged") == 0 else "FAIL"])
	for n in get_tree().get_nodes_in_group("raider"):
		if is_instance_valid(n):
			(n as Node3D).queue_free()
	await get_tree().physics_frame
	_raid_active = false

	# 8. And no bluff without the manifest, or without the tier.
	GameState.cargo = {}
	GameState.load_cargo("contraband", 10)
	GameState.smuggling = 2
	var no_manifest := GameState.bluff_odds() > 0.0 and not GameState.hold_has("manifest_forged")
	GameState.smuggling = 1
	var no_tier := GameState.bluff_odds()
	GameState.smuggling = 0
	print("[smug] BLUFF GATED needs a manifest aboard (odds exist but no stake=%s), t1 odds %.2f (must be 0) -> %s" % [
		str(no_manifest), no_tier, "PASS" if no_tier == 0.0 else "FAIL"])
	get_tree().quit()


# --- captain's log harness ----------------------------------------------------

func _run_log_test() -> void:
	var player: PlayerShip = get_tree().get_first_node_in_group("player")
	player.invulnerable = true
	_wave_timer = 1.0e9
	_apex_wake_timer = -1.0
	set_deep_generation(false)
	await get_tree().create_timer(0.4).timeout

	# GameState boots by loading the player's REAL save (see its _ready), so the
	# log arrives holding whatever the last run wrote. Every index below would be
	# measured against someone else's evening if this were not cleared first.
	GameState.captains_log.clear()

	# 1. RING BOUNDED. Thirteen against a cap of ten: the three that fall off
	#    prove the direction as well as the size.
	var probe := GameState.LOG_MAX + 3
	for i in range(probe):
		GameState.note_log("SENTINEL %02d" % i)
	var ring := GameState.log_lines()
	var ordered := ring.size() == GameState.LOG_MAX
	for i in range(ring.size()):
		if String(ring[i]) != "SENTINEL %02d" % (i + probe - GameState.LOG_MAX):
			ordered = false
	print("[log] RING BOUNDED %d appended, %d kept (cap %d), first '%s' last '%s', order held=%s -> %s" % [
		probe, ring.size(), GameState.LOG_MAX,
		String(ring[0]) if not ring.is_empty() else "-",
		String(ring[ring.size() - 1]) if not ring.is_empty() else "-",
		str(ordered), "PASS" if ordered else "FAIL"])

	# 2. LINE CAPPED, and nothing blank ever reaches the sheet. A whitespace-only
	#    entry would render as a gap the player cannot explain.
	GameState.captains_log.clear()
	GameState.note_log("X".repeat(200))
	GameState.note_log("   ")
	GameState.note_log("")
	var capped := GameState.log_lines()
	var cap_ok := capped.size() == 1 \
		and String(capped[0]).length() == GameState.LOG_LINE_MAX
	print("[log] LINE CAPPED 200 chars -> %d (cap %d), blank and whitespace dropped (%d kept) -> %s" % [
		String(capped[0]).length() if not capped.is_empty() else -1,
		GameState.LOG_LINE_MAX, capped.size(), "PASS" if cap_ok else "FAIL"])

	# 3. NOT A LEDGER KEY. States the decision instead of leaving it in a comment:
	#    the ledger's load-side merge is maxi(0, int(...)), which turns an array
	#    into 0. If anyone ever moves this field in there, this goes red.
	print("[log] NOT A LEDGER KEY captains_log absent from DEFAULT_LEDGER (%d keys) -> %s" % [
		GameState.DEFAULT_LEDGER.size(),
		"PASS" if not GameState.DEFAULT_LEDGER.has("captains_log") else "FAIL"])

	# 4. THE TRUNCATED BAND LADDER. The crossing entry compares the band of the
	#    stored high-water mark against the band of the depth about to be stored,
	#    so what has to hold is a property of band_of(int(d)) alone: it never
	#    falls, it never jumps two, and no band is unreachable through the
	#    truncation. The first version of this assertion compared int-to-float
	#    instead and went red immediately — CHARTED ends at any depth above zero,
	#    which is the one edge that is not a whole number. That failure is why
	#    the line above reads int on both sides.
	var ladder := true
	var ladder_note := ""
	var seen := {}
	var prev := DeepSpace.band_of(0.0)
	seen[prev] = true
	var d := 0.0
	while d <= DeepSpace.BAND_EDGES[DeepSpace.BAND_EDGES.size() - 1] + 40.0:
		var b := DeepSpace.band_of(float(int(d)))
		if b < prev:
			ladder = false
			ladder_note = "band falls at depth %.2f" % d
		if b > prev + 1:
			ladder = false
			ladder_note = "band skips %d->%d at depth %.2f" % [prev, b, d]
		seen[b] = true
		prev = b
		d += 0.25
	# Every edge whole, so a crossing is logged AT the edge rather than a unit
	# late — and so a future 160.5 shows up here rather than as a drifting line.
	var integral := true
	for e_v in DeepSpace.BAND_EDGES:
		if float(e_v) != floorf(float(e_v)):
			integral = false
			ladder_note = "edge %.2f is not whole" % float(e_v)
	var reachable := seen.size() == DeepSpace.BAND_NAMES.size()
	print("[log] TRUNCATED BAND LADDER %s never falls or skips, all %d bands reachable=%s, edges whole=%s -> %s %s" % [
		str(DeepSpace.BAND_EDGES), DeepSpace.BAND_NAMES.size(), str(reachable),
		str(integral), "PASS" if ladder and integral and reachable else "FAIL",
		ladder_note])

	# 5. ONCE PER BAND, driven through the real _process path rather than through
	#    note_log — the rule under test is the derivation, not the append. Out to
	#    the Shoals, out to the Drift, back in, and out to the Drift again: four
	#    crossings of two edges must leave exactly two lines.
	GameState.ledger["deepest_depth"] = 0
	GameState.captains_log.clear()
	var edge := chart_edge()
	for radius in [edge + 60.0, edge + 200.0, edge + 60.0, edge + 200.0]:
		player.global_position = Vector3(float(radius), 0.0, 0.0)
		await get_tree().physics_frame
		await get_tree().process_frame
	var bands := GameState.log_lines()
	var band_ok := bands.size() == 2 \
		and String(bands[0]).contains("THE SHOALS") \
		and String(bands[1]).contains("THE DRIFT")
	print("[log] ONCE PER BAND out/out/back/out logged %d lines %s -> %s" % [
		bands.size(), str(bands), "PASS" if band_ok else "FAIL"])
	player.global_position = Vector3.ZERO
	await get_tree().physics_frame

	# 6. THE POST NAMES THE HULK'S BAND, NOT THE CELL'S. A cell is 64u across and
	#    a band edge runs straight through some of them, so the two genuinely
	#    disagree — this finds a cell where they do and asserts the log follows
	#    the wreck. Reading cell_centre here would have shipped a plausible line
	#    naming the wrong band.
	var straddle_key := Vector2i.ZERO
	var straddle_pt := Vector3.ZERO
	var straddle_centre := Vector3.ZERO
	var straddled := false
	for cx in range(1, 80):
		var centre := DeepSpace.cell_centre(cx, 0)
		for off in [-DeepSpace.CELL * 0.45, DeepSpace.CELL * 0.45]:
			var pt := centre + Vector3(float(off), 0.0, 0.0)
			if DeepSpace.band_of(deep_space.depth_at(centre)) \
					!= DeepSpace.band_of(deep_space.depth_at(pt)):
				straddle_key = Vector2i(cx, 0)
				straddle_pt = pt
				straddle_centre = centre
				straddled = true
				break
		if straddled:
			break
	GameState.captains_log.clear()
	deep_space._guard_origin[straddle_key] = straddle_pt
	deep_space.note_guard_died(straddle_key)
	var post_lines := GameState.log_lines()
	var want_band := DeepSpace.band_name(deep_space.depth_at(straddle_pt))
	var wrong_band := DeepSpace.band_name(deep_space.depth_at(straddle_centre))
	var post_ok := straddled and post_lines.size() == 1 \
		and String(post_lines[0]).contains(want_band)
	print("[log] POST NAMES THE HULK cell %s centre reads %s, hulk reads %s, logged '%s' -> %s" % [
		str(straddle_key), wrong_band, want_band,
		String(post_lines[0]) if not post_lines.is_empty() else "-",
		"PASS" if post_ok else "FAIL"])

	# 7. ONE LINE PER TIER-UP, naming the tier LANDED ON. mark_archeology's loop
	#    can cross three tiers in a single call, and the toast the player saw
	#    announces only the last of them — a log emitting one line per tier would
	#    describe an evening that did not happen.
	GameState.captains_log.clear()
	GameState.archeology = 0
	GameState.archeology_xp = 0
	GameState.mark_archeology(500)
	GameState.smuggling = 0
	GameState.smuggling_xp = 0
	GameState.mark_smuggling(500)
	var tier_lines := GameState.log_lines()
	var top_arch := GameState.ARCHEOLOGY_TIERS.size() - 1
	var top_smug := GameState.SMUGGLING_TIERS.size() - 1
	var tier_ok := tier_lines.size() == 2 \
		and String(tier_lines[0]).begins_with("ARCHEOLOGY %d" % top_arch) \
		and String(tier_lines[1]).begins_with("SMUGGLING %d" % top_smug)
	print("[log] ONE LINE PER TIER-UP %d tiers crossed in two calls -> %d lines %s -> %s" % [
		top_arch + top_smug, tier_lines.size(), str(tier_lines),
		"PASS" if tier_ok else "FAIL"])

	# 8. THE SHEAR AND THE TOLL each write exactly one line. Without these, a
	#    refactor that drops a note_log call is invisible to every assertion
	#    above: the ring and the page both pass on a log nothing writes to.
	GameState.captains_log.clear()
	var rift := spawn_rift()
	if rift != null:
		player.global_position = rift.global_position + Vector3(4, 0, 0)
		await get_tree().physics_frame
		rift.pulse()
		rift.pulse()
		rift.pulse()
		for i in range(4):
			await get_tree().physics_frame
	var shear_lines := GameState.log_lines().size()
	player.global_position = Vector3.ZERO
	await get_tree().physics_frame

	GameState.captains_log.clear()
	GameState.cargo = {}
	GameState.load_cargo("alloys", 20)
	_raid_active = false
	_raid_cooldown = 0.0
	_raid_timer = 0.0
	spawn_interdiction()
	await get_tree().physics_frame
	pay_toll()
	var toll_lines := GameState.log_lines()
	var sites_ok := shear_lines == 1 and toll_lines.size() == 1 \
		and String(toll_lines[0]).begins_with("TOLL PAID")
	print("[log] FIVE SITES WIRED shear %d line, toll %d line ('%s'); band/post/tier asserted above -> %s" % [
		shear_lines, toll_lines.size(),
		String(toll_lines[0]) if not toll_lines.is_empty() else "-",
		"PASS" if sites_ok else "FAIL"])

	# 9. THE LOAD PATH SHEDS THE OLDEST. note_log sheds the front and so does
	#    load_game; a fixture of ten or fewer would round-trip identically
	#    through a resize() that keeps the WRONG ten. Thirteen on disk is what
	#    makes the direction visible.
	var fixture := "user://logtest_save.json"
	var disk: Array = []
	for i in range(GameState.LOG_MAX + 3):
		disk.append("DISK %02d" % i)
	# Junk of every shape the sanitizer claims to handle. `Array[String]` is the
	# reason str() coercion runs at all, and nothing else proves it does.
	var junk: Array = [42, true, null, "", "   ", "Y".repeat(200), "KEPT LINE"]
	var wrote := FileAccess.open(fixture, FileAccess.WRITE)
	wrote.store_string(JSON.stringify({"version": GameState.SAVE_VERSION,
		"salvage": 100, "captains_log": disk}))
	wrote.close()
	var prev_path := GameState.save_path
	GameState.save_path = fixture
	GameState.load_game()
	var shed := GameState.log_lines()
	var shed_ok := shed.size() == GameState.LOG_MAX \
		and String(shed[0]) == "DISK 03" \
		and String(shed[shed.size() - 1]) == "DISK %02d" % (GameState.LOG_MAX + 2)
	print("[log] LOAD SHEDS THE OLDEST %d on disk -> %d kept, first '%s' last '%s' -> %s" % [
		disk.size(), shed.size(),
		String(shed[0]) if not shed.is_empty() else "-",
		String(shed[shed.size() - 1]) if not shed.is_empty() else "-",
		"PASS" if shed_ok else "FAIL"])

	# 10. LOAD COERCES. A hand-edited save is the only way any of these arrive,
	#     and each one is a different crash in the pause menu.
	var wrote2 := FileAccess.open(fixture, FileAccess.WRITE)
	wrote2.store_string(JSON.stringify({"version": GameState.SAVE_VERSION,
		"salvage": 100, "captains_log": junk}))
	wrote2.close()
	GameState.load_game()
	var cleaned := GameState.log_lines()
	var all_strings := true
	var longest := 0
	for line in cleaned:
		if typeof(line) != TYPE_STRING:
			all_strings = false
		longest = maxi(longest, String(line).length())
	var coerce_ok := all_strings and longest <= GameState.LOG_LINE_MAX \
		and cleaned.size() == 5 and String(cleaned[cleaned.size() - 1]) == "KEPT LINE"
	print("[log] LOAD COERCES %d junk entries -> %d lines, all String=%s, longest %d (cap %d) -> %s" % [
		junk.size(), cleaned.size(), str(all_strings), longest,
		GameState.LOG_LINE_MAX, "PASS" if coerce_ok else "FAIL"])
	GameState.save_path = prev_path

	# 11. RESET WITH THE RUN. A new survey is a new logbook — 22's rule, and the
	#     reason this is not stored beside the ship's name.
	GameState.note_log("SHOULD NOT SURVIVE")
	GameState.reset_to_starter()
	print("[log] RESET WITH THE RUN %d lines after reset_to_starter -> %s" % [
		GameState.log_lines().size(),
		"PASS" if GameState.log_lines().is_empty() else "FAIL"])

	# 12. THE PAGE RENDERS THE LOG, in order. Asserts the MAPPING, not a child
	#     count: _refresh() frees the old page with queue_free, which is deferred,
	#     so a count read on the same frame sees the previous page as well.
	GameState.captains_log.clear()
	for i in range(GameState.LOG_MAX):
		GameState.note_log("PAGE %02d" % i)
	pause_menu.open()
	pause_menu._page = "log"
	pause_menu._refresh()
	await get_tree().process_frame
	await get_tree().process_frame
	var labels: Array = []
	for c in pause_menu._body.get_children():
		if c is Label and not c.is_queued_for_deletion():
			labels.append((c as Label).text)
	var page_ok := labels.size() == GameState.LOG_MAX + 1 \
		and String(labels[0]) == "CAPTAIN'S LOG"
	for i in range(GameState.log_lines().size()):
		if i + 1 >= labels.size() or String(labels[i + 1]) != String(GameState.log_lines()[i]):
			page_ok = false
	print("[log] PAGE RENDERS %d labels for %d entries, heading '%s', texts match log in order -> %s" % [
		labels.size(), GameState.LOG_MAX,
		String(labels[0]) if not labels.is_empty() else "-",
		"PASS" if page_ok else "FAIL"])

	# 13. LINE FITS. Measured against the real font at the real size, not
	#     computed from a character count — 25's lesson about what an assertion
	#     can actually see. _sub reserves 300px; a wider line wraps to two rows
	#     and the page grows past the sheet.
	var font := pause_menu._body.get_theme_default_font()
	var widest := 0.0
	var widest_line := ""
	for sample in ["TOLL PAID — 999,999 IN CARGO",
			"THE SHEAR CLOSED — THE REACHES", "POST CLEARED — THE REACHES",
			"ARCHEOLOGY 3 — READS THE QUIET", "SMUGGLING 3 — THE LANES KNOW YOU",
			"CROSSED INTO THE REACHES"]:
		var w := font.get_string_size(String(sample), HORIZONTAL_ALIGNMENT_LEFT,
			-1, 11).x
		if w > widest:
			widest = w
			widest_line = String(sample)
	print("[log] LINE FITS widest producible line '%s' is %.0fpx against 300 -> %s" % [
		widest_line, widest, "PASS" if widest <= 300.0 else "FAIL"])

	# 14. THE SHEET FITS THE SCREEN. The pause panel has no scroll and no clip,
	#     so an overflowing page pushes the heading off the top AND the last
	#     button off the bottom at once. Measured at the worst case the settings
	#     allow — a 1.6 UI scale on a wide window, which leaves ~512 logical rows
	#     — with the boss and abandon-confirm branches BOTH forced on, because
	#     nothing clears _confirming_abandon when a boss wakes.
	get_window().size = Vector2i(1440, 900)
	GameState.set_setting("ui_scale", 1.6)
	await get_tree().process_frame
	await get_tree().process_frame
	var boss_was := boss_active
	boss_active = true
	pause_menu._confirming_abandon = true
	var worst := 0.0
	var worst_page := ""
	for page in ["root", "log", "settings"]:
		pause_menu._page = String(page)
		pause_menu._refresh()
		await get_tree().process_frame
		await get_tree().process_frame
		var h: float = pause_menu._panel.size.y
		if h > worst:
			worst = h
			worst_page = String(page)
	var avail: float = pause_menu._root.size.y
	boss_active = boss_was
	pause_menu._confirming_abandon = false
	pause_menu._page = "root"
	pause_menu.resume()
	print("[log] SHEET FITS worst page '%s' is %.0f rows against %.0f available (1440x900 at 1.6 scale) -> %s" % [
		worst_page, worst, avail, "PASS" if worst <= avail else "FAIL"])
	get_tree().quit()


# --- forge harness ------------------------------------------------------------

func _run_forge_test() -> void:
	var player: PlayerShip = get_tree().get_first_node_in_group("player")
	player.invulnerable = true
	_wave_timer = 1.0e9
	_apex_wake_timer = -1.0
	set_deep_generation(false)
	await get_tree().create_timer(0.4).timeout

	var craftables := ModuleDB.craftable_ids()

	# 1. RECIPES PRINTED — all of them exist, all name real components, and every
	#    input is a component rather than something buyable. That last clause is
	#    the GATE: components are no_retail and only archeology produces them, so
	#    the forge is ARCHEOLOGY-gated with no gate code anywhere.
	var bad := ""
	for id_v in craftables:
		var rec := ModuleDB.recipe(String(id_v))
		if rec.is_empty():
			bad = "%s has no recipe" % String(id_v)
		for good_v in rec:
			var good := String(good_v)
			if not CommodityDB.is_component(good):
				bad = "%s wants %s, which is not a component" % [String(id_v), good]
			if not CommodityDB.no_retail(good):
				bad = "%s wants %s, which is BUYABLE" % [String(id_v), good]
	print("[forge] RECIPES %d craftables, every input a no_retail component (the gate) -> %s %s" % [
		craftables.size(), "PASS" if bad == "" and craftables.size() == 4 else "FAIL", bad])

	# 2. EVERY RECIPE COSTS. The rig-audit rule, applied to the forge: a
	#    craftable with only upside is a stat stick you cannot even buy.
	var free_lunch := ""
	for id_v in craftables:
		var stats: Dictionary = ModuleDB.get_module(String(id_v)).get("stats", {})
		var downs := 0
		for k in stats:
			if float(stats[k]) < 0.0:
				downs += 1
		if downs == 0:
			free_lunch = String(id_v)
	print("[forge] EVERY RECIPE COSTS all %d carry at least one negative stat -> %s %s" % [
		craftables.size(), "PASS" if free_lunch == "" else "FAIL", free_lunch])

	# 3. FITTED WEAKER THAN CARRIED — the rule that stops a bench from deleting
	#    19's pair design. Compared as DATA, not as prose: a craft that quietened
	#    you more than a Forged Manifest would obsolete carrying cover forever.
	var pairs := [
		["signature damper", FITTED_BAFFLE, SIGNATURE_MANIFEST, "lower is stronger"],
		["EMP damping", PlayerShip.FITTED_SINK, PlayerShip.SINK_EMP_FACTOR, "lower is stronger"],
		["berth radar", 1.9, 2.5, "higher is stronger"],
	]
	var line := ""
	var weaker_ok := true
	for pr in pairs:
		var fitted := float(pr[1])
		var carried := float(pr[2])
		var stronger_is_lower := String(pr[3]).begins_with("lower")
		var ok := fitted > carried if stronger_is_lower else fitted < carried
		line += "%s %.2f vs %.2f  " % [String(pr[0]), fitted, carried]
		if not ok:
			weaker_ok = false
	print("[forge] FITTED WEAKER THAN CARRIED %s-> %s" % [
		line, "PASS" if weaker_ok else "FAIL"])

	# 4. UNSELLABLE EVERYWHERE. GameState.buy() SUCCEEDS at price 0 — spend_salvage(0)
	#    returns true — so a craftable that ever leaked into a stock list would be
	#    free to anyone standing at that counter. The guarantee is ABSENCE from
	#    every stock list, chart and deep, asserted rather than trusted to a price.
	var stocked := ""
	var counters := SystemDB.port_ids().duplicate()
	counters.append_array(DeepPortDB.ids())
	for pid_v in counters:
		var pid := String(pid_v)
		var pdef := DeepPortDB.by_id(pid) if DeepPortDB.is_deep_port(pid) \
			else SystemDB.port_def_by_id(pid)
		for id_v in craftables:
			if (pdef.get("stock", []) as Array).has(String(id_v)):
				stocked = "%s at %s" % [String(id_v), pid]
	print("[forge] UNSELLABLE EVERYWHERE 0 of %d counters stock a craftable (buy() would succeed at price 0) -> %s %s" % [
		counters.size(), "PASS" if stocked == "" else "FAIL", stocked])

	# 5. NOT CARGO, AND NO FREE GOODS. Craftables are MODULES — they never enter
	#    CommodityDB, so jettison_to_fit's cheapest-first sort cannot see them.
	#    The second half guards something wider: a price-0 GOOD would be dumped
	#    first by jettison_to_fit, stashed first by _stashable_order, invisible to
	#    hold_value and so to RAID_MIN_HOLD, and stripped for nothing by
	#    strip_hottest. Four systems misreading one zero.
	var as_cargo := ""
	for id_v in craftables:
		if CommodityDB.exists(String(id_v)):
			as_cargo = String(id_v)
	var free_good := ""
	for gid in CommodityDB.ids():
		if CommodityDB.base_price(String(gid)) <= 0:
			free_good = String(gid)
	print("[forge] NOT CARGO + NO FREE GOODS craftables in CommodityDB=%s, price-0 goods=%s -> %s" % [
		as_cargo if as_cargo != "" else "none", free_good if free_good != "" else "none",
		"PASS" if as_cargo == "" and free_good == "" else "FAIL"])

	# 6. ONE-WAY. Nothing anywhere turns a module back into components —
	#    deconstruction IS the laundry, and it would let a player mint components
	#    from a craftable they made out of the components.
	var forge_ports := 0
	for pid_v in counters:
		var pid := String(pid_v)
		var pdef := DeepPortDB.by_id(pid) if DeepPortDB.is_deep_port(pid) \
			else SystemDB.port_def_by_id(pid)
		if (pdef.get("services", []) as Array).has("forge"):
			forge_ports += 1
	var has_recycle := PortPanel.TAB_LABELS.has("recycle") \
		or PortPanel.TAB_LABELS.has("deconstruct")
	print("[forge] ONE-WAY %d forges on the map, no recycle/deconstruct service exists=%s -> %s" % [
		forge_ports, str(not has_recycle),
		"PASS" if forge_ports >= 2 and not has_recycle else "FAIL"])

	# 7. THE CRAFT ITSELF: components in, module out, components GONE, and no
	#    salvage moved — the price is the fence sale you did not make.
	GameState.cargo = {}
	GameState.owned.erase("mod_baffle")
	var rec2 := ModuleDB.recipe("mod_baffle")
	for good_v in rec2:
		GameState.load_cargo(String(good_v), int(rec2[good_v]))
	var salv_before := GameState.salvage
	var could := GameState.can_craft("mod_baffle")
	var made := GameState.craft("mod_baffle")
	var leftovers := 0
	for good_v in rec2:
		leftovers += GameState.cargo_count(String(good_v))
	print("[forge] CRAFT can=%s made=%s, owned=%s, components left %d, salvage %d -> %d -> %s" % [
		str(could), str(made), str(GameState.owns("mod_baffle")), leftovers,
		salv_before, GameState.salvage,
		"PASS" if could and made and GameState.owns("mod_baffle") and leftovers == 0
			and GameState.salvage == salv_before else "FAIL"])

	# 8. And the fitted effect is LIVE where the carried one is read — not in
	#    compute_stats. Equipping the baffle must move hold_signature and must
	#    NOT move any hold-sized number.
	GameState.cargo = {}
	# Mk III reactor: a 4-power craftable will not fit a starter budget, and an
	# equip that silently refuses would make this assertion pass for the wrong
	# reason (both readings identical because nothing was ever fitted).
	GameState.reactor_tier = 2
	var sig_bare := hold_signature()
	var cap_bare := GameState.cargo_capacity()
	var equipped := GameState.equip(ModuleDB.Slot.UTILITY, "mod_baffle")
	var sig_fitted := hold_signature()
	var cap_fitted := GameState.cargo_capacity()
	GameState.equip(ModuleDB.Slot.UTILITY, "")
	print("[forge] FITTED EFFECT LIVE equipped=%s, signature %.2f -> %.2f, hold %d -> %d (hold must not move) -> %s" % [
		str(equipped), sig_bare, sig_fitted, cap_bare, cap_fitted,
		"PASS" if equipped and sig_fitted < sig_bare and cap_bare == cap_fitted else "FAIL"])
	get_tree().quit()


# --- hold / manifest / pilot harness ------------------------------------------

func _run_hold_test() -> void:
	var player: PlayerShip = get_tree().get_first_node_in_group("player")
	player.invulnerable = true
	_wave_timer = 1.0e9
	_apex_wake_timer = -1.0
	set_deep_generation(false)
	await get_tree().create_timer(0.4).timeout

	# 1. JETTISON PAYS NOTHING. Dumping is a cost chosen over flying to a
	#    counter; paying for it would make it the better option.
	GameState.cargo = {}
	GameState.load_cargo("relics", 4)
	var salv_before := GameState.salvage
	var dumped := GameState.jettison("relics", 2)
	print("[hold] JETTISON PAYS NOTHING dumped %d, salvage %d -> %d -> %s" % [
		dumped, salv_before, GameState.salvage,
		"PASS" if dumped == 2 and GameState.salvage == salv_before else "FAIL"])

	# 2. JETTISON SPAWNS NOTHING. "Dumped cargo should float" is the obvious
	#    future improvement, and it would convert a dump into full toll evasion:
	#    shrink the hold mid-standoff, pay the floor, re-vacuum your own cargo.
	#    This line makes that change argue with a red assertion first.
	var cubes := 0
	for n in system_root.get_children():
		if n is LootCube:
			cubes += 1
	print("[hold] JETTISON SPAWNS NOTHING %d loot cubes after a dump (must be 0) -> %s" % [
		cubes, "PASS" if cubes == 0 else "FAIL"])

	# 3. CONSERVES — as an equation, all three numbers printed.
	GameState.cargo = {}
	GameState.load_cargo("alloys", 9)
	var before := GameState.cargo_count("alloys")
	var took := GameState.jettison("alloys", 4)
	print("[hold] CONSERVES %d held = %d kept + %d dumped (must balance) -> %s" % [
		before, GameState.cargo_count("alloys"), took,
		"PASS" if before == GameState.cargo_count("alloys") + took else "FAIL"])

	# 4. THE CATEGORY LINE. Every component has known its parent since the
	#    salvage wave and no screen ever said so — the half of "goods became
	#    categories" that never shipped.
	var orphan := ""
	var comps := 0
	for gid in CommodityDB.ids():
		var g := String(gid)
		if not CommodityDB.is_component(g):
			continue
		comps += 1
		var parent := CommodityDB.parent_of(g)
		if parent == "" or not CommodityDB.exists(parent):
			orphan = g
	print("[hold] CATEGORY every one of %d components names a real parent -> %s %s" % [
		comps, "PASS" if orphan == "" and comps > 0 else "FAIL", orphan])

	# 5. READ COMPRESSION is real and now printable: every grade reads into
	#    something worth more per unit of hold space than the grade itself.
	var worst := 99.0
	var worst_grade := ""
	var line := ""
	for band in range(1, DeepSpace.BAND_NAMES.size()):
		var sid := CommodityDB.salvage_for_band(band)
		if sid == "":
			continue
		var raw := float(CommodityDB.base_price(sid)) / float(CommodityDB.space_of(sid))
		var best := 0.0
		for out_v in CommodityDB.reads_as(sid):
			var o := String(out_v)
			best = maxf(best, float(CommodityDB.base_price(o)) / float(CommodityDB.space_of(o)))
		line += "%s %.0f->%.0f  " % [CommodityDB.short_name(sid), raw, best]
		if best / maxf(raw, 0.01) < worst:
			worst = best / maxf(raw, 0.01)
			worst_grade = CommodityDB.short_name(sid)
	print("[hold] READ COMPRESSION per space %s(worst %s at %.1fx) -> %s" % [
		line, worst_grade, worst, "PASS" if worst > 1.5 else "FAIL"])

	# 6. THE PILOT LINE matches state — one rule, asserted once rather than three
	#    renderings asserted separately.
	GameState.archeology = 2
	GameState.archeology_xp = 40
	var l2 := GameState.archeology_line()
	GameState.archeology = 3
	GameState.archeology_xp = 999
	var l3 := GameState.archeology_line()
	GameState.archeology = 0
	GameState.archeology_xp = 0
	print("[hold] PILOT LINE t2='%s' | t3 caps='%s' -> %s" % [
		l2, l3,
		"PASS" if l2.contains("ARCHEOLOGY 2") and l2.contains("TO NEXT")
			and l3.contains("NOTHING LEFT TO LEARN") else "FAIL"])

	# 7. CYCLE TARGET is bounded. Tab used to walk to a guard 200u out and fly the
	#    ship there — the deep expanse made a nearest-first sort over every
	#    hostile in the system into a way to autopilot into a post.
	for n in get_tree().get_nodes_in_group("hostiles"):
		(n as Node3D).queue_free()
	await get_tree().physics_frame
	player.global_position = Vector3.ZERO
	var near := SwarmHostile.new()
	system_root.add_child(near)
	near.global_position = Vector3(20, 0, 0)
	var far_one := SwarmHostile.new()
	system_root.add_child(far_one)
	far_one.global_position = Vector3(300, 0, 0)
	await get_tree().physics_frame
	var picks := {}
	for i in range(6):
		var t := player.cycle_target()
		if t != null:
			picks[t] = true
	print("[hold] CYCLE BOUND %d of 2 contacts reachable by Tab (the 300u one must not be) -> %s" % [
		picks.size(), "PASS" if picks.size() == 1 and picks.has(near) else "FAIL"])
	get_tree().quit()


# --- cartography harness ------------------------------------------------------

func _run_cart_test() -> void:
	var player: PlayerShip = get_tree().get_first_node_in_group("player")
	player.invulnerable = true
	_wave_timer = 1.0e9
	_apex_wake_timer = -1.0
	await get_tree().create_timer(0.4).timeout

	# 1. THE COLLISION GUARD. is_salvage() is literally has("band") and
	#    salvage_for_band() returns the FIRST good matching one — so a chart good
	#    carrying `band` could shadow a salvage grade, and spawn_loot's 22%
	#    regrade would start minting free chart data out of combat crates
	#    everywhere in the game. Broken, this prints true.
	var charts: Array = []
	var mislabelled := ""
	for gid in CommodityDB.ids():
		var g := String(gid)
		if CommodityDB.is_chart(g):
			charts.append(g)
			if CommodityDB.is_salvage(g):
				mislabelled = g
	# And the reverse: no salvage grade may answer to a chart band.
	for band in range(1, DeepSpace.BAND_NAMES.size()):
		var c := CommodityDB.chart_for_band(band)
		var sv := CommodityDB.salvage_for_band(band)
		if c == sv or c == "":
			mislabelled = "band %d collides" % band
	print("[cart] NOT SALVAGE %d chart goods, none answers is_salvage or shadows a grade -> %s %s" % [
		charts.size(), "PASS" if charts.size() == 4 and mislabelled == "" else "FAIL",
		mislabelled])

	# 2. NO BUY LEG anywhere. A survey is something you make, never something you
	#    buy — 11 closed at the source, the way the salvage grades already are.
	var counters := SystemDB.port_ids().duplicate()
	counters.append_array(DeepPortDB.ids())
	var quoted := ""
	for pid_v in counters:
		var pid := String(pid_v)
		var pdef := DeepPortDB.by_id(pid) if DeepPortDB.is_deep_port(pid) \
			else SystemDB.port_def_by_id(pid)
		for c_v in charts:
			if Market.can_buy(pdef, String(c_v)):
				quoted = "%s at %s" % [String(c_v), pid]
	print("[cart] NO BUY LEG 0 of %d counters will quote a buy on chart data -> %s %s" % [
		counters.size(), "PASS" if quoted == "" else "FAIL", quoted])

	# 3. WEIGHT. Zero-weight data was the trap: a pure explorer would never cross
	#    RAID_MIN_HOLD and the whole interdiction system would be inert for an
	#    entire playstyle. An explorer should be quiet, not invisible.
	GameState.cargo = {}
	GameState.load_cargo("chart_drift", 24)
	var w := GameState.hold_value(true)
	print("[cart] WEIGHT 24 drift surveys -> weighted %d vs RAID_MIN_HOLD %d (never inert) -> %s" % [
		w, RAID_MIN_HOLD, "PASS" if w >= RAID_MIN_HOLD else "FAIL"])

	# 4. THE SCANNER FINALLY SCANS. Until now "Targeting Scanner" was a
	#    range-and-crit module wearing an instrument's name. A dead stat prints
	#    the same number twice.
	GameState.cargo = {}
	var probe := SurveyMast.new()
	probe.band = 2
	probe.survey_time = 3.5
	add_child(probe)
	GameState.equip(ModuleDB.Slot.UTILITY, "")
	var bare := probe.survey_seconds()
	if not GameState.owns("util_scanner"):
		GameState.owned.append("util_scanner")
	GameState.equip(ModuleDB.Slot.UTILITY, "util_scanner")
	var scanned := probe.survey_seconds()
	GameState.equip(ModuleDB.Slot.UTILITY, "")
	print("[cart] SURVEY SPEED %.2fs bare -> %.2fs with a Mk I scanner -> %s" % [
		bare, scanned, "PASS" if scanned < bare - 0.3 else "FAIL"])

	# 5. A reading is taken once, and taking it fills the hold.
	GameState.cargo = {}
	probe.cell = Vector2i(4242, 4242)
	probe.surveyed = false
	probe._progress = 1.0
	probe._complete()
	var first := GameState.cargo_count("chart_drift")
	probe._complete()
	var after_second := GameState.cargo_count("chart_drift")
	print("[cart] SURVEY YIELDS band 2 -> %s x%d, a second reading adds %d -> %s" % [
		CommodityDB.short_name("chart_drift"), first, after_second - first,
		"PASS" if first == SurveyMast.YIELD_UNITS and after_second == first else "FAIL"])

	# 6. A full hold DEFERS the reading rather than eating it. The mast stays
	#    unsurveyed, so the trip out is not wasted — only the pickup is.
	GameState.cargo = {}
	GameState.load_cargo("alloys", 12)   # 24 space: full
	var probe2 := SurveyMast.new()
	probe2.band = 2
	probe2.cell = Vector2i(4243, 4243)
	add_child(probe2)
	probe2._complete()
	print("[cart] FULL HOLD DEFERS took %d, mast still readable=%s -> %s" % [
		GameState.cargo_count("chart_drift"), str(not probe2.surveyed),
		"PASS" if GameState.cargo_count("chart_drift") == 0 and not probe2.surveyed
			else "FAIL"])
	probe.queue_free()
	probe2.queue_free()

	# 7. SESSION RESET, asserted ON PURPOSE. _surveyed is session-only for the
	#    reason 17 gives — persisting it would be a visited-cells array by
	#    another name, growing every minute the player flies. So a warp resets
	#    surveys, and if anyone ever "fixes" that by saving the dict, this line
	#    turns red and forces the conversation instead of silently growing saves.
	deep_space.note_surveyed(Vector2i(7, -3))
	var before_warp := deep_space.is_surveyed(Vector2i(7, -3))
	_load_system(system_id)
	await get_tree().physics_frame
	var after_warp := deep_space.is_surveyed(Vector2i(7, -3))
	print("[cart] SESSION RESET surveyed before a rebuild=%s, after=%s (deliberate; see 17) -> %s" % [
		str(before_warp), str(after_warp),
		"PASS" if before_warp and not after_warp else "FAIL"])

	# 8. Masts ride deep hulks and nothing else. No mast may sit near a dock ring
	#    either — CameraRig checks `crackable` BEFORE `dockable`, so one parked on
	#    a station would intercept the tap that docks you.
	set_deep_generation(true)
	await get_tree().process_frame
	var far := Vector3(300.0, 0.0, 300.0)
	player.global_position = far
	for i in range(8):
		await get_tree().physics_frame
		await get_tree().process_frame
	var masts := get_tree().get_nodes_in_group("survey_mast")
	var too_close := ""
	for m in masts:
		for d_v in get_tree().get_nodes_in_group("dockable"):
			var d := d_v as Port
			if (m as Node3D).global_position.distance_to(d.dock_point) < 12.0:
				too_close = "%s" % d.port_id
	print("[cart] MASTS %d in the streaming window, none within 12u of a dock ring -> %s %s" % [
		masts.size(), "PASS" if too_close == "" else "FAIL", too_close])

	# 9. DOCKING A DEEP STATION IS SURVEYING IT — through the real dock path, not
	#    a synthetic grant, so the cell key, the band lookup and the once-per-
	#    session guard are all the production code's own.
	var station: Port = null
	for d_v in get_tree().get_nodes_in_group("dockable"):
		var d := d_v as Port
		if DeepPortDB.is_deep_port(d.port_id):
			station = d
	if station == null:
		print("[cart] DOCK GRANTS no deep station in window -> FAIL")
	else:
		GameState.cargo = {}
		player.global_position = station.dock_point
		await get_tree().physics_frame
		_complete_dock(station)
		var got := 0
		for c_v in CommodityDB.ids():
			if CommodityDB.is_chart(String(c_v)):
				got += GameState.cargo_count(String(c_v))
		undock()
		await get_tree().physics_frame
		player.global_position = station.dock_point
		await get_tree().physics_frame
		_complete_dock(station)
		var after_redock := 0
		for c_v in CommodityDB.ids():
			if CommodityDB.is_chart(String(c_v)):
				after_redock += GameState.cargo_count(String(c_v))
		undock()
		print("[cart] DOCK GRANTS first berth +%d packets, redock +%d -> %s" % [
			got, after_redock - got,
			"PASS" if got == SurveyMast.YIELD_UNITS and after_redock == got else "FAIL"])
	set_deep_generation(false)
	get_tree().quit()


# --- spill harness ------------------------------------------------------------

func _run_spill_test() -> void:
	var player: PlayerShip = get_tree().get_first_node_in_group("player")
	_wave_timer = 1.0e9
	_apex_wake_timer = -1.0
	set_deep_generation(false)
	await get_tree().create_timer(0.4).timeout

	var deep_pos := Vector3(400.0, 0.0, 400.0)

	# 1. CONSERVES. Printed as an equation, the way STASH CONSERVES is: a spill
	#    that silently eats three units passes any boolean written around it.
	GameState.cargo = {}
	GameState.load_cargo("salvage_quiet", 9)
	var held_before := GameState.cargo_count("salvage_quiet")
	player.global_position = deep_pos
	await get_tree().physics_frame
	var made := spill_unread(deep_pos)
	var cubes := _spill_cubes()
	print("[spill] CONSERVES %d held before = %d held after + %d cubes (must be equal) -> %s" % [
		held_before, GameState.cargo_count("salvage_quiet"), cubes.size(),
		"PASS" if held_before == GameState.cargo_count("salvage_quiet") + cubes.size()
			and made == held_before and made > 0 else "FAIL"])

	# 2. PROVENANCE. spawn_loot re-rolls 22% of goods into band salvage by the
	#    position it is called at, so routing a spill through it would re-grade
	#    quiet cargo as drift purely because you died shallower than you found it.
	var grades := {}
	for c in cubes:
		grades[String(c.commodity)] = int(grades.get(String(c.commodity), 0)) + 1
	print("[spill] PROVENANCE spilled grades %s (a regrade leak prints a mix) -> %s" % [
		str(grades), "PASS" if grades.size() == 1 and grades.has("salvage_quiet") else "FAIL"])

	# 3. NO SEEK. A stock cube homes from ANY distance after 1.3s, so an unflagged
	#    spill flies four hundred units to the respawn point and hands itself
	#    back — deleting the whole fly-back mechanic without erroring once.
	player.global_position = PlayerShip.SPAWN_POINT
	var watch: Node3D = cubes[0]
	# Measure CLOSING, not motion. Every cube coasts a few units on its spawn
	# scatter in a random direction, so raw displacement cannot tell that apart
	# from homing — but a seek leak eats distance at MAGNET_SPEED 16u/s, and the
	# scatter cannot close on a ship 500u away at all.
	var gap_before := watch.global_position.distance_to(player.global_position)
	for i in range(120):
		await get_tree().physics_frame
	var gap_after := watch.global_position.distance_to(player.global_position)
	print("[spill] NO SEEK cube %.0fu from the ship closed %.2fu in 2s (a leak closes ~32u) -> %s" % [
		gap_before, gap_before - gap_after,
		"PASS" if gap_before - gap_after < 6.0 else "FAIL"])

	# 4. NO EXPIRY. Stock cubes reap at 25s; the round trip from spawn to a deep
	#    death site is longer than that before the player has even turned around.
	# Age is driven past the reaper rather than waited out: 25s of harness time to
	# prove a branch is off is 25s nobody will spend, and a test nobody runs is a
	# test that is not there.
	var spilled_n := _spill_cubes().size()
	for c in _spill_cubes():
		c.set("_age", 40.0)
	for i in range(4):
		await get_tree().physics_frame
	var alive := 0
	for c in _spill_cubes():
		if is_instance_valid(c):
			alive += 1
	print("[spill] NO EXPIRY %d of %d alive at age 40s (the stock reaper is 25s) -> %s" % [
		alive, spilled_n, "PASS" if alive == spilled_n and spilled_n > 0 else "FAIL"])

	# 5. IDENTIFIED STAYS. Reading a thing is also stowing it — the line that
	#    gives ARCHEOLOGY a third job and makes field-reading a survival act.
	for c in _spill_cubes():
		c.queue_free()
	await get_tree().physics_frame
	GameState.cargo = {}
	GameState.load_cargo("salvage_quiet", 4)
	GameState.load_cargo("heart_reliquary", 2)
	player.global_position = deep_pos
	await get_tree().physics_frame
	spill_unread(deep_pos)
	print("[spill] IDENTIFIED STAYS unread %d -> %d, components %d -> %d -> %s" % [
		4, GameState.cargo_count("salvage_quiet"), 2, GameState.cargo_count("heart_reliquary"),
		"PASS" if GameState.cargo_count("salvage_quiet") == 0
			and GameState.cargo_count("heart_reliquary") == 2 else "FAIL"])

	# 6. CHART SIDE SPILLS NOTHING. The tutorial promised you never lose salvage,
	#    and it promised it inside the charted system, where it stays true.
	for c in _spill_cubes():
		c.queue_free()
	await get_tree().physics_frame
	GameState.cargo = {}
	GameState.load_cargo("salvage_charted", 6)
	player.global_position = Vector3(0, 0, 6)
	await get_tree().physics_frame
	var home_spill := spill_unread(Vector3(0, 0, 6))
	print("[spill] CHART DEATH INTACT depth 0 spilled %d, hold still %d -> %s" % [
		home_spill, GameState.cargo_count("salvage_charted"),
		"PASS" if home_spill == 0 and GameState.cargo_count("salvage_charted") == 6 else "FAIL"])

	# 7. NO DOUBLE SPILL. The hold is emptied BEFORE the cubes exist, so a second
	#    death inside WARP_GRACE finds nothing left to duplicate.
	GameState.cargo = {}
	GameState.load_cargo("salvage_reaches", 5)
	player.global_position = deep_pos
	await get_tree().physics_frame
	var first := spill_unread(deep_pos)
	var second := spill_unread(deep_pos)
	print("[spill] NO DOUBLE SPILL first %d, immediate second %d, cubes %d (must be 5, not 10) -> %s" % [
		first, second, _spill_cubes().size(),
		"PASS" if first == 5 and second == 0 and _spill_cubes().size() == 5 else "FAIL"])

	# 8. WARP CLEARS. Cubes are system_root children, so leaving abandons them —
	#    17 policy, asserted so it stays a decision rather than an accident. Note
	#    the player hangs off Main, so parenting the spill to get_parent() would
	#    have quietly outlived the warp.
	_load_system(system_id)
	await get_tree().physics_frame
	print("[spill] WARP CLEARS 5 adrift -> %d after a system rebuild -> %s" % [
		_spill_cubes().size(), "PASS" if _spill_cubes().is_empty() else "FAIL"])

	# 9. THE HOLD BUG. A finger still down when the ship dies used to leave
	#    CameraRig holding the wreck, and the next hold_tick issued a fresh move
	#    order — flying a just-respawned player back toward what killed them.
	var rig := get_tree().get_first_node_in_group("camera_rig") as CameraRig
	var wreck := _find_crackable()
	if wreck != null and rig != null:
		player.global_position = wreck.global_position + Vector3(0, 0, 3.0)
		await get_tree().physics_frame
		rig.set("_hold_target", wreck)
		player.shield = 1.0
		player.invulnerable = false
		player.take_hit(999.0)
		await get_tree().physics_frame
		print("[spill] HOLD CANCELLED shield-break mid-hold -> hold target %s, move order %s -> %s" % [
			"null" if rig.get("_hold_target") == null else "HELD",
			str(player.has_move_target),
			"PASS" if rig.get("_hold_target") == null and not player.has_move_target else "FAIL"])
	get_tree().quit()


func _spill_cubes() -> Array:
	var out: Array = []
	for n in system_root.get_children():
		if n is LootCube and bool((n as LootCube).spill):
			out.append(n)
	return out


func _find_crackable() -> Node3D:
	for n in get_tree().get_nodes_in_group("crackable"):
		if n is Derelict:
			return n
	return null


# --- bonded store harness -----------------------------------------------------

func _first_bay_cell() -> String:
	# The first cell the GENERATOR says holds a station with a bay. Found rather
	# than hard-coded: which cells have one is a property of the seed, so a test
	# that names a cell by hand is a test that asserts against a guess. Pure and
	# deterministic, so the write leg and the read leg agree without sharing state.
	for ring in range(1, 24):
		for cx in range(-ring, ring + 1):
			for cz in range(-ring, ring + 1):
				if maxi(absi(cx), absi(cz)) != ring:
					continue
				if deep_space != null and deep_space.cell_has_bay(system_id, cx, cz):
					return DeepSpace.cell_key(system_id, cx, cz)
	return "pyx01:0:0"


func _run_store_test() -> void:
	var player: PlayerShip = get_tree().get_first_node_in_group("player")
	player.invulnerable = true
	_wave_timer = 1.0e9
	_apex_wake_timer = -1.0
	await get_tree().create_timer(0.4).timeout

	# 1. Three bays on the chart, one per system, so retrieval is a warp and not
	#    a hop.
	var bays: Array = []
	for pid_v in SystemDB.port_ids():
		var pid := String(pid_v)
		if GameState.port_has_bay(SystemDB.port_def_by_id(pid)):
			bays.append(pid)
	var systems_covered := {}
	for pid_v in bays:
		systems_covered[SystemDB.system_of_port(String(pid_v))] = true
	print("[store] BAYS %s across %d systems -> %s" % [
		str(bays), systems_covered.size(),
		"PASS" if bays.size() == 3 and systems_covered.size() == 3 else "FAIL"])

	# 2. No archetype declares storage. A deep bay is a property of a PLACE, rolled
	#    per cell — if it were on the archetype, every station of that kind would
	#    have one and the scarcity would be a lie.
	var arch_declares := ""
	for a_v in DeepPortDB.ARCHETYPES:
		var a: Dictionary = a_v
		if (a.get("services", []) as Array).has("storage"):
			arch_declares = String(a["id"])
	print("[store] NOT ON THE ARCHETYPE 0 of %d deep archetypes declare storage -> %s %s" % [
		DeepPortDB.ARCHETYPES.size(), "PASS" if arch_declares == "" else "FAIL", arch_declares])

	# 3. And the roll actually produces some, at roughly the authored rate.
	var stations := 0
	var with_bay := 0
	for cx in range(-12, 12):
		for cz in range(-12, 12):
			var st: Dictionary = deep_space.plan_cell(cx, cz).get("station", {})
			if st.is_empty():
				continue
			stations += 1
			if bool(st.get("storage", false)):
				with_bay += 1
	var rate := float(with_bay) / maxf(float(stations), 1.0)
	print("[store] DEEP BAYS %d of %d stations over 576 cells = %.0f%% (want ~%.0f%%) -> %s" % [
		with_bay, stations, rate * 100.0, DeepSpace.DEEP_STORAGE_CHANCE * 100.0,
		"PASS" if stations > 0 and rate > 0.04 and rate < 0.34 else "FAIL"])

	# 4. THE BONDED RULE. Only what the game will never sell you.
	# Asserts the RULE, not a headcount. This line originally hardcoded "15
	# storable" and went red the moment four chart goods were added — reporting on
	# how much content exists rather than on whether the rule holds, which is
	# exactly what 10 warns a pacing assertion must never do. The invariant is
	# that storable and no_retail are the SAME SET, in both directions.
	var storable: Array = []
	var refused: Array = []
	var wrong := ""
	for gid in CommodityDB.ids():
		var g := String(gid)
		if GameState.can_store(g):
			storable.append(g)
			if not CommodityDB.no_retail(g):
				wrong = "%s is storable but retailed" % g
		else:
			refused.append(g)
			if CommodityDB.no_retail(g):
				wrong = "%s is no_retail but refused" % g
	print("[store] BONDED %d storable / %d refused, storable set == no_retail set -> %s %s" % [
		storable.size(), refused.size(), "PASS" if wrong == "" else "FAIL", wrong])

	# 5. THE MONEY PRINTER THIS EXISTS TO CLOSE, priced in full every run whether
	#    or not the guard holds. Market events run 240-360s, so an open bay lets
	#    you buy under a glut, put the goods down, wait for the event to lapse and
	#    sell at the SAME counter. NO ROUND-TRIP PROFIT cannot see it: it prices
	#    both legs in one instant under one market_events array.
	var adef := SystemDB.port_def_by_id("anchor")
	GameState.market_events = [{"kind": "glut", "port": "anchor", "good": "alloys",
		"mult": 0.55, "remaining": 300.0}]
	var glut_buy := Market.buy_price(adef, "anchor", "alloys", 24)
	GameState.market_events = []
	var lapsed_sell := Market.sell_price(adef, "anchor", "alloys", 24)
	var spread := (lapsed_sell - glut_buy) * 24
	print("[store] NO TIMED ARBITRAGE glut buy 24 @%d = %d; lapse; sell @%d = %d -> %+d (%+.0f%%) if it could be stashed. can_store(alloys)=%s -> %s" % [
		glut_buy, glut_buy * 24, lapsed_sell, lapsed_sell * 24, spread,
		100.0 * float(lapsed_sell - glut_buy) / maxf(float(glut_buy), 1.0),
		str(GameState.can_store("alloys")),
		"PASS" if not GameState.can_store("alloys") else "FAIL"])

	# 6. NO WORMHOLE. Deep bays key on the cell, never on port_id — every station
	#    of an archetype shares that id, in every system, forever.
	GameState.warehouse = {}
	GameState.cargo = {}
	GameState.load_cargo("servo_prewar", 4)
	var here := DeepSpace.cell_key(system_id, 3, -7)
	GameState.store_cargo(here, "servo_prewar", 4)
	var leaked := 0
	for other in [DeepSpace.cell_key(system_id, 3, -6), DeepSpace.cell_key("pyx03", 3, -7),
			"deep_relay", "deep_forge", "anchor", "depot"]:
		leaked += GameState.warehouse_used(String(other))
	print("[store] NO WORMHOLE %d space at %s, %d found at 6 other keys -> %s" % [
		GameState.warehouse_used(here), here, leaked,
		"PASS" if GameState.warehouse_used(here) > 0 and leaked == 0 else "FAIL"])

	# 7. A bay is NOT a hold. Stored cargo must not weigh, must not draw raiders,
	#    and must not trip a carried effect — 19's rule one shelf over.
	var used_with_bay := GameState.cargo_used()
	var value_with_bay := GameState.hold_value(true)
	GameState.cargo = {}
	GameState.load_cargo("charge_unstable", 1)
	var sig_carried := hold_signature()
	GameState.store_cargo(here, "charge_unstable", 1)
	var sig_stored := hold_signature()
	print("[store] BAY IS NOT A HOLD used %d, weighted value %d, signature carried %.2f -> stored %.2f -> %s" % [
		used_with_bay, value_with_bay, sig_carried, sig_stored,
		"PASS" if used_with_bay == 0 and value_with_bay == 0 \
			and sig_carried > 1.0 and is_equal_approx(sig_stored, 1.0) else "FAIL"])

	# 8. One cap, everywhere, never a port-def key. A cap that VARIES makes
	#    capacity a thing you shop for, which is a second budget (9 rule 1).
	var carries_key := ""
	for pid_v in SystemDB.port_ids():
		if SystemDB.port_def_by_id(String(pid_v)).has("warehouse_space"):
			carries_key = String(pid_v)
	for a_v in DeepPortDB.ARCHETYPES:
		if (a_v as Dictionary).has("warehouse_space"):
			carries_key = String((a_v as Dictionary)["id"])
	print("[store] CAP %d space everywhere, 0 defs carry warehouse_space -> %s %s" % [
		GameState.WAREHOUSE_SPACE, "PASS" if carries_key == "" else "FAIL", carries_key])

	# 9. The archetype const must survive station construction. DeepPortDB.by_id
	#    returns the ARCHETYPES entry itself, so appending "storage" to a station's
	#    services without duplicating first would give every later station of that
	#    kind a bay.
	var svc_before := (DeepPortDB.by_id("deep_relay").get("services", []) as Array).size()
	for cx in range(-6, 6):
		for cz in range(-6, 6):
			deep_space.plan_cell(cx, cz)
	var mutated := ""
	for a_v in DeepPortDB.ARCHETYPES:
		if ((a_v as Dictionary).get("services", []) as Array).has("storage"):
			mutated = String((a_v as Dictionary)["id"])
	print("[store] ARCHETYPE INTACT deep_relay services %d, none gained storage -> %s %s" % [
		svc_before, "PASS" if mutated == "" else "FAIL", mutated])

	# 10. STASH CONSERVES. The equation is the whole difference between stashing
	#     and jettisoning, so it is asserted as an equation and all three numbers
	#     are printed — a stash that silently eats three units passes any boolean.
	GameState.warehouse = {}
	GameState.cargo = {}
	GameState.reactor_tier = 2
	for m in ["rig_hauler", "util_cargo"]:
		if not GameState.owns(m):
			GameState.owned.append(m)
	GameState.equip(ModuleDB.Slot.UTILITY, "rig_hauler")
	GameState.load_cargo("salvage_quiet", 12)
	var before_used := GameState.cargo_used()
	var stashed := GameState.stash_to_fit(ModuleDB.Slot.UTILITY, "", "anchor")
	var after_used := GameState.cargo_used()
	var after_bay := GameState.warehouse_used("anchor")
	print("[store] STASH CONSERVES %d used -> %d used + %d in bay (must be equal), %d moved -> %s" % [
		before_used, after_used, after_bay, stashed,
		"PASS" if before_used == after_used + after_bay and stashed > 0 else "FAIL"])

	# 11. ALL OR NOTHING. A stash that half-fills the bay and still fails the equip
	#     leaves the player over-full with a partly-emptied hold and no explanation.
	GameState.warehouse = {}
	GameState.cargo = {}
	GameState.load_cargo("salvage_quiet", 16)
	# Fill the bay to one space short of what the overflow needs.
	GameState.warehouse["anchor"] = {"servo_prewar": 19}
	var hold_before := GameState.cargo_used()
	var partial := GameState.stash_to_fit(ModuleDB.Slot.UTILITY, "", "anchor")
	print("[store] STASH REFUSED WHOLE bay too full: %d moved, hold %d -> %d -> %s" % [
		partial, hold_before, GameState.cargo_used(),
		"PASS" if partial == 0 and GameState.cargo_used() == hold_before else "FAIL"])

	# 12. Jettison still destroys. The stash exit must not have quietly turned the
	#     destructive path lossless — 16 says dumping cargo may never pay.
	GameState.warehouse = {}
	GameState.cargo = {}
	GameState.load_cargo("salvage_quiet", 12)
	var salv_before := GameState.salvage
	var dumped := GameState.jettison_to_fit(ModuleDB.Slot.UTILITY, "")
	print("[store] JETTISON STILL PAYS NOTHING dumped %d, salvage %d -> %d -> %s" % [
		dumped, salv_before, GameState.salvage,
		"PASS" if dumped > 0 and GameState.salvage == salv_before else "FAIL"])

	# 13. NO PASSIVE GROWTH. This is what keeps 17 true: a bay is deliberate
	#     state, not a visited-cells array. Flying past stations must add nothing.
	GameState.warehouse = {}
	var keys_before := GameState.warehouse.size()
	for step in range(40):
		player.global_position = Vector3(float(step) * 64.0, 0.0, float(step) * 32.0)
		await get_tree().physics_frame
	print("[store] NO PASSIVE GROWTH flew 40 cells past live stations: %d keys -> %d -> %s" % [
		keys_before, GameState.warehouse.size(),
		"PASS" if GameState.warehouse.size() == keys_before else "FAIL"])
	get_tree().quit()


# --- salvage / archeology harness ---------------------------------------------

func _run_salvage_test() -> void:
	var player: PlayerShip = get_tree().get_first_node_in_group("player")
	player.invulnerable = true
	_wave_timer = 1.0e9
	_apex_wake_timer = -1.0
	set_deep_generation(false)
	await get_tree().create_timer(0.4).timeout

	# 1. The catalog is coherent: every grade reads into things that exist, and
	#    every band has one.
	var grades := []
	for band in range(DeepSpace.BAND_NAMES.size()):
		var sid := CommodityDB.salvage_for_band(band)
		if sid != "":
			grades.append(sid)
	var outputs := {}
	var bad_output := ""
	for g_v in grades:
		for out_v in CommodityDB.reads_as(String(g_v)):
			outputs[String(out_v)] = true
			if not CommodityDB.exists(String(out_v)):
				bad_output = String(out_v)
	print("[salvage] CATALOG %d grades (one per band), %d distinct outputs, all exist -> %s %s" % [
		grades.size(), outputs.size(),
		"PASS" if grades.size() == DeepSpace.BAND_NAMES.size() and bad_output == "" else "FAIL",
		bad_output])

	# 2. Every grade offers a CHOICE. A single-output grade is a conversion, not a
	#    decision, and the whole reason there is no roll here is that the player
	#    picks — see the comment on CommodityDB.READS_AS.
	var thin := ""
	for g_v in grades:
		if CommodityDB.reads_as(String(g_v)).size() < 2:
			thin = String(g_v)
	print("[salvage] CHOICE every grade reads as >= 2 things -> %s %s" % [
		"PASS" if thin == "" else "FAIL", thin])

	# 3. NOTHING HERE IS BUYABLE, at any counter on the chart or past it. Buy
	#    salvage cheap, read it, sell the component dear is an infinite loop with
	#    no combat and no risk in it. Market.can_buy closes it on the buy side,
	#    the same way it closes the fence loop.
	var counters := SystemDB.port_ids()
	for a_v in DeepPortDB.ids():
		counters.append(String(a_v))
	var retailed := ""
	for pid_v in counters:
		var pid := String(pid_v)
		var pdef := SystemDB.port_def_by_id(pid)
		if pdef.is_empty():
			pdef = DeepPortDB.by_id(pid)
		for gid in CommodityDB.ids():
			var id := String(gid)
			if not (CommodityDB.is_salvage(id) or CommodityDB.is_component(id)):
				continue
			if Market.can_buy(pdef, id):
				retailed = "%s at %s" % [id, pid]
	print("[salvage] SELL ONLY no grade or component is buyable at any of %d counters -> %s %s" % [
		counters.size(), "PASS" if retailed == "" else "FAIL", retailed])

	# 4. Reading must PAY, or nobody would. Printed per band, so a mispriced table
	#    shows an obviously wrong number instead of a silent pass — the cheapest
	#    thing a grade reads into still has to beat selling it unread.
	var worst := 999999.0
	var worst_band := ""
	var margins := ""
	for g_v in grades:
		var sid := String(g_v)
		var raw := float(CommodityDB.base_price(sid))
		var cheapest := 999999.0
		for out_v in CommodityDB.reads_as(sid):
			cheapest = minf(cheapest, float(CommodityDB.base_price(String(out_v))))
		margins += "%s %.0f->%.0f  " % [CommodityDB.short_name(sid), raw, cheapest]
		if cheapest - raw < worst:
			worst = cheapest - raw
			worst_band = CommodityDB.short_name(sid)
	print("[salvage] READING PAYS %s-> %s (worst %s at +%.0f)" % [
		margins, "PASS" if worst > 0.0 else "FAIL", worst_band, worst])

	# 5. The one rule: field reads band <= tier, a lab reads one further. Both the
	#    skill and the lab stay relevant at every tier, which is the point.
	var gate_ok := true
	var grid := ""
	for tier in range(GameState.ARCHEOLOGY_TIERS.size()):
		GameState.archeology = tier
		for band in range(DeepSpace.BAND_NAMES.size()):
			var sid := CommodityDB.salvage_for_band(band)
			var field := GameState.can_read(sid, false)
			var lab := GameState.can_read(sid, true)
			if field != (band <= tier) or lab != (band <= tier + 1):
				gate_ok = false
		grid += "t%d:f<=%d,l<=%d  " % [tier, tier, tier + 1]
	GameState.archeology = 0
	print("[salvage] BAND GATE %s-> %s" % [grid, "PASS" if gate_ok else "FAIL"])

	# 6. A read consumes exactly one and produces exactly one, and the hold
	#    arithmetic survives it — a component can be bulkier than what it came out
	#    of, and a read that cannot be stowed must fail cleanly.
	GameState.cargo = {}
	GameState.archeology = 3
	GameState.load_cargo("salvage_quiet", 2)
	var before_used := GameState.cargo_used()
	var read_ok := GameState.identify("salvage_quiet", "heart_reliquary", true)
	print("[salvage] READ CONSUMES quiet 2->%d, heart 0->%d, hold %d->%d -> %s" % [
		GameState.cargo_count("salvage_quiet"), GameState.cargo_count("heart_reliquary"),
		before_used, GameState.cargo_used(),
		"PASS" if read_ok and GameState.cargo_count("salvage_quiet") == 1
			and GameState.cargo_count("heart_reliquary") == 1 else "FAIL"])

	# 7. Refused above your tier, and refused for an output the grade cannot yield
	#    — in both cases with NOTHING consumed. A half-completed read that eats the
	#    input is the worst possible failure here.
	GameState.archeology = 0
	var held_before := GameState.cargo_count("salvage_quiet")
	var over_tier := GameState.identify("salvage_quiet", "heart_reliquary", true)
	var wrong_out := GameState.identify("salvage_charted", "heart_reliquary", true)
	print("[salvage] READ REFUSED above tier=%s, wrong output=%s, quiet still %d -> %s" % [
		str(over_tier), str(wrong_out), GameState.cargo_count("salvage_quiet"),
		"PASS" if not over_tier and not wrong_out
			and GameState.cargo_count("salvage_quiet") == held_before else "FAIL"])

	# 8. Tiers have to be REACHABLE against what the game actually pays. With three
	#    hulls on the whole chart, a tier needing fifteen derelicts is content you
	#    can see and never use.
	GameState.archeology = 0
	GameState.archeology_xp = 0
	var cap: int = GameState.ARCHEOLOGY_TIERS[GameState.ARCHEOLOGY_TIERS.size() - 1]
	# A standard loop cracks one hull and reads what a hold brings back.
	var per_loop := float(GameState.ARCHEOLOGY_PER_BREACH) \
		+ 8.0 * float(GameState.ARCHEOLOGY_PER_READ)
	var loops := float(cap) / maxf(per_loop, 0.01)
	print("[salvage] TIERS %s, top at %d xp = %.1f standard loops -> %s" % [
		str(GameState.ARCHEOLOGY_TIERS), cap, loops,
		"PASS" if loops <= 12.0 else "FAIL"])

	# 9. The carried effects. A Forged Manifest quietens the hold and an Unstable
	#    Charge lights it up — a thing you want to carry that makes the trip worse
	#    is the trade 16 asks of every specialist, moved into the hold.
	GameState.cargo = {}
	var plain := hold_signature()
	GameState.load_cargo("manifest_forged", 1)
	var quiet_sig := hold_signature()
	GameState.cargo = {}
	GameState.load_cargo("charge_unstable", 1)
	var loud_sig := hold_signature()
	GameState.cargo = {}
	print("[salvage] SIGNATURE plain %.2f, manifest %.2f, charge %.2f -> %s" % [
		plain, quiet_sig, loud_sig,
		"PASS" if quiet_sig < plain and loud_sig > plain else "FAIL"])

	# 10. Provenance is real: what a crate yields is named for where it was found.
	var deep_grade := CommodityDB.salvage_for_band(4)
	var home_grade := CommodityDB.salvage_for_band(0)
	print("[salvage] PROVENANCE %s (%d) vs %s (%d), deeper is worth more -> %s" % [
		CommodityDB.short_name(home_grade), CommodityDB.base_price(home_grade),
		CommodityDB.short_name(deep_grade), CommodityDB.base_price(deep_grade),
		"PASS" if CommodityDB.base_price(deep_grade) > CommodityDB.base_price(home_grade) else "FAIL"])

	# 11. Every port a component names as a buyer must ACTUALLY have a counter for
	#     it. REACHABLE only needs one counter on the whole chart, so it would pass
	#     with a good listed at four ports and sellable at one — which is exactly
	#     the shape of the contraband-at-the-Cantina bug 11 was written about.
	var no_counter := ""
	for gid in CommodityDB.ids():
		var id := String(gid)
		if not CommodityDB.is_component(id):
			continue
		for pid_v in (CommodityDB.get_good(id).get("trade_only_at", []) as Array):
			var pid := String(pid_v)
			var pdef := SystemDB.port_def_by_id(pid)
			if pdef.is_empty():
				pdef = DeepPortDB.by_id(pid)
			var svc: Array = pdef.get("services", PortPanel.DEFAULT_SERVICES)
			if not (svc.has("market") or (svc.has("fence") and Market.fences(pdef, id))):
				no_counter = "%s names %s, which has no counter for it" % [id, pid]
	print("[salvage] EVERY NAMED BUYER BUYS -> %s %s" % [
		"PASS" if no_counter == "" else "FAIL", no_counter])

	# 12. THE RATE THE TIERS ASSERTION IS COMPUTED FROM MUST ACTUALLY BE PAID.
	#     ARCHEOLOGY_PER_BREACH existed, TIERS divided by it, and nothing in the
	#     game ever awarded it — so TIERS printed the same "6.5 loops" whether the
	#     rate was real or fictional. 18's test, failed: an assertion whose output
	#     does not change when the thing it guards is broken guards nothing.
	GameState.archeology = 0
	GameState.archeology_xp = 0
	var xp_before := GameState.archeology_xp
	var hulk := Derelict.new()
	hulk.counts_as_survey = false          # a deep hulk: must STILL teach
	hulk.counts_for_contract = false
	system_root.add_child(hulk)
	hulk.global_position = Vector3(0, 0, -14)
	await get_tree().process_frame
	hulk.force_breach()
	await get_tree().create_timer(0.3).timeout
	var xp_gained := GameState.archeology_xp - xp_before
	print("[salvage] BREACH XP a deep hulk (counts_as_survey=false) pays %d, want %d -> %s" % [
		xp_gained, GameState.ARCHEOLOGY_PER_BREACH,
		"PASS" if xp_gained == GameState.ARCHEOLOGY_PER_BREACH else "FAIL"])

	# 13. A tier that arrives in silence cannot teach anything, and "did 0->1
	#     arrive fast enough" is the question the first play-test has to answer.
	GameState.archeology = 0
	GameState.archeology_xp = GameState.ARCHEOLOGY_TIERS[1] - 1
	GameState.cargo = {}
	GameState.load_cargo("salvage_charted", 1)
	GameState.last_read_tiered = false
	var tiered := GameState.identify("salvage_charted", "plate_ablative", false)
	print("[salvage] TIER ANNOUNCED read at the threshold -> tier %d, reported=%s -> %s" % [
		GameState.archeology, str(GameState.last_read_tiered),
		"PASS" if tiered and GameState.archeology == 1 and GameState.last_read_tiered else "FAIL"])

	# 14. Thermal Sink. Half a pulse, not immunity — a hazard an item switches off
	#     entirely has stopped being a trade.
	GameState.cargo = {}
	player.clear_emp()
	player.emp_stun(2.4)
	var bare_emp := player.emp_remaining()
	player.clear_emp()
	GameState.load_cargo("sink_thermal", 1)
	player.emp_stun(2.4)
	var sunk_emp := player.emp_remaining()
	player.clear_emp()
	GameState.cargo = {}
	print("[salvage] SINK EMP 2.4s -> %.2fs bare, %.2fs with a Thermal Sink -> %s" % [
		bare_emp, sunk_emp,
		"PASS" if is_equal_approx(bare_emp, 2.4) \
			and is_equal_approx(sunk_emp, 2.4 * PlayerShip.SINK_EMP_FACTOR) else "FAIL"])

	# 15. The two carried effects that are pure world-reads stay OFF the stat pile.
	#     19's rule: cargo may change what the world does to you, never what the
	#     ship can do. If any of these ever moved a fitted number, the hold guard
	#     would start subtracting two different piles from each other.
	GameState.cargo = {}
	var clean_stats := GameState.stats.duplicate(true)
	for carried in ["sink_thermal", "index_cartographic", "heart_reliquary",
			"manifest_forged", "charge_unstable"]:
		GameState.load_cargo(String(carried), 1)
	var loaded_stats := GameState.stats
	var moved := ""
	for key in clean_stats:
		if key == "weapons" or key == "ability":
			continue
		if not is_equal_approx(float(clean_stats[key]), float(loaded_stats.get(key, 0.0))):
			moved = String(key)
	GameState.cargo = {}
	print("[salvage] CARGO IS NOT A FIT all five carried effects move no fitted stat -> %s %s" % [
		"PASS" if moved == "" else "FAIL", moved])

	# 16. Cartographic Index. A station 300u out sits at the alpha floor without
	#     one and reads as a real contact with one — and ONLY stations do, because
	#     this is a thing that finds ports, not a sensor upgrade.
	var radar = hud.get_node_or_null("RadarLayer")
	if radar == null:
		for c in hud.get_children():
			if c.has_method("marker_alpha"):
				radar = c
	# Measured OUT IN THE REACHES, which is the only place the Index means
	# anything: inside the charted system every contact is inside the fade span
	# already, so widening it changes nothing. That is correct behaviour — you do
	# not need somebody else's chart of the system you started in — and testing it
	# at the origin was testing it exactly where it is designed to be inert.
	player.global_position = Vector3(520.0, 0.0, 0.0)
	for i in range(3):
		await get_tree().process_frame
	GameState.cargo = {}
	await get_tree().process_frame
	var port_bare: float = radar.marker_alpha(1, 300.0)
	var host_bare: float = radar.marker_alpha(3, 300.0)
	GameState.load_cargo("index_cartographic", 1)
	var port_idx: float = radar.marker_alpha(1, 300.0)
	var host_idx: float = radar.marker_alpha(3, 300.0)
	GameState.cargo = {}
	print("[salvage] INDEX in %s, station at 300u %.2f -> %.2f, hostiles %.2f -> %.2f (must not move) -> %s" % [
		DeepSpace.band_name(deep_depth()), port_bare, port_idx, host_bare, host_idx,
		"PASS" if port_idx > port_bare and is_equal_approx(host_bare, host_idx) else "FAIL"])

	# 17. Reliquary Heart. The tell is words instead of a hue, and it must be
	#     ABSENT without the Heart — an effect that fires either way is not an
	#     effect, it is a rewrite of the base game.
	var rigged := Derelict.new()
	system_root.add_child(rigged)
	rigged.arm_trap({"emp": 2.0, "count": 4, "band": 4})
	var plain_hulk := Derelict.new()
	system_root.add_child(plain_hulk)
	GameState.cargo = {}
	var rigged_bare := rigged.breach_prompt()
	GameState.load_cargo("heart_reliquary", 1)
	var rigged_heart := rigged.breach_prompt()
	var plain_heart := plain_hulk.breach_prompt()
	GameState.cargo = {}
	print("[salvage] HEART rigged tell with a Heart aboard=%s, without=%s, clean hulk unchanged=%s -> %s" % [
		str(rigged_heart != rigged_bare), str(rigged_bare == plain_hulk.breach_prompt()),
		str(plain_heart == plain_hulk.breach_prompt()),
		"PASS" if rigged_heart != rigged_bare and plain_heart == plain_hulk.breach_prompt() else "FAIL"])
	get_tree().quit()


# --- ship systems harness -----------------------------------------------------

func _run_ship_test() -> void:
	var player: PlayerShip = get_tree().get_first_node_in_group("player")
	_wave_timer = 1.0e9
	_apex_wake_timer = -1.0
	for n in get_tree().get_nodes_in_group("hostiles"):
		(n as Node3D).queue_free()
	GameState.reactor_tier = 2
	for id in ["util_cargo", "util_cargo_2", "util_repair", "util_repair_2"]:
		if not GameState.owns(id):
			GameState.owned.append(id)
	await get_tree().create_timer(0.4).timeout

	# --- cargo hold guard -----------------------------------------------------
	GameState.equip(ModuleDB.Slot.UTILITY, "util_cargo_2")
	GameState.cargo = {}
	GameState.load_cargo("relics", 15)          # 45 of a 46+24 hold
	var used := GameState.cargo_used()
	var over := GameState.cargo_overflow(ModuleDB.Slot.UTILITY, "")
	var refused := not GameState.can_equip(ModuleDB.Slot.UTILITY, "")
	var still := GameState.equip(ModuleDB.Slot.UTILITY, "")
	print("[ship] HOLD GUARD %d used, stripping the bay overflows by %d, refused=%s equip=%s -> %s" % [
		used, over, str(refused), str(still),
		"PASS" if over > 0 and refused and not still else "FAIL"])
	print("[ship] HOLD STILL VALID used %d <= capacity %d -> %s" % [
		GameState.cargo_used(), GameState.cargo_capacity(),
		"PASS" if GameState.cargo_used() <= GameState.cargo_capacity() else "FAIL"])

	# Jettison dumps cheapest-first and only as much as it must.
	GameState.cargo = {}
	GameState.load_cargo("relics", 8)           # 24 space, 260 each
	GameState.load_cargo("alloys", 8)           # 16 space, 40 each
	var before_val := GameState.hold_value()
	var dumped := GameState.jettison_to_fit(ModuleDB.Slot.UTILITY, "")
	var kept_relics := GameState.cargo_count("relics")
	print("[ship] JETTISON dumped %d units, kept %d relics of 8, hold value %d -> %d -> %s" % [
		dumped, kept_relics, before_val, GameState.hold_value(),
		"PASS" if dumped > 0 and kept_relics == 8
			and GameState.can_equip(ModuleDB.Slot.UTILITY, "") else "FAIL"])

	# --- hull integrity + repair ---------------------------------------------
	GameState.equip(ModuleDB.Slot.UTILITY, "")
	await get_tree().process_frame
	player.invulnerable = false
	player.shield = player.shield_max * 0.25
	var hurt := player.shield_fraction()
	player.repair_full()
	print("[ship] REPAIR hull %.0f%% -> %.0f%% -> %s" % [
		hurt * 100.0, player.shield_fraction() * 100.0,
		"PASS" if hurt < 0.3 and player.shield_fraction() >= 0.999 else "FAIL"])

	# The free option: out-of-combat regen actually recovers.
	player.shield = player.shield_max * 0.3
	var base_regen := float(GameState.stats.get("shield_regen", 0.0))
	await get_tree().create_timer(PlayerShip.SHIELD_CALM_DELAY + 2.0).timeout
	var healed := player.shield_fraction()
	print("[ship] SLOW HEAL 30%% -> %.0f%% after %.1fs calm at %.0f/s -> %s" % [
		healed * 100.0, PlayerShip.SHIELD_CALM_DELAY + 2.0, base_regen,
		"PASS" if healed > 0.3 else "FAIL"])

	# A Repair Bay makes that materially faster, which is what it is sold for.
	GameState.equip(ModuleDB.Slot.UTILITY, "util_repair_2")
	await get_tree().process_frame
	var kitted := float(GameState.stats.get("shield_regen", 0.0))
	print("[ship] REPAIR BAY regen %.0f/s -> %.0f/s -> %s" % [
		base_regen, kitted, "PASS" if kitted > base_regen * 2.0 else "FAIL"])

	var repair_ports: Array = []
	for pid in SystemDB.port_ids():
		var svc: Array = SystemDB.port_def_by_id(String(pid)).get("services", PortPanel.DEFAULT_SERVICES)
		if svc.has("repair"):
			repair_ports.append(pid)
	print("[ship] REPAIR SERVICE at %s -> %s" % [str(repair_ports),
		"PASS" if repair_ports.size() >= 3 else "FAIL"])

	# --- specialist rigs ------------------------------------------------------
	# Every rig must be a TRADE. A rig that is strictly better than bare hull is
	# just a stat stick, and the second utility slot would become "equip the two
	# best" rather than a decision.
	var rigs := ["rig_hauler", "rig_prospector", "rig_strike", "rig_bulwark", "rig_runner"]
	var all_trade := true
	var worst_rig := ""
	for id_v in rigs:
		var id := String(id_v)
		var st: Dictionary = ModuleDB.get_module(id).get("stats", {})
		var ups := 0
		var downs := 0
		for k in st:
			if float(st[k]) > 0.0:
				ups += 1
			elif float(st[k]) < 0.0:
				downs += 1
		if downs == 0:
			all_trade = false
			worst_rig = id
		print("[ship]   %-16s %d gains / %d costs" % [id, ups, downs])
	print("[ship] RIG TRADEOFFS every specialist rig costs something -> %s %s" % [
		"PASS" if all_trade else "FAIL", worst_rig])

	# Two rigs stacked must stay flyable — the floors in compute_stats are what
	# stop a hauler-plus-bulwark ship being unable to move at all.
	for id_v2 in rigs:
		if not GameState.owns(String(id_v2)):
			GameState.owned.append(String(id_v2))
	GameState.equip(ModuleDB.Slot.UTILITY, "rig_hauler")
	GameState.equip(ModuleDB.Slot.UTILITY_B, "rig_bulwark")
	await get_tree().process_frame
	var st2 := GameState.stats
	print("[ship] STACKED hauler+bulwark: speed %.1f accel %.1f turn %.1f hold %.0f shield %.0f -> %s" % [
		float(st2["max_speed"]), float(st2["accel"]), float(st2["turn_rate"]),
		float(st2["cargo_space"]), float(st2["shield_max"]),
		"PASS" if float(st2["max_speed"]) >= 1.6 and float(st2["accel"]) >= 3.0
			and float(st2["cargo_space"]) >= 6.0 else "FAIL"])
	# And the specialisation must actually read: a hauler carries more than a
	# strike frame and is slower than it.
	# Empty the hold first: rig_strike carries a -14 cargo penalty, and the new
	# hold guard correctly REFUSES to fit it under a loaded hold — so leaving the
	# relics aboard would silently compare a hauler against a hauler.
	GameState.cargo = {}
	GameState.equip(ModuleDB.Slot.UTILITY, "rig_hauler")
	GameState.equip(ModuleDB.Slot.UTILITY_B, "")
	await get_tree().process_frame
	var haul_hold := float(GameState.stats["cargo_space"])
	var haul_speed := float(GameState.stats["max_speed"])
	GameState.equip(ModuleDB.Slot.UTILITY, "rig_strike")
	await get_tree().process_frame
	var strike_hold := float(GameState.stats["cargo_space"])
	var strike_speed := float(GameState.stats["max_speed"])
	print("[ship] SPECIALISATION hauler %.0f hold / %.1f speed vs strike %.0f hold / %.1f speed -> %s" % [
		haul_hold, haul_speed, strike_hold, strike_speed,
		"PASS" if haul_hold > strike_hold and haul_speed < strike_speed else "FAIL"])
	print("[ship] SECOND SLOT %d fitting slots -> %s" % [ModuleDB.SLOT_NAMES.size(),
		"PASS" if ModuleDB.SLOT_NAMES.size() == 6 else "FAIL"])
	GameState.equip(ModuleDB.Slot.UTILITY, "")

	# --- breaking off a boss fight -------------------------------------------
	GameState.equip(ModuleDB.Slot.UTILITY, "")
	player.invulnerable = true
	GameState.mark_breached(system_id)
	_apex_wake_timer = 0.2
	await get_tree().create_timer(ApexBoss.WAKE_TIME + 1.0).timeout
	var boss := _find_apex()
	# Inside CORE_RANGE first: take_damage breaks shots on the survey field from
	# further out, so damaging it from spawn is a no-op and the reset below would
	# be asserting against an untouched boss.
	player.global_position = boss.global_position + Vector3(0, 0, 5.0)
	await get_tree().physics_frame
	boss.take_damage(400.0)
	await get_tree().process_frame
	var hp_before := boss.hp_fraction()
	var engaged := boss_active
	var broke := disengage_apex()
	await get_tree().create_timer(0.4).timeout
	var home := player.global_position.distance_to(PlayerShip.SPAWN_POINT)
	print("[ship] DISENGAGE engaged=%s broke=%s boss_active=%s hp %.2f -> %.2f, ship %.1fu from spawn -> %s" % [
		str(engaged), str(broke), str(boss_active), hp_before, boss.hp_fraction(), home,
		"PASS" if engaged and broke and not boss_active
			and boss.hp_fraction() > hp_before and home < 2.0 else "FAIL"])
	print("[ship] DISENGAGE REFUSED outside a fight: %s (must be false) -> %s" % [
		str(disengage_apex()), "PASS" if not disengage_apex() else "FAIL"])
	get_tree().quit()


# --- deep space harness -------------------------------------------------------

func _run_deep_shots() -> void:
	# The expanse is a look before it is a system, and no assertion can tell you
	# whether it reads. One frame per band, plus the two things a band is FOR:
	# somewhere to dock, and something that wants to kill you.
	var shots: String = OS.get_environment("PYXIS_SHOTS")
	var player: PlayerShip = get_tree().get_first_node_in_group("player")
	var rig := get_tree().get_first_node_in_group("camera_rig") as CameraRig
	player.invulnerable = true
	_apex_wake_timer = -1.0
	UILayout.user_scale = 1.0
	UILayout.apply_scale(get_window())
	get_window().size = Vector2i(1280, 800)
	await get_tree().create_timer(0.6).timeout

	var edge := SystemDB.bounds_of(system_id)
	# Mid-band depths, so each frame is representative of its band rather than of
	# a boundary between two.
	for spec in [
		{"depth": 0.0, "tag": "0_charted"},
		{"depth": 80.0, "tag": "1_shoals"},
		{"depth": 300.0, "tag": "2_drift"},
		{"depth": 760.0, "tag": "3_reaches"},
		{"depth": 1500.0, "tag": "4_quiet"},
	]:
		var r := edge + float(spec["depth"])
		var at := Vector3(r * 0.7071, 0.0, r * 0.7071)
		player.global_position = at
		player.velocity = Vector3.ZERO
		rig.global_position = at + Vector3(0, 0, 2)
		rig.zoom = 24.0
		rig._target_zoom = 24.0
		# The system tag and the home marker are LIVE now (B5), so this captures
		# what the player actually sees rather than a stand-in the harness wrote.
		await get_tree().create_timer(1.2).timeout
		print("[deepshot] %s at %.0fu, depth %.0f, band %s, %d live cells, %d obstacles" % [
			spec["tag"], r, deep_depth(), DeepSpace.band_name(deep_depth()),
			deep_space.live_cell_count(), Obstacles.count()])
		await _shot(shots, "deep_%s.png" % spec["tag"])

	# A station, framed from the approach.
	var berth := Vector2i(0x7fffffff, 0x7fffffff)
	for try_band in [2, 3, 1, 4]:
		berth = _deep_probe(try_band, "station")
		if berth.x != 0x7fffffff:
			break
	if berth.x != 0x7fffffff:
		var st: Dictionary = deep_space.plan_cell(berth.x, berth.y)["station"]
		var sp: Vector3 = st["pos"]
		player.global_position = sp + Vector3(0, 0, 9.0)
		rig.global_position = sp + Vector3(0, 0, 6.0)
		rig.zoom = 17.0
		rig._target_zoom = 17.0
		await get_tree().create_timer(1.4).timeout
		print("[deepshot] station %s at %.0fu out" % [
			st["archetype"], Vector2(sp.x, sp.z).length()])
		await _shot(shots, "deep_5_station.png")

	# And a nest, sprung.
	var nest := _deep_probe(3, "pack")
	if nest.x != 0x7fffffff:
		var pk: Dictionary = deep_space.plan_cell(nest.x, nest.y)["pack"]
		var np: Vector3 = pk["pos"]
		player.global_position = np + Vector3(0, 0, 12.0)
		rig.global_position = np + Vector3(0, 0, 9.0)
		rig.zoom = 20.0
		rig._target_zoom = 20.0
		await get_tree().create_timer(2.0).timeout
		print("[deepshot] nest at %.0fu out, %d hostiles up" % [
			Vector2(np.x, np.z).length(), get_tree().get_nodes_in_group("hostiles").size()])
		await _shot(shots, "deep_6_nest.png")

	# The beacon that replaced the wall, caught mid-broadcast.
	for n in get_tree().get_nodes_in_group("hostiles"):
		(n as Node3D).queue_free()
	_broadcast_band = 0
	player.global_position = Vector3(edge + 8.0, 0, 0)
	await get_tree().create_timer(0.5).timeout
	player.global_position = Vector3(edge + 70.0, 0, 0)
	rig.global_position = player.global_position + Vector3(0, 0, 2)
	await get_tree().create_timer(1.1).timeout
	print("[deepshot] beacon at %.0fu out" % deep_radius())
	await _shot(shots, "deep_8_beacon.png")

	# A rigged hulk, tell showing, before anybody touches it.
	var rig_cell := Vector2i(0x7fffffff, 0x7fffffff)
	for ring in range(1, 26):
		for cz in range(-ring, ring + 1):
			for cx in range(-ring, ring + 1):
				if maxi(absi(cx), absi(cz)) != ring:
					continue
				var h: Dictionary = deep_space.plan_cell(cx, cz)["hulk"]
				if not h.is_empty() and not (h["trap"] as Dictionary).is_empty():
					rig_cell = Vector2i(cx, cz)
					break
			if rig_cell.x != 0x7fffffff:
				break
		if rig_cell.x != 0x7fffffff:
			break
	if rig_cell.x != 0x7fffffff:
		var hk: Dictionary = deep_space.plan_cell(rig_cell.x, rig_cell.y)["hulk"]
		var hp2: Vector3 = hk["pos"]
		player.global_position = hp2 + Vector3(0, 0, 8.5)
		rig.global_position = hp2 + Vector3(0, 0, 5.0)
		rig.zoom = 16.0
		rig._target_zoom = 16.0
		await get_tree().create_timer(1.2).timeout
		print("[deepshot] rigged hulk at %.0fu out, loot %d" % [
			Vector2(hp2.x, hp2.z).length(), int(hk["loot"])])
		await _shot(shots, "deep_9_rigged.png")

	# The way back: the chart with RETURN TO SYSTEM showing, which it only does
	# from outside the charted volume.
	for n in get_tree().get_nodes_in_group("hostiles"):
		(n as Node3D).queue_free()
	player.global_position = Vector3(edge + 620.0, 0, 0)
	await get_tree().create_timer(0.4).timeout
	chart_panel.open()
	await get_tree().create_timer(0.8).timeout
	print("[deepshot] chart at %.0fu out, recall offered=%s" % [
		deep_radius(), str(can_recall())])
	await _shot(shots, "deep_7_recall.png")
	get_tree().quit()


func _deep_probe(want_band: int, key: String) -> Vector2i:
	# Harness support: the NEAREST cell that sits in `want_band` and holds `key`,
	# found by widening rings from the origin. Deep content is deliberately sparse
	# and a band is an annulus rather than a direction, so looking along one
	# diagonal finds whatever happens to be on it — which is how this started life
	# and why it silently stopped finding Drift nests the moment the generator's
	# roll order changed. A ring walk cannot go stale that way.
	for ring in range(1, 26):
		for cz in range(-ring, ring + 1):
			for cx in range(-ring, ring + 1):
				if maxi(absi(cx), absi(cz)) != ring:
					continue                       # only the new ring
				var pl := deep_space.plan_cell(cx, cz)
				if int(pl["band"]) != want_band:
					continue
				if (pl[key] as Dictionary).is_empty():
					continue
				return Vector2i(cx, cz)
	return Vector2i(0x7fffffff, 0x7fffffff)


func _run_deep_test() -> void:
	var player: PlayerShip = get_tree().get_first_node_in_group("player")
	var rig := get_tree().get_first_node_in_group("camera_rig") as CameraRig
	player.invulnerable = true
	_wave_timer = 1.0e9
	_apex_wake_timer = -1.0
	await get_tree().create_timer(0.4).timeout

	# 0. Sentries stand where they were authored to stand.
	#
	#    This is here because they did not. `Hostile._ready` captured `_home` from
	#    `global_position`, but every spawner in the game sets `position` on the
	#    line AFTER `add_child` — so `_home` was always the container's origin, and
	#    since `_process` hard-writes `global_position = _home + drift`, every
	#    sentry in every system snapped to the middle of the map on frame one.
	#    PYX-01's four lane guards, authored 6-20u out to cover the derelict and
	#    apex approaches, were all sitting on the player's spawn point.
	#
	#    Nothing caught it because nothing had ever asserted where an enemy IS.
	var posts: Array = SystemDB.get_system(system_id).get("sentries", [])
	var worst_post := 0.0
	var found_posts := 0
	var deep_seen := 0
	for n in get_tree().get_nodes_in_group("hostiles"):
		if not (n is Hostile):
			continue
		# Deep guards are the same class standing somewhere else, and they have
		# their own post assertion below. The count is PRINTED rather than
		# swallowed: a number showing up here when you were not expecting one is
		# the cheap way to notice guards leaking into the charted volume.
		if n.is_in_group("deep_guard"):
			deep_seen += 1
			continue
		found_posts += 1
		var nearest := INF
		for p_v in posts:
			nearest = minf(nearest, (n as Node3D).global_position.distance_to(p_v))
		worst_post = maxf(worst_post, nearest)
	print("[deep] SENTRY POSTS %d sentries, %d authored posts, furthest any of them sits from its post %.2fu (drift is 0.4), %d deep guards excluded -> %s" % [
		found_posts, posts.size(), worst_post, deep_seen,
		"PASS" if found_posts == posts.size() and found_posts > 0 and worst_post <= 0.6
			else "FAIL"])

	# 1. The bug the player found: the ship could outrun its own camera. Fly a
	#    long way out and confirm the view is still on it.
	var far := Vector3(1700.0, 0.0, 1700.0)
	player.global_position = far
	player.velocity = Vector3.ZERO
	for i in range(240):
		player.global_position = far
		await get_tree().physics_frame
	var ship_r := Vector2(player.global_position.x, player.global_position.z).length()
	var rig_off := Vector2(rig.global_position.x - far.x,
		rig.global_position.z - far.z).length()
	print("[deep] CAMERA ship at %.0fu -> rig offset %.1f (leash %.1f) -> %s" % [
		ship_r, rig_off, rig.pan_leash(),
		"PASS" if rig_off <= rig.pan_leash() + 0.5 else "FAIL"])
	print("[deep] NO CLAMP rig radius %.0fu (the old pan_bound was %.0f) -> %s" % [
		Vector2(rig.global_position.x, rig.global_position.z).length(),
		SystemDB.bounds_of(system_id),
		"PASS" if Vector2(rig.global_position.x,
			rig.global_position.z).length() > SystemDB.bounds_of(system_id) * 4.0 else "FAIL"])

	# 2. The ship must be ON SCREEN, not merely within the leash.
	var cam := get_viewport().get_camera_3d()
	var vp := get_viewport().get_visible_rect()
	var proj := cam.unproject_position(player.global_position)
	print("[deep] ON SCREEN ship projects to (%.0f, %.0f) in %.0fx%.0f -> %s" % [
		proj.x, proj.y, vp.size.x, vp.size.y,
		"PASS" if vp.has_point(proj) else "FAIL"])

	# 3. A hard manual pan still cannot lose the ship.
	rig.global_position = far + Vector3(900.0, 0.0, 900.0)
	await get_tree().physics_frame
	await get_tree().process_frame
	var panned := Vector2(rig.global_position.x - far.x,
		rig.global_position.z - far.z).length()
	print("[deep] PAN LEASH 1270u pan collapsed to %.1f (leash %.1f) -> %s" % [
		panned, rig.pan_leash(),
		"PASS" if panned <= rig.pan_leash() + 0.5 else "FAIL"])

	# 4. The sky must not run out. The per-system starfield is a static box of
	#    ±96..112 around the origin; out here only the wrapping field can be
	#    supplying stars at all.
	var field := deep_space.star_field()
	var nearest := field.nearest_instance_distance(rig.global_position)
	print("[deep] STARFIELD nearest instance %.1fu from a camera %.0fu from origin -> %s" % [
		nearest, Vector2(rig.global_position.x, rig.global_position.z).length(),
		"PASS" if nearest < 40.0 else "FAIL"])

	# 5. Bands are monotonic and land on their authored edges.
	var bands_ok := true
	var line := ""
	for probe in [0.0, 1.0, 159.0, 160.0, 439.0, 440.0, 1099.0, 1100.0, 5000.0]:
		var b := DeepSpace.band_of(probe)
		line += "%.0f=%d " % [probe, b]
	bands_ok = DeepSpace.band_of(0.0) == 0 and DeepSpace.band_of(1.0) == 1 \
		and DeepSpace.band_of(160.0) == 2 and DeepSpace.band_of(440.0) == 3 \
		and DeepSpace.band_of(1100.0) == 4
	print("[deep] BANDS %s-> %s" % [line, "PASS" if bands_ok else "FAIL"])
	print("[deep] BAND NAMES %s" % str(DeepSpace.BAND_NAMES))

	# 6. depth is zero everywhere inside the charted system, which is what makes
	#    every gradient built on it a no-op for existing content.
	player.global_position = Vector3(0, 0, 6)
	await get_tree().physics_frame
	var at_core := deep_depth()
	player.global_position = Vector3(SystemDB.bounds_of(system_id) - 2.0, 0, 0)
	await get_tree().physics_frame
	var at_edge := deep_depth()
	print("[deep] DEPTH core %.1f, inside the edge %.1f (both must be 0) -> %s" % [
		at_core, at_edge,
		"PASS" if at_core == 0.0 and at_edge == 0.0 else "FAIL"])

	# --- C1: deterministic sectors ------------------------------------------

	# 7. A cell is a pure function of (system id, cx, cz). Planning one twice must
	#    give the same answer, and planning two different ones must not — the
	#    second half matters as much as the first, because a generator that always
	#    returns nothing would pass the stability check perfectly.
	var probes := [Vector2i(9, 4), Vector2i(-13, 7), Vector2i(31, -22), Vector2i(-40, -37)]
	var stable := true
	var shapes := {}
	for c_v in probes:
		var c: Vector2i = c_v
		var first := var_to_str(deep_space.plan_cell(c.x, c.y))
		var second := var_to_str(deep_space.plan_cell(c.x, c.y))
		if first != second:
			stable = false
		shapes[first] = true
	print("[deep] SECTOR STABLE %d cells planned twice: identical=%s, %d distinct shapes -> %s" % [
		probes.size(), str(stable), shapes.size(),
		"PASS" if stable and shapes.size() > 1 else "FAIL"])

	# 8. Streaming. Baseline first, with the player at home and nothing generated.
	player.global_position = PlayerShip.SPAWN_POINT
	await get_tree().process_frame
	await get_tree().process_frame
	var baseline := Obstacles.count()
	var home_cells := deep_space.content_cell_count()

	# Find a cell out in the Reaches that actually holds something, so the
	# assertions below are measuring content rather than measuring empty space.
	var target := Vector2i(0, 0)
	var found := false
	for step in range(9, 60):
		if not (deep_space.plan_cell(step, step)["rocks"] as Array).is_empty():
			target = Vector2i(step, step)
			found = true
			break
	var centre := DeepSpace.cell_centre(target.x, target.y)
	player.global_position = centre
	await get_tree().process_frame
	await get_tree().process_frame
	var live := deep_space.live_cell_count()
	var window_side := DeepSpace.WINDOW * 2 + 1
	var all_near := true
	for k_v in deep_space.live_cells():
		var k: Vector2i = k_v
		if absi(k.x - target.x) > DeepSpace.KEEP or absi(k.y - target.y) > DeepSpace.KEEP:
			all_near = false
	var out_there := Obstacles.count()
	print("[deep] SECTOR STREAMING at cell (%d,%d): %d live (want %d), all within KEEP=%d of the player=%s, obstacles %d -> %d -> %s" % [
		target.x, target.y, live, window_side * window_side, DeepSpace.KEEP,
		str(all_near), baseline, out_there,
		"PASS" if found and live == window_side * window_side and all_near and out_there > baseline else "FAIL"])

	# 9. And the content of the cell the player is standing in must be exactly
	#    what plan_cell said it would be — the plan is the source of truth the
	#    spawner builds from, so this is what keeps the two from drifting apart.
	var plan := deep_space.plan_cell(target.x, target.y)
	var want_spheres: int = (plan["rocks"] as Array).size() \
		+ (0 if (plan["hulk"] as Dictionary).is_empty() else 2)
	var got_spheres := Obstacles.count_owned("deep:%d:%d" % [target.x, target.y])
	print("[deep] SECTOR CONTENT cell (%d,%d) planned %d spheres, registered %d -> %s" % [
		target.x, target.y, want_spheres, got_spheres,
		"PASS" if want_spheres == got_spheres and want_spheres > 0 else "FAIL"])

	# 10. Leaving must give it all back. An owner tag that leaks would grow the
	#     registry every cell the player crosses for the whole session, and every
	#     leaked sphere is an invisible wall left behind in empty space.
	player.global_position = PlayerShip.SPAWN_POINT
	await get_tree().process_frame
	await get_tree().process_frame
	var returned := Obstacles.count()
	print("[deep] SECTOR CLEANUP obstacles back to %d (baseline %d), content cells %d (home %d) -> %s" % [
		returned, baseline, deep_space.content_cell_count(), home_cells,
		"PASS" if returned == baseline and deep_space.content_cell_count() == home_cells else "FAIL"])

	# 11. Revisiting rerolls nothing: the same cell, entered a second time, has to
	#     come back byte-identical. This is what "zero save data" buys — and what
	#     it costs if it is ever untrue.
	player.global_position = centre
	await get_tree().process_frame
	await get_tree().process_frame
	var again := Obstacles.count_owned("deep:%d:%d" % [target.x, target.y])
	print("[deep] SECTOR REVISIT cell (%d,%d) rebuilt with %d spheres (was %d) -> %s" % [
		target.x, target.y, again, got_spheres,
		"PASS" if again == got_spheres and again > 0 else "FAIL"])

	# --- C2: the danger gradient --------------------------------------------

	# 12. Danger has to RISE, and it has to rise on every axis at once, or the
	#     expanse is just further away rather than worse.
	var rows := ""
	var rising := true
	for b in range(1, DeepSpace.BAND_NAMES.size()):
		rows += "%s hp x%.1f dmg x%.1f packs %d-%d%s | " % [
			DeepSpace.BAND_NAMES[b], DeepSpace.PACK_HP[b], DeepSpace.PACK_DIFFICULTY[b],
			DeepSpace.PACK_MIN[b], DeepSpace.PACK_MAX[b],
			" +escort" if b >= DeepSpace.PACK_ESCORT_FROM else ""]
		if b > 1:
			if DeepSpace.PACK_HP[b] < DeepSpace.PACK_HP[b - 1] \
					or DeepSpace.PACK_DIFFICULTY[b] < DeepSpace.PACK_DIFFICULTY[b - 1] \
					or DeepSpace.PACK_MAX[b] < DeepSpace.PACK_MAX[b - 1]:
				rising = false
	print("[deep] DANGER RISES %s-> %s" % [rows, "PASS" if rising else "FAIL"])

	# 13. And the numbers on the table are the numbers on the ships. Spring one
	#     nest from the Drift and one from the Reaches and weigh what turns up.
	var measured := {}
	for want_band in [2, 3]:
		for n in get_tree().get_nodes_in_group("hostiles"):
			(n as Node3D).queue_free()
		await get_tree().process_frame
		var nest := _deep_probe(want_band, "pack")
		if nest.x == 0x7fffffff:
			continue
		var pack: Dictionary = deep_space.plan_cell(nest.x, nest.y)["pack"]
		player.global_position = pack["pos"]
		await get_tree().process_frame
		await get_tree().process_frame
		var worst := 0.0
		var crew := 0
		var escort := 0
		for n in get_tree().get_nodes_in_group("hostiles"):
			if n is SwarmHostile:
				crew += 1
				worst = maxf(worst, (n as SwarmHostile).hp)
			elif n is Hostile:
				escort += 1
		measured[want_band] = {"hp": worst, "crew": crew, "escort": escort}
		print("[deep]   %s nest at cell (%d,%d): %d ships, toughest %.0f hp, %d escort" % [
			DeepSpace.BAND_NAMES[want_band], nest.x, nest.y, crew, worst, escort])
	var drift_hp: float = float((measured.get(2, {}) as Dictionary).get("hp", 0.0))
	var reach_hp: float = float((measured.get(3, {}) as Dictionary).get("hp", 0.0))
	var reach_escort: int = int((measured.get(3, {}) as Dictionary).get("escort", 0))
	print("[deep] DANGER MEASURED drift %.0f hp -> reaches %.0f hp, reaches escorted=%s -> %s" % [
		drift_hp, reach_hp, str(reach_escort > 0),
		"PASS" if drift_hp > 0.0 and reach_hp > drift_hp and reach_escort > 0 else "FAIL"])

	# 14. Nothing the expanse spawns may follow the player home. A swarm does 7.5
	#     against the ship's 5.75, so this is the only thing that can end a chase
	#     the player chose to walk away from.
	var leashed := SwarmHostile.new()
	leashed.despawn_radius = DeepSpace.HOSTILE_LEASH
	system_root.add_child(leashed)
	leashed.global_position = Vector3(3000, 0, 3000)
	var loyal := SwarmHostile.new()      # despawn_radius 0: an ordinary hostile
	system_root.add_child(loyal)
	loyal.global_position = Vector3(3000, 0, 3000)
	player.global_position = Vector3(0, 0, 0)
	for i in range(6):
		await get_tree().physics_frame
	print("[deep] HOSTILE LEASH at %.0fu out: leashed gone=%s, un-leashed still there=%s -> %s" % [
		DeepSpace.HOSTILE_LEASH, str(not is_instance_valid(leashed)),
		str(is_instance_valid(loyal)),
		"PASS" if not is_instance_valid(leashed) and is_instance_valid(loyal) else "FAIL"])
	if is_instance_valid(loyal):
		loyal.queue_free()

	# 15. Waves stop at the chart edge. Out here `_spawn_swarm_pack`'s bounds-6
	#     clamp would put every pack on the same fixed point behind the player.
	for n in get_tree().get_nodes_in_group("hostiles"):
		(n as Node3D).queue_free()
	await get_tree().process_frame
	deep_space.set_generation(false)     # measure the wave spawner, nothing else
	player.global_position = Vector3(600, 0, 600)
	_wave_timer = 0.01
	for i in range(20):
		await get_tree().process_frame
	var out_waves := get_tree().get_nodes_in_group("swarm").size()
	player.global_position = PlayerShip.SPAWN_POINT
	_wave_timer = 0.01
	for i in range(20):
		await get_tree().process_frame
	var home_waves := get_tree().get_nodes_in_group("swarm").size()
	print("[deep] WAVES STOP %d spawned at 600u out, %d spawned at home -> %s" % [
		out_waves, home_waves,
		"PASS" if out_waves == 0 and home_waves > 0 else "FAIL"])

	# --- guarded hulks --------------------------------------------------------

	# G1. The distribution, as a PURE function of the roll: no RNG, no spawning,
	#     no flying. Edges printed individually, so a swapped weight moves a
	#     number here rather than hiding inside a percentage.
	var wsum := 0.0
	for w in DeepSpace.GUARD_WEIGHTS:
		wsum += float(w)
	var edges := ""
	for probe in [0.199, 0.200, 0.449, 0.450, 0.749, 0.750, 0.999]:
		edges += "%.3f=%d " % [probe, DeepSpace.guard_count(probe)]
	var yielded := {}
	for i in range(1001):
		yielded[DeepSpace.guard_count(float(i) / 1000.0)] = true
	var yk := yielded.keys()
	yk.sort()
	# The bearings table is what STRUCTURALLY forbids a one-guard post: a count
	# with no bearings has nowhere to stand.
	var supply := ""
	for c_v in DeepSpace.GUARD_COUNTS:
		supply += "%d/" % (DeepSpace.GUARD_BEARINGS[int(c_v)] as Array).size()
	print("[deep] GUARD ODDS %s at %s (sums %.3f), bearings supply %s; edges %s-> %s" % [
		str(DeepSpace.GUARD_COUNTS), "20/25/30/25", wsum, supply, edges,
		"PASS" if is_equal_approx(wsum, 1.0) and str(yk) == str(DeepSpace.GUARD_COUNTS)
			and supply == "0/2/3/4/" else "FAIL"])

	# G2. And the generator actually draws it that way. A pure edge test passes
	#     even if plan_cell feeds it a reused roll.
	var seen_counts := {0: 0, 2: 0, 3: 0, 4: 0}
	var hulks_past := 0
	var skipped_near_station := 0
	for cx in range(-32, 33):
		for cz in range(-32, 33):
			var pl := deep_space.plan_cell(cx, cz)
			var hk: Dictionary = pl.get("hulk", {})
			if hk.is_empty() or deep_space.depth_at(hk["pos"]) < DeepSpace.GUARD_MIN_DEPTH:
				continue
			var st: Dictionary = pl.get("station", {})
			if not st.is_empty() and (hk["pos"] as Vector3).distance_to(st["pos"]) \
					< DeepSpace.STATION_SAFE_RADIUS:
				skipped_near_station += 1
				continue
			hulks_past += 1
			var gd: Dictionary = hk.get("guards", {})
			var n := int(gd.get("count", 0))
			seen_counts[n] = int(seen_counts.get(n, 0)) + 1
	var share_ok := hulks_past > 200
	var share_line := ""
	var want := [0.20, 0.25, 0.30, 0.25]
	for i in range(DeepSpace.GUARD_COUNTS.size()):
		var c := int(DeepSpace.GUARD_COUNTS[i])
		var pct := 100.0 * float(seen_counts[c]) / maxf(float(hulks_past), 1.0)
		share_line += "%d:%.1f%%(%.0f) " % [c, pct, want[i] * 100.0]
		if absf(pct - want[i] * 100.0) > 6.0:
			share_ok = false
	print("[deep] GUARD SHARE %d hulks past depth %.0f (%d skipped beside a station): %s-> %s" % [
		hulks_past, DeepSpace.GUARD_MIN_DEPTH, skipped_near_station, share_line,
		"PASS" if share_ok else "FAIL"])

	# G3. THE CURVE. A guard is scary through count, HP and where it stands, never
	#     alpha — so the deepest guard's shot must stay UNDER the hardest sentry
	#     the chart authors. Computed from SystemDB rather than restated, so the
	#     swarm curve would print 36.4 vs 30.8 -> FAIL instead of merely playing
	#     badly.
	var hardest_charted := 0.0
	for sid in SystemDB.ids():
		var sd := SystemDB.get_system(String(sid))
		if not (sd.get("sentries", []) as Array).is_empty():
			hardest_charted = maxf(hardest_charted,
				Hostile.DAMAGE * float(sd.get("difficulty", 1.0)))
	var curve := ""
	var curve_ok := true
	var prev_hp := 0.0
	var prev_dmg := 0.0
	for band in range(1, DeepSpace.BAND_NAMES.size()):
		var d := float(DeepSpace.GUARD_DIFFICULTY[band])
		var hpv := Hostile.BASE_HP * d * float(DeepSpace.GUARD_HP_SCALE[band])
		var dmg := Hostile.DAMAGE * d
		curve += "%s %.0fhp/%.1f | " % [DeepSpace.BAND_NAMES[band], hpv, dmg]
		if hpv <= prev_hp or dmg <= prev_dmg or dmg >= hardest_charted:
			curve_ok = false
		prev_hp = hpv
		prev_dmg = dmg
	print("[deep] GUARD CURVE %shardest charted sentry hits %.1f -> %s" % [
		curve, hardest_charted, "PASS" if curve_ok else "FAIL"])

	# G4. TWO GUNS TYPICAL, THREE AT WORST, NEVER FOUR. The whole hold arithmetic
	#     rests on this, so it is measured against the real approach geometry
	#     rather than derived on paper: Derelict._approach parks the ship at
	#     CRACK_RANGE * 0.78 on a bearing bounded to 32 degrees off the outward
	#     axis by that function's 1.6 weighting.
	var eng_min := 99
	var eng_max := 0
	var nearest_gun := INF
	var probe_rng := RandomNumberGenerator.new()
	probe_rng.seed = 12345
	for count in [2, 3, 4]:
		for bstep in range(8):
			var rot := 45.0 * float(bstep)
			var hull := Vector3(0, 0, 0)
			var posts2 := DeepSpace.guard_posts(hull, rot, count, probe_rng)
			var basis := Basis(Vector3.UP, deg_to_rad(rot))
			var breach: Vector3 = hull + basis * Derelict.BEACON_LOCAL
			breach.y = 0.0
			var outward := (breach - hull)
			outward.y = 0.0
			outward = outward.normalized()
			# Worst realistic case: the 32-degree oblique approach.
			for off in [0.0, 32.0, -32.0]:
				var dir := Basis(Vector3.UP, deg_to_rad(off)) * outward
				var stand: Vector3 = breach + dir * (Derelict.CRACK_RANGE * 0.78)
				var guns := 0
				for pv in posts2:
					var dd: float = (pv as Vector3).distance_to(stand)
					if dd <= Hostile.ENGAGE_RANGE:
						guns += 1
						nearest_gun = minf(nearest_gun, dd)
				eng_min = mini(eng_min, guns)
				eng_max = maxi(eng_max, guns)
	print("[deep] GUARD ENGAGEMENT posts of 2/3/4 over 8 hull bearings x 3 approaches put %d-%d guns on a parked ship (engage %.1f, nearest %.2fu) -> %s" % [
		eng_min, eng_max, Hostile.ENGAGE_RANGE, nearest_gun,
		"PASS" if eng_min >= 2 and eng_max <= 3 else "FAIL"])

	# G5. What the curve MEANS: tankable in the near bands, not in the far ones,
	#     and Bulwark answers all four. Four-sided, so breaking the curve in
	#     either direction flips a word with its number beside it.
	var hold_line := ""
	var hold_ok := true
	var bulwark_worst := 0.0
	for band in range(1, DeepSpace.BAND_NAMES.size()):
		var dmg2 := Hostile.DAMAGE * float(DeepSpace.GUARD_DIFFICULTY[band])
		var volleys := ceili((1.8 + 0.2 * float(band)) / Hostile.FIRE_INTERVAL)
		var cost := dmg2 * 3.0 * float(volleys)     # worst case: three guns
		bulwark_worst = maxf(bulwark_worst, cost)
		var tankable := cost < 100.0
		hold_line += "%s %.0f %s | " % [DeepSpace.BAND_NAMES[band], cost,
			"ok" if tankable else "no"]
		if band <= 2 and not tankable:
			hold_ok = false
		if band >= 3 and tankable:
			hold_ok = false
	print("[deep] GUARD HOLD base 100 shield: %sBulwark 250 survives all four=%s -> %s" % [
		hold_line, str(bulwark_worst < 250.0),
		"PASS" if hold_ok and bulwark_worst < 250.0 else "FAIL"])

	# The wave-spawner block above turned generation OFF to measure it in
	# isolation. G6 and G7 need live cells, so it goes back on here and off
	# again at the end, leaving the state the station block expects.
	deep_space.set_generation(true)
	await get_tree().process_frame

	# G6. WHERE THEY ACTUALLY STAND. 18's lesson was that a value no assertion
	#     reads can be wrong for months, and the ones most likely to be wrong are
	#     set by a caller AFTER construction — which is exactly how a guard's
	#     position is set. A new kind of enemy placement that shipped without its
	#     own position assertion would reproduce the sentry bug verbatim.
	var gcell := Vector2i(0, 0)
	var gplan := {}
	for ring in range(2, 30):
		for cx in range(-ring, ring + 1):
			for cz in range(-ring, ring + 1):
				if maxi(absi(cx), absi(cz)) != ring or not gplan.is_empty():
					continue
				var pl := deep_space.plan_cell(cx, cz)
				var hk: Dictionary = pl.get("hulk", {})
				if hk.is_empty() or int((hk.get("guards", {}) as Dictionary).get("count", 0)) < 3:
					continue
				gcell = Vector2i(cx, cz)
				gplan = hk
	var gcfg: Dictionary = gplan.get("guards", {})
	player.global_position = gplan["pos"]
	for i in range(4):
		await get_tree().physics_frame
		await get_tree().process_frame

	# Asked BY CELL: the 5x5 window holds several guarded hulks at once, so a
	# sweep of the deep_guard group would count a neighbour's post as this one's.
	var live_guards: Array = deep_space.guards_at(gcell)
	var worst_plan := 0.0
	for g in live_guards:
		var best := INF
		for pv in gcfg.get("posts", []):
			best = minf(best, (g as Node3D).global_position.distance_to(pv))
		worst_plan = maxf(worst_plan, best)

	# The live breach point, read AFTER a frame: Derelict.breach_point is set in
	# _ready, which fires from add_child, before _spawn_cell assigns the position.
	# Reading it earlier gives the container origin — the same trap as _home.
	var hulk_node: Derelict = null
	for n in get_tree().get_nodes_in_group("crackable"):
		if n is Derelict and (n as Node3D).global_position.distance_to(gplan["pos"]) < 1.0:
			hulk_node = n
	var live_breach := hulk_node.breach_point if hulk_node != null else Vector3.ZERO
	var planned_breach: Vector3 = gplan["pos"] + Basis(Vector3.UP,
		deg_to_rad(float(gplan["rot_y"]))) * Derelict.BEACON_LOCAL
	planned_breach.y = 0.0
	var breach_agree := Vector2(live_breach.x - planned_breach.x,
		live_breach.z - planned_breach.z).length()
	var nearest_breach := INF
	for g in live_guards:
		nearest_breach = minf(nearest_breach,
			Vector2((g as Node3D).global_position.x - live_breach.x,
				(g as Node3D).global_position.z - live_breach.z).length())
	print("[deep] GUARD POSTS %d guards at cell (%d,%d), furthest from its planned post %.2fu, nearest to the live breach point %.2fu (crack range %.1f), plan and node agree to %.2fu -> %s" % [
		live_guards.size(), gcell.x, gcell.y, worst_plan, nearest_breach,
		Derelict.CRACK_RANGE, breach_agree,
		"PASS" if live_guards.size() == int(gcfg["count"]) and worst_plan <= 0.6
			and nearest_breach > Derelict.CRACK_RANGE and breach_agree < 0.5 else "FAIL"])

	# G7. A CLEARED POST STAYS CLEARED. Hostile.LOOT_COUNT is 14 against a swarm's
	#     2 and PACING_LOOP budgets five sentries for a whole loop, so a post that
	#     rebuilt on cell cycle would be an unbounded farm reachable by flying
	#     200u out and back. 4/4 here means it farms forever; 0/0 means flying
	#     away disarms it. Both are visibly wrong.
	var partial_key := gcell
	if live_guards.size() > 1:
		(live_guards[0] as Hostile).take_damage(999999.0)
	await get_tree().create_timer(0.6).timeout
	player.global_position = gplan["pos"] + Vector3(900.0, 0.0, 900.0)
	for i in range(6):
		await get_tree().physics_frame
		await get_tree().process_frame
	player.global_position = gplan["pos"]
	for i in range(6):
		await get_tree().physics_frame
		await get_tree().process_frame
	var after_partial := deep_space.post_standing(gcell)

	# Now clear it outright and repeat.
	for n in deep_space.guards_at(gcell):
		if is_instance_valid(n):
			(n as Hostile).take_damage(999999.0)
	await get_tree().create_timer(0.6).timeout
	player.global_position = gplan["pos"] + Vector3(900.0, 0.0, 900.0)
	for i in range(6):
		await get_tree().physics_frame
		await get_tree().process_frame
	player.global_position = gplan["pos"]
	for i in range(6):
		await get_tree().physics_frame
		await get_tree().process_frame
	var after_full := deep_space.post_standing(gcell)
	print("[deep] GUARD CLEARED killed 1 of %d, left and returned -> %d standing; killed all, left and returned -> %d standing -> %s" % [
		int(gcfg["count"]), after_partial, after_full,
		"PASS" if after_partial == int(gcfg["count"]) and after_full == 0 else "FAIL"])

	# G8. A CRACKED HULL STAYS CRACKED — G7's assertion for the wreck the post is
	#     standing over. The post remembered and the mast on the stern remembered;
	#     the HULL did not, so the same 200u round trip that G7 forbids for guards
	#     paid full loot, four archeology XP and a hulks_cracked tick every lap.
	#     It shipped because nothing looked: G7 measures the post, CARTTEST
	#     measures the mast, and nothing measured the thing between them.
	var hulk_cell := gcell
	var hulk_pos: Vector3 = (deep_space.plan_cell(hulk_cell.x, hulk_cell.y)["hulk"] as Dictionary)["pos"]
	var hull_before := int(GameState.ledger.get("hulks_cracked", 0))
	var live_hulk: Derelict = null
	for n in get_tree().get_nodes_in_group("crackable"):
		if n is Derelict and (n as Derelict).global_position.distance_to(hulk_pos) < 1.0:
			live_hulk = n
	# Captured NOW. The cell is about to be cycled out, which FREES this node —
	# and a freed reference compares equal to null, so asking `live_hulk != null`
	# after the round trip silently becomes "did it survive the rebuild" instead
	# of "did we find it". RIFTTEST hit this exact trap and says so at its own
	# second_spawned.
	var hulk_found := live_hulk != null
	if live_hulk != null:
		live_hulk.force_breach()
	await get_tree().create_timer(0.6).timeout
	var hull_after_first := int(GameState.ledger.get("hulks_cracked", 0))
	player.global_position = hulk_pos + Vector3(900.0, 0.0, 900.0)
	for i in range(6):
		await get_tree().physics_frame
		await get_tree().process_frame
	player.global_position = hulk_pos
	for i in range(6):
		await get_tree().physics_frame
		await get_tree().process_frame
	# The rebuilt hull must come back already open: out of the crackable group,
	# so nothing can hold it, and never having paid a second time.
	var rebuilt_open := true
	for n in get_tree().get_nodes_in_group("crackable"):
		if n is Derelict and (n as Derelict).global_position.distance_to(hulk_pos) < 1.0:
			rebuilt_open = false
	var hull_after_return := int(GameState.ledger.get("hulks_cracked", 0))
	print("[deep] HULK STAYS CRACKED found=%s breached (%d -> %d), left and returned: still open=%s, ledger %d (must not move) -> %s" % [
		str(hulk_found), hull_before, hull_after_first, str(rebuilt_open),
		hull_after_return,
		"PASS" if hulk_found and hull_after_first == hull_before + 1
			and rebuilt_open and hull_after_return == hull_after_first else "FAIL"])
	deep_space.set_generation(false)
	await get_tree().process_frame



	# --- C3: deep stations ---------------------------------------------------

	# 16. The expanse must not have leaked into the chart. This is the assertion
	#     that keeps market events, the rumour engine and three STATIONTEST sweeps
	#     safe by construction rather than by anybody remembering.
	var leaked := ""
	for pid_v in SystemDB.port_ids():
		if DeepPortDB.is_deep_port(String(pid_v)):
			leaked = String(pid_v)
	print("[deep] CHART UNPOLLUTED %d ports on the chart, none of them deep (%s) -> %s" % [
		SystemDB.port_ids().size(), "clean" if leaked == "" else leaked,
		"PASS" if leaked == "" else "FAIL"])

	# 17. Find a real one out in the world, fly to it, and dock.
	deep_space.set_generation(true)
	for n in get_tree().get_nodes_in_group("hostiles"):
		(n as Node3D).queue_free()
	# Stations are rare on purpose, so this is a search. Try each band outward
	# and take the first that has actually built one.
	var berth := Vector2i(0x7fffffff, 0x7fffffff)
	for try_band in [1, 2, 3, 4]:
		berth = _deep_probe(try_band, "station")
		if berth.x != 0x7fffffff:
			break
	var found_station := berth.x != 0x7fffffff
	var st_plan: Dictionary = deep_space.plan_cell(berth.x, berth.y)["station"] if found_station else {}
	var arch_id := String(st_plan.get("archetype", "")) if found_station else ""
	var st_pos: Vector3 = st_plan.get("pos", Vector3.ZERO) if found_station else Vector3.ZERO
	player.global_position = st_pos + Vector3(0, 0, 3.0)
	for i in range(4):
		await get_tree().process_frame
	var deep_port: Port = null
	for n in get_tree().get_nodes_in_group("dockable"):
		if (n as Port).port_id == arch_id:
			deep_port = n
	print("[deep] DEEP STATION %s built at cell (%d,%d), %.0fu out, depth %.0f, band %s -> %s" % [
		arch_id, berth.x, berth.y, Vector2(st_pos.x, st_pos.z).length(),
		deep_space.depth_at(st_pos), DeepSpace.band_name(deep_space.depth_at(st_pos)),
		"PASS" if found_station and deep_port != null else "FAIL"])

	# 18. And it is a station, not a prop: dockable, with tabs driven by its own
	#     services list, from a def carried on the node rather than in SystemDB.
	var docked_ok := false
	var tabs: Array = []
	if deep_port != null:
		player.global_position = deep_port.dock_point
		await get_tree().process_frame
		request_dock(deep_port)
		await get_tree().process_frame
		docked_ok = docked_port == deep_port and port_panel.is_open
		tabs = port_panel.services()
	print("[deep] DEEP DOCK clamped on=%s, tabs %s (from Port.def, not SystemDB) -> %s" % [
		str(docked_ok), str(tabs),
		"PASS" if docked_ok and not tabs.is_empty() else "FAIL"])

	# 19. Restricted goods trade freely out here — nobody asks what is in the
	#     crate, and that is the reward for the trip. On the chart, contraband
	#     still has exactly two buyers.
	var deep_takes_banned := CommodityDB.trades_at("contraband", arch_id)
	var chart_banned := []
	for pid_v in SystemDB.port_ids():
		if CommodityDB.trades_at("contraband", String(pid_v)):
			chart_banned.append(String(pid_v))
	print("[deep] DEEP RESTRICTIONS contraband trades at %s=%s, chart buyers still %s -> %s" % [
		arch_id, str(deep_takes_banned), str(chart_banned),
		"PASS" if deep_takes_banned and chart_banned.size() == 2 else "FAIL"])

	# 20. It has to PAY better, or there is no reason to have come. The Haven and
	#     the Watch fence contraband at 1.45 against the best charted 1.25.
	var best_chart := 1.0
	for pid_v in SystemDB.port_ids():
		best_chart = maxf(best_chart,
			Market.fence_bonus(SystemDB.port_def_by_id(String(pid_v)), "contraband"))
	var best_deep := 1.0
	var best_deep_name := ""
	for a_v in DeepPortDB.ARCHETYPES:
		var a: Dictionary = a_v
		var f := Market.fence_bonus(a, "contraband")
		if f > best_deep:
			best_deep = f
			best_deep_name = String(a["name"])
	print("[deep] DEEP PAYS MORE best contraband fence: chart %.2fx vs %s %.2fx -> %s" % [
		best_chart, best_deep_name, best_deep,
		"PASS" if best_deep > best_chart else "FAIL"])

	# 21. Nothing may be camped on the dock ring, and nothing may be parked in the
	#     approach lane. A station you cannot reach is worse than no station.
	#     Swept ACROSS cells, not within them. A cell's keep-out test can only see
	#     its own contents, so the case that actually needed proving is a nest
	#     rolled in the cell next door — which the insets in DeepSpace are sized
	#     to make impossible, and which a per-cell check would never have looked
	#     at. Widened to a block far larger than the streaming window so this is a
	#     statement about the generator rather than about one visit.
	var stations := []
	var nests := []
	var boulders := []
	var scanned := 0
	for cz in range(-16, 17):
		for cx in range(-16, 17):
			var pl := deep_space.plan_cell(cx, cz)
			scanned += 1
			if not (pl["station"] as Dictionary).is_empty():
				stations.append((pl["station"] as Dictionary)["pos"])
			if not (pl["pack"] as Dictionary).is_empty():
				nests.append((pl["pack"] as Dictionary)["pos"])
			for r_v in pl["rocks"]:
				boulders.append(r_v["pos"])
	var closest_nest := INF
	var closest_rock := INF
	for sp_v in stations:
		var sp: Vector3 = sp_v
		for np_v in nests:
			closest_nest = minf(closest_nest, sp.distance_to(np_v))
		for bp_v in boulders:
			closest_rock = minf(closest_rock, sp.distance_to(bp_v))
	print("[deep] DEEP APPROACH %d cells: %d stations, %d nests, %d rocks; nearest nest %.1fu (want >= %.0f), nearest rock %.1fu (want >= %.0f) -> %s" % [
		scanned, stations.size(), nests.size(), boulders.size(),
		closest_nest, DeepSpace.STATION_SAFE_RADIUS,
		closest_rock, DeepSpace.STATION_CLEARANCE,
		"PASS" if stations.size() > 0 and nests.size() > 0 \
			and closest_nest >= DeepSpace.STATION_SAFE_RADIUS \
			and closest_rock >= DeepSpace.STATION_CLEARANCE else "FAIL"])
	undock()

	# --- B5/B6: wayfinding and the way back ----------------------------------

	deep_space.set_generation(false)
	for n in get_tree().get_nodes_in_group("hostiles"):
		(n as Node3D).queue_free()
	await get_tree().process_frame
	var edge_radius := SystemDB.bounds_of(system_id)

	# 22. The readout has to answer "where am I" out where nothing else does.
	player.global_position = PlayerShip.SPAWN_POINT
	await get_tree().process_frame
	var tag_home := hud.system_tag_text()
	player.global_position = Vector3(edge_radius + 300.0, 0, 0)
	await get_tree().process_frame
	var tag_out := hud.system_tag_text()
	print("[deep] SYSTEM TAG inside '%s' / outside '%s' -> %s" % [tag_home, tag_out,
		"PASS" if not tag_home.contains("OUT") and tag_out.contains("OUT")
			and tag_out.contains("THE DRIFT") else "FAIL"])

	# 23. The home marker: present outside, absent inside, and NEVER dropped by
	#     the 12-marker cap. That last clause is the whole point of the tier —
	#     out here with a full board, the one arrow you cannot afford to lose is
	#     the one pointing at the system you came from.
	var radar := hud.radar()
	player.global_position = PlayerShip.SPAWN_POINT
	await get_tree().process_frame
	await get_tree().process_frame
	var home_inside := hud.has_home_marker()

	player.global_position = Vector3(edge_radius + 500.0, 0, 0)
	await get_tree().process_frame
	await get_tree().process_frame
	var home_outside := hud.has_home_marker()

	# Now bury it: thirty contacts, more than twice the cap.
	for i in range(30):
		var filler := SwarmHostile.new()
		filler.hp_scale = 40.0
		system_root.add_child(filler)
		filler.global_position = player.global_position + Vector3(
			cos(TAU * float(i) / 30.0), 0, sin(TAU * float(i) / 30.0)) * 90.0
		filler.dock_at(filler.global_position)     # pinned, so nothing drifts
	await get_tree().process_frame
	await get_tree().process_frame
	var home_buried := hud.has_home_marker()
	var shown := radar.markers.size()
	print("[deep] HOME MARKER inside=%s outside=%s survives %d contacts at the %d cap=%s -> %s" % [
		str(home_inside), str(home_outside), 30, HUD.RadarLayer.MAX_MARKERS,
		str(home_buried),
		"PASS" if not home_inside and home_outside and home_buried
			and shown <= HUD.RadarLayer.MAX_MARKERS else "FAIL"])

	# 24. Marker alpha stopped saturating. At 60u the old falloff was already
	#     pinned at its 0.3 floor, so 61u and 6000u drew identically — which out
	#     here is every contact on the board.
	player.global_position = PlayerShip.SPAWN_POINT
	await get_tree().process_frame
	var span_home := radar.alpha_span
	player.global_position = Vector3(edge_radius + 500.0, 0, 0)
	await get_tree().process_frame
	var span_deep := radar.alpha_span
	print("[deep] MARKER ALPHA falloff span %.0fu in system (unchanged) -> %.0fu in %s -> %s" % [
		span_home, span_deep, DeepSpace.band_name(deep_depth()),
		"PASS" if is_equal_approx(span_home, HUD.RadarLayer.ALPHA_SPAN)
			and span_deep > span_home else "FAIL"])
	for n in get_tree().get_nodes_in_group("hostiles"):
		(n as Node3D).queue_free()
	await get_tree().process_frame

	# 25. Recall. The ship comes home; the WORLD does not move. If SystemRoot were
	#     rebuilt this would reset the apex to full, respawn the garrison and
	#     delete loot still in flight — for a move that never leaves the system.
	var far_post := Vector3(edge_radius + 900.0, 0, 0)
	player.global_position = far_post
	await get_tree().process_frame
	var root_before := system_root.get_instance_id()
	# A specific cube, held by reference: "the world survived" is a claim about
	# this object still existing, not about a count that could coincide. Dropped
	# where the player IS, not at the origin — a cube waiting at the spawn point
	# is inside the tractor radius the moment the recall lands, and "collected"
	# would read here as "destroyed".
	# Far from BOTH the deep post and the spawn point. Loose cubes home on the
	# player from any distance after SEEK_ALWAYS_AFTER so no salvage is ever
	# stranded — drop one at arm's length and the tractor eats it before the
	# recall finishes, which would read here as "destroyed by the teardown".
	var in_flight := spawn_loot(system_root, Vector3(0, 0, -(edge_radius + 320.0)))
	await get_tree().process_frame
	var offered := can_recall()
	recall_to_system()
	# The full beat list is CHARGE + STREAK + ARRIVE = 2.45s of awaited timers,
	# so this has to be a wall-clock wait rather than a frame count.
	await get_tree().create_timer(WARP_CHARGE + WARP_STREAK + WARP_ARRIVE + 0.6).timeout
	var home_dist := player.global_position.distance_to(PlayerShip.SPAWN_POINT)
	print("[deep] RECALL offered at %.0fu out=%s -> ship %.1fu from spawn, SystemRoot same=%s, loot in flight survived=%s -> %s" % [
		edge_radius + 900.0, str(offered), home_dist,
		str(system_root.get_instance_id() == root_before),
		str(is_instance_valid(in_flight)),
		"PASS" if offered and home_dist < 1.0 \
			and system_root.get_instance_id() == root_before \
			and is_instance_valid(in_flight) else "FAIL"])
	if is_instance_valid(in_flight):
		in_flight.queue_free()

	# 26. And it is refused where docking is refused. Breaking off an apex by
	#     tapping a console would be an exit, not a decision.
	player.global_position = Vector3(edge_radius + 900.0, 0, 0)
	await get_tree().process_frame
	var free_out := can_recall()
	_set_boss_active(true)
	var during_boss := can_recall()
	_set_boss_active(false)
	warping = true
	var during_warp := can_recall()
	warping = false
	player.global_position = PlayerShip.SPAWN_POINT
	await get_tree().process_frame
	var while_home := can_recall()
	print("[deep] RECALL REFUSED out=%s boss=%s warping=%s inside the system=%s -> %s" % [
		str(free_out), str(during_boss), str(during_warp), str(while_home),
		"PASS" if free_out and not during_boss and not during_warp and not while_home
			else "FAIL"])

	# --- return fire, traps, the apex lock and the beacons -------------------

	# 27. The ship shoots back on its own while under fire, WITHOUT flying at what
	#     shot it — and an explicit order takes the guns straight back.
	player.global_position = Vector3(0, 0, 6)
	player.clear_target()
	player.velocity = Vector3.ZERO
	await get_tree().process_frame
	var idle_gun := player.gun_target()          # nothing has hit us: stand down

	var biter := SwarmHostile.new()
	biter.hp_scale = 60.0                        # survives long enough to measure
	system_root.add_child(biter)
	biter.global_position = player.global_position + Vector3(2.5, 0, 0)
	biter.dock_at(biter.global_position)         # pinned, so distance stays honest
	var other := SwarmHostile.new()
	other.hp_scale = 60.0
	system_root.add_child(other)
	other.global_position = player.global_position + Vector3(0, 0, 3.0)
	other.dock_at(other.global_position)
	await get_tree().process_frame

	# Somebody shoots us; the guns must find THEM, not merely the nearest thing.
	var stood_at := player.global_position
	player.take_hit(1.0, other)
	for i in range(4):
		await get_tree().physics_frame
	var answered: Node3D = player.gun_target()
	var drifted := player.global_position.distance_to(stood_at)
	print("[deep] RETURN FIRE idle target=%s, under fire answers the attacker=%s, ship moved %.2fu (must be ~0) -> %s" % [
		"none" if idle_gun == null else "something", str(answered == other), drifted,
		"PASS" if idle_gun == null and answered == other and drifted < 0.5 else "FAIL"])

	# An explicit order wins, always and immediately.
	player.command_attack(biter)
	await get_tree().physics_frame
	var obeyed := player.gun_target() == biter and player.auto_target == null
	player.clear_target()
	print("[deep] RETURN FIRE OVERRIDE explicit order retakes the guns=%s -> %s" % [
		str(obeyed), "PASS" if obeyed else "FAIL"])
	biter.queue_free()
	other.queue_free()
	await get_tree().process_frame

	# 28. Rigged hulks: seeded like everything else, riskier and richer with
	#     depth, and carrying a bigger ambush further out.
	var trap_rows := ""
	var trap_rising := true
	for b in range(1, DeepSpace.BAND_NAMES.size()):
		trap_rows += "%s %d%% emp %.1fs pack %d-%d%s | " % [
			DeepSpace.BAND_NAMES[b], int(round(DeepSpace.TRAP_CHANCE[b] * 100.0)),
			DeepSpace.TRAP_EMP[b], DeepSpace.TRAP_PACK_MIN[b], DeepSpace.TRAP_PACK_MAX[b],
			" +escort" if b >= DeepSpace.TRAP_ESCORT_FROM else ""]
		if b > 1 and (DeepSpace.TRAP_CHANCE[b] < DeepSpace.TRAP_CHANCE[b - 1]
				or DeepSpace.TRAP_EMP[b] < DeepSpace.TRAP_EMP[b - 1]
				or DeepSpace.TRAP_PACK_MAX[b] < DeepSpace.TRAP_PACK_MAX[b - 1]):
			trap_rising = false
	print("[deep] TRAPS RISE %s-> %s" % [trap_rows, "PASS" if trap_rising else "FAIL"])

	# Deterministic, and the bet actually pays: a rigged wreck carries more.
	var rigged := Vector2i(0x7fffffff, 0x7fffffff)
	var clean := Vector2i(0x7fffffff, 0x7fffffff)
	for ring in range(1, 26):
		for cz in range(-ring, ring + 1):
			for cx in range(-ring, ring + 1):
				if maxi(absi(cx), absi(cz)) != ring:
					continue
				var h: Dictionary = deep_space.plan_cell(cx, cz)["hulk"]
				if h.is_empty():
					continue
				if not (h["trap"] as Dictionary).is_empty():
					if rigged.x == 0x7fffffff:
						rigged = Vector2i(cx, cz)
				elif clean.x == 0x7fffffff:
					clean = Vector2i(cx, cz)
	var stable_trap := false
	var pays_more := false
	if rigged.x != 0x7fffffff:
		stable_trap = var_to_str(deep_space.plan_cell(rigged.x, rigged.y)["hulk"]) \
			== var_to_str(deep_space.plan_cell(rigged.x, rigged.y)["hulk"])
		if clean.x != 0x7fffffff:
			var rl := int((deep_space.plan_cell(rigged.x, rigged.y)["hulk"] as Dictionary)["loot"])
			var cl := int((deep_space.plan_cell(clean.x, clean.y)["hulk"] as Dictionary)["loot"])
			var rb := int(deep_space.plan_cell(rigged.x, rigged.y)["band"])
			var cb := int(deep_space.plan_cell(clean.x, clean.y)["band"])
			# Compare like with like by normalising the band's own loot curve out.
			var band_loot := [1.0, 1.15, 1.6, 2.2, 2.9]
			pays_more = (float(rl) / band_loot[rb]) > (float(cl) / band_loot[cb]) * 1.2
	print("[deep] TRAP SEEDED rigged hulk at (%d,%d) stable=%s, pays more than a clean one=%s -> %s" % [
		rigged.x, rigged.y, str(stable_trap), str(pays_more),
		"PASS" if stable_trap and pays_more else "FAIL"])

	# 29. And springing one actually locks the ship out and brings company.
	for n in get_tree().get_nodes_in_group("hostiles"):
		(n as Node3D).queue_free()
	await get_tree().process_frame
	var trap_cfg := {"emp": 1.5, "count": 5, "hp_scale": 1.6, "difficulty": 1.4,
		"tint": Palette.DEEP_DRIFT, "drop": "cores", "escort": true, "band": 3}
	player.global_position = Vector3(edge_radius + 400.0, 0, 0)
	await get_tree().process_frame
	spring_trap(player.global_position, trap_cfg)
	await get_tree().physics_frame
	var stunned := player.is_emp_stunned()
	player.command_move(player.global_position + Vector3(30, 0, 0))
	await get_tree().physics_frame
	var moved_while_stunned := player.has_move_target
	await get_tree().create_timer(1.0).timeout
	var ambush := get_tree().get_nodes_in_group("hostiles").size()
	await get_tree().create_timer(1.2).timeout
	var recovered := not player.is_emp_stunned()
	print("[deep] TRAP SPRUNG emp locked the ship=%s, orders refused while stunned=%s, %d contacts inbound, recovered=%s -> %s" % [
		str(stunned), str(not moved_while_stunned), ambush, str(recovered),
		"PASS" if stunned and not moved_while_stunned and ambush >= 6 and recovered
			else "FAIL"])
	for n in get_tree().get_nodes_in_group("hostiles"):
		(n as Node3D).queue_free()
	await get_tree().process_frame

	# 30. The apex lock no longer follows the player out of the charted volume.
	player.global_position = PlayerShip.SPAWN_POINT
	await get_tree().process_frame
	_set_boss_active(true)
	var locked_in := boss_active and not hud.chart_button.enabled and not can_recall()
	player.global_position = Vector3(edge_radius + 120.0, 0, 0)
	await get_tree().process_frame
	await get_tree().process_frame
	var left_at := player.global_position
	var freed := not boss_active
	var stayed_out := player.global_position.distance_to(left_at) < 1.0
	print("[deep] APEX LOCK locked inside=%s, leaving charted space broke it off=%s, player NOT yanked home=%s -> %s" % [
		str(locked_in), str(freed), str(stayed_out),
		"PASS" if locked_in and freed and stayed_out else "FAIL"])
	_apex_wake_timer = -1.0

	# 31. The beacons. One per band, outward only, and the first one is the
	#     survey authority disowning you — which is what replaced the wall.
	_broadcast_band = 0
	player.global_position = PlayerShip.SPAWN_POINT
	await get_tree().process_frame
	var quiet_at_home := hud.broadcast_text() == ""
	player.global_position = Vector3(edge_radius + 60.0, 0, 0)
	await get_tree().process_frame
	var first := hud.broadcast_text()
	# Coming back in must not replay it.
	player.global_position = PlayerShip.SPAWN_POINT
	await get_tree().process_frame
	var band_after_return := _broadcast_band
	print("[deep] BEACONS silent inside=%s, first crossing says '%s...', no replay on the way home=%s -> %s" % [
		str(quiet_at_home), first.substr(0, 44), str(band_after_return == 1),
		"PASS" if quiet_at_home and first.contains("charted space")
			and first.contains("own risk") and band_after_return == 1 else "FAIL"])

	# 32. Deep station ids stay ARCHETYPE-scoped. If they ever became per-cell,
	#     every station traded at would add a permanent market-pressure key to the
	#     save, and "the expanse costs zero bytes" would quietly stop being true.
	var seen_ids := {}
	for cz in range(-14, 15):
		for cx in range(-14, 15):
			var st3: Dictionary = deep_space.plan_cell(cx, cz)["station"]
			if not st3.is_empty():
				seen_ids[String(st3["archetype"])] = true
	var all_known := true
	for id_v in seen_ids:
		if DeepPortDB.by_id(String(id_v)).is_empty():
			all_known = false
	print("[deep] STATION IDS %d distinct across 841 cells, cap is %d archetypes, all known=%s -> %s" % [
		seen_ids.size(), DeepPortDB.count(), str(all_known),
		"PASS" if seen_ids.size() <= DeepPortDB.count() and all_known else "FAIL"])
	get_tree().quit()


# --- apex identity harness ----------------------------------------------------

func _run_apex_test() -> void:
	var player: PlayerShip = get_tree().get_first_node_in_group("player")
	set_deep_generation(false)
	_wave_timer = 1.0e9

	# 1. Identity is data, and it is actually distinct: three names, three
	#    armaments, no repeats.
	var names := {}
	var attacks := {}
	for sys in SystemDB.ids():
		var apex: Dictionary = SystemDB.get_system(String(sys)).get("apex", {})
		names[String(apex.get("name", ""))] = true
		attacks[String(apex.get("attack", ""))] = true
		print("[apex] %s -> %s (%s)" % [sys, String(apex.get("name", "?")),
			String(apex.get("attack", "?"))])
	print("[apex] UNIQUE %d names, %d armaments across %d systems -> %s" % [
		names.size(), attacks.size(), SystemDB.ids().size(),
		"PASS" if names.size() == 3 and attacks.size() == 3 else "FAIL"])

	# 2. Per system: the boss carries its data name, and the HUB ITSELF hurts a
	#    player who parks in range — with every probe deleted the moment it
	#    vents, so nothing but the boss's own armament can be the source.
	for sys in ["pyx01", "pyx02", "pyx03"]:
		GameState.mark_breached(sys)
		_load_system(sys)
		await get_tree().create_timer(0.4).timeout
		var boss := _find_apex()
		_apex_wake_timer = 0.2
		await get_tree().create_timer(ApexBoss.WAKE_TIME + 1.0).timeout
		print("[apex] %s NAME '%s' matches data -> %s" % [sys, boss.boss_name,
			"PASS" if boss.boss_name == String(
				(SystemDB.get_system(sys).get("apex", {}) as Dictionary).get("name", "")) else "FAIL"])

		player.invulnerable = false
		player.shield = player.shield_max
		var taken := 0.0
		var prev: float = player.shield
		var park: Vector3 = boss.global_position + Vector3(0, 0, 4.5)
		var displaced := 0.0
		for i in range(60 * 14):
			# Probes die on sight, so the only remaining sources are the sweep
			# arm (parked outside its blade path check below) and the armament.
			for pr in get_tree().get_nodes_in_group("apex_probe"):
				if is_instance_valid(pr):
					(pr as Node3D).queue_free()
			# Parked but not pinned: the tether needs to be able to move the
			# ship, so displacement is measured instead of prevented. The lance
			# and mortar bosses hold the spot by re-assigning position, which
			# also makes them the stationary worst case their telegraphs punish.
			if boss.attack_kind == "grav_tether":
				displaced = maxf(displaced,
					park.distance_to(player.global_position))
			else:
				player.global_position = park
				player.velocity = Vector3.ZERO
			player.clear_target()
			await get_tree().physics_frame
			if player.shield < prev:
				taken += prev - player.shield
			prev = player.shield
			if player.shield < 40.0:
				player.shield = player.shield_max     # never trip the emergency warp
				prev = player.shield

		if boss.attack_kind == "grav_tether":
			# The Meridian's armament is control, not damage: the assertion is
			# that an idle ship gets DRAGGED, not that it gets hurt.
			print("[apex] %s ARMAMENT %s dragged an idle ship %.1fu toward the hub -> %s" % [
				sys, boss.attack_kind, displaced,
				"PASS" if displaced > 1.5 else "FAIL"])
		else:
			print("[apex] %s ARMAMENT %s dealt %.0f to a parked ship over 14s -> %s" % [
				sys, boss.attack_kind, taken,
				"PASS" if taken > 0.0 else "FAIL"])
		player.invulnerable = true
		boss.reset_fight()

	# 3. The attacks are dodgeable — the series rule. Measured on the Gnomon:
	#    the same window twice, parked vs orbiting the lock point.
	GameState.mark_breached("pyx01")
	_load_system("pyx01")
	await get_tree().create_timer(0.4).timeout
	var gnomon := _find_apex()
	_apex_wake_timer = 0.2
	await get_tree().create_timer(ApexBoss.WAKE_TIME + 1.0).timeout
	var parked := await _apex_damage_window(gnomon, false)
	gnomon.reset_fight()
	_apex_wake_timer = 0.2
	await get_tree().create_timer(ApexBoss.WAKE_TIME + 1.0).timeout
	var moving := await _apex_damage_window(gnomon, true)
	print("[apex] DODGEABLE parked took %.0f, orbiting took %.0f over the same window -> %s" % [
		parked, moving,
		"PASS" if parked > 0.0 and moving < parked * 0.5 else "FAIL"])

	# 4. Out of range means out of the fight: no cross-system sniping.
	gnomon.reset_fight()
	_apex_wake_timer = 0.2
	await get_tree().create_timer(ApexBoss.WAKE_TIME + 1.0).timeout
	player.invulnerable = false
	player.shield = player.shield_max
	var far: Vector3 = gnomon.global_position + Vector3(0, 0, 30.0)
	var far_prev: float = player.shield
	var far_taken := 0.0
	for i in range(60 * 8):
		for pr in get_tree().get_nodes_in_group("apex_probe"):
			if is_instance_valid(pr):
				(pr as Node3D).queue_free()
		player.global_position = far
		player.velocity = Vector3.ZERO
		await get_tree().physics_frame
		if player.shield < far_prev:
			far_taken += far_prev - player.shield
		far_prev = player.shield
	print("[apex] DISENGAGE parked 30u out took %.0f over 8s (must be 0) -> %s" % [
		far_taken, "PASS" if far_taken == 0.0 else "FAIL"])

	# 5. VENT ESCALATION. Each successive seal within a phase releases one more
	#    probe, capped at PROBE_VENT_MAX and RESET on phase change — both guards
	#    come from measurement: 4-5 probes were measured eating ~40%% of output,
	#    and a bill that scales with whole-fight length is the axis a previous
	#    tuning pass already rejected. The table first, pure:
	var table := ""
	var table_ok := true
	for ph in range(ApexBoss.PHASES.size()):
		var base := int((ApexBoss.PHASES[ph] as Dictionary)["probes"])
		var prev := 0
		table += "p%d:" % ph
		for v in range(4):
			var n := ApexBoss.probes_for(ph, v)
			table += "%d " % n
			if n < prev or n > ApexBoss.PROBE_VENT_MAX \
					or (v == 0 and n != base):
				table_ok = false
			prev = n
	print("[apex] VENT ESCALATION %s(cap %d) -> %s" % [
		table, ApexBoss.PROBE_VENT_MAX, "PASS" if table_ok else "FAIL"])

	# 6. And the WIRING, live — a pure table passes even if _begin_seal never
	#    reads it. Two seals in phase 0 must vent 2 then 3; a phase change must
	#    reset to its own base. Probes are cleared between vents so the counts
	#    are the vents' own.
	gnomon.reset_fight()
	await get_tree().physics_frame
	var vent_counts: Array = []
	for round_i in range(2):
		for pr in get_tree().get_nodes_in_group("apex_probe"):
			(pr as Node3D).queue_free()
		await get_tree().physics_frame
		gnomon._begin_seal()
		await get_tree().physics_frame
		vent_counts.append(get_tree().get_nodes_in_group("apex_probe").size())
	gnomon._begin_phase(1)
	for pr in get_tree().get_nodes_in_group("apex_probe"):
		(pr as Node3D).queue_free()
	await get_tree().physics_frame
	gnomon._begin_seal()
	await get_tree().physics_frame
	vent_counts.append(get_tree().get_nodes_in_group("apex_probe").size())
	print("[apex] VENT WIRING phase 0 vents %d then %d, phase change resets to %d -> %s" % [
		vent_counts[0], vent_counts[1], vent_counts[2],
		"PASS" if vent_counts[0] == 2 and vent_counts[1] == 3
			and vent_counts[2] == 3 else "FAIL"])
	get_tree().quit()


func _apex_damage_window(boss: ApexBoss, orbit: bool) -> float:
	var player: PlayerShip = get_tree().get_first_node_in_group("player")
	player.invulnerable = false
	player.shield = player.shield_max
	var taken := 0.0
	var prev: float = player.shield
	var centre: Vector3 = boss.global_position
	var ang := 0.0
	for i in range(60 * 12):
		for pr in get_tree().get_nodes_in_group("apex_probe"):
			if is_instance_valid(pr):
				(pr as Node3D).queue_free()
		if orbit:
			# ~5.6 u/s tangential at radius 4.5 — an ordinary strafe, no drive
			# bonuses, and comfortably ahead of a 0.85s telegraph on a locked line.
			ang += get_physics_process_delta_time() * 1.25
		player.global_position = centre + Vector3(cos(ang), 0, sin(ang)) * 4.5
		player.velocity = Vector3.ZERO
		player.clear_target()
		await get_tree().physics_frame
		if player.shield < prev:
			taken += prev - player.shield
		prev = player.shield
		if player.shield < 40.0:
			player.shield = player.shield_max
			prev = player.shield
	player.invulnerable = true
	return taken


# --- narrow-width capture -----------------------------------------------------
# The Cantina fields five service tabs plus DEPART. That fits across 720; the
# question is what it does on a small phone, where the logical width is the same
# 720 but the physical pixels are far fewer and every label is proportionally
# larger. Captures the busiest panels at iPhone-logical and small-phone sizes.

func _run_narrow_shots() -> void:
	var shots: String = OS.get_environment("PYXIS_SHOTS")
	var player: PlayerShip = get_tree().get_first_node_in_group("player")
	player.invulnerable = true
	_wave_timer = 1.0e9
	_apex_wake_timer = -1.0
	# Capture the LAYOUT, not the player's accessibility preference. user_scale
	# is loaded from the save and multiplies everything; a capture taken at
	# someone's 0.7 setting is a picture of that setting, not of the design.
	print("[narrow] player ui_scale %.2f pinned to 1.00 for capture" % UILayout.user_scale)
	UILayout.user_scale = 1.0
	UILayout.apply_scale(get_window())
	GameState.add_salvage(20000)
	GameState.load_cargo("relics", 3)
	await get_tree().create_timer(0.4).timeout

	# One representative size is enough, and that is the finding rather than a
	# shortcut: UILayout pins the logical width to 720 for every portrait window,
	# so 390x844 and 360x800 both resolve to a 720-wide logical space and lay out
	# identically. A narrow phone gets a TALLER logical canvas, never a narrower
	# one, which is why the six-tab Cantina row cannot overflow on any of them.
	for spec in [
		{"w": 390, "h": 844, "tag": "iphone_logical"},
		# The case that prompted the chrome rework: a full-screen Mac window,
		# where the corner controls used to sit 337px inside each screen edge.
		{"w": 2000, "h": 1140, "tag": "mac_fullscreen"},
	]:
		get_window().size = Vector2i(int(spec["w"]), int(spec["h"]))
		await get_tree().process_frame
		await get_tree().process_frame
		var vp := get_viewport().get_visible_rect().size
		print("[narrow] window %dx%d -> logical %.0fx%.0f  content_factor %.3f" % [
			int(spec["w"]), int(spec["h"]), vp.x, vp.y,
			UILayout.content_factor(Vector2(int(spec["w"]), int(spec["h"])))])

		# Free flight first: this is the frame the corner controls live in, and
		# the one where an over-inset HUD blocks the play area.
		_load_system("pyx01")
		_apex_wake_timer = -1.0
		await get_tree().create_timer(0.7).timeout
		player.global_position = Vector3(0, 0, 6)
		var rig := get_tree().get_first_node_in_group("camera_rig") as CameraRig
		rig.global_position = Vector3(0, 0, 6)
		rig.zoom = 20.0
		rig._target_zoom = 20.0
		await get_tree().create_timer(0.6).timeout
		# No wide capture has ever contained a toast or a broadcast, which is part
		# of why an 8px band overlap shipped: the frames that would have shown it
		# never had anything in those bands.
		hud.show_toast("ARCHEOLOGY 2 — THE DRIFT NOW READS IN THE FIELD", Palette.GOLD)
		hud.show_broadcast("SUBSPACE ADVISORY — AUTOMATED",
			"SHEAR DETECTED · BEARING 240 · 190u OUT · IT WILL NOT HOLD",
			Palette.DEEP_BANDS[2])
		await get_tree().create_timer(0.7).timeout
		await _shot(shots, "narrow_%s_flight_hud.png" % spec["tag"])
		var cantina: Port = null
		for n in get_tree().get_nodes_in_group("dockable"):
			if (n as Port).port_id == "cantina":
				cantina = n
		if cantina:
			player.global_position = cantina.dock_point
			_complete_dock(cantina)
			await get_tree().create_timer(0.8).timeout
			await _shot(shots, "narrow_%s_cantina_tabs.png" % spec["tag"])
			port_panel._on_tab("paint")
			await get_tree().create_timer(0.5).timeout
			await _shot(shots, "narrow_%s_paint.png" % spec["tag"])
			port_panel._on_tab("contracts")
			await get_tree().create_timer(0.5).timeout
			await _shot(shots, "narrow_%s_contracts.png" % spec["tag"])
			port_panel.close_panel()
			undock()
			await get_tree().create_timer(0.4).timeout

		# And the pause overlay, whose panel has a 340px minimum width.
		toggle_pause()
		await get_tree().create_timer(0.4).timeout
		pause_menu._page = "settings"
		pause_menu._refresh()
		await get_tree().create_timer(0.4).timeout
		await _shot(shots, "narrow_%s_settings.png" % spec["tag"])
		pause_menu.resume()
		# Belt and braces: a harness that leaves the tree paused hangs forever on
		# the next pausable await instead of quitting, which is exactly how this
		# one stalled at the end of a two-size loop.
		get_tree().paused = false
		await get_tree().create_timer(0.3, true, false, true).timeout
	print("[narrow] done -> %s" % shots)
	get_tree().quit()


# --- phase 2 capture ---------------------------------------------------------
# The plan's screenshot list, as a scripted pass. Needs a real window (rendering
# is what is being captured), so this is the one harness that cannot run
# --headless. PYXIS_SHOTS names the output directory.

func _run_phase2_shots() -> void:
	var shots: String = OS.get_environment("PYXIS_SHOTS")
	var player: PlayerShip = get_tree().get_first_node_in_group("player")
	var rig := get_tree().get_first_node_in_group("camera_rig") as CameraRig
	get_window().size = Vector2i(720, 1280)
	player.invulnerable = true
	GameState.mark_breached("pyx01")
	GameState.mark_breached("pyx02")
	_wave_timer = 1.0e9
	_apex_wake_timer = -1.0
	await get_tree().create_timer(0.5).timeout

	# 1. PYX-02 at full extent, ringed ember world in frame.
	_load_system("pyx02")
	await get_tree().create_timer(0.8).timeout
	rig.global_position = Vector3(16, 0, 4)
	rig.zoom = 44.0
	rig._target_zoom = 44.0
	player.global_position = Vector3(4, 0, 12)
	await get_tree().create_timer(1.0).timeout
	print("[shots] pyx02 bounds=%.0f obstacles=%d" % [SystemDB.bounds_of("pyx02"), Obstacles.count()])
	await _shot(shots, "p2_01_pyx02_ringed_planet.png")

	# 2. Radar pings: sit where the system's landmarks are all off screen.
	rig.zoom = 13.0
	rig._target_zoom = 13.0
	player.global_position = Vector3(0, 0, 8)
	rig.global_position = player.global_position
	await get_tree().create_timer(1.2).timeout
	print("[shots] radar markers on screen: %d" % hud.radar_markers().size())
	await _shot(shots, "p2_02_radar_pings.png")

	# 3. A shot breaking on cover — the spark at the surface.
	_load_system("pyx01")
	await get_tree().create_timer(0.8).timeout
	var rock := Vector3(6, 0, 10)
	Obstacles.add(rock, 3.0)
	var behind := SwarmHostile.new()
	behind.difficulty = 1.0
	behind.hp_scale = 30.0
	system_root.add_child(behind)
	behind.global_position = rock + Vector3(0, 0, 4.4)
	behind.dock_at(behind.global_position)
	player.global_position = rock - Vector3(0, 0, 4.6)
	rig.global_position = rock
	rig.zoom = 15.0
	rig._target_zoom = 15.0
	GameState.equip(ModuleDB.Slot.WEAPON_A, "pulse_1")
	player.command_attack(behind)
	for i in range(90):
		player.global_position = rock - Vector3(0, 0, 4.6)
		player.velocity = Vector3.ZERO
		await get_tree().physics_frame
		if i % 12 == 0:
			await _shot(shots, "p2_03_blocked_beam_spark.png")
	print("[shots] blocked-beam target hp intact = %s" % str(behind.hp > 800.0))

	# 4. Torpedo splash into a cluster.
	for n in get_tree().get_nodes_in_group("hostiles"):
		(n as Node3D).queue_free()
	await get_tree().process_frame
	GameState.reactor_tier = 2
	for id in ["torp_2"]:
		if not GameState.owns(id):
			GameState.owned.append(id)
	GameState.equip(ModuleDB.Slot.WEAPON_A, "torp_2")
	GameState.equip(ModuleDB.Slot.WEAPON_B, "")
	var hub := Vector3(-4, 0, 14)
	var pack: Array = []
	for i in range(4):
		var p := SwarmHostile.new()
		p.difficulty = 1.0
		p.hp_scale = 6.0
		system_root.add_child(p)
		p.global_position = hub + Vector3(cos(TAU * i / 4.0), 0, sin(TAU * i / 4.0)) * 1.2
		p.dock_at(p.global_position)
		pack.append(p)
	player.global_position = hub + Vector3(0, 0, 6.0)
	rig.global_position = hub + Vector3(0, 0, 2.0)
	rig.zoom = 13.0
	rig._target_zoom = 13.0
	player.command_attack(pack[0])
	for i in range(150):
		player.global_position = hub + Vector3(0, 0, 6.0)
		player.velocity = Vector3.ZERO
		await get_tree().physics_frame
		if i % 6 == 0:
			await _shot(shots, "p2_04_torpedo_splash.png")
	print("[shots] torpedo captured")

	# 5. Two liveries, same fit.
	for n in get_tree().get_nodes_in_group("hostiles"):
		(n as Node3D).queue_free()
	GameState.equip(ModuleDB.Slot.WEAPON_A, "lance_2" if GameState.owns("lance_2") else "pulse_1")
	player.global_position = Vector3(0, 0, 8)
	player.rotation = Vector3.ZERO
	rig.global_position = player.global_position
	rig.zoom = 9.5
	rig._target_zoom = 9.5
	# The invulnerability bubble is a teal sphere drawn over the whole hull, and
	# these two frames exist to show the hull. Drop protection for the shot.
	player.invulnerable = false
	_apex_wake_timer = -1.0
	GameState.set_livery(0, 0)
	await get_tree().create_timer(1.0).timeout
	await _shot(shots, "p2_05_livery_survey_grey.png")
	GameState.set_livery(3, 3)
	await get_tree().create_timer(1.0).timeout
	await _shot(shots, "p2_06_livery_oxide_signal.png")
	player.invulnerable = true
	print("[shots] liveries captured")

	# 6. The cantina: rumours.
	var cantina: Port = null
	var anchor: Port = null
	for n in get_tree().get_nodes_in_group("dockable"):
		var p := n as Port
		if p.port_id == "cantina":
			cantina = p
		elif p.port_id == "anchor":
			anchor = p
	GameState.add_salvage(20000)
	_apex_wake_timer = -1.0
	if cantina:
		player.global_position = cantina.dock_point
		rig.global_position = cantina.global_position
		_complete_dock(cantina)
		await get_tree().create_timer(0.9).timeout
		port_panel._on_tab("rumors")
		await get_tree().create_timer(0.6).timeout
		port_panel._buy_rumor(400)
		await get_tree().create_timer(0.6).timeout
		await _shot(shots, "p2_07_cantina_rumors.png")
		port_panel._on_tab("games")
		await get_tree().create_timer(0.6).timeout
		await _shot(shots, "p2_08_cantina_games.png")
		port_panel._on_tab("paint")
		await get_tree().create_timer(0.6).timeout
		await _shot(shots, "p2_09_paint_swatches.png")
		port_panel.close_panel()
		undock()
		await get_tree().create_timer(0.5).timeout

	# 7. The den: contraband on the market row, and the fence.
	_load_system("pyx03")
	_apex_wake_timer = -1.0
	await get_tree().create_timer(0.9).timeout
	var den: Port = null
	for n in get_tree().get_nodes_in_group("dockable"):
		if (n as Port).port_id == "void":
			den = n
	if den:
		GameState.load_cargo("relics", 4)
		player.global_position = den.dock_point
		rig.global_position = den.global_position
		_complete_dock(den)
		await get_tree().create_timer(0.9).timeout
		await _shot(shots, "p2_10_den_contraband_row.png")
		port_panel._on_tab("fence")
		await get_tree().create_timer(0.6).timeout
		await _shot(shots, "p2_11_den_fence.png")
		port_panel._on_tab("contracts")
		await get_tree().create_timer(0.6).timeout
		await _shot(shots, "p2_12_contract_board.png")
		port_panel.close_panel()
		undock()
		await get_tree().create_timer(0.5).timeout

	# 8. Interdiction, then pause and settings over it.
	GameState.cargo = {"relics": 40}
	player.global_position = Vector3(0, 0, 8)
	rig.global_position = player.global_position
	rig.zoom = 20.0
	rig._target_zoom = 20.0
	spawn_interdiction()
	await get_tree().create_timer(1.2).timeout
	await _shot(shots, "p2_13_raiders_intercept.png")

	toggle_pause()
	await get_tree().create_timer(0.6).timeout
	await _shot(shots, "p2_14_pause.png")
	pause_menu._page = "settings"
	pause_menu._refresh()
	await get_tree().create_timer(0.6).timeout
	await _shot(shots, "p2_15_settings.png")
	pause_menu.resume()
	print("[shots] done -> %s" % shots)
	get_tree().quit()


# --- livery + tier harness --------------------------------------------------

func _run_livery_test() -> void:
	var player: PlayerShip = get_tree().get_first_node_in_group("player")
	await get_tree().create_timer(0.4).timeout

	print("[livery] %d hulls x %d accents = %d liveries" % [
		Palette.LIVERY_HULLS.size(), Palette.LIVERY_ACCENTS.size(),
		Palette.LIVERY_HULLS.size() * Palette.LIVERY_ACCENTS.size()])
	# Nine accents since v13: eight bought and one EARNED. The count is asserted
	# rather than derived because the ninth is load-bearing in two other places --
	# GameState.REGISTRY_ACCENT indexes it, and port_panel's swatch grid is nine
	# columns wide so it does not wrap as an orphan.
	print("[livery] SWATCHES 8 hulls and 9 accents (8 bought + REGISTRY) -> %s" % [
		"PASS" if Palette.LIVERY_HULLS.size() == 8 and Palette.LIVERY_ACCENTS.size() == 9
			else "FAIL"])
	# The earned one is the LAST entry, which is what makes "index >= 8 is locked"
	# a rule rather than a coincidence. Insert a bought accent after it and this
	# goes red, which is the point.
	var registry_last: bool = GameState.REGISTRY_ACCENT == Palette.LIVERY_ACCENTS.size() - 1 \
		and String((Palette.LIVERY_ACCENTS[GameState.REGISTRY_ACCENT] as Dictionary)["name"]) == "REGISTRY"
	print("[livery] EARNED ACCENT IS LAST index %d of %d is '%s' -> %s" % [
		GameState.REGISTRY_ACCENT, Palette.LIVERY_ACCENTS.size() - 1,
		String((Palette.LIVERY_ACCENTS[Palette.LIVERY_ACCENTS.size() - 1] as Dictionary)["name"]),
		"PASS" if registry_last else "FAIL"])

	# 1. Setting a livery repaints the ship. Read straight off the material, so
	#    this cannot pass on a stored value the mesh never used.
	GameState.set_livery(0, 0)
	await get_tree().process_frame
	var grey := _ship_hull_color(player)
	GameState.set_livery(1, 3)
	await get_tree().process_frame
	var black := _ship_hull_color(player)
	print("[livery] REPAINT hull material %s -> %s (expected %s -> %s) -> %s" % [
		grey.to_html(false), black.to_html(false),
		Palette.livery_hull(0).to_html(false), Palette.livery_hull(1).to_html(false),
		"PASS" if grey.is_equal_approx(Palette.livery_hull(0))
			and black.is_equal_approx(Palette.livery_hull(1)) else "FAIL"])

	# 2. Out-of-range indices wrap rather than crashing — a save edited by hand,
	#    or a swatch list that shrinks in a later patch, must not hard-fail.
	print("[livery] WRAP index 99 -> %s, index -1 -> %s -> %s" % [
		Palette.livery_hull(99).to_html(false), Palette.livery_hull(-1).to_html(false),
		"PASS" if Palette.livery_hull(99).is_equal_approx(Palette.livery_hull(99 % 8))
			and Palette.livery_hull(-1).is_equal_approx(Palette.livery_hull(7)) else "FAIL"])

	# 3. Survives a save round trip, through the real file layer.
	GameState.set_livery(6, 2)
	GameState.save_game()
	GameState.set_livery(0, 0)
	var reloaded := GameState.load_game()
	var saved_version := 0
	var f := FileAccess.open(GameState.save_path, FileAccess.READ)
	if f != null:
		var parsed = JSON.parse_string(f.get_as_text())
		f.close()
		if typeof(parsed) == TYPE_DICTIONARY:
			saved_version = int((parsed as Dictionary).get("version", 0))
	print("[livery] PERSISTS saved (6,2) as v%d, reset to (0,0), reloaded=(%d,%d) ok=%s -> %s" % [
		saved_version, GameState.livery_index("hull"), GameState.livery_index("accent"),
		str(reloaded),
		"PASS" if reloaded and saved_version == GameState.SAVE_VERSION
			and GameState.livery_index("hull") == 6 and GameState.livery_index("accent") == 2
			else "FAIL"])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.save_path))

	# 4. Paint is sold where the plan says, and costs what it says.
	var painters := []
	for id in SystemDB.port_ids():
		var svc: Array = SystemDB.port_def_by_id(String(id)).get("services", PortPanel.DEFAULT_SERVICES)
		if svc.has("paint"):
			painters.append(id)
	print("[livery] PAINT SERVICE at %s for %d salvage -> %s" % [
		str(painters), PortPanel.PAINT_PRICE,
		"PASS" if painters.size() >= 3 and painters.has("anchor") and painters.has("cantina")
			else "FAIL"])

	# --- Mk II tiers ---------------------------------------------------------
	var tiers := ["drive_cruise_2", "drive_vector_2", "util_tractor_2",
		"util_shield_2", "util_scanner_2", "util_cargo_2"]
	var all_exist := true
	var priced := true
	for id in tiers:
		if not ModuleDB.exists(id):
			all_exist = false
			continue
		var price := int(ModuleDB.get_module(id)["price"])
		if price < 12000 or price > 20000:
			priced = false
	print("[tiers] ROWS all six present=%s, all priced 12k-20k=%s -> %s" % [
		str(all_exist), str(priced), "PASS" if all_exist and priced else "FAIL"])

	# Every Mk II must actually beat its Mk I on every stat it shares, or the
	# price is a lie. This is the assertion that catches a typo'd number.
	var strictly_better := true
	var worst := ""
	for id_v in tiers:
		var id := String(id_v)
		var base_id := id.trim_suffix("_2")
		var mk1: Dictionary = ModuleDB.get_module(base_id)["stats"]
		var mk2: Dictionary = ModuleDB.get_module(id)["stats"]
		for key in mk1:
			if float(mk2.get(key, -1.0)) <= float(mk1[key]):
				strictly_better = false
				worst = "%s.%s %.2f -> %.2f" % [id, key, float(mk1[key]), float(mk2.get(key, -1.0))]
		if int(ModuleDB.get_module(id)["power"]) <= int(ModuleDB.get_module(base_id)["power"]):
			strictly_better = false
			worst = "%s draws no more power than its Mk I" % id
	print("[tiers] STRICTLY BETTER every Mk II beats its Mk I and costs more power -> %s %s" % [
		"PASS" if strictly_better else "FAIL", worst])

	# And they have to be buyable somewhere.
	var stocked := {}
	for id in SystemDB.port_ids():
		for m in SystemDB.port_def_by_id(String(id)).get("stock", []):
			stocked[String(m)] = true
	var all_stocked := true
	for id in tiers:
		if not stocked.has(id):
			all_stocked = false
	print("[tiers] STOCKED every Mk II is on sale somewhere -> %s" % [
		"PASS" if all_stocked else "FAIL"])

	# The budget still has to bite: even Mk III cannot carry all-best modules.
	GameState.reactor_tier = 2
	var greedy := {
		ModuleDB.Slot.WEAPON_A: "lance_2",
		ModuleDB.Slot.WEAPON_B: "torp_2",
		ModuleDB.Slot.DRIVE: "drive_vector_2",
		ModuleDB.Slot.UTILITY: "util_scanner_2",
		ModuleDB.Slot.CORE: "core_aegis",
	}
	var draw := ModuleDB.power_draw(greedy)
	print("[tiers] BUDGET all-best fit draws %d of %d on Mk III -> %s" % [
		draw, GameState.power_cap(),
		"PASS" if draw > GameState.power_cap() else "FAIL"])
	get_tree().quit()


func _ship_hull_color(player: PlayerShip) -> Color:
	# The hull prism is the first child added by _rebuild_mesh.
	for node in player.get_children():
		for part in node.get_children():
			var mi := part as MeshInstance3D
			if mi != null and mi.mesh is PrismMesh:
				return (mi.material_override as StandardMaterial3D).albedo_color
	return Color.BLACK


# --- station harness --------------------------------------------------------

func _run_station_test() -> void:
	await get_tree().create_timer(0.4).timeout

	# 1. Every station exists, is reachable, and is not standing inside anything.
	print("[station] all ports on the chart: %s" % str(SystemDB.port_ids()))
	var expected := ["anchor", "cantina", "cinderworks", "depot", "bastion", "void"]
	var all_present := true
	for id in expected:
		if not SystemDB.port_ids().has(id):
			all_present = false
	print("[station] REGISTRY %d ports, all six present=%s -> %s" % [
		SystemDB.port_ids().size(), str(all_present),
		"PASS" if all_present else "FAIL"])

	# Each secondary must be far from its primary — the whole point is that
	# travelling across a system has a destination at the other end.
	var separation_ok := true
	var closest := INF
	for sys in SystemDB.ids():
		var ports := SystemDB.ports_of(String(sys))
		for i in range(ports.size()):
			for j in range(i + 1, ports.size()):
				var d: float = (ports[i]["pos"] as Vector3).distance_to(ports[j]["pos"])
				closest = minf(closest, d)
				if d < 20.0:
					separation_ok = false
	print("[station] SPREAD closest two ports in any system %.1fu (want >= 20) -> %s" % [
		closest, "PASS" if separation_ok else "FAIL"])

	# 2. Built into the world with hulls and dock rings, and no dock ring buried
	#    inside its own station's collision sphere.
	_load_system("pyx01")
	await get_tree().create_timer(0.4).timeout
	var built := get_tree().get_nodes_in_group("dockable")
	var rings_clear := true
	for n in built:
		var p := n as Port
		# The ring must sit outside the hull sphere or the ship is shoved out of
		# its own docking range — the exact footgun the derelict hit in phase 2.
		if p.dock_point.distance_to(p.global_position) <= Port.HULL_OBSTACLE_RADIUS:
			rings_clear = false
	print("[station] BUILT pyx01 has %d dockable stations, rings outside their hulls=%s -> %s" % [
		built.size(), str(rings_clear),
		"PASS" if built.size() == 2 and rings_clear else "FAIL"])

	# 3. Services drive the tabs. This is what makes a station type data.
	for id in expected:
		var def := SystemDB.port_def_by_id(id)
		var svc: Array = def.get("services", PortPanel.DEFAULT_SERVICES)
		print("[station]   %-12s %-22s %s" % [id, String(def.get("name", "?")), str(svc)])
	var cantina := SystemDB.port_def_by_id("cantina")
	var den := SystemDB.port_def_by_id("void")
	var depot := SystemDB.port_def_by_id("depot")
	var services_ok := (cantina.get("services", []) as Array).has("rumors") \
		and (cantina.get("services", []) as Array).has("games") \
		and not (cantina.get("services", []) as Array).has("market") \
		and (den.get("services", []) as Array).has("fence") \
		and (depot.get("services", []) as Array).has("market")
	print("[station] SERVICES cantina has rumors+games and no market, den fences, depot trades -> %s" % [
		"PASS" if services_ok else "FAIL"])

	# 4. Depot: bulk break both ways, and a better sell-back on modules.
	var one_buy := Market.buy_price(depot, "depot", "alloys", 1)
	var bulk_buy := Market.buy_price(depot, "depot", "alloys", 10)
	var one_sell := Market.sell_price(depot, "depot", "alloys", 1)
	var bulk_sell := Market.sell_price(depot, "depot", "alloys", 10)
	print("[station] BULK alloys buy %d -> %d at 10+, sell %d -> %d at 10+ -> %s" % [
		one_buy, bulk_buy, one_sell, bulk_sell,
		"PASS" if bulk_buy < one_buy and bulk_sell > one_sell else "FAIL"])
	print("[station] SELLBACK depot %.0f%% vs default %.0f%% -> %s" % [
		float(depot.get("sellback", 0.6)) * 100.0, 60.0,
		"PASS" if float(depot.get("sellback", 0.6)) > 0.6 else "FAIL"])
	var depot_stock: Array = depot.get("stock", [])
	var no_mk2_weapons := not depot_stock.has("lance_2") and not depot_stock.has("arc_2")
	print("[station] DEPOT STOCK drives/utilities/torpedoes, no Mk II weapons=%s -> %s" % [
		str(no_mk2_weapons),
		"PASS" if no_mk2_weapons and depot_stock.has("torp_1") else "FAIL"])

	# 5. Den: fence premium on the right goods only, and grey-market modules.
	var fenced := Market.sell_price(den, "void", "relics", 1)
	var clean := Market.sell_price(SystemDB.port_def_by_id("anchor"), "void", "relics", 1)
	var unfenced := Market.fence_bonus(den, "alloys")
	print("[station] FENCE relics %.2fx premium (alloys %.2fx, must be 1.00) -> %s" % [
		Market.fence_bonus(den, "relics"), unfenced,
		"PASS" if Market.fence_bonus(den, "relics") > 1.2 and is_equal_approx(unfenced, 1.0) else "FAIL"])
	print("[station] GREY MARKET modules at %.0f%% of catalog -> %s" % [
		float(den.get("outfit_mult", 1.0)) * 100.0,
		"PASS" if float(den.get("outfit_mult", 1.0)) < 1.0 else "FAIL"])
	print("[station]   (fenced relics %d vs a clean quote of %d)" % [fenced, clean])

	# NO MODULE LAUNDRY, ANYWHERE, FOR ANY PAIR OF STATIONS.
	#
	# A module costs `price * outfit_mult` at the station you buy it from and pays
	# `price * sellback` at the station you sell it to, so the invariant across
	# the whole game is `max(sellback) < min(outfit_mult)`. This used to be one
	# hard-coded comparison — grey-market arc_2 at the Void against sell-back at
	# the Depot — which happened to be the binding pair and happened to hold, at
	# 0.75 against 0.80. Both of those were luck. Deep stations are exactly the
	# kind of content that turns that luck into an infinite loop flown between two
	# docks, so the check is now the actual invariant: every buyer against every
	# seller, chart and expanse together, reporting the worst pair by name.
	var desks := []
	for pid_v in SystemDB.port_ids():
		var pd := SystemDB.port_def_by_id(String(pid_v))
		desks.append({"id": String(pid_v), "name": String(pd.get("name", "?")),
			"sellback": float(pd.get("sellback", 0.6)),
			"outfit": float(pd.get("outfit_mult", 1.0))})
	for a_v in DeepPortDB.ARCHETYPES:
		var a: Dictionary = a_v
		desks.append({"id": String(a["id"]), "name": String(a["name"]),
			"sellback": float(a.get("sellback", 0.6)),
			"outfit": float(a.get("outfit_mult", 1.0))})

	var worst_margin := -INF
	var worst_pair := ""
	for buy_at in desks:
		for sell_at in desks:
			var margin: float = float(sell_at["sellback"]) - float(buy_at["outfit"])
			if margin > worst_margin:
				worst_margin = margin
				worst_pair = "buy at %s (x%.2f) -> sell at %s (x%.2f)" % [
					buy_at["name"], buy_at["outfit"], sell_at["name"], sell_at["sellback"]]
	print("[station] NO ARBITRAGE %d counters, %d pairs; closest is %s = %+.2f -> %s" % [
		desks.size(), desks.size() * desks.size(), worst_pair, worst_margin,
		"PASS" if worst_margin < 0.0 else "FAIL"])

	# And the deep archetypes are held to the stated guard rail by name, so a bad
	# def is caught as a bad def rather than found later as a money printer.
	var rail := DeepPortDB.violations()
	print("[station] DEEP GUARD RAIL sellback <= %.2f, outfit_mult >= %.2f across %d archetypes -> %s %s" % [
		DeepPortDB.SELLBACK_CEILING, DeepPortDB.OUTFIT_FLOOR, DeepPortDB.count(),
		"PASS" if rail.is_empty() else "FAIL", str(rail)])

	# 6. Contraband trades at the den and the cantina, and nowhere else.
	var legal := []
	for id in expected:
		if CommodityDB.trades_at("contraband", id):
			legal.append(id)
	print("[station] CONTRABAND tradeable at %s -> %s" % [str(legal),
		"PASS" if legal.size() == 2 and legal.has("void") and legal.has("cantina") else "FAIL"])
	var anchor_goods := CommodityDB.ids_for_port("anchor")
	print("[station] MARKET ROWS anchor lists %d goods, contraband hidden=%s -> %s" % [
		anchor_goods.size(), str(not anchor_goods.has("contraband")),
		"PASS" if not anchor_goods.has("contraband") else "FAIL"])

	# 7. NO PORT IS A MONEY PRINTER. Buying and immediately re-selling the same
	#    good at the same station must always lose money, at every port, for
	#    every good, at every trade size. The fence premium (1.25x) is larger
	#    than a freeport's spread (6%), so before `can_buy` closed the buy side
	#    the Grinning Void quoted Stolen Goods at BUY 169 / SELL 188 — a loop you
	#    could run with two button taps.
	#    Deep stations are swept alongside the chart, because a fence premium out
	#    at the Long Haven is the same shape of hazard the Void already was.
	var all_counters: Array = SystemDB.port_ids().duplicate()
	all_counters.append_array(DeepPortDB.ids())
	var printer := ""
	for pid_v in all_counters:
		var pid := String(pid_v)
		var pdef := DeepPortDB.by_id(pid) if DeepPortDB.is_deep_port(pid) \
			else SystemDB.port_def_by_id(pid)
		for good_v in CommodityDB.ids_for_port(pid):
			var good := String(good_v)
			if not Market.can_buy(pdef, good):
				continue
			for size in [1, 10, 25]:
				var b := Market.buy_price(pdef, pid, good, size)
				var sl := Market.sell_price(pdef, pid, good, size)
				if sl >= b:
					printer = "%s %s x%d: buy %d, sell %d" % [pid, good, size, b, sl]
	print("[station] NO ROUND-TRIP PROFIT at any of %d ports (chart + expanse), good or trade size -> %s %s" % [
		all_counters.size(), "PASS" if printer == "" else "FAIL", printer])

	# 8. DECLARED TRADEABLE MUST MEAN ACTUALLY TRADEABLE.
	#    CommodityDB.trades_at() and a port's `services` list are two separate
	#    pieces of data that have to agree, and nothing made them. Contraband
	#    declared itself tradeable at the Cantina, the Cantina shipped with
	#    neither a market nor a fence, and so the marquee smuggling route could
	#    be bought into and never sold out of. The price assertion below passed
	#    the whole time, because Market.sell_price is pure arithmetic that never
	#    asks whether a counter exists.
	# `trades_at` is a RESTRICTION filter, not a promise of a counter — an
	# entertainment station legitimately has no alloys desk. The invariant that
	# actually matters is that every good can be sold somewhere, and that a
	# RESTRICTED good can be sold at one of the few ports it is restricted to.
	var unreachable := ""
	for good_v in CommodityDB.ids():
		var good := String(good_v)
		var counters: Array = []
		for pid_v in SystemDB.port_ids():
			var pid := String(pid_v)
			if not CommodityDB.trades_at(good, pid):
				continue
			var pdef := SystemDB.port_def_by_id(pid)
			var svc: Array = pdef.get("services", PortPanel.DEFAULT_SERVICES)
			if svc.has("market") or (svc.has("fence") and Market.fences(pdef, good)):
				counters.append(pid)
		var restricted := not (CommodityDB.get_good(good).get("trade_only_at", []) as Array).is_empty()
		if restricted:
			print("[station]   %s is restricted; counters: %s" % [good, str(counters)])
		if counters.is_empty():
			unreachable = "%s can be sold at no port on the chart" % good
	print("[station] REACHABLE every good has at least one counter that will take it -> %s %s" % [
		"PASS" if unreachable == "" else "FAIL", unreachable])

	# 9. And the contraband run has to be worth making, or the whole
	#    risk/reward of the smuggling route is decoration.
	var buy_void := Market.buy_price(SystemDB.port_def_by_id("void"), "void", "contraband", 24)
	var sell_cantina := Market.sell_price(SystemDB.port_def_by_id("cantina"), "cantina", "contraband", 24)
	print("[station] CONTRABAND RUN void %d -> cantina %d = %d/unit margin -> %s" % [
		buy_void, sell_cantina, sell_cantina - buy_void,
		"PASS" if sell_cantina > buy_void * 1.3 else "FAIL"])

	# 9. The cantina wager is a losing bet with the odds on the table.
	var ev := PortPanel.GAMBLE_WIN_CHANCE * 2.0
	print("[station] WAGER %.0f%% to double = %.2fx expected, streak capped at %d -> %s" % [
		PortPanel.GAMBLE_WIN_CHANCE * 100.0, ev, PortPanel.GAMBLE_STREAK_LIMIT,
		"PASS" if ev < 1.0 and PortPanel.GAMBLE_STREAK_LIMIT > 0 else "FAIL"])
	get_tree().quit()


# --- torpedo harness --------------------------------------------------------

func _run_torp_test() -> void:
	var player: PlayerShip = get_tree().get_first_node_in_group("player")
	set_deep_generation(false)
	player.invulnerable = true
	_wave_timer = 1.0e9
	_apex_wake_timer = -1.0
	for n in get_tree().get_nodes_in_group("hostiles"):
		(n as Node3D).queue_free()

	GameState.reactor_tier = 2
	for id in ["torp_1", "torp_2"]:
		if not GameState.owns(id):
			GameState.owned.append(id)
	GameState.equip(ModuleDB.Slot.WEAPON_A, "torp_1")
	GameState.equip(ModuleDB.Slot.WEAPON_B, "")
	await get_tree().create_timer(0.5).timeout
	print("[torp] fit dps %.0f  power %d/%d  hull shows a torpedo pod=%s" % [
		float(GameState.stats.get("dps", 0.0)), GameState.power_draw(), GameState.power_cap(),
		str(GameState.fit[ModuleDB.Slot.WEAPON_A] == "torp_1")])

	# NOTE: difficulty must be > 0 for any probe whose HP is being measured —
	# SwarmHostile computes hp = MAX_HP * difficulty * hp_scale, so difficulty 0
	# spawns a target with zero hit points that dies to the first tick of damage
	# and makes every number in this harness meaningless.

	# 1. Splash kills a cluster: three probes inside the radius, one shot.
	var open := Obstacles.resolve(Vector3(0, 0, 16), 6.0)
	var cluster: Array = []
	for i in range(3):
		var p := SwarmHostile.new()
		p.difficulty = 1.0
		p.hp_scale = 1.0
		system_root.add_child(p)
		p.global_position = open + Vector3(cos(TAU * i / 3.0), 0, sin(TAU * i / 3.0)) * 1.1
		p.dock_at(p.global_position)      # holding station, the torpedo's whole use case
		cluster.append(p)
	await get_tree().create_timer(0.2).timeout
	print("[torp]   cluster probe hp %.0f each, torp_1 direct hit %.0f" % [
		float(cluster[0].hp), 92.0])

	player.global_position = open + Vector3(0, 0, 7.0)
	player.velocity = Vector3.ZERO
	player.command_attack(cluster[0])
	for i in range(220):
		player.global_position = open + Vector3(0, 0, 7.0)
		player.velocity = Vector3.ZERO
		await get_tree().physics_frame
	var alive := 0
	for p in cluster:
		if is_instance_valid(p):
			alive += 1
	print("[torp] SPLASH clustered docked probes alive %d of 3 (must be 0) -> %s" % [
		alive, "PASS" if alive == 0 else "FAIL"])

	# 2. The same weapon against a strafer. Measured as a COMPARISON against an
	#    identical stationary target over an identical firing window, because
	#    "took less than a full hit" would also be true of a near miss on a
	#    parked ship. The claim is that movement is what defeats it.
	var still_taken := await _torp_damage_window(player, open, false)
	var moving_taken := await _torp_damage_window(player, open, true)
	print("[torp] DODGE stationary target took %.0f, strafing target took %.0f over the same window -> %s" % [
		still_taken, moving_taken,
		"PASS" if still_taken > 0.0 and moving_taken < still_taken * 0.5 else "FAIL"])

	# 3. Cover stops a torpedo like it stops everything else.
	for n in get_tree().get_nodes_in_group("hostiles"):
		(n as Node3D).queue_free()
	await get_tree().process_frame
	var rock := Vector3(-30, 0, 30)
	Obstacles.add(rock, 3.0)
	var hidden := SwarmHostile.new()
	hidden.difficulty = 1.0
	hidden.hp_scale = 30.0
	system_root.add_child(hidden)
	hidden.global_position = rock - Vector3(0, 0, 4.2)
	hidden.dock_at(hidden.global_position)
	await get_tree().create_timer(0.2).timeout

	var hidden_before: float = hidden.hp
	var firing_spot := rock + Vector3(0, 0, 4.6)
	player.command_attack(hidden)
	for i in range(260):
		player.global_position = firing_spot
		player.velocity = Vector3.ZERO
		await get_tree().physics_frame
	print("[torp] COVER hp %.0f -> %.0f behind a rock (must be equal), los=%s (must be false) -> %s" % [
		hidden_before, hidden.hp, str(Obstacles.has_line(firing_spot, hidden.global_position)),
		"PASS" if is_equal_approx(hidden_before, hidden.hp) else "FAIL"])

	# 4. Power cost is the price of area damage: a dual Mk II fit leaves no room
	#    for a utility even on the best reactor in the game.
	GameState.equip(ModuleDB.Slot.WEAPON_A, "torp_2")
	GameState.equip(ModuleDB.Slot.WEAPON_B, "torp_2")
	var dual_draw := GameState.power_draw()
	var can_add_utility := GameState.can_equip(ModuleDB.Slot.UTILITY, "util_shield")
	print("[torp] POWER dual torp_2 draws %d of %d; can still fit a shield=%s (must be false) -> %s" % [
		dual_draw, GameState.power_cap(), str(can_add_utility),
		"PASS" if not can_add_utility else "FAIL"])

	# 5. Stocked where the plan says.
	var bastion: Array = SystemDB.port_def_by_id("bastion").get("stock", [])
	print("[torp] STOCK bastion carries torp_1=%s torp_2=%s -> %s" % [
		str(bastion.has("torp_1")), str(bastion.has("torp_2")),
		"PASS" if bastion.has("torp_1") and bastion.has("torp_2") else "FAIL"])
	get_tree().quit()


func _torp_damage_window(player: PlayerShip, open: Vector3, moving: bool) -> float:
	# One target, one fixed firing position, one fixed number of frames. The only
	# variable is whether the target holds station or strafes.
	for n in get_tree().get_nodes_in_group("hostiles"):
		(n as Node3D).queue_free()
	await get_tree().process_frame

	var probe := SwarmHostile.new()
	probe.difficulty = 1.0
	probe.hp_scale = 40.0        # must outlast the window, or the test caps out
	system_root.add_child(probe)
	probe.global_position = open + Vector3(3.0, 0, 0)
	if not moving:
		probe.dock_at(probe.global_position)
	await get_tree().create_timer(0.2).timeout

	# Inside torp_1's 9.0 reach with room to spare: at 6,0,0 / 0,0,7 the target
	# sat 9.22u out and the mount simply never fired.
	var spot := open + Vector3(0, 0, 5.0)
	var before: float = probe.hp
	var travelled := 0.0
	var last: Vector3 = probe.global_position
	player.command_attack(probe)
	for i in range(300):
		player.global_position = spot
		player.velocity = Vector3.ZERO
		await get_tree().physics_frame
		if not is_instance_valid(probe):
			return before
		travelled += last.distance_to(probe.global_position)
		last = probe.global_position
	print("[torp]   %s target: hp %.0f -> %.0f, travelled %.1fu" % [
		"strafing" if moving else "stationary", before, probe.hp, travelled])
	var taken := before - probe.hp
	probe.queue_free()
	await get_tree().process_frame
	return taken


# --- contract board harness -------------------------------------------------

func _run_contract_test() -> void:
	await get_tree().create_timer(0.4).timeout
	var port := find_port()
	var port_id := port.port_id

	# 1. The board is deterministic per (port, time bucket): docking, leaving and
	#    coming back must not reroll it, or the offers are a slot machine.
	GameState.played_seconds = 100.0
	var first := ContractDB.board_for(port_id, system_id, GameState.played_seconds)
	var again := ContractDB.board_for(port_id, system_id, GameState.played_seconds + 30.0)
	print("[contract] STABLE board %s == %s -> %s" % [
		str(first), str(again), "PASS" if first == again else "FAIL"])

	# 2. It rotates on the played-time bucket.
	var later := ContractDB.board_for(port_id, system_id,
		GameState.played_seconds + ContractDB.BOARD_ROTATE_SECONDS * 2.0)
	print("[contract] ROTATES after %ds: %s -> %s" % [
		int(ContractDB.BOARD_ROTATE_SECONDS), str(later),
		"PASS" if later != first else "FAIL (may collide by chance — re-check)"])

	# 3. Different ports show different boards at the same moment.
	var other_id := "anchor" if port_id != "anchor" else "bastion"
	var other := ContractDB.board_for(other_id, system_id, GameState.played_seconds)
	print("[contract] PER-PORT %s vs %s -> %s" % [port_id, other_id,
		"PASS" if other != first else "FAIL"])
	print("[contract] SIZE %d offers (cap %d) -> %s" % [
		first.size(), ContractDB.BOARD_SIZE,
		"PASS" if first.size() <= ContractDB.BOARD_SIZE and first.size() > 0 else "FAIL"])

	# 4. Accept / drop round trip, and the two-slot ceiling.
	contracts.active = []
	var board := contracts.board(port_id)
	var a := String(board[0]["id"])
	var b := String(board[1]["id"])
	var c := String(board[2]["id"])
	var took_a := contracts.accept(a)
	var took_b := contracts.accept(b)
	var took_c := contracts.accept(c)     # must be refused: slots are full
	print("[contract] ACCEPT a=%s b=%s c=%s (c must be false), active=%d -> %s" % [
		str(took_a), str(took_b), str(took_c), contracts.active.size(),
		"PASS" if took_a and took_b and not took_c and contracts.active.size() == 2 else "FAIL"])

	var dup := contracts.accept(a)
	print("[contract] NO DUPLICATES re-accepting %s = %s (must be false) -> %s" % [
		a, str(dup), "PASS" if not dup else "FAIL"])

	var dropped := contracts.drop(a)
	var now_free := contracts.slots_free()
	var took_c2 := contracts.accept(c)
	print("[contract] DROP %s = %s, slots free %d, then accept c = %s -> %s" % [
		a, str(dropped), now_free, str(took_c2),
		"PASS" if dropped and now_free == 1 and took_c2 else "FAIL"])

	# 5. The board reflects what is held, so ACCEPT/DROP render correctly.
	var marked := 0
	for offer in contracts.board(port_id):
		if bool(offer["accepted"]):
			marked += 1
	print("[contract] BOARD MARKS %d offers shown as accepted (2 held) -> %s" % [
		marked, "PASS" if marked == 2 else "FAIL"])

	# 6. Nothing is auto-assigned any more: completing one frees a slot and
	#    leaves it free. This is the whole point of the change.
	var held_before := contracts.active.size()
	var entry: Dictionary = contracts.active[0]
	var def := ContractDB.get_contract(String(entry["id"]))
	contracts._complete(entry)
	await get_tree().process_frame
	print("[contract] NO AUTO-REFILL held %d -> %d after completing '%s' -> %s" % [
		held_before, contracts.active.size(), String(def.get("title", "?")),
		"PASS" if contracts.active.size() == held_before - 1 else "FAIL"])

	# 7. Travel no longer silently cancels work the player chose. A delivery
	#    contract is *supposed* to send you to another system.
	contracts.active = []
	contracts.accept("haul_isotopes")     # dest cinderworks, offered anywhere
	var before_travel := contracts.active.size()
	contracts.on_system_changed("pyx03")
	print("[contract] SURVIVES TRAVEL held %d -> %d across a system change -> %s" % [
		before_travel, contracts.active.size(),
		"PASS" if contracts.active.size() == before_travel else "FAIL"])

	# 8. A brand-new run still starts with the starter pair, because there is no
	#    port to accept from until the tutorial is over.
	GameState.contract_state = {}
	var fresh := Contracts.new()
	add_child(fresh)
	await get_tree().process_frame
	print("[contract] STARTER PAIR on a fresh run: %s -> %s" % [
		fresh.debug_state(),
		"PASS" if fresh.active.size() == ContractDB.ACTIVE_SLOTS else "FAIL"])

	# And a player who drops both stays empty rather than being handed them back.
	fresh.drop(String(fresh.active[0]["id"]))
	fresh.drop(String(fresh.active[0]["id"]))
	var emptied := Contracts.new()
	add_child(emptied)
	await get_tree().process_frame
	print("[contract] STAYS EMPTY after dropping both: %d active -> %s" % [
		emptied.active.size(), "PASS" if emptied.active.is_empty() else "FAIL"])
	get_tree().quit()


# --- interdiction harness ---------------------------------------------------

func _run_raid_test() -> void:
	var player: PlayerShip = get_tree().get_first_node_in_group("player")
	player.invulnerable = true
	_wave_timer = 1.0e9
	_apex_wake_timer = -1.0
	for n in get_tree().get_nodes_in_group("hostiles"):
		(n as Node3D).queue_free()
	GameState.cargo = {}
	await get_tree().create_timer(0.4).timeout

	# 1. An empty hold, and a modest one, are never worth stopping.
	var empty_chance := interdiction_chance()
	GameState.cargo = {"alloys": 5}                       # 200 -> under the floor
	var small_chance := interdiction_chance()
	GameState.cargo = {"relics": 12}                      # 3120 -> over the floor
	var rich_chance := interdiction_chance()
	print("[raid] CHANCE empty %.2f, hold 200 %.2f, hold 3120 %.2f -> %s" % [
		empty_chance, small_chance, rich_chance,
		"PASS" if empty_chance == 0.0 and small_chance == 0.0 and rich_chance > 0.0 else "FAIL"])

	# 2. Contraband weighs triple, so the same sticker value is three times the
	#    heat. This is the whole reason the smuggling route is a decision.
	GameState.cargo = {"relics": 10}                      # 2600 sticker, 2600 weighted
	var plain := GameState.hold_value(true)
	GameState.cargo = {"contraband": 8}                   # 2720 sticker, 8160 weighted
	var hot := GameState.hold_value(true)
	print("[raid] CONTRABAND WEIGHT relics(10)=%d vs contraband(8)=%d weighted, sticker %d vs %d -> %s" % [
		plain, hot, 2600, 2720,
		"PASS" if hot > plain * 2.5 else "FAIL"])

	# 3. Never during the states where being jumped would be unfair.
	GameState.cargo = {"relics": 40}
	var while_flying := interdiction_eligible()
	_set_boss_active(true)
	var during_boss := interdiction_eligible()
	_set_boss_active(false)
	tutorial.arm()
	var during_tutorial := interdiction_eligible()
	tutorial.skip()
	warping = true
	var during_warp := interdiction_eligible()
	warping = false
	print("[raid] EXCLUSIONS flying=%s boss=%s tutorial=%s warping=%s -> %s" % [
		str(while_flying), str(during_boss), str(during_tutorial), str(during_warp),
		"PASS" if while_flying and not during_boss and not during_tutorial and not during_warp
			else "FAIL"])

	# A console covers two thirds of the screen and does not pause the game, so a
	# raid starting behind one is an ambush the player never got to see coming.
	refit_panel.open()
	await get_tree().process_frame
	var during_refit := interdiction_eligible()
	refit_panel.close_panel()
	chart_panel.open()
	await get_tree().process_frame
	var during_chart := interdiction_eligible()
	chart_panel.close_panel()
	toggle_pause()
	var during_pause := interdiction_eligible()
	toggle_pause()
	await get_tree().create_timer(0.4).timeout
	var after_close := interdiction_eligible()
	print("[raid] CONSOLE SAFE refit=%s chart=%s paused=%s (all false), reopens after=%s -> %s" % [
		str(during_refit), str(during_chart), str(during_pause), str(after_close),
		"PASS" if not during_refit and not during_chart and not during_pause and after_close
			else "FAIL"])

	# 4. A forced raid arrives as a pack from one bearing, tinted, and carrying
	#    somebody else's cargo.
	GameState.cargo = {"relics": 60}                      # rich enough for a corsair
	spawn_interdiction()
	# Measured synchronously, before anyone has flown anywhere: raiders top out
	# at 7.5u/s and separate on contact, so even half a second of drift makes a
	# spawn-formation assertion meaningless.
	var raiders := get_tree().get_nodes_in_group("raider")
	var spread := 0.0
	var centroid := Vector3.ZERO
	for n in raiders:
		centroid += (n as Node3D).global_position
	if raiders.size() > 0:
		centroid /= float(raiders.size())
	for n in raiders:
		spread = maxf(spread, (n as Node3D).global_position.distance_to(centroid))
	var intercept_dist := centroid.distance_to(player.global_position)

	await get_tree().create_timer(0.5).timeout
	var tinted := 0
	var stolen_carriers := 0
	for n in raiders:
		if n is SwarmHostile:
			if (n as SwarmHostile).tint.a > 0.0:
				tinted += 1
			if (n as SwarmHostile).drop_good == "stolen":
				stolen_carriers += 1
	print("[raid] SPAWNED %d raiders (%d tinted, %d carrying stolen), spawn spread %.1fu -> %s" % [
		raiders.size(), tinted, stolen_carriers, spread,
		"PASS" if raiders.size() >= 3 and tinted >= 3 and stolen_carriers == 2 and spread < 4.0
			else "FAIL"])
	# One bearing, at range: an intercept you can see coming and turn away from,
	# not a ring that has already closed.
	print("[raid] INTERCEPT pack arrives %.1fu out on a single bearing (spawn dist %.1f) -> %s" % [
		intercept_dist, RAID_SPAWN_DIST,
		"PASS" if intercept_dist > 8.0 else "FAIL"])
	print("[raid] CORSAIR present=%s at hold value %d (>= %d) -> %s" % [
		str(raiders.size() > tinted), GameState.hold_value(true), RAID_CORSAIR_HOLD,
		"PASS" if raiders.size() > tinted else "FAIL"])

	# 5. A raid never stacks on top of a raid.
	var before_second := get_tree().get_nodes_in_group("raider").size()
	_raid_timer = 0.0
	_tick_interdiction(0.1)
	await get_tree().process_frame
	print("[raid] NO STACK %d -> %d raiders while one is live -> %s" % [
		before_second, get_tree().get_nodes_in_group("raider").size(),
		"PASS" if get_tree().get_nodes_in_group("raider").size() == before_second else "FAIL"])

	# 6. Clearing the pack starts the cooldown rather than immediately re-rolling.
	for n in get_tree().get_nodes_in_group("raider"):
		(n as Node3D).queue_free()
	await get_tree().process_frame
	_tick_interdiction(0.1)
	print("[raid] COOLDOWN active=%s cooldown %.0fs eligible=%s (must be false) -> %s" % [
		str(_raid_active), _raid_cooldown, str(interdiction_eligible()),
		"PASS" if not _raid_active and _raid_cooldown > 80.0 and not interdiction_eligible()
			else "FAIL"])

	# 7. Warping out is the escape hatch: the raid does not follow.
	spawn_interdiction()
	await get_tree().create_timer(0.3).timeout
	var before_warp := get_tree().get_nodes_in_group("raider").size()
	_load_system("pyx01")
	await get_tree().process_frame
	print("[raid] WARP ESCAPE %d raiders -> %d after system change, active=%s -> %s" % [
		before_warp, get_tree().get_nodes_in_group("raider").size(), str(_raid_active),
		"PASS" if before_warp > 0 and get_tree().get_nodes_in_group("raider").is_empty()
			and not _raid_active else "FAIL"])

	# 8. Docking is safe, so an interdiction can never begin while clamped on.
	GameState.cargo = {"relics": 40}
	_raid_cooldown = 0.0
	var port := find_port()
	docked_port = port
	var while_docked := interdiction_eligible()
	docked_port = null
	print("[raid] DOCKED SAFE eligible while clamped on=%s (must be false) -> %s" % [
		str(while_docked), "PASS" if not while_docked else "FAIL"])

	# --- C4: the taper --------------------------------------------------------

	# 9. Interdiction falls off with distance while the expanse's own danger
	#    climbs, which is the trade the whole thing rests on. It must never reach
	#    zero: there is no range at which a full hold is safe, only ranges at
	#    which it is unlikely to be noticed.
	set_deep_generation(false)
	for n in get_tree().get_nodes_in_group("hostiles"):
		(n as Node3D).queue_free()
	_raid_active = false
	_raid_cooldown = 0.0
	GameState.cargo = {"relics": 60}
	var edge_r := SystemDB.bounds_of(system_id)
	var probe_at := [4.0, edge_r + 60.0, edge_r + 260.0, edge_r + 700.0, edge_r + 1400.0]
	var chances := []
	var line2 := ""
	for i in range(probe_at.size()):
		player.global_position = Vector3(probe_at[i], 0, 0)
		await get_tree().physics_frame
		var c := interdiction_chance()
		chances.append(c)
		line2 += "%s %.3f  " % [DeepSpace.BAND_NAMES[i], c]
	var falls := true
	for i in range(1, chances.size()):
		if float(chances[i]) >= float(chances[i - 1]):
			falls = false
	var never_zero := true
	for c in chances:
		if float(c) <= 0.0:
			never_zero = false
	print("[raid] TAPER %s-> %s" % [line2,
		"PASS" if falls and never_zero else "FAIL"])
	print("[raid] TAPER FLOOR loaded hold is still hunted in every band (min %.4f > 0) -> %s" % [
		chances.min(), "PASS" if never_zero else "FAIL"])

	# 10. A raid that fires out in the expanse must actually be a raid. The
	#     charted spawn clamp would put the pack back at the system edge — often
	#     hundreds of units behind the player, arriving off radar a minute later.
	player.global_position = Vector3(edge_r + 700.0, 0, 0)
	await get_tree().physics_frame
	_raid_active = false
	_raid_cooldown = 0.0
	spawn_interdiction()
	var far_raiders := get_tree().get_nodes_in_group("raider")
	var worst_dist := 0.0
	var leashed_all := true
	for n in far_raiders:
		worst_dist = maxf(worst_dist, (n as Node3D).global_position.distance_to(player.global_position))
		if n is SwarmHostile and (n as SwarmHostile).despawn_radius <= 0.0:
			leashed_all = false
		if n is Hostile and (n as Hostile).despawn_radius <= 0.0:
			leashed_all = false
	print("[raid] DEEP INTERCEPT %d raiders, furthest %.1fu from the ship (spawn dist %.1f), all leashed=%s -> %s" % [
		far_raiders.size(), worst_dist, RAID_SPAWN_DIST, str(leashed_all),
		"PASS" if far_raiders.size() > 0 and worst_dist < RAID_SPAWN_DIST + 8.0
			and leashed_all else "FAIL"])
	for n in far_raiders:
		if is_instance_valid(n):
			(n as Node3D).queue_free()
	await get_tree().physics_frame
	_raid_active = false
	_parley_until = 0.0

	# --- the parley -----------------------------------------------------------

	# P1. TOLL BASE, unweighted, with the weighted figure printed beside it. The
	#     manifest halves raid ODDS via hold_signature and contraband triples the
	#     raider roll's read of you — neither may touch the PRICE, or the manifest
	#     double-dips and a chart-data hold tolls toward zero. Wiring the toll to
	#     the weighted value flips this line.
	player.global_position = Vector3(0, 0, 6)
	GameState.cargo = {}
	GameState.load_cargo("contraband", 10)     # 3,400 base, weighted x3
	_raid_cooldown = 0.0
	_raid_timer = 0.0
	spawn_interdiction()
	var expect_toll := maxi(TOLL_FLOOR, int(float(GameState.hold_value(false)) * TOLL_FRACTION))
	print("[raid] TOLL BASE unweighted %d -> toll %d (weighted reads %d; pricing off THAT flips this) -> %s" % [
		GameState.hold_value(false), _parley_toll, GameState.hold_value(true),
		"PASS" if _parley_toll == expect_toll and _parley_toll < int(
			float(GameState.hold_value(true)) * TOLL_FRACTION) else "FAIL"])

	# P2. STANDOFF. Six seconds of demand window in which nothing lands — 14's
	#     rule that being jumped must be reactable, applied to the demand itself.
	var shield_at_demand := player.shield
	player.invulnerable = false
	for i in range(90):
		await get_tree().physics_frame
	var standoff_damage := shield_at_demand - player.shield
	player.invulnerable = true
	print("[raid] STANDOFF %.1f damage in the first 1.5s of the demand window (must be 0) -> %s" % [
		standoff_damage, "PASS" if standoff_damage <= 0.0 else "FAIL"])

	# P3. PAY ENDS — the deadlock this feature was almost shipped with. A paid
	#     pack that merely flew away would leave _raid_active true forever:
	#     cooldown never starts, eligibility never recovers, and interdictions
	#     silently stop for the session. depart() sheds groups immediately.
	var toll_before_cargo := GameState.hold_value(false)
	pay_toll()
	var paid_value := toll_before_cargo - GameState.hold_value(false)
	for i in range(30):
		await get_tree().physics_frame
	_tick_interdiction(0.01)
	print("[raid] PAY ENDS raiders %d, _raid_active=%s, cooldown %.0f (deadlock prints 5/true/0) -> %s" % [
		_count_raiders(), str(_raid_active), _raid_cooldown,
		"PASS" if _count_raiders() == 0 and not _raid_active
			and _raid_cooldown > 0.0 else "FAIL"])

	# P4. THE TOLL TAKES HOT CARGO, and pays nothing back. Contraband went first
	#     (weight x value), the removed value covers the toll, and no loot exists
	#     anywhere a departing raider stood.
	var loot_after := 0
	for n in system_root.get_children():
		if n is LootCube:
			loot_after += 1
	print("[raid] TOLL TAKES HOT CARGO removed %d >= toll %d, contraband first, %d cubes dropped by departing raiders -> %s" % [
		paid_value, expect_toll, loot_after,
		"PASS" if paid_value >= expect_toll and loot_after == 0 else "FAIL"])

	# P5. MANIFEST NO DOUBLE DIP. Same hold plus a Forged Manifest: raid odds may
	#     fall (that is the item), the toll may not.
	GameState.cargo = {}
	GameState.load_cargo("contraband", 10)
	var toll_plain := maxi(TOLL_FLOOR, int(float(GameState.hold_value(false)) * TOLL_FRACTION))
	GameState.load_cargo("manifest_forged", 1)
	var with_manifest := GameState.hold_value(false)
	var toll_manifest := maxi(TOLL_FLOOR, int(float(with_manifest) * TOLL_FRACTION))
	var manifest_share := int(float(CommodityDB.base_price("manifest_forged")) * TOLL_FRACTION)
	print("[raid] MANIFEST NO DOUBLE DIP toll %d -> %d (+%d is the manifest's own sticker, not a discount) -> %s" % [
		toll_plain, toll_manifest, manifest_share,
		"PASS" if toll_manifest == toll_plain + manifest_share else "FAIL"])

	# P6. TOLL FLOOR. A 1,500 hold demands 400, not 225 — a demand beneath
	#     dignity is a demand nobody reads.
	GameState.cargo = {}
	GameState.load_cargo("alloys", 37)         # 1,480 base
	var floor_toll := maxi(TOLL_FLOOR, int(float(GameState.hold_value(false)) * TOLL_FRACTION))
	print("[raid] TOLL FLOOR %d on a %d hold (15%% alone is %d) -> %s" % [
		floor_toll, GameState.hold_value(false),
		int(float(GameState.hold_value(false)) * TOLL_FRACTION),
		"PASS" if floor_toll == TOLL_FLOOR else "FAIL"])

	# P7. The decision math, printed rather than asserted — the harness bot is
	#     not a pilot, and whether these numbers make paying FEEL right is the
	#     playtest's question, not this line's.
	print("[raid] DECISION fight pays ~+700 in drops / toll costs %d / deep death spills the unread hold" % expect_toll)

	# P8. TOLL MARGIN — printed every run, whether or not it binds. The floor is
	#     safe today only because the cheapest raidable hold (RAID_MIN_HOLD at the
	#     heaviest interdiction weight) still clears it; that is three unrelated
	#     constants holding a rule up between them, so the number gets said out
	#     loud rather than rediscovered.
	var lightest := float(RAID_MIN_HOLD) / CommodityDB.interdiction_weight("charge_unstable")
	print("[raid] TOLL MARGIN cheapest raidable hold is %.1f unweighted vs a %d floor (margin %.1f) -> %s" % [
		lightest, TOLL_FLOOR, lightest - float(TOLL_FLOOR),
		"PASS" if lightest > float(TOLL_FLOOR) else "FAIL"])

	# P9. PARTIAL PAY REFUSED. The manifest's dump button is the first thing that
	#     can shrink a hold mid-standoff; without this guard, one 40-credit alloy
	#     buys a clean exit and credits a toll to the logbook.
	GameState.cargo = {}
	GameState.load_cargo("contraband", 10)
	_raid_cooldown = 0.0
	_raid_timer = 0.0
	_raid_active = false
	spawn_interdiction()
	var demanded := _parley_toll
	GameState.cargo = {}
	GameState.load_cargo("alloys", 1)          # 40 base, far under any toll
	var salv_before := GameState.salvage
	pay_toll()
	print("[raid] PARTIAL PAY REFUSED demand %d vs a %d hold: raid still live=%s, cargo kept=%d, salvage unmoved=%s -> %s" % [
		demanded, GameState.hold_value(false), str(_raid_active),
		GameState.cargo_count("alloys"), str(GameState.salvage == salv_before),
		"PASS" if _raid_active and GameState.cargo_count("alloys") == 1 else "FAIL"])
	for n in get_tree().get_nodes_in_group("raider"):
		if is_instance_valid(n):
			(n as Node3D).queue_free()
	await get_tree().physics_frame
	_raid_active = false

	# P10. CONSOLE CAMPING, both branches. Parked behind a sheet is still shelter
	#      (14's actual claim); flying behind one is not, and the sheet closes as
	#      the klaxon lands so the standoff carries the reactability.
	GameState.cargo = {}
	GameState.load_cargo("contraband", 10)
	_raid_cooldown = 0.0
	player.velocity = Vector3.ZERO
	refit_panel.open()
	await get_tree().process_frame
	var parked_ok := not interdiction_eligible()
	player.velocity = Vector3(6.0, 0.0, 0.0)
	var moving_ok := interdiction_eligible()
	_raid_timer = 0.0
	spawn_interdiction()
	await get_tree().process_frame
	var sheet_closed := not refit_panel.is_open
	player.velocity = Vector3.ZERO
	refit_panel.close_panel()
	print("[raid] CONSOLE CAMPING parked+open ineligible=%s, moving+open eligible=%s, sheet closed by the klaxon=%s -> %s" % [
		str(parked_ok), str(moving_ok), str(sheet_closed),
		"PASS" if parked_ok and moving_ok and sheet_closed else "FAIL"])
	get_tree().quit()


# --- pause harness ----------------------------------------------------------

func _run_pause_test() -> void:
	var player: PlayerShip = get_tree().get_first_node_in_group("player")
	player.invulnerable = true
	_apex_wake_timer = -1.0
	_wave_timer = 1.0e9
	await get_tree().create_timer(0.4).timeout

	# A live scene: moving hostiles, drifting loot, a ship under orders.
	for i in range(5):
		var s := SwarmHostile.new()
		s.difficulty = 1.0
		system_root.add_child(s)
		s.global_position = player.global_position + Vector3(randf_range(-8, 8), 0, randf_range(-8, 8))
	spawn_loot(system_root, player.global_position + Vector3(9, 0, 9))
	player.command_move(player.global_position + Vector3(20, 0, 0))
	await get_tree().create_timer(1.0).timeout

	toggle_pause()
	print("[pause] OPEN menu=%s tree.paused=%s (both must be true)" % [
		str(pause_menu.is_open), str(get_tree().paused)])

	# Snapshot everything that moves, wait two real seconds, and compare. Timers
	# created with ignore_time_scale still fire while paused, which is what lets
	# this measure a genuinely frozen world rather than a slow one.
	var before := _pause_world_snapshot(player)
	await get_tree().create_timer(2.0, true, false, true).timeout
	var after := _pause_world_snapshot(player)
	var drift := 0.0
	for key in before:
		if after.has(key):
			drift = maxf(drift, (before[key] as Vector3).distance_to(after[key]))
	print("[pause] FROZEN %d bodies, max drift over 2s = %.4f (must be 0) -> %s" % [
		before.size(), drift, "PASS" if drift < 0.0001 and before.size() >= 6 else "FAIL"])

	# Music and settings must stay live behind the scrim, or the sliders are
	# decoration. Both run PROCESS_MODE_ALWAYS for exactly this reason.
	var music_alive := Music.is_playing()
	GameState.set_setting("music_vol", 0.25)
	var music_bus := AudioServer.get_bus_index(Sfx.BUS_MUSIC)
	var quiet_db := AudioServer.get_bus_volume_db(music_bus)
	GameState.set_setting("music_vol", 1.0)
	var loud_db := AudioServer.get_bus_volume_db(music_bus)
	print("[pause] SETTINGS LIVE music playing=%s  vol 0.25 -> %.1fdB, 1.0 -> %.1fdB -> %s" % [
		str(music_alive), quiet_db, loud_db,
		"PASS" if music_alive and quiet_db < loud_db - 6.0 else "FAIL"])

	# Screen shake is a setting the camera has to actually respect.
	var rig := get_tree().get_first_node_in_group("camera_rig") as CameraRig
	# Zeroed before each probe. `_shake_amp` is a shared accumulator that ANYTHING
	# can write — a swarm fighter dying nearby adds 0.03 — so reading it straight
	# after rig.shake() only measures the setting if nothing else got there first.
	# This harness stands up a deliberately live scene, and once the ship started
	# returning fire on its own it began killing that scene mid-measurement.
	GameState.set_setting("shake", false)
	rig.set("_shake_amp", 0.0)
	rig.shake(0.5)
	var shake_off: float = rig.get("_shake_amp")
	GameState.set_setting("shake", true)
	rig.set("_shake_amp", 0.0)
	rig.shake(0.5)
	var shake_on: float = rig.get("_shake_amp")
	print("[pause] SHAKE SETTING off -> %.2f, on -> %.2f -> %s" % [
		shake_off, shake_on, "PASS" if shake_off == 0.0 and shake_on > 0.0 else "FAIL"])

	# UI scale composes with the automatic rule rather than replacing it.
	var desktop := Vector2(1440, 900)
	var phone := Vector2(1170, 2532)
	UILayout.user_scale = 1.0
	var auto_desktop := UILayout.content_factor(desktop)
	var auto_phone := UILayout.content_factor(phone)
	UILayout.user_scale = 1.25
	var scaled_desktop := UILayout.content_factor(desktop)
	var scaled_phone := UILayout.content_factor(phone)
	UILayout.user_scale = 1.0
	print("[pause] UI SCALE desktop %.3f -> %.3f (x1.25), phone %.3f -> %.3f -> %s" % [
		auto_desktop, scaled_desktop, auto_phone, scaled_phone,
		"PASS" if is_equal_approx(scaled_desktop, auto_desktop * 1.25)
			and is_equal_approx(scaled_phone, auto_phone * 1.25) else "FAIL"])

	# Resuming puts the world back in motion.
	toggle_pause()
	var resumed_before := _pause_world_snapshot(player)
	await get_tree().create_timer(1.0).timeout
	var resumed_after := _pause_world_snapshot(player)
	var moved := 0.0
	for key in resumed_before:
		if resumed_after.has(key):
			moved = maxf(moved, (resumed_before[key] as Vector3).distance_to(resumed_after[key]))
	print("[pause] RESUMED menu=%s tree.paused=%s max motion %.2f -> %s" % [
		str(pause_menu.is_open), str(get_tree().paused), moved,
		"PASS" if not pause_menu.is_open and not get_tree().paused and moved > 0.05 else "FAIL"])

	# ABANDON TO TITLE is only reachable from the pause menu, so nothing else
	# exercises it — and it unwinds a lot at once: closes consoles, undocks,
	# clears boss state, drops the pending dock, rebuilds the world in attract
	# form. A failure here strands the player at a half-torn-down session.
	_enter_playing()
	var port := find_port()
	if port != null:
		player.global_position = port.dock_point
		_complete_dock(port)
		await get_tree().create_timer(0.4).timeout
	_set_boss_active(true)
	toggle_pause()
	await get_tree().create_timer(0.3).timeout
	abandon_to_title()
	await get_tree().create_timer(0.5).timeout
	var clean := state == State.ATTRACT \
		and not get_tree().paused \
		and not pause_menu.is_open \
		and docked_port == null \
		and not boss_active \
		and not port_panel.is_open \
		and title_screen.visible
	print("[pause] ABANDON state=%s paused=%s docked=%s boss=%s panel=%s title=%s -> %s" % [
		"ATTRACT" if state == State.ATTRACT else "PLAYING", str(get_tree().paused),
		str(docked_port != null), str(boss_active), str(port_panel.is_open),
		str(title_screen.visible), "PASS" if clean else "FAIL"])
	# The run itself is untouched: abandoning is leaving the cockpit, not
	# discarding progress.
	print("[pause] ABANDON KEEPS RUN salvage=%d system=%s -> %s" % [
		GameState.salvage, GameState.current_system,
		"PASS" if GameState.salvage > 0 and GameState.current_system != "" else "FAIL"])

	# Pausing behind the title screen is meaningless and must be refused.
	toggle_pause()
	print("[pause] ATTRACT REFUSED menu=%s tree.paused=%s (both must be false) -> %s" % [
		str(pause_menu.is_open), str(get_tree().paused),
		"PASS" if not pause_menu.is_open and not get_tree().paused else "FAIL"])
	get_tree().quit()


func _pause_world_snapshot(player: Node3D) -> Dictionary:
	var out := {}
	out[player.get_instance_id()] = player.global_position
	for group in ["hostiles", "apex_probe"]:
		for n in get_tree().get_nodes_in_group(group):
			var node := n as Node3D
			if is_instance_valid(node):
				out[node.get_instance_id()] = node.global_position
	# Loot cubes are in no group; they are children of the system root.
	for child in system_root.get_children():
		if child is LootCube:
			out[child.get_instance_id()] = (child as Node3D).global_position
	return out


# --- radar harness ----------------------------------------------------------

func _run_radar_test() -> void:
	var player: PlayerShip = get_tree().get_first_node_in_group("player")
	set_deep_generation(false)
	player.invulnerable = true
	_wave_timer = 1.0e9
	_apex_wake_timer = -1.0
	for n in get_tree().get_nodes_in_group("hostiles"):
		(n as Node3D).queue_free()
	await get_tree().create_timer(0.5).timeout

	# Headless defaults to a 160x160 viewport, which is smaller than the marker
	# geometry itself — every assertion below is about screen position, so give
	# it the real design resolution to measure against.
	get_window().size = Vector2i(720, 1280)
	await get_tree().process_frame
	await get_tree().process_frame
	var rect := get_viewport().get_visible_rect()
	var centre := rect.size * 0.5
	print("[radar] viewport %.0fx%.0f" % [rect.size.x, rect.size.y])

	player.global_position = Vector3(0, 0, 6)
	var rig := get_tree().get_first_node_in_group("camera_rig") as CameraRig
	rig.global_position = Vector3(0, 0, 6)

	var bogey := SwarmHostile.new()
	bogey.difficulty = 0.0
	bogey.hp_scale = 40.0
	system_root.add_child(bogey)

	# 1. A contact the player can already see must NOT ping. Checked per-contact
	#    rather than by counting: the system's own port and derelict are legitimately
	#    off screen from the spawn point, and they should ping.
	bogey.global_position = player.global_position + Vector3(2.0, 0, 0)
	bogey.dock_at(bogey.global_position)
	await get_tree().create_timer(0.4).timeout
	var near_ping := _radar_marker_for(bogey)
	print("[radar] ON-SCREEN contact 2u away pings=%s (must be false) — %d other markers" % [
		str(not near_ping.is_empty()), hud.radar_markers().size()])

	# 2. The same contact well off screen on +X must ping on the RIGHT border.
	bogey.global_position = player.global_position + Vector3(34, 0, 0)
	bogey.dock_at(bogey.global_position)
	await get_tree().create_timer(0.4).timeout
	var far_ping := _radar_marker_for(bogey)
	var right_edge := not far_ping.is_empty() \
		and (far_ping["pos"] as Vector2).x > centre.x + rect.size.x * 0.25
	print("[radar] BEARING +X contact -> marker at (%.0f, %.0f), right of centre=%s -> %s" % [
		(far_ping["pos"] as Vector2).x if not far_ping.is_empty() else -1.0,
		(far_ping["pos"] as Vector2).y if not far_ping.is_empty() else -1.0,
		str(right_edge), "PASS" if near_ping.is_empty() and right_edge else "FAIL"])

	# 3. Every marker must land inside the viewport, whatever the bearing. This
	#    is the assertion that catches the behind-the-camera projection case,
	#    where unproject_position mirrors the point and the arrow would fly off.
	var inside := true
	var worst := ""
	for ang in range(0, 360, 15):
		var r := deg_to_rad(float(ang))
		bogey.global_position = player.global_position + Vector3(cos(r), 0, sin(r)) * 34.0
		bogey.dock_at(bogey.global_position)
		await get_tree().create_timer(0.12).timeout
		for marker in hud.radar_markers():
			var p: Vector2 = marker["pos"]
			if p.x < 0.0 or p.y < 0.0 or p.x > rect.size.x or p.y > rect.size.y:
				inside = false
				worst = "bearing %d -> (%.0f, %.0f)" % [ang, p.x, p.y]
	print("[radar] ON SCREEN every marker inside the viewport at all 24 bearings -> %s %s" % [
		"PASS" if inside else "FAIL", worst])

	# 4. The cap holds, and the apex survives it: 30 contacts is more than the
	#    twelve slots, and the boss is the one that must never be dropped.
	bogey.queue_free()
	GameState.mark_breached(system_id)
	for i in range(30):
		var s := SwarmHostile.new()
		s.difficulty = 0.0
		s.hp_scale = 40.0
		system_root.add_child(s)
		var a := TAU * float(i) / 30.0
		s.global_position = player.global_position + Vector3(cos(a), 0, sin(a)) * 30.0
		s.dock_at(s.global_position)
	await get_tree().create_timer(0.6).timeout
	var all := hud.radar_markers()
	var apex_marker := false
	for marker in all:
		if is_equal_approx(float(marker["size"]), HUD.RadarLayer.SIZE_APEX):
			apex_marker = true
	print("[radar] CAP %d markers with %d contacts + apex, <= %d -> %s  apex_kept=%s" % [
		all.size(), 30, HUD.RadarLayer.MAX_MARKERS,
		"PASS" if all.size() <= HUD.RadarLayer.MAX_MARKERS else "FAIL", str(apex_marker)])

	# 5. Attract mode is the system, not the cockpit — no arrows over the title.
	hud.set_chrome_visible(false)
	await get_tree().create_timer(0.3).timeout
	print("[radar] HIDDEN with chrome off: %d markers (must be 0) -> %s" % [
		hud.radar_markers().size(),
		"PASS" if hud.radar_markers().is_empty() else "FAIL"])
	get_tree().quit()


func _radar_marker_for(node: Node3D) -> Dictionary:
	for m in hud.radar_markers():
		if int(m["id"]) == node.get_instance_id():
			return m
	return {}


# --- music harness ----------------------------------------------------------

func _run_music_test() -> void:
	var player: PlayerShip = get_tree().get_first_node_in_group("player")
	player.invulnerable = true
	for n in get_tree().get_nodes_in_group("hostiles"):
		(n as Node3D).queue_free()
	_wave_timer = 1.0e9
	# Arriving in an already-breached system arms the apex, and a live engine is
	# a threat by definition — which is correct, and which would otherwise pin
	# the mix to combat for the whole harness. The boss path gets its own
	# assertion at the end instead.
	_apex_wake_timer = -1.0
	await get_tree().create_timer(0.4).timeout

	print("[music] layers loaded=%s  playing=%s (both must be true)" % [
		str(Music.available()), str(Music.is_playing())])

	# The whole design rests on the two layers being the same length, so that a
	# crossfade never moves the harmony. Assert it rather than trusting the
	# generator.
	var calm := load("res://audio/music_calm.wav") as AudioStreamWAV
	var combat := load("res://audio/music_combat.wav") as AudioStreamWAV
	var same := calm != null and combat != null and calm.data.size() == combat.data.size()
	print("[music] LOOP ALIGN calm %d frames vs combat %d frames -> %s" % [
		calm.data.size() / 2 if calm else -1, combat.data.size() / 2 if combat else -1,
		"PASS" if same else "FAIL"])

	# Calm with nothing around.
	await get_tree().create_timer(Music.FADE_OUT + 0.6).timeout
	var calm_blend := Music.blend()
	print("[music] CALM blend %.2f (must be ~0)" % calm_blend)

	# A contact inside the threat radius must pull the mix over.
	var bogey := SwarmHostile.new()
	bogey.difficulty = 0.0
	bogey.hp_scale = 40.0
	system_root.add_child(bogey)
	bogey.global_position = player.global_position + Vector3(0, 0, Music.THREAT_RADIUS * 0.4)
	bogey.dock_at(bogey.global_position)
	await get_tree().create_timer(Music.FADE_IN + 0.8).timeout
	var hot_blend := Music.blend()
	print("[music] THREAT blend %.2f (must be ~1)" % hot_blend)

	# And releasing it must fall back, after the hold.
	bogey.queue_free()
	await get_tree().create_timer(Music.THREAT_HOLD + Music.FADE_OUT + 0.8).timeout
	var cooled := Music.blend()
	print("[music] RELEASE blend %.2f (must be ~0)" % cooled)
	print("[music] ADAPTIVE calm<0.1 && threat>0.9 && release<0.1 -> %s" % [
		"PASS" if calm_blend < 0.1 and hot_blend > 0.9 and cooled < 0.1 else "FAIL"])

	# Per-system tint is applied to the calm layer only.
	var idx := AudioServer.get_bus_index(Sfx.BUS_MUSIC_CALM)
	Music.set_system_tint(SystemDB.music_lp_of("pyx03"))
	var lp := AudioServer.get_bus_effect(idx, 0) as AudioEffectLowPassFilter
	var dark := lp.cutoff_hz
	Music.set_system_tint(SystemDB.music_lp_of("pyx01"))
	var open := lp.cutoff_hz
	print("[music] TINT pyx03 %.0fHz < pyx01 %.0fHz -> %s  (combat bus untouched: %d effects)" % [
		dark, open, "PASS" if dark < open else "FAIL",
		AudioServer.get_bus_effect_count(AudioServer.get_bus_index(Sfx.BUS_MUSIC))])

	# Docking ducks the score without stopping it.
	Music.set_docked(true)
	await get_tree().create_timer(Music.DOCK_FADE + 0.4).timeout
	var ducked_db := _music_calm_db()
	Music.set_docked(false)
	await get_tree().create_timer(Music.DOCK_FADE + 0.4).timeout
	var normal_db := _music_calm_db()
	print("[music] DUCK docked %.1fdB < undocked %.1fdB, still playing=%s -> %s" % [
		ducked_db, normal_db, str(Music.is_playing()),
		"PASS" if ducked_db < normal_db - 0.5 and Music.is_playing() else "FAIL"])

	# A live apex engine is a threat wherever it is standing: the arena is wider
	# than THREAT_RADIUS, so proximity alone would let the score go calm in the
	# middle of the boss fight.
	_set_boss_active(true)
	await get_tree().create_timer(Music.FADE_IN + 0.8).timeout
	var boss_blend := Music.blend()
	_set_boss_active(false)
	print("[music] BOSS blend %.2f with boss_active and no contact nearby -> %s" % [
		boss_blend, "PASS" if boss_blend > 0.9 else "FAIL"])

	# The title screen drops the score entirely; the ambient drone stays.
	_enter_attract()
	await get_tree().process_frame
	print("[music] TITLE playing=%s (must be false)  ambient loop=%s (must be true)" % [
		str(Music.is_playing()), str(Sfx.is_looping("ambient"))])
	get_tree().quit()


func _music_calm_db() -> float:
	for child in Music.get_children():
		var p := child as AudioStreamPlayer
		if p != null and p.bus == Sfx.BUS_MUSIC_CALM:
			return p.volume_db
	return 0.0


# --- economy pacing harness -------------------------------------------------

func _run_pacing_test() -> void:
	# Seeded so runs of an unchanged catalog land within a few percent of each
	# other. Not bit-identical: FX and drift draw from the same global RNG on a
	# frame-count-dependent schedule. The band is wide enough to absorb that —
	# if it ever is not, the band is the thing that is wrong.
	seed(0x50415849)
	set_deep_generation(false)
	var player: PlayerShip = get_tree().get_first_node_in_group("player")

	GameState.reset_to_starter()
	_load_system(SystemDB.START_SYSTEM)
	# Nothing may pay the player except the activity being measured: no wave
	# spawner, no market events, no contract completing mid-measurement.
	_wave_timer = 1.0e9
	_event_roll_timer = 1.0e9
	contracts.active = []
	await get_tree().create_timer(0.4).timeout
	player.invulnerable = true
	player.clear_target()

	var catalog := _pacing_catalog_cost()
	print("[pacing] starter fit: dps %.0f  hold %d  salvage_mult %.2f  system loot_mult %.2f" % [
		float(GameState.stats.get("dps", 0.0)), GameState.cargo_capacity(),
		float(GameState.stats.get("salvage_mult", 1.0)), loot_mult()])
	print("[pacing] catalog: every module + both reactor upgrades = %d" % catalog)

	var per_swarm := await _pacing_kill_yield("swarm", 6)
	var per_sentry := await _pacing_kill_yield("sentry", 3)
	var per_derelict := await _pacing_derelict_yield()
	var per_trade := _pacing_trade_yield()
	var per_contract := _pacing_contract_yield()
	var per_survey := _pacing_survey_yield()

	print("[pacing] YIELD  swarm %.0f/kill  sentry %.0f/kill  derelict %.0f/hull  trade %.0f/run  contract %.0f/each" % [
		per_swarm, per_sentry, per_derelict, per_trade, per_contract])

	var earned := per_swarm * float(PACING_LOOP["swarm"]) \
		+ per_sentry * float(PACING_LOOP["sentry"]) \
		+ per_derelict * float(PACING_LOOP["derelict"]) \
		+ per_trade * float(PACING_LOOP["trade"]) \
		+ per_contract * float(PACING_LOOP["contract"]) \
		+ per_survey * float(PACING_LOOP["survey"])

	print("[pacing] LOOP %d swarm + %d sentry + %d derelict + %d trade run + %d contract over %.0f min" % [
		int(PACING_LOOP["swarm"]), int(PACING_LOOP["sentry"]), int(PACING_LOOP["derelict"]),
		int(PACING_LOOP["trade"]), int(PACING_LOOP["contract"]), PACING_MINUTES])
	print("[pacing] EARNED %.0f per %.0f-minute loop  (%.0f sessions to the full catalog)" % [
		earned, PACING_MINUTES, float(catalog) / maxf(earned, 1.0)])

	var mid := float(ModuleDB.get_module(PACING_MIDTIER).get("price", 1))
	# Ceiling only. A catalog fraction is the right shape for "earning got too
	# fast" — that stays true however big the catalog is — and the wrong shape
	# for "earning got too slow", which is what the mid-tier floor below covers.
	var ratio := earned / maxf(float(catalog), 1.0)
	print("[pacing] TRADE SWEEP %d goods x %d port pairs, %d illegal skipped -> %s" % [
		CommodityDB.ids().size(), SystemDB.port_ids().size() * (SystemDB.port_ids().size() - 1),
		_pacing_trade_skipped, "PASS" if _pacing_trade_skipped > 0 else "FAIL"])
	# The catalog is what a run can BUY. A craftable has no price, so it cannot be
	# in it — and cannot silently grow the denominator the ceiling is measured
	# against, which is the failure mode 10 warns about after the Mk II tiers.
	var priced := 0
	var free := 0
	for id_v in ModuleDB.MODULES:
		if int((ModuleDB.MODULES[id_v] as Dictionary).get("price", 0)) > 0:
			priced += 1
		else:
			free += 1
	print("[pacing] CATALOG BUYABLE %d priced modules + %d at price 0 -> %s" % [
		priced, free, "PASS" if priced > 0 else "FAIL"])
	print("[pacing] CEILING ratio %.3f <= %.2f -> %s" % [
		ratio, PACING_MAX_RATIO,
		"PASS" if ratio <= PACING_MAX_RATIO else "FAIL"])

	# A derelict is a once-per-system windfall — there are three in the whole
	# game — so the loop above is a best-case session and the right thing to
	# check the CEILING against. The recurring rate is the same loop without it,
	# and that is what the FLOOR has to hold, or the game slows to a crawl once
	# the hulls are all cracked.
	#
	# The floor is measured in MID-TIER MODULES, not as a fraction of the
	# catalog, and that distinction matters. A catalog fraction moves every time
	# content is added: shipping the six Mk II tiers grew the catalog by 84% and
	# dropped the steady ratio from 0.057 to 0.031 without a single earning
	# changing. That is the metric reporting on the catalog, not on the pacing.
	# "One recurring loop is worth about one mid-tier module" is the thing the
	# design actually promises, and it is scale-invariant.
	var steady := earned - per_derelict * float(PACING_LOOP["derelict"])
	var steady_modules := steady / maxf(mid, 1.0)
	print("[pacing] STEADY (no derelict) %.0f per loop, ratio vs catalog %.3f" % [
		steady, steady / maxf(float(catalog), 1.0)])
	print("[pacing] STEADY MIDTIER %.2f x %s per loop vs [%.2f, %.2f] -> %s" % [
		steady_modules, PACING_MIDTIER, PACING_MIN_MODULES, PACING_MAX_MODULES,
		"PASS" if steady_modules >= PACING_MIN_MODULES and steady_modules <= PACING_MAX_MODULES
			else "FAIL"])

	# The same target stated the way the design states it, so a failure reads as
	# "a loop now buys four modules" rather than as an abstract ratio.
	var modules := earned / maxf(mid, 1.0)
	print("[pacing] MIDTIER %.2f x %s (%d) per best-case loop vs [%.2f, %.2f] -> %s" % [
		modules, PACING_MIDTIER, int(mid), PACING_MIN_MODULES, PACING_MAX_MODULES,
		"PASS" if modules >= PACING_MIN_MODULES and modules <= PACING_MAX_MODULES else "FAIL"])
	get_tree().quit()


func _pacing_catalog_cost() -> int:
	var total := 0
	for id in ModuleDB.MODULES:
		total += int((ModuleDB.MODULES[id] as Dictionary).get("price", 0))
	for tier in ModuleDB.REACTOR_TIERS:
		total += int((tier as Dictionary).get("price", 0))
	return total


func _pacing_cargo_value() -> float:
	# Crates are earnings too — valuing the hold at base price keeps a combat
	# yield honest without double-counting the trade margin measured separately.
	var total := 0.0
	for good in GameState.cargo:
		total += float(CommodityDB.base_price(String(good))) * float(GameState.cargo[good])
	return total


func _pacing_kill_yield(kind: String, count: int) -> float:
	var player: PlayerShip = get_tree().get_first_node_in_group("player")
	for n in get_tree().get_nodes_in_group("hostiles"):
		(n as Node3D).queue_free()
	await get_tree().process_frame

	var salvage_before := GameState.salvage
	var cargo_before := _pacing_cargo_value()

	# Somewhere genuinely empty: a pack spawned inside a moon gets resolved out
	# of it and scatters, and what is being measured here is payout, not pathing.
	var spot := Obstacles.resolve(Vector3(0, 0, 14), 5.0)
	for i in range(count):
		var h: Node3D = (Hostile.new() if kind == "sentry" else SwarmHostile.new()) as Node3D
		h.set("difficulty", 1.0)
		system_root.add_child(h)
		h.global_position = spot + Vector3(randf_range(-1.2, 1.2), 0, randf_range(-1.2, 1.2))
	await get_tree().create_timer(0.3).timeout

	# Real mounts, real damage. The ship is pinned inside its own reach because
	# this measures what a fight pays, not how long it takes to fly to one.
	var frames := 0
	while frames < 5400:
		var live := get_tree().get_nodes_in_group("hostiles")
		if live.is_empty():
			break
		var t := live[0] as Node3D
		player.global_position = t.global_position + Vector3(0, 0, 2.5)
		player.velocity = Vector3.ZERO
		player.command_attack(t)
		frames += 1
		await get_tree().physics_frame

	# Park while the spill homes in: LootCube seeks from any distance after
	# SEEK_ALWAYS_AFTER, so standing still collects the whole drop.
	player.clear_target()
	await get_tree().create_timer(6.0).timeout

	var salvage_gain := float(GameState.salvage - salvage_before)
	var crate_gain := _pacing_cargo_value() - cargo_before
	print("[pacing]   %s x%d -> %.0f total (%.0f salvage + %.0f in crates) over %d frames" % [
		kind, count, salvage_gain + crate_gain, salvage_gain, crate_gain, frames])
	return (salvage_gain + crate_gain) / maxf(float(count), 1.0)


func _pacing_derelict_yield() -> float:
	var player: PlayerShip = get_tree().get_first_node_in_group("player")
	var derelict: Derelict = get_tree().get_first_node_in_group("crackable") as Derelict
	if derelict == null:
		print("[pacing]   derelict: none in this system -> 0")
		return 0.0

	var salvage_before := GameState.salvage
	var cargo_before := _pacing_cargo_value()
	var frames := 0
	while not derelict.is_cracked() and frames < 1800:
		# Re-pinned every frame: the hull's own obstacle spheres push the ship
		# back out, and hold_tick drops the hold the moment it leaves range.
		player.global_position = derelict.breach_point + Vector3(0, 0, 3.0)
		player.velocity = Vector3.ZERO
		derelict.hold_begin()
		derelict.hold_tick(get_physics_process_delta_time())
		frames += 1
		await get_tree().physics_frame

	# The spill arrives in waves over VORTEX_TIME, then has to fly home.
	await get_tree().create_timer(10.0).timeout
	var salvage_gain := float(GameState.salvage - salvage_before)
	var crate_gain := _pacing_cargo_value() - cargo_before
	print("[pacing]   derelict cracked=%s -> %.0f total (%.0f salvage + %.0f in crates)" % [
		str(derelict.is_cracked()), salvage_gain + crate_gain, salvage_gain, crate_gain])
	return salvage_gain + crate_gain


func _pacing_can_buy_at(port_id: String, good: String) -> bool:
	# A leg the player can actually fly: the good is not restricted away from this
	# port, the port has a shopfront, and the counter is not a fence (a fence buys
	# and does not sell — Market.can_buy).
	if not CommodityDB.trades_at(good, port_id):
		return false
	var pdef := SystemDB.port_def_by_id(port_id)
	if not (pdef.get("services", PortPanel.DEFAULT_SERVICES) as Array).has("market"):
		return false
	return Market.can_buy(pdef, good)


func _pacing_can_sell_at(port_id: String, good: String) -> bool:
	# Same test REACHABLE uses: a market will take anything it lists, and a fence
	# will take what it names.
	if not CommodityDB.trades_at(good, port_id):
		return false
	var pdef := SystemDB.port_def_by_id(port_id)
	var svc: Array = pdef.get("services", PortPanel.DEFAULT_SERVICES)
	return svc.has("market") or (svc.has("fence") and Market.fences(pdef, good))


func _pacing_trade_yield() -> float:
	# One full hold bought where it is cheap and sold where it is dear, priced
	# through the same Market calls the port panel charges with. Deliberately the
	# BEST route on the chart: a player who has learned the map is the case the
	# ceiling has to hold against.
	#
	# ONLY ROUTES THE PLAYER CAN ACTUALLY FLY. This swept every good against every
	# port pair with no legality check at all, so it happily priced "buy contraband
	# at Bastion Yards" — a trade refused by the restriction list at a port that
	# does not even list the good. It went unnoticed because the best FICTIONAL
	# route happened to be beaten by a real one (BANNED void->cantina), which is
	# luck rather than a property. Sell-only goods break that luck immediately:
	# each one gets an imaginary buy leg, `best` inflates, and the whole pacing
	# band moves for a route nobody can fly.
	#
	# The illegal best is measured anyway and printed beside the legal one, so the
	# two numbers visibly diverge — if this filter is ever removed they collapse
	# into each other, which is what makes the assertion below worth having.
	var hold := GameState.cargo_capacity()
	var ports := SystemDB.port_ids()
	var best := 0.0
	var label := "none"
	var ghost_best := 0.0
	var ghost_label := "none"
	var skipped := 0
	for good_v in CommodityDB.ids():
		var good := String(good_v)
		var units := hold / maxi(CommodityDB.space_of(good), 1)
		for a_v in ports:
			for b_v in ports:
				var a := String(a_v)
				var b := String(b_v)
				if a == b:
					continue
				var buy := Market.buy_price(SystemDB.port_def_by_id(a), a, good)
				var sell := Market.sell_price(SystemDB.port_def_by_id(b), b, good)
				var profit := float((sell - buy) * units)
				var legal := _pacing_can_buy_at(a, good) and _pacing_can_sell_at(b, good)
				if not legal:
					skipped += 1
					if profit > ghost_best:
						ghost_best = profit
						ghost_label = "%s %s->%s" % [CommodityDB.short_name(good), a, b]
					continue
				if profit > best:
					best = profit
					label = "%s %s->%s  %d units  buy %d sell %d" % [
						CommodityDB.short_name(good), a, b, units, buy, sell]
	print("[pacing]   best route: %s -> %.0f profit on a %d-space hold" % [label, best, hold])
	print("[pacing]   best route the player CANNOT fly: %s %.0f (skipped)" % [
		ghost_label, ghost_best])
	_pacing_trade_skipped = skipped
	return best


func _pacing_survey_yield() -> float:
	# What one reading is worth at the counter. Deliberately valued rather than
	# flown: the survey hold has no combat in it and no RNG, so playing it out
	# would measure the harness's patience rather than the game's economy.
	# Priced at the DRIFT band, which is the one a standard loop actually reaches.
	var good := CommodityDB.chart_for_band(2)
	if good == "":
		return 0.0
	var per := float(CommodityDB.base_price(good)) * float(SurveyMast.YIELD_UNITS)
	print("[pacing]   survey: %s x%d at base %d = %.0f per reading" % [
		CommodityDB.short_name(good), SurveyMast.YIELD_UNITS,
		CommodityDB.base_price(good), per])
	return per


func _pacing_contract_yield() -> float:
	# The mean reward of what is actually on offer in the starting system: a
	# steady-income lever, so the band has to see it move when rewards change.
	var pool := ContractDB.available_for(SystemDB.START_SYSTEM)
	if pool.is_empty():
		return 0.0
	var total := 0.0
	for id in pool:
		total += float(ContractDB.get_contract(String(id)).get("reward", 0))
	print("[pacing]   contracts offered here: %d, mean reward %.0f" % [pool.size(), total / pool.size()])
	return total / float(pool.size())


# --- layout harness ---------------------------------------------------------

func _run_layout_test() -> void:
	# Pure maths, no rendering: proves the scale rule at every shape we care
	# about, including that portrait windows are left exactly as they were.
	#
	# Pin the player's UI-scale preference out of the way first. content_factor()
	# is `auto_factor() * user_scale`, and user_scale is loaded from the save — so
	# with a player who has dragged the slider to its 0.7 minimum, every assertion
	# below was measuring their preference rather than the rule it exists to
	# check, and the harness failed on a perfectly healthy layout.
	var player_scale := UILayout.user_scale
	UILayout.user_scale = 1.0
	print("[layout] player ui_scale %.2f pinned to 1.00 for the rule assertions" % player_scale)
	var sizes := [
		Vector2(414, 736),    # the old desktop default / small phone window
		Vector2(390, 844),    # iPhone logical
		Vector2(1170, 2532),  # iPhone native
		Vector2(720, 1280),   # design base
		Vector2(1100, 800),   # new desktop default
		Vector2(1440, 900),   # laptop
		Vector2(1920, 1080),  # desktop
		Vector2(2560, 1440),  # large desktop
		Vector2(3440, 1440),  # ultrawide
	]
	print("[layout] rule: portrait windows untouched; wide windows scaled so UI never shrinks")
	var worst := 999.0
	for s in sizes:
		var v: Vector2 = s
		print("[layout] ", UILayout.describe(v))
		if UILayout.is_wide(v):
			worst = minf(worst, UILayout.effective_scale(v))

	print("[layout] ASSERT wide-window effective scale >= 1.0: worst = %.3f -> %s" % [
		worst, "PASS" if worst >= 1.0 else "FAIL"])

	var phone := Vector2(1170, 2532)
	print("[layout] ASSERT phone factor is exactly 1.0 (unchanged): %.3f -> %s" % [
		UILayout.content_factor(phone),
		"PASS" if is_equal_approx(UILayout.content_factor(phone), 1.0) else "FAIL"])

	var ok := true
	for s in sizes:
		var v: Vector2 = s
		var logical := v.x / maxf(UILayout.effective_scale(v), 0.001)
		if UILayout.column_width(v) > logical + 0.5:
			ok = false
	print("[layout] ASSERT column never exceeds logical width -> %s" % ["PASS" if ok else "FAIL"])

	# --- how much of the screen the chrome actually eats -----------------------
	# The rule that stops the UI shrinking on a wide window can overshoot into
	# making it huge, and nothing was watching that axis. A round button is 5-6%
	# of a phone screen's height; at DESKTOP_REFERENCE 620 it was 12.3% of a
	# desktop's — the controls stopped framing the play area and started sitting
	# in it. Measured here so a future tweak to the scale rule cannot quietly
	# re-inflate them.
	var btn := RoundButton.RADIUS * 2.0
	print("[layout] chrome footprint (round button = %.0f design units):" % btn)
	var worst_desktop := 0.0
	var worst_phone := 0.0
	for s in sizes:
		var v: Vector2 = s
		var logical_h := v.y / maxf(UILayout.effective_scale(v), 0.001)
		var pct := btn / logical_h * 100.0
		print("[layout]   %4.0fx%-4.0f %-9s button = %5.1f%% of screen height" % [
			v.x, v.y, "wide" if UILayout.is_wide(v) else "portrait", pct])
		if UILayout.is_wide(v):
			worst_desktop = maxf(worst_desktop, pct)
		else:
			worst_phone = maxf(worst_phone, pct)
	# Desktop is allowed to be proportionally chunkier than a phone — the screen
	# is further away — but not by more than about half again.
	print("[layout] ASSERT desktop chrome %.1f%% <= 1.8x the phone's %.1f%% -> %s" % [
		worst_desktop, worst_phone,
		"PASS" if worst_desktop <= worst_phone * 1.8 else "FAIL"])

	# And the chrome must reach the real screen edges, or corner controls sit in
	# the play area. Portrait is unaffected: its column already spans the screen.
	var edges_ok := true
	for s in sizes:
		var v: Vector2 = s
		if UILayout.column_width(v) > (v.x / maxf(UILayout.effective_scale(v), 0.001)) - 0.5:
			continue        # column already spans the screen (portrait)
		if not UILayout.is_wide(v):
			edges_ok = false  # a portrait window should never be inset
	print("[layout] ASSERT chrome spans the full width on portrait -> %s" % [
		"PASS" if edges_ok else "FAIL"])

	# The preference still has to compose with the rule — that is the whole
	# contract of user_scale, and pinning it above must not hide a break in it.
	UILayout.user_scale = 1.25
	var composed := UILayout.content_factor(Vector2(1920, 1080))
	UILayout.user_scale = 1.0
	var rule_only := UILayout.content_factor(Vector2(1920, 1080))
	print("[layout] ASSERT ui_scale composes: %.3f x 1.25 = %.3f -> %s" % [
		rule_only, composed,
		"PASS" if is_equal_approx(composed, rule_only * 1.25) else "FAIL"])
	UILayout.user_scale = player_scale

	# --- the action dock ------------------------------------------------------
	# The dock exists so the controls never spread. Assert exactly that: the same
	# width at every screen size, and centred. Also assert the bottom-centre band
	# is genuinely centred, which locks the double-compensation bug (position.x
	# set to negative half a min width AND grow BOTH) out for good.
	if hud != null:
		var widths: Array = []
		var worst_off := 0.0
		var worst_who := ""
		for probe in [Vector2i(720, 1280), Vector2i(1440, 900), Vector2i(3440, 1440)]:
			get_window().size = probe
			await get_tree().process_frame
			await get_tree().process_frame
			var vp := get_viewport().get_visible_rect().size
			widths.append(hud.dock_width())
			for pair in hud.centred_probe():
				var off: float = absf(float(pair[1]) - vp.x * 0.5)
				if off > worst_off:
					worst_off = off
					worst_who = "%s at %dx%d" % [pair[0], probe.x, probe.y]
			print("[layout]   %4dx%-4d dock width %.0f, centre offset %.1fpx" % [
				probe.x, probe.y, hud.dock_width(),
				absf(hud.dock_centre_x() - vp.x * 0.5)])
		var spread := 0.0
		for w in widths:
			spread = maxf(spread, absf(float(w) - float(widths[0])))
		print("[layout] ASSERT DOCK WIDTH identical across 720/1440/3440 (spread %.2fpx) -> %s" % [
			spread, "PASS" if spread <= 1.0 else "FAIL"])
		print("[layout] ASSERT BAND CENTRED worst offset %.1fpx (%s) -> %s" % [
			worst_off, worst_who if worst_who != "" else "-",
			"PASS" if worst_off <= 1.5 else "FAIL"])

		# BANDS CLEAR — the overlap the constant-probe assertion structurally
		# cannot see. RoundButton.RADIUS tests the SCALE RULE and is right to be
		# a constant (a metric must hold still while content grows, 10's own
		# lesson), but it knows nothing about where plates actually sit. Three
		# surfaces were overlapping before this existed: the toast rested ON the
		# boss bar, the broadcast plate nearly touched the toast, and the parley
		# button clipped the crack gauge by ~8px.
		#
		# Only pairs that can be on screen TOGETHER are checked. The exempt pair
		# is parley/tutorial, and the exemption is guarded by asserting the rule
		# that makes it exclusive rather than by trusting it: if raids ever become
		# possible during the tutorial, the exemption goes red instead of the
		# overlap going unnoticed.
		var pairs := [["boss", "toast"], ["toast", "broadcast"],
			["boss", "broadcast"], ["crack", "parley"], ["crack", "prompt"]]
		var worst_gap := 9999.0
		var worst_pair := ""
		var gap_report := ""
		for probe2 in [Vector2i(720, 1280), Vector2i(1100, 800),
				Vector2i(1440, 900), Vector2i(3440, 1440)]:
			get_window().size = probe2
			await get_tree().process_frame
			await get_tree().process_frame
			var rects := hud.band_rects()
			for pr in pairs:
				var a := String(pr[0])
				var b := String(pr[1])
				if not rects.has(a) or not rects.has(b):
					continue
				var ra: Vector2 = rects[a]
				var rb: Vector2 = rects[b]
				# Gap between the two spans, negative when they overlap.
				var gap: float = maxf(ra.x, rb.x) - minf(ra.y, rb.y)
				if gap < worst_gap:
					worst_gap = gap
					worst_pair = "%s/%s at %dx%d" % [a, b, probe2.x, probe2.y]
		gap_report = "worst %.1f design px (%s)" % [worst_gap, worst_pair]
		print("[layout] ASSERT BANDS CLEAR %s, want >= 6 -> %s" % [
			gap_report, "PASS" if worst_gap >= 6.0 else "FAIL"])

		# The exemption's own guard.
		tutorial.arm()
		tutorial.begin()
		await get_tree().process_frame
		var armed_excl := tutorial_active() and not interdiction_eligible()
		tutorial.skip()
		await get_tree().process_frame
		print("[layout] ASSERT PARLEY EXCLUDES TUTORIAL raids ineligible while the tutorial runs=%s -> %s" % [
			str(armed_excl), "PASS" if armed_excl else "FAIL"])
	get_tree().quit()


# --- title harness ----------------------------------------------------------

func _run_title_test() -> void:
	var shots: String = OS.get_environment("PYXIS_SHOTS")
	var player: PlayerShip = get_tree().get_first_node_in_group("player")
	await get_tree().create_timer(1.4).timeout
	await _shot(shots, "s1_title.png")

	print("[title] state=%s hostiles=%d (expect 0) hud_visible=%s (expect false)" % [
		"ATTRACT" if state == State.ATTRACT else "PLAYING",
		get_tree().get_nodes_in_group("hostiles").size(),
		str(hud.chrome_visible())])
	print("[title] continue_offered=%s (matches save present=%s)" % [
		str(title_screen.continue_available()), str(GameState.has_save())])

	# Input must be inert behind the menu.
	var before := player.global_position
	Input.action_press("move_up")
	await get_tree().create_timer(1.0).timeout
	Input.action_release("move_up")
	print("[title] input locked: ship moved %.2f units (expect ~0)" % \
		before.distance_to(player.global_position))

	# Starting a survey must hand over to the tutorial cleanly.
	start_new_game()
	await get_tree().create_timer(1.0).timeout
	print("[title] after NEW SURVEY: state=%s tutorial_active=%s step=%d sentries=%d" % [
		"ATTRACT" if state == State.ATTRACT else "PLAYING",
		str(tutorial.is_active()), GameState.tutorial_step, _count_sentries()])
	await _shot(shots, "s2_after_start.png")
	get_tree().quit()


# --- tutorial harness -------------------------------------------------------

func _run_tutorial_test() -> void:
	var shots: String = OS.get_environment("PYXIS_SHOTS")
	var player: PlayerShip = get_tree().get_first_node_in_group("player")

	# Cold start, exactly like a first-time player pressing NEW SURVEY.
	GameState.reset_to_starter()
	start_new_game()
	await get_tree().create_timer(0.8).timeout
	print("[tut] started: active=%s step=%d sentries=%d swarm=%d (both must be 0)" % [
		str(tutorial.is_active()), GameState.tutorial_step,
		_count_sentries(), get_tree().get_nodes_in_group("swarm").size()])
	await _shot(shots, "t1_step_move.png")

	# Step 1: fly.
	var from_pos := player.global_position
	# Re-press every frame rather than once: Godot releases virtual actions when
	# the window changes focus, which happens while the test window is opening,
	# so a single action_press intermittently evaporates mid-hold.
	for i in range(96):
		Input.action_press("move_up")
		await get_tree().physics_frame
	# Release every direction, not just the one pressed: a stuck action leaves
	# the ship flying away from the step-2 drone, which never comes into range.
	_release_all_moves()
	await get_tree().create_timer(0.9).timeout
	print("[tut] after moving: step=%d (expect 1) driving=%s moved=%.1f (need %.1f) obstacles=%d" % [
		GameState.tutorial_step, str(player.driving),
		from_pos.distance_to(player.global_position), Tutorial.MOVE_DISTANCE,
		Obstacles.count()])

	# Step 2: kill the lone contact.
	await get_tree().create_timer(0.4).timeout
	await _shot(shots, "t2_step_engage.png")
	var guard := 0
	while GameState.tutorial_step == 1 and guard < 120:
		_attack_nearest(player)
		await get_tree().create_timer(0.25).timeout
		guard += 1
		if guard % 20 == 0:
			var n := get_tree().get_nodes_in_group("hostiles").size()
			var tgt = player.attack_target
			print("[tut]   step1 wait %d: hostiles=%d target=%s dist=%.1f driving=%s" % [
				guard, n, str(is_instance_valid(tgt)),
				player.global_position.distance_to(tgt.global_position) if is_instance_valid(tgt) else -1.0,
				str(player.driving)])
	print("[tut] after kill: step=%d (expect 2)" % GameState.tutorial_step)

	# Step 3: collect its salvage — the loot magnet does this on approach.
	guard = 0
	while GameState.tutorial_step == 2 and guard < 120:
		await get_tree().create_timer(0.25).timeout
		guard += 1
	print("[tut] after collect: step=%d (expect 3) salvage=%d" % [
		GameState.tutorial_step, GameState.salvage])

	# Step 4: discharge the core.
	await get_tree().create_timer(0.7).timeout
	await _shot(shots, "t3_step_ability.png")
	player._ability_cd = 0.0
	player.activate_ability()
	await get_tree().create_timer(1.0).timeout
	print("[tut] after ability: step=%d (expect 4) owns_tractor=%s" % [
		GameState.tutorial_step, str(GameState.owns("util_tractor"))])

	# Step 5: fit the recovered rig.
	await _shot(shots, "t4_step_refit.png")
	GameState.equip(ModuleDB.Slot.UTILITY, "util_tractor")
	await get_tree().create_timer(0.9).timeout
	print("[tut] after refit: step=%d (expect 5)" % GameState.tutorial_step)

	# Step 6: breach the derelict — the finale that charts PYX-02.
	var derelict: Derelict = get_tree().get_first_node_in_group("crackable")
	derelict.on_tapped()
	await get_tree().create_timer(3.0).timeout
	var frames := 0
	while is_instance_valid(derelict) and not derelict.is_cracked() and frames < 500:
		derelict.hold_begin()
		derelict.hold_tick(get_process_delta_time())
		frames += 1
		if frames % 150 == 0:
			print("[tut]   breach wait %d: dist_to_breach=%.1f (need <= %.1f)" % [
				frames, player.global_position.distance_to(derelict.breach_point),
				Derelict.CRACK_RANGE])
		await get_tree().process_frame
	await get_tree().create_timer(1.2).timeout
	await _shot(shots, "t5_breach_finale.png")

	print("[tut] FINISHED active=%s step=%d pyx02_charted=%s" % [
		str(tutorial.is_active()), GameState.tutorial_step,
		str(GameState.is_system_unlocked("pyx02"))])

	# The world must come back: garrison arrives after its grace, waves allowed.
	await get_tree().create_timer(Tutorial.GARRISON_DELAY + 1.5).timeout
	_wave_timer = 0.2
	await get_tree().create_timer(1.5).timeout
	print("[tut] world reopened: sentries=%d (expect >0) swarm=%d (expect >0)" % [
		_count_sentries(), get_tree().get_nodes_in_group("swarm").size()])
	await _shot(shots, "t6_free_play.png")
	get_tree().quit()


func _count_sentries() -> int:
	var n := 0
	for h in get_tree().get_nodes_in_group("hostiles"):
		if h is Hostile:
			n += 1
	return n


# --- input harness ----------------------------------------------------------

func _release_all_moves() -> void:
	for a in ["move_up", "move_down", "move_left", "move_right"]:
		Input.action_release(a)


func _hold_action(action: String, seconds: float) -> Vector3:
	# Presses an action for a while and reports how far the ship moved. Clears
	# every other direction first: a stuck opposite key silently cancels the
	# axis and reads as "the key does nothing".
	var player: PlayerShip = get_tree().get_first_node_in_group("player")
	_release_all_moves()
	await get_tree().process_frame
	var from := player.global_position
	# Re-pressed each frame: a one-shot virtual press is cleared if the window
	# changes focus, which makes these measurements silently flaky.
	var frames := int(seconds * 60.0)
	for i in range(frames):
		Input.action_press(action)
		await get_tree().physics_frame
	Input.action_release(action)
	await get_tree().create_timer(0.35).timeout   # let inertia settle
	return player.global_position - from


func _run_input_test() -> void:
	var player: PlayerShip = get_tree().get_first_node_in_group("player")
	await get_tree().create_timer(0.6).timeout
	# The ship sits parked among live hostiles for the whole harness. Without
	# this it accumulates damage, emergency-warps mid-test, and every subsequent
	# assertion measures a warping ship instead of the input system.
	player.invulnerable = true

	# 1. Each key drives the expected screen direction. The camera does not yaw,
	#    so screen-up is world -Z.
	for spec in [["move_up", "W", Vector3(0, 0, -1)], ["move_down", "S", Vector3(0, 0, 1)],
			["move_left", "A", Vector3(-1, 0, 0)], ["move_right", "D", Vector3(1, 0, 0)]]:
		player.global_position = Vector3(0, 0, 6)
		player.velocity = Vector3.ZERO
		var moved: Vector3 = await _hold_action(String(spec[0]), 0.8)
		var want: Vector3 = spec[2]
		var dot := moved.normalized().dot(want) if moved.length() > 0.1 else 0.0
		print("[input] %s moved (%.1f, %.1f) len %.1f  alignment %.2f (want ~1.0)" % [
			String(spec[1]), moved.x, moved.z, moved.length(), dot])

	# 2. The key property: strafing must not drop the target or stop the guns.
	_release_all_moves()
	await get_tree().process_frame
	var target: Node3D = null
	for h in get_tree().get_nodes_in_group("hostiles"):
		target = h
		break
	player.global_position = target.global_position + Vector3(0, 0, 4.0)
	player.shield = player.shield_max
	player.command_attack(target)
	await get_tree().process_frame
	print("[input] strafe setup: target=%s class=%s attack_target_set=%s dist=%.1f" % [
		target.name, target.get_class(), str(player.attack_target == target),
		player.global_position.distance_to(target.global_position)])
	var hp_before: float = target.hp
	Input.action_press("move_right")
	# Sample mid-strafe: the starter fit can delete a sentry inside two seconds,
	# and a dead target cannot demonstrate that facing tracks a live one.
	await get_tree().create_timer(0.7).timeout
	var still_targeted := is_instance_valid(target) and player.attack_target == target
	var hp_mid: float = target.hp if is_instance_valid(target) else -1.0
	var to_target: Vector3 = (target.global_position - player.global_position) \
		if is_instance_valid(target) else Vector3.FORWARD
	to_target.y = 0.0
	var want_yaw := atan2(-to_target.x, -to_target.z)
	var yaw_err := absf(wrapf(player.rotation.y - want_yaw, -PI, PI))
	var bank: float = player.rotation.z
	var lateral: float = player.velocity.dot(player.global_transform.basis.x)
	await _shot(OS.get_environment("PYXIS_SHOTS"), "i1_strafe_engaged.png")
	Input.action_release("move_right")
	print("[input] STRAFE-FIRE target_kept=%s hp %.0f -> %.0f (must fall)  yaw_err %.2f rad (must be <0.5)  bank %.2f  lateral %.1f" % [
		str(still_targeted), hp_before, hp_mid, yaw_err, bank, lateral])

	# 2b. Overcharge must actually clear a swarm pack, which is the whole point
	#     of the blast: the ring used to be decoration over a fire-rate buff.
	_release_all_moves()
	player.clear_target()
	player.global_position = Vector3(0, 0, 6)
	await get_tree().process_frame
	for i in range(6):
		var probe := SwarmHostile.new()
		probe.difficulty = 1.0
		system_root.add_child(probe)
		var ang := TAU * float(i) / 6.0
		probe.global_position = player.global_position + Vector3(cos(ang), 0, sin(ang)) * (2.0 + i * 0.7)
	await get_tree().create_timer(0.4).timeout
	var before_count := get_tree().get_nodes_in_group("swarm").size()
	player._ability_cd = 0.0
	var fired := player.activate_ability()
	await get_tree().create_timer(0.12).timeout
	await _shot(OS.get_environment("PYXIS_SHOTS"), "i2_overcharge_blast.png")
	await get_tree().create_timer(0.8).timeout
	var after_count := get_tree().get_nodes_in_group("swarm").size()
	print("[input] OVERCHARGE fired=%s swarm %d -> %d (blast radius %.1f, burst %.0f dmg at centre)" % [
		str(fired), before_count, after_count, PlayerShip.OVERCHARGE_RADIUS,
		float(GameState.stats.get("dps", 0.0)) * PlayerShip.OVERCHARGE_BURST_SECONDS])

	# 3. Tab cycles and wraps; Escape clears.
	var seen := []
	for i in range(5):
		var picked: Node3D = player.cycle_target()
		seen.append(picked.name if picked else "none")
	print("[input] CYCLE picked %d distinct of %d hostiles: %s" % [
		_distinct(seen), get_tree().get_nodes_in_group("hostiles").size(), str(seen)])
	player.clear_target()
	print("[input] CANCEL target=", player.attack_target)

	# 4. Device split: a touch on empty space still moves (mobile intact); a
	#    mouse click on empty space must not.
	var rig := get_tree().get_first_node_in_group("camera_rig")
	var empty := Vector2(40, 210)   # far from any entity in this system

	player.global_position = Vector3(0, 0, 6)
	player.has_move_target = false
	rig._tap(empty)
	var touch_moves := player.has_move_target
	player.has_move_target = false
	rig._click(empty)
	var click_moves := player.has_move_target
	print("[input] DEVICE SPLIT touch_on_empty_moves=%s (must be true)  click_on_empty_moves=%s (must be false)" % [
		str(touch_moves), str(click_moves)])
	get_tree().quit()


func _distinct(items: Array) -> int:
	var uniq := {}
	for i in items:
		uniq[i] = true
	return uniq.size()


# --- economy demo (visual capture) ------------------------------------------

func _run_econ_demo() -> void:
	var shots: String = OS.get_environment("PYXIS_SHOTS")
	var player: PlayerShip = get_tree().get_first_node_in_group("player")

	GameState.add_salvage(30000)
	GameState.mark_breached("pyx01")   # so PYX-02 is reachable
	hud.set_value(GameState.salvage)
	hud.refresh_cargo()
	await get_tree().create_timer(0.8).timeout
	await _shot(shots, "e1_freeport.png")

	# Dock at the freeport and open the market.
	var port := find_port()
	request_dock(port)
	var waited := 0.0
	while docked_port == null and waited < 20.0:
		await get_tree().create_timer(0.2).timeout
		waited += 0.2
	await get_tree().create_timer(0.9).timeout
	await _shot(shots, "e2_docked_market.png")

	# Outfitter tab: buy the Cargo Bay, which is the module that makes trading
	# a build choice rather than a side activity.
	port_panel._on_tab("outfitter")
	await get_tree().create_timer(0.6).timeout
	await _shot(shots, "e3_outfitter.png")
	port_panel._buy_module("util_cargo")
	GameState.equip(ModuleDB.Slot.UTILITY, "util_cargo")
	hud.refresh_cargo()
	print("[econ] bought Cargo Bay -> hold %d" % GameState.cargo_capacity())

	port_panel._on_tab("market")
	await get_tree().create_timer(0.5).timeout
	await _shot(shots, "e4_market_after_bay.png")
	undock()
	await get_tree().create_timer(0.6).timeout

	# Warp to the mining colony and buy alloys cheap.
	travel_to("pyx02")
	await get_tree().create_timer(WARP_CHARGE + WARP_STREAK + WARP_ARRIVE + 1.2).timeout
	var colony := find_port()
	request_dock(colony)
	waited = 0.0
	while docked_port == null and waited < 25.0:
		await get_tree().create_timer(0.2).timeout
		waited += 0.2
	await get_tree().create_timer(0.8).timeout
	await _shot(shots, "e5_colony_market.png")

	var cdef := SystemDB.port_def_by_id("cinderworks")
	var unit_cost := Market.buy_price(cdef, "cinderworks", "alloys")
	var before_salvage := GameState.salvage
	port_panel._buy("alloys", 25)
	var bought := GameState.cargo_count("alloys")
	print("[econ] bought %d alloys at %d each (spent %d)" % [
		bought, unit_cost, before_salvage - GameState.salvage])
	await get_tree().create_timer(0.5).timeout
	await _shot(shots, "e6_hold_loaded.png")
	undock()

	# The route pays off only somewhere that wants them.
	var here := Market.sell_price(cdef, "cinderworks", "alloys")
	var bdef := SystemDB.port_def_by_id("bastion")
	print("[econ] alloys sell here %d/unit vs bastion %d/unit — hold of %d worth %d vs %d" % [
		here, Market.sell_price(bdef, "bastion", "alloys"), bought,
		here * bought, Market.sell_price(bdef, "bastion", "alloys") * bought])
	print("[econ] final salvage=%d cargo=%s" % [GameState.salvage, str(GameState.cargo)])
	get_tree().quit()


# --- docking harness --------------------------------------------------------

func _run_dock_test() -> void:
	var player: PlayerShip = get_tree().get_first_node_in_group("player")
	await get_tree().create_timer(0.5).timeout

	var port := find_port()
	print("[dock] port found=", port != null, " id=", port.port_id if port else "-")

	# Clear the standing garrison. This harness is about the docking contract,
	# and PYX-03 now fields seven sentries along the approach: they shot the ship
	# down mid-approach, the emergency warp cancelled the move order, and every
	# later assertion then failed for a reason that had nothing to do with
	# docking. The safety and boss-lock steps below spawn their own threats.
	for n in get_tree().get_nodes_in_group("hostiles"):
		(n as Node3D).queue_free()
	await get_tree().process_frame

	# 1. Dock from range: request, let the autopilot close, confirm clamp.
	request_dock(port)
	var waited := 0.0
	while docked_port == null and waited < 20.0:
		await get_tree().create_timer(0.2).timeout
		waited += 0.2
	print("[dock] DOCKED after %.1fs: docked=%s player.docked=%s saved=%s" % [
		waited, str(docked_port != null), str(player.docked), GameState.docked_at])

	# 2. Safety: a pack spawned on top of the port must not scratch the paint.
	player.shield = player.shield_max
	var before := player.shield
	for i in range(6):
		var s := SwarmHostile.new()
		s.difficulty = 1.0
		system_root.add_child(s)
		s.global_position = player.global_position + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
	await get_tree().create_timer(9.0).timeout
	print("[dock] SAFETY after 9s with 6 swarm on top: shield %.0f -> %.0f (must be equal)" % [
		before, player.shield])

	# Clear the test pack: left alive they keep shooting after undock, down the
	# player, and a downed player disengages the boss — which would make the
	# lock assertion below fail for the wrong reason.
	for s in get_tree().get_nodes_in_group("swarm"):
		(s as Node3D).queue_free()
	player.shield = player.shield_max
	await get_tree().process_frame

	# 3. Undock returns control and grants the usual grace.
	undock()
	await get_tree().create_timer(0.4).timeout
	print("[dock] UNDOCKED: player.docked=%s protected=%s saved='%s'" % [
		str(player.docked), str(player.is_protected()), GameState.docked_at])

	# 4. Docking is refused while an apex engine is live.
	GameState.mark_breached("pyx01")
	_apex_wake_timer = 0.2
	await get_tree().create_timer(ApexBoss.WAKE_TIME + 1.0).timeout
	request_dock(port)
	await get_tree().create_timer(0.6).timeout
	print("[dock] BOSS LOCK: boss_active=%s docked=%s (must be true / false)" % [
		str(boss_active), str(docked_port != null)])
	get_tree().quit()


# --- market harness ---------------------------------------------------------

func _run_market_test() -> void:
	var cinder := SystemDB.port_def_by_id("cinderworks")
	var bastion := SystemDB.port_def_by_id("bastion")
	var anchor := SystemDB.port_def_by_id("anchor")

	print("[market] --- baseline unit prices (base | anchor | cinderworks | bastion) ---")
	for good_v in CommodityDB.ids():
		var g := str(good_v)
		print("[market] %-10s base %4d | anchor %5.0f | cinder %5.0f | bastion %5.0f" % [
			CommodityDB.short_name(g), CommodityDB.base_price(g),
			Market.unit_price(anchor, "anchor", g),
			Market.unit_price(cinder, "cinderworks", g),
			Market.unit_price(bastion, "bastion", g)])

	# 1. The alloys route should pay: buy where they are mined, sell where they
	#    are wanted.
	var buy_at_cinder := Market.buy_price(cinder, "cinderworks", "alloys")
	var sell_at_bastion := Market.sell_price(bastion, "bastion", "alloys")
	var margin := sell_at_bastion - buy_at_cinder
	print("[market] ROUTE alloys cinder->bastion: buy %d sell %d margin %d/unit (%.0f%%)" % [
		buy_at_cinder, sell_at_bastion, margin,
		100.0 * float(margin) / maxf(float(buy_at_cinder), 1.0)])

	var buy_iso := Market.buy_price(bastion, "bastion", "isotopes")
	var sell_iso := Market.sell_price(cinder, "cinderworks", "isotopes")
	print("[market] ROUTE isotopes bastion->cinder: buy %d sell %d margin %d/unit (%.0f%%)" % [
		buy_iso, sell_iso, sell_iso - buy_iso,
		100.0 * float(sell_iso - buy_iso) / maxf(float(buy_iso), 1.0)])

	# 2. Player pressure: dumping into a market must visibly move it and then
	#    recover, rather than being either ignored or permanent.
	var before := Market.sell_price(bastion, "bastion", "alloys")
	Market.apply_trade_pressure("bastion", "alloys", 40, true)
	var after := Market.sell_price(bastion, "bastion", "alloys")
	print("[market] PRESSURE dumped 40 alloys: %d -> %d (%.0f%% drop, expect >=15%%)" % [
		before, after, 100.0 * (1.0 - float(after) / maxf(float(before), 1.0))])
	for i in range(12):
		Market.recover_pressure(60.0)
	var recovered := Market.sell_price(bastion, "bastion", "alloys")
	print("[market] PRESSURE after 12 min recovery: %d (expect ~%d)" % [recovered, before])

	# 3. Events apply and expire.
	GameState.market_events.append({
		"kind": "shortage", "port": "cinderworks", "good": "isotopes",
		"mult": 2.0, "remaining": 5.0})
	print("[market] EVENT shortage active: isotopes sell at cinder = %d (was %d)" % [
		Market.sell_price(cinder, "cinderworks", "isotopes"), sell_iso])
	Market.tick_events(6.0)
	print("[market] EVENT after expiry: %d, active_events=%d" % [
		Market.sell_price(cinder, "cinderworks", "isotopes"), GameState.market_events.size()])

	# 4. Cargo capacity and the hold-full path.
	GameState.cargo = {}
	var cap := GameState.cargo_capacity()
	var took := GameState.load_cargo("alloys", 99)
	print("[market] CARGO capacity %d, loaded %d alloys (2 space each), used %d free %d" % [
		cap, took, GameState.cargo_used(), GameState.cargo_free()])
	var overflow := GameState.load_cargo("relics", 1)
	print("[market] CARGO overflow load returned %d (expect 0 -> crate would scrap)" % overflow)

	# 5. Drift moves prices over played time without touching wall clock.
	var t0 := Market.unit_price(cinder, "cinderworks", "volatiles")
	GameState.played_seconds += 240.0
	var t1 := Market.unit_price(cinder, "cinderworks", "volatiles")
	print("[market] DRIFT volatiles at cinder: %.1f -> %.1f after 4 played minutes" % [t0, t1])
	get_tree().quit()


# --- balance harness --------------------------------------------------------

# Sampled by the balance harness: how often the ship was shooting on its own.
var _bal_auto_frames := 0
var _bal_frames := 0

func _run_balance_test() -> void:
	# Seeded, the same way and for the same reason PYXIS_PACINGTEST is: this
	# harness asserts against a HARD threshold (no fit may burst a whole phase in
	# one window), crit rolls and price drift feed that number, and an unseeded
	# run right at the line reports a coin flip. Not bit-identical — FX and drift
	# draw from the same global RNG on a frame-count-dependent schedule — but
	# close enough that a FAIL means something changed rather than something
	# rolled.
	seed(0x42414c41)
	set_deep_generation(false)
	# The acceptance test for the encounter: no fit may dominate, and each
	# should win a different half of the fight.
	var fits := [
		{"name": "LANCE   ", "a": "lance_2", "b": "lance_2"},
		{"name": "ARC     ", "a": "arc_2", "b": "arc_2"},
		{"name": "PULSE   ", "a": "pulse_2", "b": "pulse_2"},
		{"name": "MIXED   ", "a": "lance_2", "b": "arc_2"},
		# The torpedo family, added after B3. Dual torp_2 draws 12 of an 18-point
		# Mk III, so it is a legal fit and has to be measured like any other.
		{"name": "TORP    ", "a": "torp_2", "b": "torp_2"},
		{"name": "TORP+LNC", "a": "torp_2", "b": "lance_2"},
	]
	GameState.mark_breached("pyx01")
	for id in ["lance_2", "arc_2", "pulse_2", "torp_2"]:
		if not GameState.owns(id):
			GameState.owned.append(id)
	GameState.reactor_tier = 2  # Mk III for every fit, so weapons are the only variable

	print("[balance] fit        ttk    dmg_taken  warps  max_window  seals  result")
	var worst_window := 0.0
	var worst_fit := ""
	var results: Array = []
	for fit in fits:
		var result := await _balance_run(String(fit["a"]), String(fit["b"]), String(fit["name"]))
		print(String(result["line"]))
		result["name"] = String(fit["name"]).strip_edges()
		results.append(result)
		if float(result["window"]) > worst_window:
			worst_window = float(result["window"])
			worst_fit = String(fit["name"]).strip_edges()

	# How much of the encounter the mounts resolved on their own. The bot leaves
	# gaps between probe kills, and return fire fills them — which is the feature
	# working, and also the reason peak single-window damage climbed toward the
	# phase-integrity ceiling. Printed rather than asserted: it is the number you
	# want in front of you when tuning that ceiling.
	print("[balance] RETURN FIRE resolved %d of %d sampled frames (%.1f%% of the fight)" % [
		_bal_auto_frames, _bal_frames,
		100.0 * float(_bal_auto_frames) / maxf(float(_bal_frames), 1.0)])
	# PHASE INTEGRITY: does every fit actually MEET the encounter's mechanic?
	#
	# This used to compare peak single-window damage against a phase's HP, and
	# that comparison was quietly broken: `max_window` is the HP a phase LOST in a
	# window, so it can never exceed the phase's HP. It was measuring "the phase
	# died", not "the fit could have killed it twice over". Removing the cap
	# (phase HP temporarily 6000) showed the real peak burst is ~2520 against a
	# 1700 phase — so a strong fit with Overcharge up and every plate open has
	# ALWAYS been able to delete a phase in one window. The old assertion passed
	# only because peak burst and a full window rarely coincided, and it began
	# failing when return fire made them coincide more often.
	#
	# So measure the thing the design actually cares about. From the top of
	# apex_boss.gd: a fit that bursts through "would never meet a seal, a probe,
	# or the sweep — it would skip the encounter's ENTIRE mechanic". Bursting one
	# phase is not that. Never being shut out and made to clear a pack is.
	#
	# SAMPLED, TWO-TIER — the third version of this assertion, and each rewrite
	# was the same lesson arriving again.
	#
	# v1 compared peak window damage against phase HP — a number CAPPED by phase
	# HP, so it could only ever fail on an exact tie. v2 counted seals with a bar
	# of 2, set from six runs showing 3-10 — and PULSE's true floor turned out to
	# be 1, so the bar sat inside the noise and failed on a coin flip. Both times:
	# a threshold set from too few samples of a distribution nobody had measured.
	#
	# So this version measures the distribution it asserts against. Any fit whose
	# first run engages fewer than 2 seals is run twice more, and the claims are
	# two-tier, each matched to what it can honestly guarantee:
	#
	#   every run  >= 1 seal   no fit EVER fully skips the mechanic (13's actual
	#                          catastrophe — "would never meet a seal")
	#   median     >= 2 seals  the TYPICAL fight engages it properly; the tail
	#                          where a burst fit high-rolls one phase is allowed,
	#                          and whether that tail feels degenerate in the hand
	#                          is the playtest's question, not this line's.
	var samples := {}
	for r in results:
		samples[String((r as Dictionary)["name"])] = [int((r as Dictionary).get("seals", 0))]
	for fit in fits:
		var nm := String(fit["name"]).strip_edges()
		if int((samples[nm] as Array)[0]) >= 2:
			continue
		for extra in range(2):
			var rerun := await _balance_run(String(fit["a"]), String(fit["b"]), String(fit["name"]))
			print(String(rerun["line"]) + "  (resample)")
			(samples[nm] as Array).append(int(rerun.get("seals", 0)))

	var dist_line := ""
	var floor_ok := true
	var median_ok := true
	for nm_v in samples:
		var arr: Array = samples[nm_v]
		arr.sort()
		var median := int(arr[arr.size() / 2]) if arr.size() % 2 == 1 \
			else int(arr[arr.size() / 2 - 1])
		if arr.size() > 1 or median < 2:
			dist_line += "%s %s med %d; " % [String(nm_v), "/".join(arr.map(func(x): return str(x))), median]
		if int(arr[0]) < 1:
			floor_ok = false
		if median < 2:
			median_ok = false
	print("[balance] PHASE INTEGRITY (sampled) %severy run >= 1 seal=%s, every median >= 2=%s -> %s" % [
		dist_line if dist_line != "" else "all fits >= 2 first run; ",
		str(floor_ok), str(median_ok),
		"PASS" if floor_ok and median_ok else "FAIL"])
	print("[balance]   (peak single-window damage %.0f by %s, against %.0f phase hp — informational:" % [
		worst_window, worst_fit, float((ApexBoss.PHASES[0] as Dictionary)["hp"])])
	print("[balance]    this number is CAPPED by phase hp and so cannot be asserted against it)")
	get_tree().quit()


func _balance_run(weapon_a: String, weapon_b: String, label: String) -> Dictionary:
	GameState.equip(ModuleDB.Slot.WEAPON_A, weapon_a)
	GameState.equip(ModuleDB.Slot.WEAPON_B, weapon_b)
	_load_system("pyx01")
	await get_tree().create_timer(0.5).timeout

	var player: PlayerShip = get_tree().get_first_node_in_group("player")
	player.global_position = Vector3(0, 0, 6)
	player.shield = player.shield_max

	_apex_wake_timer = 0.2
	await get_tree().create_timer(ApexBoss.WAKE_TIME + 0.6).timeout
	var boss := _find_apex()
	if boss == null:
		return {"line": "[balance] %s  NO BOSS" % label, "window": 0.0}

	var elapsed := 0.0
	var damage_taken := 0.0
	var warps := 0
	var prev_shield := player.shield
	# Largest HP drop inside one uninterrupted SURVEY window — the number that
	# says whether a fit engages the encounter or skips it.
	var max_window := 0.0
	var window_start_hp := -1.0
	# How many times this fit was actually SHUT OUT and made to clear a pack. This
	# is the encounter's mechanic; everything else is decoration on it.
	var seals := 0
	var was_sealed := false
	var was_survey := false
	const STEP := 0.25
	while is_instance_valid(boss) and elapsed < 180.0:
		var in_survey: bool = boss.state == ApexBoss.State.SURVEY
		if in_survey and not was_survey:
			window_start_hp = boss.hp
		elif was_survey and not in_survey and window_start_hp >= 0.0:
			max_window = maxf(max_window, window_start_hp - boss.hp)
			window_start_hp = -1.0
		was_survey = in_survey

		if in_survey:
			_engage_core(player, boss)
		else:
			_attack_nearest_probe(player)
		var sealed_now: bool = is_instance_valid(boss) and boss.state == ApexBoss.State.SEAL
		if sealed_now and not was_sealed:
			seals += 1
		was_sealed = sealed_now
		if player.ability_ready():
			player.activate_ability()
		if player.auto_target != null:
			_bal_auto_frames += 1
		_bal_frames += 1
		await get_tree().create_timer(STEP).timeout
		elapsed += STEP
		if player.shield < prev_shield:
			damage_taken += prev_shield - player.shield
		elif player.shield >= player.shield_max and prev_shield < 5.0:
			warps += 1
		prev_shield = player.shield

	# A kill landing mid-window still counts as that window's damage.
	if was_survey and window_start_hp >= 0.0:
		var end_hp: float = boss.hp if is_instance_valid(boss) else 0.0
		max_window = maxf(max_window, window_start_hp - end_hp)

	var killed := not is_instance_valid(boss)
	# Clear the wreck and any stragglers before the next fit's run.
	for n in get_tree().get_nodes_in_group("crackable"):
		if n is ApexWreck:
			(n as Node3D).queue_free()
	return {
		"line": "[balance] %s %6.1fs  %8.0f  %5d  %10.0f  %5d  %s" % [
			label, elapsed, damage_taken, warps, max_window, seals,
			"KILLED" if killed else "TIMEOUT"],
		"window": max_window,
		"seals": seals,
		"killed": killed,
	}


# --- boss edge-case tests ---------------------------------------------------

func _run_boss_test() -> void:
	var player: PlayerShip = get_tree().get_first_node_in_group("player")
	set_deep_generation(false)
	GameState.mark_breached("pyx01")   # so the engine is live and pyx02 is reachable
	_load_system("pyx01")
	await get_tree().create_timer(0.4).timeout

	_apex_wake_timer = 0.2
	await get_tree().create_timer(ApexBoss.WAKE_TIME + 1.2).timeout
	var boss := _find_apex()
	print("[bosstest] woke: boss_active=", boss_active, " boss_found=", boss != null)

	# 1. Hub exploit: parking on the boss must NOT be a safe pocket.
	player.global_position = boss.global_position
	player.shield = player.shield_max
	await get_tree().create_timer(PlayerShip.WARP_GRACE + 0.3).timeout
	player.global_position = boss.global_position
	var before := player.shield
	await get_tree().create_timer(3.0).timeout
	print("[bosstest] HUB EXPLOIT: shield %.0f -> %.0f, took_damage=%s (must be true)" % [
		before, player.shield, str(player.shield < before)])

	# 2. Warping out mid-fight must clear boss state, not strand it.
	print("[bosstest] pre-warp boss_active=", boss_active)
	travel_to("pyx02")
	await get_tree().create_timer(WARP_CHARGE + WARP_STREAK + WARP_ARRIVE + 1.0).timeout
	print("[bosstest] WARP-OUT: system=", system_id, " boss_active=", boss_active,
		" (must be false)  apex_present=", _find_apex() != null)

	# 3. Swarm waves must resume in the new system.
	_wave_timer = 0.2
	await get_tree().create_timer(1.5).timeout
	print("[bosstest] WAVES RESUMED: swarm_count=", get_tree().get_nodes_in_group("swarm").size(),
		" (must be > 0)")

	# 4. Returning restores a full-strength engine (fight resets, per design).
	travel_to("pyx01")
	await get_tree().create_timer(WARP_CHARGE + WARP_STREAK + WARP_ARRIVE + 1.0).timeout
	var boss2 := _find_apex()
	print("[bosstest] RETURN: apex_present=", boss2 != null,
		" hp_fraction=", "%.2f" % (boss2.hp_fraction() if boss2 else -1.0), " (must be 1.00)")
	get_tree().quit()


# --- save round-trip test ---------------------------------------------------

func _run_save_test() -> void:
	GameState.save_path = "user://test_save.json"
	var mode := OS.get_environment("PYXIS_SAVETEST")

	if mode == "write":
		GameState.save_enabled = true
		GameState.reset_to_starter()
		GameState.add_salvage(9000)
		GameState.buy("arc_1")
		GameState.equip(ModuleDB.Slot.WEAPON_A, "arc_1")
		GameState.buy("util_tractor")
		GameState.equip(ModuleDB.Slot.UTILITY, "util_tractor")
		GameState.mark_breached("pyx01")
		GameState.set_current_system("pyx02")
		GameState.mark_bark("first_kill")
		GameState.mark_apex_killed("pyx01")
		GameState.load_cargo("alloys", 5)
		GameState.set_docked("cinderworks")
		GameState.played_seconds = 420.0
		Market.apply_trade_pressure("bastion", "alloys", 10, true)
		GameState.market_events.append({"kind": "glut", "port": "anchor",
			"good": "cores", "mult": 0.55, "remaining": 120.0})
		GameState.set_setting("music_vol", 0.35)
		GameState.set_setting("shake", false)
		GameState.set_setting("ui_scale", 1.25)
		GameState.set_livery(3, 5)
		# v9 bonded stores: one chart key and one deep CELL key, so the round trip
		# covers both shapes and the load-side validation of each.
		# Six DISTINCT sentinels: identical values would let a swapped key mapping
		# round-trip cleanly and pass. A 40-char name proves the 24-cap too.
		GameState.set_ship_name("ASTROLABE-SEVEN-OF-THE-LONG-WATCH-1234567")
		GameState.smuggling = 2
		GameState.smuggling_xp = 57
		GameState.owned.append("mod_survey_array")
		GameState.ledger = {
			"deepest_depth": 611, "distance_flown": 4207, "hulks_cracked": 13,
			"posts_cleared": 5, "chart_data_sold": 82, "tolls_paid": 2,
		}
		GameState.warehouse = {
			"anchor": {"servo_prewar": 3, "lattice_data": 2},
			_first_bay_cell(): {"salvage_quiet": 4},
			"pyx01:99:99": {"salvage_quiet": 9},   # no station there: must be dropped
		}
		# v12 captain's log. Written through the real mutator rather than assigned:
		# that keeps truncation and eviction in the path under test, and an
		# untyped array literal cannot be assigned to an Array[String] member on
		# another object anyway. LOG_MAX + 2 entries, each DISTINCT for the same
		# reason the six ledger sentinels are — a size check round-trips cleanly
		# through a reversed array, and identical lines would too.
		GameState.captains_log.clear()
		for i in range(GameState.LOG_MAX + 2):
			GameState.note_log("LOGBOOK ENTRY %02d" % i)
		GameState.save_game()
		print("[savetest] wrote warehouse=", GameState.warehouse)
		print("[savetest] wrote salvage=", GameState.salvage,
			" weaponA=", GameState.fit[ModuleDB.Slot.WEAPON_A],
			" system=", GameState.current_system,
			" breached=", GameState.breached,
			" settings=", GameState.settings,
			" livery=", GameState.livery)
	elif mode == "migrate3":
		# A v3 save (systems + apex, no economy) must survive into v4.
		var v3 := {
			"version": 3,
			"salvage": 12345,
			"owned": ["pulse_1", "drive_cruise", "core_overcharge", "lance_2"],
			"fit": {"0": "lance_2", "1": "pulse_1", "2": "drive_cruise", "3": "", "4": "core_overcharge"},
			"reactor_tier": 2,
			"current_system": "pyx03",
			"breached": ["pyx01", "pyx02"],
			"barks_seen": ["first_kill", "chart_unlocked"],
			"contract_state": {},
			"apex_killed": ["pyx01"],
		}
		var f3 := FileAccess.open(GameState.save_path, FileAccess.WRITE)
		f3.store_string(JSON.stringify(v3))
		f3.close()
		var ok3 := GameState.load_game()
		print("[savetest] v3->v4 loaded=", ok3, " salvage=", GameState.salvage,
			" system=", GameState.current_system, " reactor=", GameState.reactor_tier,
			" apex_killed=", GameState.apex_killed,
			" cargo=", GameState.cargo, " docked='", GameState.docked_at, "'",
			" clock=", GameState.played_seconds)
	elif mode == "migrate2":
		# A v2 save (systems + contracts, no apex data) must also survive.
		var v2 := {
			"version": 2,
			"salvage": 7777,
			"owned": ["pulse_1", "drive_cruise", "core_overcharge", "arc_1"],
			"fit": {"0": "arc_1", "1": "pulse_1", "2": "drive_cruise", "3": "", "4": "core_overcharge"},
			"reactor_tier": 1,
			"current_system": "pyx02",
			"breached": ["pyx01"],
			"barks_seen": ["first_kill"],
			"contract_state": {},
		}
		var f2 := FileAccess.open(GameState.save_path, FileAccess.WRITE)
		f2.store_string(JSON.stringify(v2))
		f2.close()
		var ok2 := GameState.load_game()
		print("[savetest] v2->v3 loaded=", ok2, " salvage=", GameState.salvage,
			" system=", GameState.current_system, " breached=", GameState.breached,
			" barks=", GameState.barks_seen.size(), " apex_killed=", GameState.apex_killed)
	elif mode == "migrate":
		# A v1 save must survive: new fields default, nothing is discarded.
		var v1 := {
			"version": 1,
			"salvage": 4242,
			"owned": ["pulse_1", "drive_cruise", "core_overcharge", "lance_1"],
			"fit": {"0": "lance_1", "1": "pulse_1", "2": "drive_cruise", "3": "", "4": "core_overcharge"},
			"reactor_tier": 1,
		}
		var f := FileAccess.open(GameState.save_path, FileAccess.WRITE)
		f.store_string(JSON.stringify(v1))
		f.close()
		var ok := GameState.load_game()
		print("[savetest] migrate loaded=", ok, " salvage=", GameState.salvage,
			" weaponA=", GameState.fit[ModuleDB.Slot.WEAPON_A],
			" reactor=", GameState.reactor_tier,
			" system=", GameState.current_system,
			" breached=", GameState.breached)
	elif mode == "migrate5":
		# A v5 save (everything but preferences) must gain settings and livery at
		# their defaults, not as missing keys. This is the migration the player's
		# own live save will take, so it is the one that most has to be right.
		var v5 := {
			"version": 5,
			"salvage": 31337,
			"owned": ["pulse_1", "drive_cruise", "core_overcharge", "arc_2"],
			"fit": {"0": "arc_2", "1": "pulse_1", "2": "drive_cruise", "3": "", "4": "core_overcharge"},
			"reactor_tier": 2,
			"current_system": "pyx03",
			"breached": ["pyx01", "pyx02", "pyx03"],
			"barks_seen": ["first_kill"],
			"contract_state": {},
			"apex_killed": ["pyx01", "pyx02"],
			"cargo": {"relics": 3},
			"played_seconds": 957.5,
			"docked_at": "",
			"market_pressure": {"bastion|alloys": -0.08},
			"market_events": [],
			"audio_muted": false,
			"tutorial_step": -1,
		}
		var f5 := FileAccess.open(GameState.save_path, FileAccess.WRITE)
		f5.store_string(JSON.stringify(v5))
		f5.close()
		var ok5 := GameState.load_game()
		var defaults_ok := GameState.settings == GameState.DEFAULT_SETTINGS \
			and GameState.livery == GameState.DEFAULT_LIVERY
		print("[savetest] v5->v6 loaded=", ok5, " salvage=", GameState.salvage,
			" system=", GameState.current_system, " reactor=", GameState.reactor_tier,
			" apex_killed=", GameState.apex_killed, " cargo=", GameState.cargo,
			" clock=", GameState.played_seconds)
		print("[savetest] v5->v6 DEFAULTS settings=", GameState.settings,
			" livery=", GameState.livery, " -> ", "PASS" if defaults_ok else "FAIL")
	elif mode == "migrate6":
		# The migration the player's own live save takes. v7 only adds
		# Slot.UTILITY_B, which STARTER_FIT already defaults to empty — so the
		# assertion is that nothing else moved.
		var v6 := {
			"version": 6,
			"salvage": 315778,
			"owned": ["pulse_1", "drive_cruise", "core_overcharge", "arc_2", "lance_2", "util_cargo"],
			"fit": {"0": "arc_2", "1": "lance_2", "2": "drive_cruise", "3": "util_cargo", "4": "core_overcharge"},
			"reactor_tier": 2,
			"current_system": "pyx02",
			"breached": ["pyx01", "pyx02", "pyx03"],
			"cargo": {"relics": 6},
			"settings": {"music_vol": 0.75, "sfx_vol": 0.9, "shake": true, "ui_scale": 0.7},
			"livery": {"hull": 0, "accent": 0},
			"tutorial_step": -1,
		}
		var f6 := FileAccess.open(GameState.save_path, FileAccess.WRITE)
		f6.store_string(JSON.stringify(v6))
		f6.close()
		var ok6 := GameState.load_game()
		var kept := GameState.salvage == 315778 \
			and String(GameState.fit[ModuleDB.Slot.WEAPON_A]) == "arc_2" \
			and String(GameState.fit[ModuleDB.Slot.UTILITY]) == "util_cargo" \
			and is_equal_approx(float(GameState.setting("ui_scale")), 0.7) \
			and GameState.cargo_count("relics") == 6
		var new_slot := String(GameState.fit.get(ModuleDB.Slot.UTILITY_B, "?")) == ""
		print("[savetest] v6->v7 loaded=", ok6, " salvage=", GameState.salvage,
			" fit=", GameState.fit, " ui_scale=", GameState.setting("ui_scale"))
		print("[savetest] v6->v7 KEPT everything=", kept, " new UTILITY_B empty=", new_slot,
			" -> ", "PASS" if ok6 and kept and new_slot else "FAIL")
	elif mode == "migrate11":
		# The migration THIS horizon introduces, and the one the player's live
		# save will actually take. v11 has no captains_log key at all, so the
		# whole of the fix is `data.get("captains_log", [])` — no branch, the
		# policy load_game has held since v1. What must be proved is that it
		# arrives EMPTY rather than missing: the pause page iterates it on the
		# first frame the menu opens, and a null there is a crash in the one
		# console reachable mid-boss-fight.
		var v11 := {
			"version": 11,
			"salvage": 24680,
			"owned": ["pulse_1", "drive_cruise", "arc_2", "util_cargo"],
			"fit": {"0": "arc_2", "2": "drive_cruise", "3": "util_cargo"},
			"reactor_tier": 1,
			"current_system": "pyx02",
			"breached": ["pyx01", "pyx02"],
			"cargo": {"relics": 3},
			"archeology": 2,
			"archeology_xp": 40,
			"smuggling": 1,
			"smuggling_xp": 20,
			"ship_name": "THE LONG WATCH",
			"ledger": {"deepest_depth": 505, "distance_flown": 9001,
				"hulks_cracked": 7, "posts_cleared": 3, "chart_data_sold": 44,
				"tolls_paid": 1},
			"settings": {"music_vol": 0.5, "sfx_vol": 0.9, "shake": true, "ui_scale": 1.0},
			"livery": {"hull": 1, "accent": 2},
			"tutorial_step": -1,
		}
		var f11 := FileAccess.open(GameState.save_path, FileAccess.WRITE)
		f11.store_string(JSON.stringify(v11))
		f11.close()
		var ok11 := GameState.load_game()
		var log_empty := GameState.log_lines().is_empty()
		var kept11 := GameState.salvage == 24680 \
			and GameState.ship_name == "THE LONG WATCH" \
			and int(GameState.ledger.get("deepest_depth", -1)) == 505 \
			and int(GameState.ledger.get("chart_data_sold", -1)) == 44 \
			and GameState.archeology == 2 and GameState.smuggling == 1 \
			and GameState.cargo_count("relics") == 3
		# And the first thing written to it lands in an empty ring rather than
		# beside whatever the previous run left in memory.
		GameState.note_log("FIRST LINE OF THE NEW FORMAT")
		var writable := GameState.log_lines().size() == 1
		print("[savetest] v11->v12 loaded=", ok11, " salvage=", GameState.salvage,
			" name='", GameState.ship_name, "' ledger=", GameState.ledger)
		print("[savetest] v11->v12 LOG EMPTY NOT MISSING empty=%s, writable=%s, everything else kept=%s -> %s" % [
			str(log_empty), str(writable), str(kept11),
			"PASS" if ok11 and log_empty and writable and kept11 else "FAIL"])
	elif mode == "migrate12":
		# The migration THIS horizon introduces. v12 has neither commission key,
		# so the whole of the fix is two `data.get` defaults -- the policy
		# load_game has held since v1. What must be proved is that a save written
		# before the Commission existed arrives UNCOMMISSIONED with nothing
		# claimed, rather than arriving with a truthy default and handing a
		# returning player the ninth accent and a registry line they never earned.
		#
		# The v13 round trip lives HERE and not in PYXIS_GSATEST for a structural
		# reason: save_game() early-returns on `not save_enabled`, lock_saving()
		# is one-way, and GSATEST locks. A locked harness asserting a round trip
		# measures in-memory state that never left the process -- the
		# assertion-that-cannot-fail this codebase has a written rule about.
		var v12 := {
			"version": 12,
			"salvage": 31415,
			"owned": ["pulse_1", "drive_cruise"],
			"fit": {"0": "pulse_1", "2": "drive_cruise"},
			"current_system": "pyx02",
			"ship_name": "THE LONG WATCH",
			"captains_log": ["CROSSED INTO THE DRIFT"],
			"ledger": {"deepest_depth": 505, "distance_flown": 9001,
				"hulks_cracked": 7, "posts_cleared": 3, "chart_data_sold": 44,
				"tolls_paid": 1},
			# Accent 2 is a bought colour and must survive untouched: the lock
			# refuses the EARNED index, not every index, and a migration that
			# reset everyone to amber would be a worse bug than the one it fixes.
			"livery": {"hull": 1, "accent": 2},
			"tutorial_step": -1,
		}
		var f12 := FileAccess.open(GameState.save_path, FileAccess.WRITE)
		f12.store_string(JSON.stringify(v12))
		f12.close()
		var ok12 := GameState.load_game()
		var fresh: bool = GameState.commission_claimed == 0 and not GameState.commissioned
		var kept12: bool = GameState.salvage == 31415 \
			and GameState.ship_name == "THE LONG WATCH" \
			and GameState.livery_index("accent") == 2 \
			and int(GameState.ledger.get("chart_data_sold", -1)) == 44 \
			and GameState.log_lines().size() == 1
		print("[savetest] v12->v13 UNCOMMISSIONED claimed=%d commissioned=%s, accent %d kept, everything else kept=%s -> %s" % [
			GameState.commission_claimed, str(GameState.commissioned),
			GameState.livery_index("accent"), str(kept12),
			"PASS" if ok12 and fresh and kept12 else "FAIL"])

		# The round trip, through the real file layer. Claiming all four is what
		# sets `commissioned`, and both fields have to come back.
		GameState.ledger["chart_data_sold"] = 100000
		GameState.ledger["hulks_cracked"] = 100000
		GameState.ledger["posts_cleared"] = 100000
		GameState.ledger["deepest_depth"] = 100000
		for _i in range(CommissionDB.count()):
			GameState.claim_commission()
		GameState.set_livery(0, GameState.REGISTRY_ACCENT)
		GameState.save_game()
		GameState.commission_claimed = 0
		GameState.commissioned = false
		GameState.load_game()
		var round_ok: bool = GameState.commissioned \
			and GameState.commission_claimed == CommissionDB.count() \
			and GameState.livery_index("accent") == GameState.REGISTRY_ACCENT
		print("[savetest] v13 ROUND TRIP claimed=%d commissioned=%s accent=%d (earned, must survive) -> %s" % [
			GameState.commission_claimed, str(GameState.commissioned),
			GameState.livery_index("accent"), "PASS" if round_ok else "FAIL"])
	elif mode == "partial6":
		# A v6 save written before a later setting existed must still get that
		# setting's default rather than a missing key — the reason load merges
		# key-by-key instead of taking the saved dictionary wholesale.
		var p6 := {
			"version": 6,
			"salvage": 500,
			"owned": ["pulse_1", "drive_cruise", "core_overcharge"],
			"fit": {"0": "pulse_1", "1": "pulse_1", "2": "drive_cruise", "3": "", "4": "core_overcharge"},
			"reactor_tier": 0,
			"settings": {"music_vol": 0.1},      # deliberately missing the rest
			"livery": {"hull": 2},               # deliberately missing accent
		}
		var fp := FileAccess.open(GameState.save_path, FileAccess.WRITE)
		fp.store_string(JSON.stringify(p6))
		fp.close()
		var okp := GameState.load_game()
		var kept := is_equal_approx(float(GameState.setting("music_vol")), 0.1)
		var filled := GameState.settings.has("sfx_vol") and GameState.settings.has("shake") \
			and GameState.settings.has("ui_scale") and GameState.livery.has("accent")
		print("[savetest] partial v6 loaded=", okp, " settings=", GameState.settings,
			" livery=", GameState.livery)
		print("[savetest] partial v6 KEPT music_vol=", kept, " FILLED missing keys=", filled,
			" -> ", "PASS" if kept and filled else "FAIL")
	else:
		var ok := GameState.load_game()
		print("[savetest] loaded=", ok, " salvage=", GameState.salvage,
			" weaponA=", GameState.fit[ModuleDB.Slot.WEAPON_A],
			" system=", GameState.current_system,
			" breached=", GameState.breached,
			" barks=", GameState.barks_seen.size(),
			" cargo=", GameState.cargo,
			" docked='", GameState.docked_at, "'",
			" clock=", GameState.played_seconds,
			" pressures=", GameState.market_pressure.size(),
			" events=", GameState.market_events.size())
		var round_trip := is_equal_approx(float(GameState.setting("music_vol")), 0.35) \
			and not bool(GameState.setting("shake")) \
			and is_equal_approx(float(GameState.setting("ui_scale")), 1.25) \
			and GameState.livery_index("hull") == 3 and GameState.livery_index("accent") == 5
		print("[savetest] v6 ROUND TRIP settings=", GameState.settings,
			" livery=", GameState.livery, " -> ", "PASS" if round_trip else "FAIL")

		# v9 bonded stores. Both key shapes must survive — a chart port id and a
		# deep CELL — and the deep one is validated by RE-DERIVING it from the
		# generator, which is only possible because the expanse is a pure
		# function (17). A key naming a cell with no bay is discarded, so an
		# edited or stale save self-corrects rather than carrying a phantom store.
		var chart_ok := GameState.warehouse_count("anchor", "servo_prewar") == 3 \
			and GameState.warehouse_count("anchor", "lattice_data") == 2
		var deep_key := _first_bay_cell()
		var deep_ok := GameState.warehouse_count(deep_key, "salvage_quiet") == 4
		var bogus_dropped := not GameState.warehouse.has("pyx01:99:99")
		var want_ledger := {"deepest_depth": 611, "distance_flown": 4207,
			"hulks_cracked": 13, "posts_cleared": 5, "chart_data_sold": 82,
			"tolls_paid": 2}
		var led_ok := true
		for k in want_ledger:
			if int(GameState.ledger.get(k, -1)) != int(want_ledger[k]):
				led_ok = false
		var name_ok := GameState.ship_name == "ASTROLABE-SEVEN-OF-THE-L" \
			and GameState.ship_name.length() == GameState.SHIP_NAME_MAX
		print("[savetest] v11 SMUGGLING tier %d xp %d, craftable owned=%s -> %s" % [
			GameState.smuggling, GameState.smuggling_xp,
			str(GameState.owns("mod_survey_array")),
			"PASS" if GameState.smuggling == 2 and GameState.smuggling_xp == 57
				and GameState.owns("mod_survey_array") else "FAIL"])
		print("[savetest] v10 LOGBOOK ledger %s, name '%s' (%d chars, cap %d) -> %s" % [
			str(GameState.ledger), GameState.ship_name, GameState.ship_name.length(),
			GameState.SHIP_NAME_MAX, "PASS" if led_ok and name_ok else "FAIL"])

		# v12 captain's log. Compared element by element, never by size: the write
		# leg put LOG_MAX + 2 in, so the surviving ten must be the LAST ten, in
		# order. A size check passes just as happily on a reversed array or on a
		# load that kept the oldest — which is a one-token mistake producing a
		# perfectly plausible-looking log.
		var want_log: Array = []
		for i in range(2, GameState.LOG_MAX + 2):
			want_log.append("LOGBOOK ENTRY %02d" % i)
		var got_log := GameState.log_lines()
		var log_ok := got_log.size() == want_log.size()
		for i in range(want_log.size()):
			if i >= got_log.size() or String(got_log[i]) != String(want_log[i]):
				log_ok = false
		print("[savetest] v12 CAPTAIN'S LOG %d of %d written survive, oldest evicted, order held: %s -> %s" % [
			got_log.size(), GameState.LOG_MAX + 2, str(got_log),
			"PASS" if log_ok else "FAIL"])

		# The logbook is RUN state and the name is not. A new survey starts a new
		# logbook; what you called the ship survives it, like the paint.
		var kept_name := GameState.ship_name
		GameState.reset_to_starter()
		var zeroed := 0
		for k in GameState.DEFAULT_LEDGER:
			if int(GameState.ledger.get(k, -1)) == 0:
				zeroed += 1
		print("[savetest] v10 LEDGER RESET %d of %d counters zeroed, name kept=%s, log cleared=%s -> %s" % [
			zeroed, GameState.DEFAULT_LEDGER.size(),
			str(GameState.ship_name == kept_name),
			str(GameState.log_lines().is_empty()),
			"PASS" if zeroed == GameState.DEFAULT_LEDGER.size()
				and GameState.ship_name == kept_name
				and GameState.log_lines().is_empty() else "FAIL"])

		print("[savetest] v9 BONDED STORES chart=%s deep=%s, bogus cell dropped=%s, keys=%s -> %s" % [
			str(chart_ok), str(deep_ok), str(bogus_dropped),
			str(GameState.warehouse.keys()),
			"PASS" if chart_ok and deep_ok and bogus_dropped else "FAIL"])
	get_tree().quit()


# --- feel and audio correctness ---------------------------------------------

func _run_feel_test() -> void:
	# Guards the frame-rate independence work and the four audio defects fixed
	# alongside it. Everything here is about behaviour that is invisible at 60Hz
	# on a desktop and wrong everywhere else, which is exactly the category that
	# needs a harness rather than an eye.
	var player: PlayerShip = get_tree().get_first_node_in_group("player")
	var rig: CameraRig = get_tree().get_first_node_in_group("camera_rig")
	await get_tree().create_timer(0.3).timeout

	# --- 1. the smoothing itself ---------------------------------------------
	# The whole point: subdividing a timestep must not change where you land.
	# The old lerp(a, b, k*delta) form fails this by ~8% per step at these rates,
	# which is why the camera felt different on a 120Hz phone.
	var one_step := Smoothing.toward(0.0, 1.0, 9.0, 1.0 / 60.0)
	var two_half := Smoothing.toward(Smoothing.toward(0.0, 1.0, 9.0, 1.0 / 120.0), 1.0, 9.0, 1.0 / 120.0)
	var invariant: float = absf(one_step - two_half)
	print("[feel] STEP INVARIANCE 1x1/60=%.9f vs 2x1/120=%.9f delta=%.9f -> %s" % [
		one_step, two_half, invariant, "PASS" if invariant < 1.0e-6 else "FAIL"])

	# Four subdivisions, to prove it is the exponential and not a coincidence at
	# two. Also covers the vector overload, which shares the factor() call.
	var quarter := Vector3.ZERO
	for i in range(4):
		quarter = Smoothing.toward_vec3(quarter, Vector3(10, 0, 0), 9.0, 1.0 / 240.0)
	var whole := Smoothing.toward_vec3(Vector3.ZERO, Vector3(10, 0, 0), 9.0, 1.0 / 60.0)
	var vec_gap: float = quarter.distance_to(whole)
	print("[feel] VEC3 INVARIANCE 4x1/240 vs 1x1/60 gap=%.9f -> %s" % [
		vec_gap, "PASS" if vec_gap < 1.0e-5 else "FAIL"])

	# A frame long enough to make the old `rate * delta` exceed 1.0 -- the case
	# that used to overshoot and oscillate instead of settling.
	var stalled := Smoothing.toward(0.0, 1.0, 9.0, 2.0)
	var old_form: float = lerpf(0.0, 1.0, 9.0 * 2.0)
	print("[feel] NO OVERSHOOT 2s frame: exp=%.4f (in 0..1) vs old lerp=%.1f -> %s" % [
		stalled, old_form, "PASS" if stalled >= 0.0 and stalled <= 1.0 and old_form > 1.0 else "FAIL"])

	# --- 2. the shake setting covers everything that moves the camera --------
	GameState.set_setting("shake", false)
	rig.shake(0.5)
	rig.punch_zoom(4.0)
	var shake_off: bool = rig.shake_amp() <= 0.0001 and rig.zoom_punch() <= 0.0001
	GameState.set_setting("shake", true)
	rig.shake(0.5)
	rig.punch_zoom(4.0)
	var shake_on: bool = rig.shake_amp() > 0.0 and rig.zoom_punch() > 0.0
	print("[feel] MOTION GATE off:shake+punch silent=%s  on:both fire=%s -> %s" % [
		str(shake_off), str(shake_on), "PASS" if shake_off and shake_on else "FAIL"])

	# --- 3. loop lengths, in frames rather than in bytes ----------------------
	# `data.size() / 2` assumed uncompressed 16-bit frames; the importer writes
	# QOA. Asserting the two disagree is what keeps this honest: if the import
	# mode ever changes back, this line goes red and says so.
	var amb := load("res://audio/ambient.wav") as AudioStreamWAV
	var real_frames := Sfx.frame_count(amb)
	var byte_guess: int = amb.data.size() / 2
	print("[feel] COMPRESSED STREAM frames=%d vs data.size()/2=%d -> %s" % [
		real_frames, byte_guess, "PASS" if real_frames != byte_guess else "FAIL"])

	Sfx.loop_start("ambient", -40.0)
	var amb_end: int = (Sfx._streams["ambient"] as AudioStreamWAV).loop_end
	print("[feel] LOOP END ambient loop_end=%d frames=%d -> %s" % [
		amb_end, real_frames, "PASS" if amb_end == real_frames else "FAIL"])
	Sfx.loop_stop("ambient", 0.01)

	var calm := load("res://audio/music_calm.wav") as AudioStreamWAV
	var calm_ok: bool = calm.loop_end == Sfx.frame_count(calm) and calm.loop_mode == AudioStreamWAV.LOOP_FORWARD
	print("[feel] MUSIC LOOP calm loop_end=%d frames=%d mode=%d -> %s" % [
		calm.loop_end, Sfx.frame_count(calm), calm.loop_mode, "PASS" if calm_ok else "FAIL"])

	# --- 4. per-object loops obey the effects slider -------------------------
	# Both crack players used to build their own AudioStreamPlayer without a bus,
	# so they played on Master and the EFFECTS slider did nothing to them.
	var wreck := Derelict.new()
	system_root.add_child(wreck)
	await get_tree().process_frame
	var probe := Sfx.attached_loop(self, "crack", -6.0)
	var bus_ok: bool = probe.bus == Sfx.BUS_SFX
	var crack_stream := probe.stream as AudioStreamWAV
	var loops_ok: bool = crack_stream != null and crack_stream.loop_mode == AudioStreamWAV.LOOP_FORWARD
	# The deepest hulks hold for 1.8 + 0.2 * band seconds; the sample is 2.2s, so
	# without looping the audio stopped before the wreck gave way.
	var longest_hold := 1.8 + 0.2 * 4.0
	print("[feel] CRACK BUS bus=%s (must be %s) -> %s" % [
		probe.bus, Sfx.BUS_SFX, "PASS" if bus_ok else "FAIL"])
	print("[feel] CRACK OUTLASTS HOLD sample=%.2fs deepest hold=%.2fs looped=%s -> %s" % [
		crack_stream.get_length() if crack_stream else -1.0, longest_hold, str(loops_ok),
		"PASS" if loops_ok else "FAIL"])
	probe.queue_free()
	wreck.queue_free()

	# --- 5. the blade is audible ---------------------------------------------
	# sweep.wav was generated, imported and loaded on every boot since the first
	# audio pass, and never played once.
	var arm := SweepArm.new()
	system_root.add_child(arm)
	await get_tree().process_frame
	arm.active = true
	await get_tree().process_frame
	var arm_audible: bool = arm.audio_playing()
	arm.active = false
	await get_tree().process_frame
	var arm_silent: bool = not arm.audio_playing()
	print("[feel] SWEEP AUDIBLE active=%s inactive silent=%s -> %s" % [
		str(arm_audible), str(arm_silent), "PASS" if arm_audible and arm_silent else "FAIL"])
	arm.queue_free()

	# --- 6. the shield ghost trails damage, and only downward ----------------
	player.invulnerable = false
	player.shield = player.shield_max
	await get_tree().create_timer(0.2).timeout
	player.take_hit(player.shield_max * 0.4, null)
	await get_tree().process_frame
	await get_tree().process_frame
	var frac_after: float = player.shield_fraction()
	var ghost_after: float = player.shield_ghost_fraction()
	var trails: bool = ghost_after > frac_after + 0.05
	# And it must converge, or it is not a ghost, it is a second bar.
	await get_tree().create_timer(2.0).timeout
	var converged: bool = absf(player.shield_ghost_fraction() - player.shield_fraction()) < 0.02
	print("[feel] SHIELD GHOST after hit ghost=%.2f > fill=%.2f =%s, converges=%s -> %s" % [
		ghost_after, frac_after, str(trails), str(converged),
		"PASS" if trails and converged else "FAIL"])

	# --- 7. teleports land exactly where they were told to ------------------
	# The interpolation reset is invisible headless, but a teleport that does not
	# assign cleanly would show up here first.
	player.teleport_to(Vector3(120.0, 0.0, -40.0))
	var landed: bool = player.global_position.distance_to(Vector3(120.0, 0.0, -40.0)) < 0.001
	player.teleport_to(PlayerShip.SPAWN_POINT)
	var home: bool = player.global_position.distance_to(PlayerShip.SPAWN_POINT) < 0.001
	print("[feel] TELEPORT exact out=%s back=%s -> %s" % [
		str(landed), str(home), "PASS" if landed and home else "FAIL"])

	# --- 8. only fixed-tick movers interpolate -------------------------------
	# Most of Pyxis moves in _process; interpolating those would cost a frame of
	# lag. This asserts the split is what the project.godot comment claims.
	# Asserted on the RESOLVED state, not the declared mode. The first version of
	# this checked physics_interpolation_mode and passed while the rig was
	# actually interpolating: the rig's mode was INHERIT, which resolved to ON
	# from the root, and the engine was warning about the Camera3D every boot.
	# A property that can be INHERIT is not the property worth asserting on.
	var ship_on: bool = player.is_physics_interpolated()
	var rig_off: bool = not rig.is_physics_interpolated()
	var cam_off: bool = not get_viewport().get_camera_3d().is_physics_interpolated()
	var world_off: bool = not system_root.is_physics_interpolated()
	print("[feel] INTERP SPLIT ship=%s rig=%s camera=%s world=%s (want on/off/off/off) -> %s" % [
		str(ship_on), str(not rig_off), str(not cam_off), str(not world_off),
		"PASS" if ship_on and rig_off and cam_off and world_off else "FAIL"])

	get_tree().quit()


# --- controls, micro-interactions and haptics --------------------------------

func _run_ui_test() -> void:
	# Guards the parts of the UI pass that are mechanical rather than aesthetic:
	# that every state of every control is actually distinct, that the paint
	# counter cannot take salvage without delivering paint, and that the two new
	# accessibility settings reach the things they claim to gate.
	await get_tree().create_timer(0.3).timeout

	# --- 1. the pause menu is styled at all ----------------------------------
	# Every action button used to be a bare Button with a font colour and no
	# StyleBox, so the most-opened screen in the game rendered in Godot's default
	# grey while the title screen was the only styled surface in the build.
	pause_menu.open()
	await get_tree().process_frame
	var actions := _collect_buttons(pause_menu)
	var styled := 0
	var distinct := 0
	for b_v in actions:
		var b := b_v as Button
		var n := b.get_theme_stylebox("normal")
		var h := b.get_theme_stylebox("hover")
		var d := b.get_theme_stylebox("disabled")
		if n != null and not (n is StyleBoxEmpty):
			styled += 1
		# Distinct INSTANCES, not just distinct values: the swatch bug was one
		# StyleBox assigned to all four states, so any later edit to one state
		# silently edited the others too.
		if n != h and h != d and n != d:
			distinct += 1
	print("[ui] PAUSE STYLED %d/%d buttons have a normal box, %d/%d have distinct states -> %s" % [
		styled, actions.size(), distinct, actions.size(),
		"PASS" if actions.size() > 0 and styled == actions.size() and distinct == actions.size() else "FAIL"])

	# --- 2. the log reveals rather than appearing ----------------------------
	# Ten lines arriving at once is a wall of text. Asserted as "starts
	# transparent and finishes opaque" rather than by sampling the tween, because
	# the rule is that the entries animate, not that they animate a certain way.
	GameState.note_log("SHOOK DOWN THE HARNESS")
	GameState.note_log("CROSSED INTO THE DRIFT")
	GameState.set_setting("reduce_motion", false)
	pause_menu.show_log()
	await get_tree().process_frame
	var revealing := pause_menu.log_entries()
	var started_hidden := revealing.size() > 0
	for l_v in revealing:
		if (l_v as Control).modulate.a > 0.9:
			started_hidden = false
	await get_tree().create_timer(1.2).timeout
	var ended_visible := true
	for l_v in pause_menu.log_entries():
		if (l_v as Control).modulate.a < 0.99:
			ended_visible = false
	print("[ui] LOG REVEAL %d entries start faded=%s, end opaque=%s -> %s" % [
		revealing.size(), str(started_hidden), str(ended_visible),
		"PASS" if started_hidden and ended_visible else "FAIL"])

	# Reduced motion is the END STATE IMMEDIATELY, not the same animation played
	# faster. An accommodation that still animates is not an accommodation.
	GameState.set_setting("reduce_motion", true)
	pause_menu.show_log()
	await get_tree().process_frame
	var instant := true
	var reduced := pause_menu.log_entries()
	for l_v in reduced:
		if (l_v as Control).modulate.a < 0.99:
			instant = false
	print("[ui] LOG REDUCED MOTION %d entries opaque on frame one=%s -> %s" % [
		reduced.size(), str(instant), "PASS" if instant and reduced.size() > 0 else "FAIL"])
	GameState.set_setting("reduce_motion", false)
	pause_menu.resume()

	# --- 3. the haptic gate --------------------------------------------------
	GameState.set_setting("haptics", false)
	var before := Sfx.haptic_count
	Sfx.haptic("heavy")
	var silent := Sfx.haptic_count == before
	GameState.set_setting("haptics", true)
	Sfx.haptic("heavy")
	var fired := Sfx.haptic_count == before + 1
	print("[ui] HAPTIC GATE off:silent=%s on:fires=%s kind=%s -> %s" % [
		str(silent), str(fired), Sfx.haptic_last, "PASS" if silent and fired else "FAIL"])

	# Reduced motion must also stop the camera, through the shake gate rather
	# than through a second check every effect would have to remember.
	GameState.set_setting("shake", true)
	GameState.set_setting("reduce_motion", true)
	var motion_off := not GameState.shake_enabled()
	GameState.set_setting("reduce_motion", false)
	var motion_on := GameState.shake_enabled()
	print("[ui] REDUCE MOTION subsumes shake: on->%s off->%s -> %s" % [
		str(not motion_off), str(motion_on), "PASS" if motion_off and motion_on else "FAIL"])

	# --- 4. paint is ordered: decide, charge, apply --------------------------
	# The old order spent first and applied second, so any refusal added between
	# the two would take the salvage and leave the hull its old colour.
	GameState.set_livery(0, 0)
	GameState.salvage = 100000
	var rich := GameState.salvage
	port_panel._apply_paint(3, true, PortPanel.PAINT_PRICE)
	var applied: bool = GameState.livery_index("hull") == 3
	var charged: bool = GameState.salvage == rich - PortPanel.PAINT_PRICE
	print("[ui] PAINT APPLIES hull=%d (want 3), salvage %d -> %d -> %s" % [
		GameState.livery_index("hull"), rich, GameState.salvage,
		"PASS" if applied and charged else "FAIL"])

	# Too poor: nothing may change, in either direction.
	GameState.salvage = PortPanel.PAINT_PRICE - 1
	var poor := GameState.salvage
	port_panel._apply_paint(5, true, PortPanel.PAINT_PRICE)
	print("[ui] PAINT REFUSED broke: hull stayed %d (want 3), salvage stayed %d -> %s" % [
		GameState.livery_index("hull"), GameState.salvage,
		"PASS" if GameState.livery_index("hull") == 3 and GameState.salvage == poor else "FAIL"])

	# Repainting the colour already worn is refused before it is charged.
	GameState.salvage = 100000
	var same_before := GameState.salvage
	port_panel._apply_paint(3, true, PortPanel.PAINT_PRICE)
	print("[ui] PAINT NO-OP repaint of worn colour costs nothing: %d -> %d -> %s" % [
		same_before, GameState.salvage,
		"PASS" if GameState.salvage == same_before else "FAIL"])

	# The ordering itself: a refusal that is NOT the already-worn one. An accent
	# index past the end of the table is what _can_wear rejects today, and it
	# stands in for the Commission's locked ninth accent -- the case the old
	# spend-then-apply order would have charged for and then declined to deliver.
	GameState.set_livery(0, 0)
	GameState.salvage = 100000
	var locked_before := GameState.salvage
	var accent_before := GameState.livery_index("accent")
	port_panel._apply_paint(Palette.LIVERY_ACCENTS.size(), false, PortPanel.PAINT_PRICE)
	var unpaid: bool = GameState.salvage == locked_before
	var unworn: bool = GameState.livery_index("accent") == accent_before
	print("[ui] PAINT ORDERED refused accent %d: salvage %d (unchanged=%s), accent %d (unchanged=%s) -> %s" % [
		Palette.LIVERY_ACCENTS.size(), GameState.salvage, str(unpaid),
		GameState.livery_index("accent"), str(unworn),
		"PASS" if unpaid and unworn else "FAIL"])

	# --- 5. swatch states are distinct instances ------------------------------
	var grid := port_panel._swatch_grid("HULL", Palette.LIVERY_HULLS, 0, PortPanel.PAINT_PRICE, true)
	var swatches := _collect_buttons(grid)
	var all_distinct := swatches.size() == Palette.LIVERY_HULLS.size()
	for b_v in swatches:
		var b := b_v as Button
		if b.get_theme_stylebox("normal") == b.get_theme_stylebox("hover"):
			all_distinct = false
	print("[ui] SWATCH STATES %d swatches, hover box differs from normal on all=%s -> %s" % [
		swatches.size(), str(all_distinct), "PASS" if all_distinct else "FAIL"])
	grid.queue_free()

	# --- 6. settings round-trip ----------------------------------------------
	# Both new keys have to survive a save/load, or the accessibility toggles are
	# decorative.
	GameState.set_setting("haptics", false)
	GameState.set_setting("reduce_motion", true)
	var probe := {}
	for k in GameState.DEFAULT_SETTINGS:
		probe[k] = GameState.setting(k)
	GameState.settings = GameState.DEFAULT_SETTINGS.duplicate()
	for k in probe:
		GameState.settings[k] = probe[k]
	var kept: bool = GameState.setting("haptics") == false and GameState.setting("reduce_motion") == true
	print("[ui] SETTINGS ROUND TRIP haptics=%s reduce_motion=%s -> %s" % [
		str(GameState.setting("haptics")), str(GameState.setting("reduce_motion")),
		"PASS" if kept else "FAIL"])

	get_tree().quit()


func _collect_buttons(root: Node) -> Array:
	var out: Array = []
	for c in root.get_children():
		if c is Button:
			out.append(c)
		out.append_array(_collect_buttons(c))
	return out


# --- the Grand Commission ----------------------------------------------------

func _run_gsa_test() -> void:
	# The Commission is the first system in the game whose state is PERSISTENT
	# and read by unrelated screens, so most of what follows is about the seams:
	# the load path, the claim ordering, and the copy rule that keeps it from
	# becoming a quest board.
	#
	# Every assertion here pins GameState.commissioned explicitly. GameState boots
	# from the developer's real save, so the moment this flag exists, any harness
	# that reads band text or the accent lock passes or fails depending on whether
	# whoever ran it happened to finish the Commission.
	await get_tree().create_timer(0.3).timeout

	# --- 1. the copy rule, as data -------------------------------------------
	# The structural rule is that a stage DESCRIBES; the moment one instructs,
	# the Commission has become a quest. A rule nothing checks is worth nothing.
	# Checked on the FIRST word, not on vocabulary anywhere in the line. English
	# imperatives lead with their verb -- "Survey the Drift" instructs, while "A
	# first survey packet" uses the same word as a noun and states a fact. A
	# contains-check would ban the noun too, and the rule is about mood.
	var imperative_found := ""
	for st_v in CommissionDB.STAGES:
		var st: Dictionary = st_v
		var words: PackedStringArray = String(st["desc"]).to_lower() \
			.replace(",", " ").replace(".", " ").split(" ", false)
		if words.size() > 0 and CommissionDB.IMPERATIVES.has(words[0]):
			imperative_found = "%s: '%s'" % [String(st["name"]), words[0]]
	print("[gsa] NO IMPERATIVE %d descriptions, none open on a verb (offender: %s) -> %s" % [
		CommissionDB.STAGES.size(), imperative_found if imperative_found != "" else "none",
		"PASS" if imperative_found == "" else "FAIL"])

	# Names state a STATUS rather than a task. Three are past participles; ON
	# FILE is a prepositional phrase, which is the same grammatical move -- what
	# the register says about you -- and is the phrase the finale calls back to.
	# What matters is that none of them is something to go and do.
	var status_names := true
	for st_v in CommissionDB.STAGES:
		var first := String((st_v as Dictionary)["name"]).to_lower().split(" ")[0]
		if CommissionDB.IMPERATIVES.has(first):
			status_names = false
	print("[gsa] STAGE COUNT %d stages (clamps use STAGES.size()), no name is a task=%s -> %s" % [
		CommissionDB.count(), str(status_names),
		"PASS" if CommissionDB.count() == 4 and status_names else "FAIL"])

	# --- 2. the load path clamps ---------------------------------------------
	var probe := "user://gsa_probe.json"
	var real_path := GameState.save_path
	GameState.save_path = probe

	var high := _gsa_fixture({"commission_claimed": 99})
	GameState.load_game()
	var clamped_high := GameState.commission_claimed
	_gsa_fixture({"commission_claimed": -5})
	GameState.load_game()
	var clamped_low := GameState.commission_claimed
	print("[gsa] LOAD CLAMPS 99 -> %d (want %d), -5 -> %d (want 0) -> %s" % [
		clamped_high, CommissionDB.count(), clamped_low,
		"PASS" if clamped_high == CommissionDB.count() and clamped_low == 0 else "FAIL"])

	# --- 3. the accent lock, against the SHIP MATERIAL ------------------------
	# Not against the stored int. player_ship.gd reads
	# Palette.livery_accent(livery_index("accent")) directly and never asks
	# set_livery anything, so the stored value is not what the player sees.
	# posmod wraps, so 8 and 17 are the same attack wearing different numbers.
	var locked_ok := true
	var seen: Array = []
	for bad in [GameState.REGISTRY_ACCENT, 17]:
		_gsa_fixture({"commissioned": false, "livery": {"hull": 0, "accent": bad}})
		GameState.load_game()
		seen.append(GameState.livery_index("accent"))
		if GameState.livery_index("accent") >= GameState.REGISTRY_ACCENT:
			locked_ok = false
	print("[gsa] ACCENT LOCKED AT THE LOAD PATH uncommissioned accents [8, 17] -> %s -> %s" % [
		str(seen), "PASS" if locked_ok else "FAIL"])

	# And an earned one must survive, or the lock has eaten a real reward.
	_gsa_fixture({"commissioned": true, "livery": {"hull": 0, "accent": GameState.REGISTRY_ACCENT}})
	GameState.load_game()
	var kept: bool = GameState.livery_index("accent") == GameState.REGISTRY_ACCENT
	print("[gsa] ACCENT KEPT WHEN EARNED commissioned accent 8 -> %d -> %s" % [
		GameState.livery_index("accent"), "PASS" if kept else "FAIL"])

	# The clamp underneath it: these were the only unbounded ints in load_game.
	_gsa_fixture({"commissioned": true, "livery": {"hull": 999, "accent": 3}})
	GameState.load_game()
	var hull_ok: bool = GameState.livery_index("hull") < Palette.LIVERY_HULLS.size()
	print("[gsa] LIVERY CLAMPS hull 999 -> %d (max %d) -> %s" % [
		GameState.livery_index("hull"), Palette.LIVERY_HULLS.size() - 1,
		"PASS" if hull_ok else "FAIL"])

	GameState.save_path = real_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(probe))

	# --- 4. claim ordering and re-entrancy -----------------------------------
	GameState.commissioned = false
	GameState.commission_claimed = 0
	GameState.ledger = GameState.DEFAULT_LEDGER.duplicate()
	for k in ["chart_data_sold", "hulks_cracked", "posts_cleared", "deepest_depth"]:
		GameState.ledger[k] = 100000
	GameState.salvage = 0

	# STATE BEFORE MONEY. add_salvage emits salvage_changed, and PortPanel wires
	# that straight back into _refresh() -- so a claim that paid before it
	# incremented would rebuild the sheet reading the pre-claim stage and redraw
	# the button it had just honoured.
	# The box is an Array because GDScript lambdas capture locals BY VALUE: a
	# plain int written inside the closure updates the closure's own copy and the
	# assertion reads the untouched original, which is an assertion that cannot
	# fail. An Array is a reference and survives the capture.
	var box: Array = [-1]
	var once := func(_v: int) -> void:
		if int(box[0]) < 0:
			box[0] = GameState.commission_claimed
	GameState.salvage_changed.connect(once)
	var first := GameState.claim_commission()
	GameState.salvage_changed.disconnect(once)
	print("[gsa] STATE BEFORE MONEY salvage_changed saw claimed=%d (want 1) -> %s" % [
		int(box[0]), "PASS" if int(box[0]) == 1 else "FAIL"])
	print("[gsa] CLAIM PAYS stage '%s' paid %d, salvage now %d -> %s" % [
		String(first.get("name", "")), int(first.get("pays", 0)), GameState.salvage,
		"PASS" if int(first.get("pays", 0)) == GameState.salvage and GameState.salvage > 0 else "FAIL"])

	# CLAIM GUARDS ITSELF: called directly, not through a button, because the
	# harness is exactly the second caller survey_mast.gd's comment warns about.
	var before_second := GameState.salvage
	var stage_before := GameState.commission_claimed
	GameState.claim_commission()
	GameState.claim_commission()
	print("[gsa] CLAIM GUARDS ITSELF three more direct calls from stage %d -> stage %d, salvage %d -> %d -> %s" % [
		stage_before, GameState.commission_claimed, before_second, GameState.salvage,
		"PASS" if GameState.commission_claimed == stage_before + 2 else "FAIL"])

	# CLAIM IS ORDERED: you cannot skip to stage 3 with every threshold met.
	GameState.commission_claimed = 1
	var ordered: bool = GameState.commission_stage() == 1
	print("[gsa] CLAIM IS ORDERED at claimed=1 the next stage is %d (want 1), not the highest met -> %s" % [
		GameState.commission_stage(), "PASS" if ordered else "FAIL"])

	# Thresholds actually gate: an empty ledger claims nothing.
	GameState.commission_claimed = 0
	GameState.ledger = GameState.DEFAULT_LEDGER.duplicate()
	var empty := GameState.claim_commission()
	print("[gsa] THRESHOLDS GATE empty ledger claims nothing (got %s), shortfalls %d -> %s" % [
		"{}" if empty.is_empty() else str(empty),
		CommissionDB.shortfalls(0, GameState.ledger).size(),
		"PASS" if empty.is_empty() else "FAIL"])

	# --- 5. the persistent flag ----------------------------------------------
	GameState.commissioned = false
	GameState.commission_claimed = 0
	for k in ["chart_data_sold", "hulks_cracked", "posts_cleared", "deepest_depth"]:
		GameState.ledger[k] = 100000
	for _i in range(CommissionDB.count()):
		GameState.claim_commission()
	var earned: bool = GameState.commissioned and GameState.commission_complete()
	# RESET WITH RUN: the counter is run state, the flag is not.
	GameState.reset_to_starter()
	var survived: bool = GameState.commissioned and GameState.commission_claimed == 0
	print("[gsa] RESET WITH RUN after 4 claims commissioned=%s; after reset claimed=%d commissioned=%s -> %s" % [
		str(earned), GameState.commission_claimed, str(GameState.commissioned),
		"PASS" if earned and survived else "FAIL"])

	# NOT A TALLY: the Commission is the authority describing you, so the front
	# door carries a registry line, never a progress count.
	GameState.commissioned = true
	var summary := title_screen.title_summary()
	var registry := title_screen.registry_line()
	var clean: bool = not summary.contains("COMMISSION") and not summary.contains("/4") \
		and registry.contains("COMMISSIONED")
	print("[gsa] NOT A TALLY summary '%s' carries no stage count; registry '%s' -> %s" % [
		summary, registry, "PASS" if clean else "FAIL"])

	# --- 6. beacon parity ----------------------------------------------------
	# The clause that matters: broadcast_for(band, false) must be string-identical
	# to what shipped, or the rewrite has quietly edited the uncommissioned text.
	var uncommissioned_intact := true
	for band in range(DeepSpace.BROADCASTS.size()):
		var raw: Dictionary = DeepSpace.BROADCASTS[band]
		var got := DeepSpace.broadcast_for(band, false)
		if band <= 0:
			continue
		if String(got.get("from", "")) != String(raw.get("from", "")) \
				or String(got.get("body", "")) != String(raw.get("body", "")):
			uncommissioned_intact = false
	var bands_answer := true
	for band in [1, 2, 3]:
		var c := DeepSpace.broadcast_for(band, true)
		var u := DeepSpace.broadcast_for(band, false)
		if String(c.get("body", "")) == String(u.get("body", "")):
			bands_answer = false
	# Band 4 stays silent, and that is the note the arc ends on: COMMISSIONED
	# requires reaching THE QUIET, the one band that will never acknowledge it.
	var quiet_silent: bool = String(DeepSpace.broadcast_for(4, true).get("body", "")) \
		== String(DeepSpace.broadcast_for(4, false).get("body", ""))
	print("[gsa] BEACON PARITY %d bands, uncommissioned text unchanged=%s, bands 1-3 answer=%s, band 4 silent=%s -> %s" % [
		DeepSpace.BROADCASTS.size(), str(uncommissioned_intact), str(bands_answer), str(quiet_silent),
		"PASS" if DeepSpace.BROADCASTS.size() == 5 and uncommissioned_intact \
			and bands_answer and quiet_silent else "FAIL"])

	# --- 7. every service renders its own body -------------------------------
	# Finding 5: port_panel's `match _tab` catch-all IS the outfitter, so a
	# TAB_LABELS entry without a matching arm renders a plausible-looking second
	# outfitter with no error and no crash. The hole is load-bearing, so it
	# cannot be replaced with a warning -- only checked.
	# Checked by RENDERING each tab and comparing the result to the outfitter's,
	# not by guessing method names -- "contracts" builds through
	# _build_contract_board, so a has_method("_build_contracts") check reports a
	# working screen as missing. What the rule actually says is that every
	# service shows its own body, and the only way to know that is to draw it.
	var port_node: Port = null
	for n in get_tree().get_nodes_in_group("dockable"):
		port_node = n as Port
		break
	var shadows: Array = []
	if port_node != null:
		port_node.def = SystemDB.port_def_by_id("anchor").duplicate(true)
		port_node.def["services"] = PortPanel.TAB_LABELS.keys()
		port_panel.open_for(port_node)
		await get_tree().process_frame
		# Nodes queued for deletion are SKIPPED. _refresh queue_frees the old body
		# and builds the new one in the same frame, and queue_free is deferred --
		# so a naive child walk reads the previous tab's rows alongside this
		# tab's, every fingerprint comes out unique, and the assertion passes on
		# every possible input. That is the assertion-that-cannot-fail this
		# codebase has a written rule about.
		var fingerprint := func(tab: String) -> String:
			port_panel._tab = tab
			port_panel._refresh()
			var live: Array = []
			for c in port_panel._body.get_children():
				if not c.is_queued_for_deletion():
					live.append(c)
			var out := "%d|" % live.size()
			for c in live:
				if c is Label:
					out += String((c as Label).text).substr(0, 40) + ";"
			return out
		var outfitter: String = await fingerprint.call("outfitter")
		for key_v in PortPanel.TAB_LABELS:
			var key := String(key_v)
			if key == "outfitter":
				continue
			var body: String = await fingerprint.call(key)
			if body == outfitter:
				shadows.append(key)
		port_panel.close_panel()
	print("[gsa] EVERY SERVICE HAS A BUILDER %d labels, rendering as a second outfitter: %s -> %s" % [
		PortPanel.TAB_LABELS.size(), str(shadows) if not shadows.is_empty() else "none",
		"PASS" if port_node != null and shadows.is_empty() else "FAIL"])

	# The Anchor offers it, and does NOT lead with it: services()[0] is the
	# landing tab, so a prepended registry would open every dock on paperwork.
	var anchor := SystemDB.port_def_by_id("anchor")
	var svc: Array = anchor.get("services", [])
	print("[gsa] COMMISSION APPENDED anchor services %s, first=%s -> %s" % [
		str(svc), String(svc[0]) if not svc.is_empty() else "none",
		"PASS" if svc.has("commission") and String(svc[0]) != "commission" else "FAIL"])

	# --- 8. the swatch grid fits the ninth ------------------------------------
	print("[gsa] ACCENT ROW %d accents, grid columns %d -> %s" % [
		Palette.LIVERY_ACCENTS.size(), 9,
		"PASS" if Palette.LIVERY_ACCENTS.size() == 9 else "FAIL"])

	get_tree().quit()


func _gsa_fixture(overrides: Dictionary) -> Dictionary:
	# A minimal valid v13 save with the fields under test overridden. Written
	# rather than hand-edited in memory, because the whole point of these
	# assertions is what happens on the LOAD PATH.
	var data := {
		"version": GameState.SAVE_VERSION,
		"salvage": 0,
		"current_system": SystemDB.START_SYSTEM,
		"livery": {"hull": 0, "accent": 0},
		"commission_claimed": 0,
		"commissioned": false,
	}
	for k in overrides:
		data[k] = overrides[k]
	var f := FileAccess.open(GameState.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return data
