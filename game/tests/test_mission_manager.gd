extends GutTest
## Unit tests for the Ghost Station mission FSM (MissionManager). These cover the
## transitions a headless boot can't reach — dock -> hack -> extract -> success,
## plus both fail paths and the terminal-state guard. The FSM is driven directly
## (calling its handlers / _process with a fixed delta) so no real flying is needed.

var _root: Node3D
var _ship: ShipController
var _cargo: CargoSystem
var _dock: ShipZone
var _mm: MissionManager

func before_each() -> void:
	# The "dock" action must exist for the synthetic InputEventAction in the
	# dock-press test to resolve.
	if not InputMap.has_action("dock"):
		InputMap.add_action("dock")

	_root = Node3D.new()
	add_child_autofree(_root)

	_ship = ShipController.new()
	_root.add_child(_ship)
	_cargo = CargoSystem.new()
	_ship.add_child(_cargo)
	_ship.cargo = _cargo

	_dock = ShipZone.new()
	_root.add_child(_dock)

	var def := MissionDef.new()
	def.hack_duration = 1.0
	def.extract_duration = 1.0
	def.station_distance = 100.0
	def.extraction_distance = 100.0
	def.hack_wave_size = 0       # isolate the FSM from drone spawning
	def.extract_wave_size = 0
	def.wave_interval = 999.0

	_mm = MissionManager.new()
	_mm.mission_def = def
	_mm.setup(_ship, _cargo, _dock)
	_root.add_child(_mm)         # _mm.get_parent() == _root -> spawns land in _root

func test_starts_in_approach() -> void:
	assert_eq(_mm._state, MissionManager.State.APPROACH, "mission begins in APPROACH")

func test_entering_dock_zone_enables_docking() -> void:
	assert_false(_mm._can_dock, "cannot dock before entering the zone")
	_mm._on_dock_entered()
	assert_true(_mm._can_dock, "entering the dock zone enables docking")

func test_dock_press_starts_hack() -> void:
	_mm._on_dock_entered()
	var ev := InputEventAction.new()
	ev.action = "dock"
	ev.pressed = true
	_mm._unhandled_input(ev)
	assert_eq(_mm._state, MissionManager.State.HACK, "pressing dock while in range starts the hack")

func test_dock_press_ignored_when_not_in_range() -> void:
	var ev := InputEventAction.new()
	ev.action = "dock"
	ev.pressed = true
	_mm._unhandled_input(ev)
	assert_eq(_mm._state, MissionManager.State.APPROACH, "dock press does nothing outside the zone")

func test_hack_completes_grants_core_and_extracts() -> void:
	_mm._enter_hack()
	assert_eq(_mm._state, MissionManager.State.HACK)
	assert_false(_cargo.has_item(MissionManager.DATA_CORE), "no core mid-hack")
	# hack_duration is 1.0; drain it.
	_mm._process(0.6)
	_mm._process(0.6)
	assert_eq(_mm._state, MissionManager.State.EXTRACT, "hack completing moves to EXTRACT")
	assert_true(_cargo.has_item(MissionManager.DATA_CORE), "Data Core added to cargo on hack complete")

func test_reaching_extraction_zone_succeeds() -> void:
	_mm._enter_hack()
	_mm._process(1.1)                 # -> EXTRACT
	assert_eq(_mm._state, MissionManager.State.EXTRACT)
	_mm._succeed()                    # simulate flying into the extraction zone
	assert_eq(_mm._state, MissionManager.State.SUCCESS, "entering extraction with the core wins")

func test_meltdown_timer_expiry_fails() -> void:
	_mm._enter_hack()
	_mm._process(1.1)                 # -> EXTRACT, extract_left = 1.0
	assert_eq(_mm._state, MissionManager.State.EXTRACT)
	_mm._process(1.1)                 # drain meltdown timer
	assert_eq(_mm._state, MissionManager.State.FAILED, "letting the meltdown timer expire fails")

func test_ship_destroyed_fails_mission() -> void:
	_mm._enter_hack()
	EventBus.ship_destroyed.emit()
	assert_eq(_mm._state, MissionManager.State.FAILED, "ship destruction fails the mission")

func test_success_is_terminal() -> void:
	_mm._enter_hack()
	_mm._process(1.1)
	_mm._succeed()
	assert_eq(_mm._state, MissionManager.State.SUCCESS)
	_mm._fail("late hit")             # should be ignored after success
	assert_eq(_mm._state, MissionManager.State.SUCCESS, "a terminal SUCCESS is not overwritten by a later fail")
