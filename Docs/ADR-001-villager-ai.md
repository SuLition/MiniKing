# ADR-001: Villager AI 与任务调度系统

**状态**: 已采纳
**日期**: 2026-06-06
**关联里程碑**: M3 收尾 + M6 收尾

---

## 1. 背景

### 1.1 现状
当前 NPC 系统由三块组成：

| 模块 | 职责 |
|------|------|
| `Villager.gd` | 单个村民的状态机（7 个状态）和移动 |
| `JobManager.gd` | 监听 `tool_available` 和 `became_idle`，撮合"空闲村民 ↔ 工具" |
| `ConstructionManager.gd` | 监听 `construction_ordered` 和 `became_builder_available`，撮合"建造工 ↔ 工地" |

### 1.2 暴露的问题
1. **村民必须先回家才能干活**。`set_home_position()` 把村民锁进 `MOVING_TO_HOME` → `IDLE`，工具放在距离营地 200px 处时也要先走回中心。
2. **两个 Manager 是同一个模式的拷贝**。每加一种任务（修墙、运金币、巡逻）就要再写一个 Manager。
3. **Push 模型违背 GDD 设计支柱**。GDD §2 写明"臣民自动工作，玩家负责安排方向"。当前实现是 Manager 推任务给村民，村民被动接受——和"自动"的语义反向。
4. **没有 idle 视觉表现**。村民没事时直接立正不动，缺少 GDD §2 提到的"生活感"。

### 1.3 触发因素
M6 闭环已通，接下来要补 M3 的 Archer 系统。如果继续沿用 push 模型，将再增加一个 `ArcherManager.gd`，重复问题会从 2 倍变成 3 倍。**这是修正架构的最后窗口**。

---

## 2. 决策

### 2.1 模式
采用 **Pull-based 任务面板 (TaskBoard) 模式**：
- 任务发布者（HammerStand、BuildSite 等）主动把任务挂上 TaskBoard
- NPC 自己 poll TaskBoard，按自身能力筛选 + 距离排序，原子领取一个任务
- 任务完成后从面板移除

### 2.2 模块划分

```
Autoload
└── TaskBoard.gd            # 全局任务面板（单例）
    ├── post_task(task)
    ├── claim_nearest(filter, position) → Task | null
    ├── complete_task(task)
    └── release_task(task)

scripts/ai/
└── Task.gd                 # 任务数据类（RefCounted）
    enum Kind { TOOL_PICKUP, CONSTRUCTION }
    var kind, position, provider, payload, claimed

scripts/npc/
└── Villager.gd             # 重写状态机：IDLE / WANDER / SEEK / WORK
                            # IDLE 周期性 poll TaskBoard

scripts/jobs/
└── JobPoint.gd             # 改用 TaskBoard.post_task 发布工具任务

scripts/construction/
└── BuildSite.gd            # 改用 TaskBoard.post_task 发布建造任务

# 删除
scripts/jobs/JobManager.gd
scripts/construction/ConstructionManager.gd
```

### 2.3 Villager 状态机

```
       ┌─────────────────────────────────────┐
       │                                     │
       ▼                                     │
    ┌──────┐  task found  ┌──────┐  arrived ┌──────┐  done
    │ IDLE │ ───────────→ │ SEEK │ ───────→ │ WORK │ ───→ (回 IDLE)
    └──┬───┘              └──────┘          └──────┘
       │ no task > 2s
       ▼
    ┌────────┐  task found
    │ WANDER │ ───────────→ (回 IDLE 准备 SEEK)
    └────────┘
       │ wander 走完一段
       ▼
    (回 IDLE)
```

**IDLE**：每 0.5 秒 poll 一次 TaskBoard。无任务超过 2 秒进 WANDER。
**WANDER**：在 `_home_position.x ± 60` 范围随机走，每走完一段歇 1 秒，期间持续 poll。
**SEEK**：径直走向 `task.position`，到达后进 WORK。
**WORK**：把控制权交给 task.provider（调用 `provider.start_work(self, task)`），等 provider 调 `finish_work` 回 IDLE。

### 2.4 任务能力筛选
Villager 持有 `_tool_type: StringName`：
- `&""`（无工具）→ 只领 `TOOL_PICKUP`
- `&"builder"`（持锤）→ 只领 `CONSTRUCTION`
- `&"archer"`（持弓）→ 不走任务系统，进入自治战斗（后续 ADR）

