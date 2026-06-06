# MiniKing 当前架构说明

## 目的

本文定义当前垂直切片代码的系统边界和运行时契约。本文只约束架构，不决定玩法规则和数值平衡。

## 系统边界

### 场景组装

`scenes/main.tscn` 是组合根。它可以实例化场景、注入 `NodePath`、挂载高层 manager。它不应拥有实体状态，例如 HP、工具、任务进度。

### 实体

实体拥有自己的可变状态。

- `PlayerController.gd` 拥有玩家移动和玩家 group 注册。
- `Villager.gd` 拥有村民状态机、工具状态、HP、任务领取状态和战斗状态。
- `Greed.gd` 拥有 Greed 移动、HP、攻击墙状态和接触效果。
- `Wall.gd` 拥有墙体 HP 和销毁。

其他系统应通过公开方法和信号交互，不直接改实体内部字段。

### 任务系统

`TaskBoard.gd` 是基础设施 autoload。它只负责存储任务、过滤失效任务、原子领取任务，不决定具体玩法资格。Worker 是否能做某类任务，由 worker 状态机判断；任务完成行为由 provider 自己拥有。

`Task.gd` 是数据包，不包含行为。

### 任务提供者

任务提供者只在自身前置条件满足后创建任务。任务提供者拥有自己任务的执行和完成逻辑。

当前 provider：

- `JobPoint.gd`
- `BuildSite.gd`

### 职业系统

职业系统采用 ADR-003 的数据驱动模型。职业定义属于 `ProfessionDefinition` 资源；NPC 持有当前职业引用；职业行为通过能力模块扩展。

`Villager.gd` 可以调度职业能力，但不应硬编码具体职业名。新增职业优先新增 `.tres` 资源；需要新行为时新增或复用能力模块。

### 战斗与伤害

受伤对象拥有自己的生命值。伤害来源只能通过 `Damageable` 契约调用 `apply_damage(amount)`，不能直接修改 `hp`。

投射物应依赖契约，不依赖具体敌人类型。

### 时间与波次

`TimeManager.gd` 拥有昼夜阶段和阶段时长。`WaveManager.gd` 监听阶段变化，只负责敌人生成和清理。波次系统不拥有敌人 HP，也不决定战斗结果。

### UI

UI 脚本监听状态变化并显示结果。UI 不拥有玩法状态。

## 运行时 Group 常量

所有脚本使用的 group 名必须来自 `scripts/core/GameGroups.gd`。

当前 group：

- `GameGroups.PLAYER`
- `GameGroups.VILLAGER`
- `GameGroups.GREED`
- `GameGroups.WALL`
- `GameGroups.DAMAGEABLE`
- `GameGroups.TASK_PROVIDER`

新增运行时 group 时，先加入 `GameGroups.gd`，再在脚本中使用。

## 运行时契约

### Damageable

必须：

- 加入 `GameGroups.DAMAGEABLE`。
- 实现 `apply_damage(amount: int) -> void`。
- 实现 `get_hp() -> int`。

推荐信号：

- `hp_changed(current_hp: int, max_hp: int)`
- `destroyed`

所有权规则：只有 Damageable 节点自己能更新自己的 HP。

### TaskProvider

必须：

- 加入 `GameGroups.TASK_PROVIDER`。
- 实现 `start_work(claimant: Node, task: Task) -> bool`。
- 只发布 `provider == self` 的任务。

所有权规则：provider 拥有任务完成行为，并在任务完成后调用 `TaskBoard.complete_task(task)`。

### Worker

当前 NPC worker 必须：

- 实现 `assign_profession(profession: ProfessionDefinition) -> void`。
- 实现 `equip_tool(tool_type: StringName) -> void`。
- 实现 `set_home_position(home_position: Vector2) -> void`。
- 实现 `finish_work() -> void`。

`equip_tool()` 是旧工具路径的兼容接口；新职业系统应优先使用 `assign_profession()`。

所有权规则：worker 拥有自己的移动和状态迁移；provider 只能通过公开方法请求动作。

### ProfessionDefinition

职业定义必须：

- 提供稳定 `id: StringName`。
- 提供显示名、基础属性、任务资格、视觉配置或能力模块引用。
- 行为标签使用 `ProfessionTags.gd` 中定义的稳定常量。
- 不包含场景节点引用。

所有权规则：职业资源描述能力和配置，不拥有运行时状态。

### ProfessionCapability

职业能力模块必须：

- 作为 `Resource` 被职业定义引用。
- 只通过 worker 公开方法和既有系统 API 工作。
- 不直接修改 worker 私有字段。

所有权规则：能力模块提供行为片段，运行时状态仍由实体或对应系统拥有。

## 依赖规则

- UI 可以依赖 manager 或实体信号来显示信息，但不能拥有玩法状态。
- `TaskBoard` 可以知道 `TaskProvider` 契约，但不能知道具体 provider 子类。
- 战斗代码可以知道 `Damageable` 契约，但不能枚举所有具体受伤对象。
- 职业代码可以知道职业能力契约，但不能把具体职业名写进 `Villager.gd` 主状态机。
- Manager 负责流程协调，不应成为实体内部状态的拥有者。
- 新系统如果跨越以上边界，应先补 ADR，再实现。
