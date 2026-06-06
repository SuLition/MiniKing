extends Node

# 全局任务面板，Autoload 单例。
#
# 接口契约：
# - 任务发布者在自身确认任务（如玩家下单建造）后调用 post_task
# - NPC 在 IDLE / WANDER 状态周期性调用 claim_nearest 拉取
# - 任务完成时由 provider 调用 complete_task
# - 任务被放弃时（如 NPC 死亡）由放弃方调用 release_task
#
# 设计约束：
# - 本类不知道游戏规则，只负责存储、匹配、原子领取
# - claim_nearest 在单一帧内原子，无需锁
# - 任务的 provider 节点失效时（queue_free 后），任务保留——由 claim 方在 start_work 失败时 release

signal task_posted(task: Task)
signal task_claimed(task: Task)
signal task_completed(task: Task)

var _tasks: Array[Task] = []

func post_task(task: Task) -> void:
	if task == null:
		push_warning("TaskBoard: cannot post null task")
		return

	_tasks.append(task)
	task_posted.emit(task)

func claim_nearest(filter: Callable, origin: Vector2) -> Task:
	var nearest: Task = null
	var nearest_distance: float = INF

	for task in _tasks:
		if task.claimed:
			continue
		if not bool(filter.call(task)):
			continue

		var distance: float = origin.distance_to(task.position)
		if distance < nearest_distance:
			nearest = task
			nearest_distance = distance

	if nearest != null:
		nearest.claimed = true
		task_claimed.emit(nearest)

	return nearest

func complete_task(task: Task) -> void:
	if task == null:
		return

	_tasks.erase(task)
	task_completed.emit(task)

func release_task(task: Task) -> void:
	if task == null:
		return

	task.claimed = false

func open_task_count() -> int:
	var count: int = 0
	for task in _tasks:
		if not task.claimed:
			count += 1
	return count

func clear() -> void:
	_tasks.clear()