筛选用 `Callable` 传给 TaskBoard，TaskBoard 不知道具体规则，只做匹配。

### 2.5 招募流程修正
`RecruitCamp` 不再 `set_home_position` 触发"先回家"。改为：
- 生成 Villager 时直接给 `_home_position`（用于 WANDER 范围中心）
- 初始状态就是 IDLE，立刻开始 poll

---

## 3. 设计原则

| 原则 | 体现 |
|------|------|
| 任务发布者不知道 NPC 存在 | HammerStand 只调 `TaskBoard.post_task`，不查任何村民 |
| NPC 不知道任务发布者类型 | Villager 只 `TaskBoard.claim_nearest`，不引用 HammerStand / BuildSite |
| TaskBoard 不知道游戏规则 | 不判断"什么村民能领什么任务"，规则由 Villager 传入 filter |
| 状态机封闭在 Villager 内 | 外部只能通过 task 完成回调 / 信号影响状态 |
| 原子领取 | `claim_nearest` 内部置 `task.claimed = true` 后返回，无竞态 |

---

## 4. 后果

### 4.1 收益
- 加新任务类型 = 加一个 `Task.Kind` 枚举 + 任务发布者，**不动 NPC 代码**
- 加新 NPC 类型 = 加一个 filter，**不动任务发布者代码**
- 删 2 个 Manager 文件 + 一堆 main.tscn 信号连线
- NPC 行为有"生活感"（WANDER）
- 整个系统能在不读 main.tscn 的情况下读懂

### 4.2 代价
- 引入 Autoload 单例（多一个全局依赖；但 ResourceManager 已开此先例）
- Villager 多一个 `_process` 计时器开销（每 0.5s poll，可忽略）
- 一次性把 push 模型全部拆掉，**改动面较大**（约 5 个文件 + main.tscn 信号清理）

### 4.3 风险
- TaskBoard 是全局可见的——任何脚本都能 post 任务。需要约定：**只有挂 `task_provider` group 的节点才允许 post**（口头约定，不强制）。
- WANDER 让村民乱跑，可能挡道。先做最简版（随机 X 漂移），若手测发现挡玩家或挡 Greed，再加避让。

---

## 5. 不采纳的方案

| 方案 | 不采纳原因 |
|------|----------|
| 行为树 (Behavior Tree) | NPC 行为太简单，BT 是过度工程 |
| Utility AI | 当前只有 2 种 NPC，没必要做评分系统 |
| GOAP | 杀鸡用牛刀 |
| 继续 push 模型，只删 home 步骤 | 没解决重复 Manager 问题；以后还得改 |
| 中央 NPC Director | 又一个上帝对象，违背 NPC 自治 |

---

## 6. 实施计划

按顺序，每步可独立 commit / 验证：

1. **新建 `Task.gd`**（数据类，无依赖）
2. **新建 `TaskBoard.gd`** 并注册为 Autoload
3. **改 `JobPoint.gd`**：在 `_try_buy_tool` 成功后 `TaskBoard.post_task`
4. **改 `BuildSite.gd`**：在确认建造时 `TaskBoard.post_task`
5. **重写 `Villager.gd` 状态机**：IDLE/WANDER/SEEK/WORK + poll 逻辑
6. **改 `RecruitCamp.gd`**：删 `set_home_position` 的强制 MOVING_TO_HOME
7. **删 `JobManager.gd` 和 `ConstructionManager.gd`**
8. **清理 `main.tscn`**：删两个 Manager 节点 + 相关 signal connections + 注册 TaskBoard autoload
9. **手测**：招募一个村民 → 应该立刻原地待命/漂移；按 E 买锤 → 村民自动走过去拿；下建造单 → 村民自动去建

---

## 7. 未决问题

- **多个空闲村民同时 poll，会不会都奔向同一个任务？** → `claim_nearest` 原子，第二个会拿到 `null`，回 IDLE 继续 poll。OK。
- **Archer 持弓后能不能也领任务？** → ADR-002 处理。当前先让 archer 进入自治战斗状态，不走任务系统。
- **WANDER 是否要避开 Greed？** → 先不做。Greed 接触村民应该有逻辑（偷金币或杀村民），那是另一个系统。
