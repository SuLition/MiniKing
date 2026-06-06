class_name ProfessionCapability
extends Resource

func on_assigned(_worker: Node) -> void:
	pass

func can_claim_task(_worker: Node, _task: Task) -> bool:
	return false

func process_idle(_worker: Node, _delta: float) -> bool:
	return false

func process_wander(_worker: Node, _delta: float) -> bool:
	return false

func process_combat(_worker: Node, _delta: float) -> bool:
	return false
