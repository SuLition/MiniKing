class_name ProfessionDefinition
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var tool_id: StringName = &""
@export var base_max_hp: int = 0
@export var base_walk_speed: float = 0.0
@export var task_kinds: Array[int] = []
@export var behavior_tags: Array[StringName] = []
@export var body_color: Color = Color(0.35, 0.62, 0.95, 1.0)
@export var show_role_label: bool = true
@export var capabilities: Array[ProfessionCapability] = []

func can_claim_task(worker: Node, task: Task) -> bool:
	if task == null:
		return false

	for capability: ProfessionCapability in capabilities:
		if capability != null and capability.can_claim_task(worker, task):
			return true

	return task_kinds.has(task.kind)

func has_behavior_tag(tag: StringName) -> bool:
	return behavior_tags.has(tag)

func notify_assigned(worker: Node) -> void:
	for capability: ProfessionCapability in capabilities:
		if capability != null:
			capability.on_assigned(worker)

func process_idle(worker: Node, delta: float) -> bool:
	for capability: ProfessionCapability in capabilities:
		if capability != null and capability.process_idle(worker, delta):
			return true
	return false

func process_wander(worker: Node, delta: float) -> bool:
	for capability: ProfessionCapability in capabilities:
		if capability != null and capability.process_wander(worker, delta):
			return true
	return false

func process_combat(worker: Node, delta: float) -> bool:
	for capability: ProfessionCapability in capabilities:
		if capability != null and capability.process_combat(worker, delta):
			return true
	return false
