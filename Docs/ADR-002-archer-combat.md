# ADR-002: Archer 自治战斗与投射物系统

**状态**: 已采纳
**日期**: 2026-06-06
**关联里程碑**: M3 收尾
**依赖**: ADR-001

---

## 1. 背景

ADR-001 §7 留了一个未决问题：**Archer 持弓后能不能领任务？** 当时给的答案是"先让 archer 进入自治战斗状态，不走任务系统"。本 ADR 把这个决定落实。

GDD §5.3 对 Archer 的定义：
> 来源：领取弓
> 行为：白天可产生少量金币；夜晚攻击靠近的 Greed

GDD §10 给的数值：
- 弓成本：2 coins
- Greed HP：3
- Greed 攻击：1 damage/sec

---

## 2. 决策

### 2.1 总体方向
Archer 不走 TaskBoard。持弓后 Villager 进入 **自治战斗状态**，每帧自己扫描射程内的 Greed，按间隔射箭。

理由：
- 战斗是"持续行为"，不是"离散任务"。强行包装成 Task 反而别扭
- TaskBoard 是为"有限可数的待办"设计的（拿这把锤、建这堵墙）。战斗目标动态变化、可能无限多
- 自治战斗与"建造任务"职责正交，互不污染

### 2.2 子系统拆分

```
scripts/ai/
└── (已有) Task.gd, TaskBoard.gd

scripts/combat/          (新)
├── Arrow.gd             # 投射物：线性飞行 + Area2D 命中检测
└── (没有 CombatManager — 没有中央对象)

scripts/enemies/
└── Greed.gd             # 加 HP 字段 + apply_damage 方法（沿用 Wall.gd 模式）

scripts/npc/
└── Villager.gd          # 加 ARCHER 分支：扫描 + 射击；不动 IDLE/WANDER/SEEK/WORK

scripts/jobs/
└── JobPoint.gd          # 不动 — BowStand 直接复用，仅 export 改 tool_type="archer"

scenes/jobs/
└── BowStand.tscn        # 新场景，clone HammerStand 模板

scenes/combat/           (新)
└── Arrow.tscn
```

### 2.3 Villager 状态机扩展

**修订（基于手测反馈）**：原方案让 Archer 持弓后永远站定（ARCHER_GUARD），缺乏"工人感"。改为 Archer 复用 Builder 的 IDLE / WANDER 循环，仅在敌人入射程时切入 COMBAT 状态。

新增 1 个状态：**COMBAT**（替代 ARCHER_GUARD，仅 archer 进入）。

状态流转：
```
finish_work() (archer)
  → IDLE
       ↓ no enemy + 2s
       WANDER ←─────────┐
       ↓ enemy detected │
       COMBAT           │
       ↓ no enemy        │
       IDLE  ───────────┘
```

**IDLE/WANDER 对 archer 的差异**：
- _process_idle 和 _process_wander 内的周期 poll：
  - 非 archer：调 `_try_claim_task()`（TaskBoard）
  - archer：调 `_try_engage_combat()`（扫描 group "greed"）
- WANDER 行为本身不变：在 `_home_position ± wander_radius` 内随机走

**COMBAT 行为**（每帧）：
1. 站定（速度归零）
2. `_attack_timer` 倒数
3. timer 到 → 扫描 attack_range 内最近 Greed
   - 有目标 → 射箭，timer = attack_interval
   - 无目标 → 退回 IDLE（自然进入 WANDER 循环）

**为什么这样设计**：
- Archer 和 Builder 共享 IDLE/WANDER 机制，避免代码重复
- 状态机只多一个 COMBAT，不污染现有路径
- "有事时主动作战 / 无事时漫步" 符合 GDD §2「臣民自动工作」的设计支柱

### 2.4 Arrow 投射物设计

**单一职责**：朝目标点飞，命中 Greed 时造成伤害。

字段：
- `direction: Vector2`（标准化方向，初始化时计算一次）
- `speed: float`（默认 400 px/s）
- `damage: int`（默认 1）
- `max_lifetime: float`（默认 2 秒，防止飞出地图永不销毁）

碰撞：
- Arrow 是 `Area2D`（不参与物理碰撞，只检测进入）
- collision_mask 包含 Enemy layer
- `area_entered` / `body_entered` 触发 → 调 collider.apply_damage(damage) → queue_free()

**非追踪**：发射时拍一次方向就锁定，飞过去如果敌人移开就 miss。MVP 保持简单，将来再加追踪。

### 2.5 Greed HP 系统

复用 Wall.gd 模式（已经验证可行）：
- `@export var max_hp: int = 3`
- `hp_changed(current, max)` 信号
- `destroyed` 信号
- `apply_damage(amount: int)` 公开方法
- HP 归零 → emit destroyed → queue_free
- 视觉上变色（hp 越低越红，沿用 Wall 的渐变）

