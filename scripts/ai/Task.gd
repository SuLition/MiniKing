class_name Task
extends RefCounted

# 任务数据类。
# 由任务发布者（HammerStand / BuildSite 等）创建并通过 TaskBoard.post_task 上传。
# 由 NPC 通过 TaskBoard.claim_nearest 领取。
#
# 设计约束：
# - 仅承载数据，不持有行为
# - provider 必须实现 start_work(claimant: Node, task: Task) -> bool
# - claimed 由 TaskBoard 原子置位，外部不要直接改

enum Kind {
	TOOL_PICKUP,
	CONSTRUCTION,
}

var kind: int = Kind.TOOL_PICKUP
var position: Vector2 = Vector2.ZERO
var provider: Node = null
var payload: Dictionary = {}
var claimed: bool = false
