# ADR-003: 数据驱动职业系统与能力模块

**状态**: 已采纳
**日期**: 2026-06-06
**关联里程碑**: 职业系统扩展
**依赖**: ADR-001, ADR-002

---

## 1. 背景

当前职业实现仍然是 MVP 形态：

- `JobPoint.gd` 通过 `tool_type: StringName` 表示工具/职业。
- `Villager.gd` 通过 `_tool_type` 判断能否领任务，以及是否进入 archer 战斗分支。
- `VillagerVisual.gd` 通过 `_tool_type` 改外观标签。
- `Task.Kind` 当前只有 `TOOL_PICKUP` 和 `CONSTRUCTION`。

这在 `builder` / `archer` 两个职业时还能维护，但未来基础职业至少包括：

- 农民
- 猎人
- 工匠
- 武士

并且未来可能继续增加更多职业。若继续把职业行为写成 `if _tool_type == ...` 或 `match _tool_type`，会导致：

1. `Villager.gd` 同时承担职业定义、任务资格、战斗行为、生产行为、视觉表现，职责过多。
2. 每新增职业都要修改 NPC 状态机，扩展成本高。
3. 职业属性和数值散落在脚本和场景 export 中，不利于平衡和素材替换。
4. TaskBoard 有被迫理解职业规则的风险，违背 ADR-001 的边界。
5. Archer 在 ADR-002 中作为特例接入，后续需要被收敛到通用职业能力模型。

---

## 2. 决策

采用 **数据驱动职业定义 + Villager 通用状态机 + 能力模块扩展**。

核心原则：

- 职业是数据资源，不是硬编码分支。
- Villager 持有当前职业定义，但不硬编码每个职业的具体玩法。
- 职业能力通过小模块挂接，按能力扩展，不按职业堆 `if/else`。
- TaskBoard 继续只存储和领取任务，不理解职业。
- JobPoint 提供职业定义，不再提供裸字符串 `tool_type`。

---

## 3. 模块设计

### 3.1 职业定义资源

新增：

```
scripts/professions/ProfessionDefinition.gd
```

类型：

```gdscript
class_name ProfessionDefinition
extends Resource
```

建议字段：

```gdscript
@export var id: StringName
@export var display_name: String
@export var tool_id: StringName
@export var base_max_hp: int
@export var base_walk_speed: float
@export var task_kinds: Array[int]
@export var behavior_tags: Array[StringName]
@export var body_color: Color
@export var show_role_label: bool
@export var capabilities: Array[ProfessionCapability]
```

说明：

- `id` 是稳定职业 ID，例如 `farmer`, `hunter`, `artisan`, `warrior`。
- `task_kinds` 描述该职业能领取哪些任务类型。
- `behavior_tags` 用于轻量判断能力类别，例如 `combat`, `production`, `construction`。
- `body_color` / `show_role_label` 是当前 MVP 视觉配置；后续可替换为独立 `visual_profile`。
- `capabilities` 是可组合能力模块。
- 运行时代码引用行为标签时应使用 `ProfessionTags.gd` 常量，避免散落字符串。

每个职业用一个 `.tres` 表示：

```
resources/professions/farmer.tres
resources/professions/hunter.tres
resources/professions/artisan.tres
resources/professions/warrior.tres
```

### 3.2 能力模块基类

新增：

```
scripts/professions/ProfessionCapability.gd
```

类型：

```gdscript
class_name ProfessionCapability
extends Resource
```

基础接口：

```gdscript
func on_assigned(worker: Node) -> void
func can_claim_task(worker: Node, task: Task) -> bool
func process_idle(worker: Node, delta: float) -> bool
func process_wander(worker: Node, delta: float) -> bool
func process_combat(worker: Node, delta: float) -> bool
```

约定：

- 默认实现全部为空或返回 `false`。
- 返回 `true` 表示该能力已经处理了当前 tick 的行为。
- 能力模块不能直接改其他系统状态，必须通过公开方法或既有 manager API。
- 能力模块可以请求 worker 的公开接口，例如移动、开火、完成任务，但不直接改 worker 私有字段。

### 3.3 能力类型

首批建议拆分：

```
scripts/professions/capabilities/TaskWorkCapability.gd
scripts/professions/capabilities/CombatCapability.gd
scripts/professions/capabilities/ProductionCapability.gd
scripts/professions/capabilities/VisualCapability.gd
```

职责：

| 能力 | 职责 |
|------|------|
| `TaskWorkCapability` | 决定该职业能否领取某类 Task |
| `CombatCapability` | 管理目标扫描、攻击间隔、攻击方式 |
| `ProductionCapability` | 管理周期性产出、阶段条件、产出目标 |
| `VisualCapability` | 管理职业外观、标签、动画参数 |

能力模块不决定具体职业是否存在。职业存在于 `ProfessionDefinition` 数据中。

### 3.4 Villager 的职责变化

`Villager.gd` 保留：

- 通用状态机：IDLE / WANDER / SEEK / WORK / COMBAT。
- 移动、任务领取流程、死亡、信号。
- 当前职业引用。

`Villager.gd` 移除或弱化：

- `_tool_type` 作为职业主判断依据。
- `match _tool_type` 决定任务资格。
- `if archer` 这样的职业特例分支。

新增接口：

```gdscript
func assign_profession(profession: ProfessionDefinition) -> void
func get_profession_id() -> StringName
func has_behavior_tag(tag: StringName) -> bool
```