### 2.6 BowStand 场景
直接 clone HammerStand：
- 改 Stand 颜色为绿色调
- 改 HammerIcon 为 BowIcon（细长矩形 + 弦）
- 节点根挂 JobPoint.gd（同一脚本），export：
  - `tool_type = "archer"`
  - `display_name = "Bow"`
  - `cost = 2`

---

## 3. 设计原则

| 原则 | 体现 |
|------|------|
| 战斗系统不知道任务系统存在 | Arrow / Greed.apply_damage 不引用 TaskBoard |
| Archer 不知道 Arrow 实现细节 | Archer 只调 `arrow_scene.instantiate()` + 设置初始方向 |
| Arrow 不知道发射者类型 | Arrow 不持有 archer 引用，只关心目标方向 |
| Greed 不知道伤害来源 | apply_damage 不区分来自 Arrow / 玩家 / 其他 |
| BowStand 与 HammerStand 共脚本 | JobPoint.gd 不动，验证之前架构的通用性 |

---

## 4. 后果

### 4.1 收益
- 完成 M3，玩家有进攻手段
- 解锁 M7（巢穴用 Arrow 摧毁）
- Arrow 系统将来可被玩家武器、塔、巫师等复用（任何主动伤害源）
- Greed HP 系统让难度有调节空间（Greed 不再只能"被墙挡住"）

### 4.2 代价
- Villager.gd 状态数从 4 增到 5（COMBAT）
- IDLE / WANDER 内的 poll 分支随 _tool_type 走两条路径（可读性略降，但避免代码复制）
- 新增 scripts/combat/ 模块（虽小但又一个目录）
- Archer 漫步范围由 home_position 决定（recruitment 时设的中心点）——和 Builder 一样，目前所有 archer 都漫步在 KingdomCenter 周边

### 4.3 风险
- **Archer 站定可能位置不好**：如果 BowStand 在地图中间，Greed 从两侧来时其中一侧可能超出射程。MVP 接受这个限制；后续可加"塔"系统让 Archer 移动到塔上
- **Arrow 飞行性能**：场上同时几十支箭可能成为问题。MVP 不优化，先看实测
- **没有 Archer 死亡机制**：Greed 接触 Archer 时不会杀死他（Archer 不在 _try_steal_from_player 的处理路径上）。MVP 接受；后续可加

---

## 5. 不采纳的方案

| 方案 | 不采纳原因 |
|------|----------|
| Archer 走 TaskBoard（每个 Greed 是一个任务）| Greed 死了任务也消失，频繁 post / complete 浪费；且无法处理射程概念 |
| Archer 移动到"塔"位置 | 需要新的 Tower 建筑系统（GDD §5.4 明确推迟到第二阶段）|
| Arrow 追踪目标 | MVP 不需要；未追踪箭让玩家可观察到 miss，反而增加策略性 |
| 中央 CombatManager 撮合 Archer 和 Greed | 又一个上帝对象，违背"自治"原则 |
| 把战斗逻辑塞进 Villager.gd 主循环 | 可以但代码会膨胀；ADR-002 选择 ARCHER_GUARD 单独分支保留可读性 |
| Archer 白天产币也走本 ADR | 范围太广；本 ADR 只覆盖战斗。白天产币留给后续小迭代 |

---

## 6. 实施计划

按依赖顺序，每步可独立验证：

1. **Greed HP**：加 max_hp / hp / apply_damage / destroyed 信号
2. **Arrow 场景与脚本**：能从一点直线飞向另一点，命中 Greed 扣血
3. **BowStand 场景**：clone HammerStand，参数改 archer/Bow/2
4. **main.tscn 加 BowStand 节点**（玩家场上能交互）
5. **Villager.gd 扩展**：tool_changed 到 "archer" 时进 ARCHER_GUARD；该状态扫描 + 射箭
6. **手测**：买弓 → 村民拿弓 → 站定变绿色 Archer → Greed 进入射程 → 射箭 → Greed 死

**估计总时长 2 小时**。

---

## 7. 未决问题

- **Archer 白天产币**：本 ADR 不实现。后续可加每 N 秒 ResourceManager.add_coins(1) 的简单逻辑
- **Archer 死亡**：Greed 当前不主动攻击 Archer。如果 Archer 在 Greed 行进路径上，要不要被推开 / 杀死？MVP 暂不处理
- **Arrow 视觉**：MVP 用细长 ColorRect。后续美术可换 sprite
- **射击方向受地形影响**：Arrow 是 Area2D，会穿墙穿地形。MVP 接受；可后续加 raycast 检查
