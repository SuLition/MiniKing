extends Node

signal phase_changed(phase_name: StringName, day_count: int, seconds_remaining: int, phase_duration: int)
signal time_tick(phase_name: StringName, day_count: int, seconds_remaining: int, phase_duration: int)

enum Phase {
	DAY,
	NIGHT,
	DAWN,
}

const GDD_DAY_DURATION: float = 90.0
const GDD_NIGHT_DURATION: float = 45.0
const GDD_DAWN_DURATION: float = 5.0

# Default exports stay short for local iteration; enable this for GDD timing.
@export var use_gdd_duration_profile: bool = false
@export var day_duration: float = 20.0
@export var night_duration: float = 10.0
@export var dawn_duration: float = 5.0
@export var auto_start: bool = true

var _phase: Phase = Phase.DAY
var _day_count: int = 1
var _seconds_remaining: float = 0.0
var _running: bool = false
var _last_reported_second: int = -1

func _ready() -> void:
	if auto_start:
		start_cycle()

func _process(delta: float) -> void:
	if not _running:
		return

	_seconds_remaining -= delta
	if _seconds_remaining <= 0.0:
		_advance_phase()
		return

	_emit_tick_if_needed()

func start_cycle() -> void:
	_day_count = max(_day_count, 1)
	_set_phase(Phase.DAY)
	_running = true

func pause_cycle() -> void:
	_running = false

func resume_cycle() -> void:
	_running = true
	_emit_tick_if_needed(true)

func get_phase_name() -> StringName:
	return _phase_to_name(_phase)

func get_day_count() -> int:
	return _day_count

func get_seconds_remaining() -> int:
	return int(ceil(_seconds_remaining))

func get_phase_duration() -> int:
	return int(ceil(_get_phase_duration(_phase)))

func _advance_phase() -> void:
	match _phase:
		Phase.DAY:
			_set_phase(Phase.NIGHT)
		Phase.NIGHT:
			_set_phase(Phase.DAWN)
		Phase.DAWN:
			_day_count += 1
			_set_phase(Phase.DAY)

func _set_phase(next_phase: Phase) -> void:
	_phase = next_phase
	_seconds_remaining = _get_phase_duration(_phase)
	_last_reported_second = -1

	var seconds_remaining: int = get_seconds_remaining()
	var phase_duration: int = get_phase_duration()
	phase_changed.emit(get_phase_name(), _day_count, seconds_remaining, phase_duration)
	time_tick.emit(get_phase_name(), _day_count, seconds_remaining, phase_duration)

func _emit_tick_if_needed(force_emit: bool = false) -> void:
	var current_second: int = get_seconds_remaining()
	if not force_emit and current_second == _last_reported_second:
		return

	_last_reported_second = current_second
	time_tick.emit(get_phase_name(), _day_count, current_second, get_phase_duration())

func _get_phase_duration(phase: Phase) -> float:
	if use_gdd_duration_profile:
		return _get_gdd_phase_duration(phase)

	match phase:
		Phase.DAY:
			return max(day_duration, 1.0)
		Phase.NIGHT:
			return max(night_duration, 1.0)
		Phase.DAWN:
			return max(dawn_duration, 1.0)
		_:
			return 1.0

func _get_gdd_phase_duration(phase: Phase) -> float:
	match phase:
		Phase.DAY:
			return GDD_DAY_DURATION
		Phase.NIGHT:
			return GDD_NIGHT_DURATION
		Phase.DAWN:
			return GDD_DAWN_DURATION
		_:
			return 1.0

func _phase_to_name(phase: Phase) -> StringName:
	match phase:
		Phase.DAY:
			return &"Day"
		Phase.NIGHT:
			return &"Night"
		Phase.DAWN:
			return &"Dawn"
		_:
			return &"Unknown"