任务资格判断改为：

```gdscript
func _can_do_task(task: Task) -> bool:
    return _profession != null and _profession.can_claim_task(self, task)
```

具体实现可以由 `ProfessionDefinition` 委托给能力模块。

### 3.5 JobPoint 的职责变化

`JobPoint.gd` 从：

```gdscript
@export var tool_type: StringName
```

改为：

```gdscript
@export var profession: ProfessionDefinition
```

领取工具任务完成时：

```gdscript
claimant.assign_profession(profession)
```

JobPoint 不知道职业能力，也不判断职业行为。

### 3.6 TaskBoard 边界保持不变

`TaskBoard.gd` 不新增职业知识。

它仍然只做：

- `post_task`
- `claim_nearest`
- `complete_task`
- `release_task`
- 过滤无效 provider

职业资格判断仍由 worker 提供的 filter 完成。

### 3.7 Visual 边界

`VillagerVisual.gd` 不再直接 match 职业字符串。

它应监听：

```gdscript
profession_changed(profession: ProfessionDefinition)
```

再读取 `ProfessionDefinition` 的视觉字段；后续可替换为 `profession.visual_profile` 或 `VisualCapability`。

---

## 4. 设计原则

| 原则 | 体现 |
|------|------|
| 数据驱动 | 职业定义存在 `.tres` 中，新增职业优先新增资源 |
| 开闭原则 | 新职业通过新 `ProfessionDefinition` + 能力组合扩展，不改 Villager 主状态机 |
| TaskBoard 无玩法知识 | 职业任务资格由 worker/filter 判断 |
| 能力组合优先 | 职业不是类继承树，而是能力组合 |
| 实体拥有自身状态 | HP、移动、当前职业仍由 Villager 拥有 |
| UI/表现不拥有玩法 | Visual 读取职业视觉数据，不决定职业逻辑 |

---

## 5. 不采纳的方案

| 方案 | 不采纳原因 |
|------|------------|
| 每个职业一个 Villager 子类 | Godot 场景和脚本数量膨胀，职业间共享移动/任务/死亡逻辑困难 |
| 在 `Villager.gd` 中继续 `match _tool_type` | 职业越多，状态机越难维护，违反单一职责 |
| 中央 ProfessionManager 管所有职业行为 | 容易变成上帝对象，违背 NPC 自治和实体状态所有权 |
| TaskBoard 直接按职业筛任务 | 破坏 ADR-001，TaskBoard 会开始理解玩法规则 |
| 用 group 表示职业 | group 适合运行时契约，不适合承载属性、能力和视觉数据 |

---

## 6. 后果

### 6.1 收益

- 新增职业主要是新增 `.tres` 和可复用能力模块。
- Villager 状态机保持通用，不因职业数量线性膨胀。
- 职业属性、视觉和能力可以被素材/数值工作流独立维护。
- Archer 特例可以收敛为 `CombatCapability`。
- 农民、猎人、工匠、武士可共享同一套职业分配流程。

### 6.2 代价

- 引入 Resource 数据层，前期文件数量增加。
- 能力模块接口需要保持克制，否则会变成半套 ECS。
- 初次迁移需要把 `_tool_type`、`tool_changed`、`VillagerVisual`、`JobPoint` 统一改造。

### 6.3 风险

- 过早抽象能力模块可能超过 MVP 需要。缓解方式：只实现当前需要的能力，接口保持小。
- `ProfessionCapability` 如果拿到过多 worker 私有状态，会重新制造耦合。缓解方式：能力只调用 worker 公开方法。
- `.tres` 数据如果缺校验，会出现空职业或无效能力。缓解方式：JobPoint 和 Villager 在赋值时做 null 检查并报警。

---

## 7. 实施计划

按顺序实施，每步都应可独立验证：

1. 新建 `ProfessionDefinition.gd` 和 `ProfessionCapability.gd`。
2. 新建 `resources/professions/`，先迁移现有 `builder` / `archer` 两个职业数据。
3. `JobPoint.gd` 从 `tool_type` 改为 `profession`。
4. `Villager.gd` 增加 `_profession`、`assign_profession()`、`profession_changed` 信号。
5. `_can_do_task()` 改为询问职业定义/能力，而不是 match `_tool_type`。
6. 将 archer 战斗分支迁入 `CombatCapability`，保持现有行为不变。
7. `VillagerVisual.gd` 改为读取职业视觉配置。
8. 清理 `_tool_type` 和 `tool_changed` 的旧路径，必要时保留兼容函数但标记为过渡。
9. 跑回归手测：招募、拿锤、建墙、拿弓、射击、死亡、任务释放。

---

## 8. 架构约束

- 新职业不得直接修改 `TaskBoard.gd`。
- 新职业不得要求 `Villager.gd` 新增职业名判断。
- 新职业若只改变数据，应只新增 `.tres`。
- 新职业若需要新行为，应新增或复用 `ProfessionCapability`。
- 新能力跨越多个系统时，应新增 ADR 或修订本 ADR。

---

## 9. 未决问题

以下属于玩法/数值设计，不在本 ADR 中决定：

- 农民具体生产什么。
- 猎人与当前 Archer 的关系是替代、升级还是并存。
- 工匠与 Builder 的关系是同一职业、升级职业还是不同分工。
- 武士的攻击方式、站位、目标优先级。
- 职业是否有等级、经验、转职链。

这些问题由玩法设计决定；架构只保证它们能以数据和能力模块方式扩展。
