# 战役 Lua 兼容性全面检查报告

- 日期：2026-11-09
- 范围：`SCFA-Original-Campaign/SC_Campaign_Main.scd`（19 张地图 / 259 个 lua）+ 8 个 schook 文件
- 目标：找出"SC 原版有、FA 没有"的 API，以及因此导致的运行时 Lua 错误

---

## 一、检查方法

对以下 6 类逐一做差集/交叉验证，而不是靠猜测：

1. **语法体检**：8 个 schook 文件的注释符、块结构、括号配平
2. **import 可达性**：50 条 `import()` 路径逐条在 FA 的 lua 搜索路径里解析
3. **模块函数差集**：SC 原版 lua 与 FA lua 的同名模块（platoon / AIBehaviors /
   ScenarioFramework / ScenarioPlatoonAI / SimObjectives / ScenarioStrings /
   ScenarioUtils / aibuildstructures / aibuildunits / aiutilities / simcamera /
   cinematics / utilities / weather / EffectTemplates）逐个比对函数名
4. **符号级差集**：SC 全树 6211 个全局符号 vs FA 全树 30127 个，取"仅在 SC 存在"
   的 659 个，再反向检索战役脚本的活代码引用（已剥离 `--`、`--[[ ]]`、`#` 注释）
5. **platoon 方法调用**：提取全部 `xxx:Method()` 并与 SC+FA 的 platoon 方法表比对
6. **日志实证**：以 `game_uef_1-3.log` / `game_uef_4-BUG.log` 的运行时错误为准，
   校正静态分析结论

---

## 二、确认的真实 BUG

### BUG 1：`PatrolLocationFactoriesAI` 缺失 —— 12 处调用 / 7 张地图

| 地图 | 调用处 |
|------|--------|
| SCCA_E01 | `SCCA_E01_script.lua:869` |
| SCCA_E02 | `SCCA_E02_script.lua:2079` |
| SCCA_E03 | `SCCA_E03_script.lua:141` |
| SCCA_A03 | `SCCA_A03_script.lua:707 / 765 / 774 / 813` |
| SCCA_A05 | `SCCA_A05_script.lua:969 / 1138` |
| SCCA_A06 | `SCCA_A06_script.lua:1080` |
| SCCA_R06 | `SCCA_R06_script.lua:166 / 263` |

- SC 的 `lua/platoon.lua:546` 定义了它，FA 的 `lua/platoon.lua` 完全没有
- 运行时表现：`attempt to call method 'PatrolLocationFactoriesAI' (a nil value)`
- 后果：调用该方法的 AI 线程整条中断，后续逻辑（含任务目标注册）不再执行

### BUG 2：三个 `GenericReminder` 对话表缺失 —— 37 处引用 / 8 张地图

| 变量 | 引用数 | 地图 |
|------|--------|------|
| `AeonGenericReminder` | 9 | A02(4), A03(2), A06(3) |
| `CybranGenericReminder` | 23 | R02(7), R03(7), R04(5), R05(4) |
| `UEFGenericReminder` | 5 | E02(2), E03(3) |

- SC 的 `lua/ScenarioStrings.lua:110-116` 有定义，FA 版本只剩 21 个变量，这 3 个被删
- 崩溃链路：
  ```
  ScenarioFramework.Dialogue( ScenarioStrings.UEFGenericReminder )   -- 传 nil
    -> table.deepcopy(nil)  == nil
    -> dTable.Callback = callback                                   -- 索引 nil，硬崩
  ```
- 触发条件：玩家在某个任务上停留、第二次收到"提醒"对话时（提醒有 A/B 交替逻辑）。
  这就是"卡关一会儿就报错/卡死"的隐性问题
- 好消息：`<LOC E01_M01_060_010>` 等三个本地化键在
  `SC_Campaign_Main_Localization.scd/lua/sc_campaign/loc/*/strings_db.lua`
  **全部存在且含中文译文**，只缺表绑定

### BUG 3：`CDROverchargeBehavior` 走错模块 —— 2 处 / 2 张地图

| 地图 | 调用处 | 写法 |
|------|--------|------|
| SCCA_E04 | `SCCA_E04_script.lua:483` | `import('/lua/ai/AIBehaviors.lua').CDROverchargeBehavior` |
| SCCA_R05 | `SCCA_R05_script.lua:1148` | 同上 |

- FA 把该函数从 `AIBehaviors.lua` 移到了 `lua/AI/OpAI/OpBehaviors.lua`
- 其余 6 处调用（A03/A05×2/A06/E01/E02）本来就走 `OpBehaviors`，**没有**问题
- E04 的后果链：`StartMission2()` 在 483 行崩溃 → 后面的研究设施生成（504）、
  `M2P1` 占领任务（513）、`M2P3` 击杀任务（526）全部不执行
  → 玩家感受就是"占领完实验室、对话播完，再也没新任务"

---

## 三、根因修正（重要，推翻了上一轮的两个判断）

### 3.1 `#` 注释不是 bug

上一轮把 `schook/lua/ai/AIBehaviors.lua` 的 `#` 注释判为"非法 Lua、文件从未执行"。
**这个判断是错的。**

证据：
- SC 原版 `lua/` 下有 132 个文件、FA 的 `lua.scd` 解包里有 203 个文件使用行首 `#` 注释，
  游戏正常运行
- 官方 `gamedata/02_sorian_ai_pack.scd/schook/lua/AI/AIBehaviors.lua` 里
  `#LOG('*NukeCheck Starting')`、`# used by engineers...` 就在**活代码**中间
- 战役自己的 `SCCA_E04_script.lua:477-480` 也大量使用 `#`

结论：`#` 是 SC 引擎（LuaPlus）支持的注释方言，**地图脚本和 hook 文件里都合法**。
把它改成 `--` 是无害的规范化，但不是根因。

### 3.2 真正的根因：Sorian AI Pack 的同名 schook 覆盖了战役的 hook

日志里的挂载顺序：

```
行 106  gamedata/02_sorian_ai_pack.scd          mounted as '/'
行 144  scfa-original-campaign/sc_campaign_main.scd  mounted as '/'
```

两边都存在**完全相同的 VFS 路径**：

| 路径 | Sorian 版本 | 战役版本 |
|------|-------------|----------|
| `/schook/lua/platoon.lua` | 有 | 有 |
| `/schook/lua/AI/AIBehaviors.lua` | 有 | 有（`ai/` 仅大小写差异） |

引擎对同一 VFS 路径只解析到**一个**文件，所以：

- 日志确实有 `Hooked /lua/platoon.lua with /schook/lua/platoon.lua` —— 但那一条是
  **Sorian 的 hook**，不是战役的
- Sorian 的 `platoon.lua` 里 `PatrolLocationFactoriesAI` 出现次数 = **0**
- Sorian 的 `AIBehaviors.lua` 里 `CDROverchargeBehavior` 出现次数 = **0**

这解释了全部矛盾：补丁写对了、路径正确、日志有 Hooked，运行时却仍是 nil。

**对照证明**：`ScenarioFramework.lua` 的日志有 3 条不同来源的 Hooked 记录
（schook / blackopsacus / m28ai），因为它们的路径不同、可以共存；
而 `platoon.lua` 只有 1 条，因为路径撞车。

### 3.3 次要问题：`Platoon` 类不是实例的基类

FA 的 `Brain:MakePlatoon()` 用引擎基表 `moho.platoon_methods` 创建实例；
`class.lua` 的 `ConstructClass` 是**字段复制式**继承（`class.__index = class`，
没有指回 base 的 `__index` 链），Lua 层 `Platoon` 类从未被实例化。
所以方法必须挂到 `moho.platoon_methods`。

---

## 四、已排除的误报（逐条验证过，不是 bug）

| 项目 | 表面现象 | 实际原因 |
|------|----------|----------|
| `/lua/modules/*`、`/lua/ScenarioUtilities.lua` 等 7 条 import | 找不到文件 | 全部位于 `SCCA_E05_aeonaiplan1.lua` 的 `--[[ ]]` 块注释内，且该 plan 文件从未被加载 |
| `ScenarioFramework.Capture/Kill/Reclaim/...` | 模块里搜不到 | `import()` 返回 `_G`，这些是 `SimObjectives.lua` 里的裸全局函数，实际存在 |
| `ChevronFormation` / `TravellingFormation` / `StaggeredChevronFormation` | 全局符号差集命中 107/19/8 次 | 全是**带引号的字符串参数**（237 处 `'ChevronFormation'`），不是变量引用 |
| `AddObjective` / `RemoveObjective` | platoon 方法检测命中 | 属于 `Objectives.CreateGroup()` 返回的 ObjectiveGroup 对象，不是 platoon |
| `AggressiveMoveToLocation` / `GetSquadUnits` / `IsCommandsActive` / `IsPatrolling` 等 15 个 | platoon 方法表里找不到 | SC 全树也没有定义 → 属于 `moho` 引擎原生方法，两版都支持 |
| `TrackEntity` / `CheckUnitPathing` / `TAPDSHitLand01` / `TPlasmaCannonHeavyHitLand01` | 模块差集命中 | 战役脚本从未调用 |
| `ScenarioUtils`（11 个成员）/ `Objectives`（15 个成员） | —— | 全部存在，missing = 0 |
| `ScenarioFramework` / `ScenarioPlatoonAI` / `SimObjectives` 函数差集 | —— | missing = 0 |
| `E06_M02_055` / `M3MissionStartDialogue` | 找不到定义 | 位于 `#` 注释行内 |
| `M3GateTrigger` / `M2GateTrigger` | 找不到定义 | 是赋值（`ScenarioFramework.X = CreateAreaTrigger(...)`），不是引用 |
| `buff.lua(930) GetBaseHP` | 日志有报错 | TotalVeterancy mod，按约定忽略 |
| `m28ai` / `usermusic` / `IsAutoMode` | 日志大量报错 | mod / 引擎噪声，按约定忽略 |

---

## 五、已实施的修复

### 5.1 `schook/lua/ScenarioFramework.lua`（新增段落）

把 `PatrolLocationFactoriesAI`（SC `platoon.lua:546` 的原实现）挂到
`moho.platoon_methods`。选这个文件是因为它**没有路径冲突**（已验证 3 个来源的
hook 都能共存），且所有战役脚本都会 import 它。

### 5.2 `schook/lua/ScenarioStrings.lua`（新建）

补回 `UEFGenericReminder` / `CybranGenericReminder` / `AeonGenericReminder`
三个表，`text` 用 `<LOC ...>` 键 + SC 原文的 `vid/bank/cue/faction`。
Sorian 没有 hook 这个文件，不会冲突。

### 5.3 `maps/SCCA_E04/SCCA_E04_script.lua:483`（改调用点）

```lua
-- 原：import('/lua/ai/AIBehaviors.lua').CDROverchargeBehavior(cdrPlatoon)
local SC_OpBehaviors = import('/lua/AI/OpAI/OpBehaviors.lua')
if SC_OpBehaviors and SC_OpBehaviors.CDROverchargeBehavior then
    SC_OpBehaviors.CDROverchargeBehavior(cdrPlatoon)
end
```

### 5.4 `maps/SCCA_R05/SCCA_R05_script.lua:1148`（同上）

同样的改法。

### 5.5 `schook/lua/platoon.lua`（保留为 fallback）

内容不变（已挂 `moho.platoon_methods`），但头部加了说明：该路径会被 Sorian 的
同名 hook 遮蔽，主定义已迁到 `ScenarioFramework.lua`；卸载 Sorian 时本文件仍生效。

### 5.6 `schook/lua/ai/AIBehaviors.lua`（保留为 fallback）

`#` 已规范化为 `--`，并加了 `OpBehaviors` 存在性保护与 `_G` 兜底。
由于 5.3/5.4 已直接改调用点，这个文件不再是必需路径。

---

## 六、验证方法

schook 只在**启动时**合并，改完必须完全退出游戏再启动。

在 `game.log` 里搜索 `[SC Campaign]`：

| 期望日志 | 含义 |
|----------|------|
| `PatrolLocationFactoriesAI attached to moho.platoon_methods` | BUG 1 补丁已挂载 |
| `ScenarioStrings: restored UEF/Cybran/Aeon GenericReminder dialogue tables` | BUG 2 补丁已挂载 |
| `FAILED to attach ...` / `moho.platoon_methods unavailable` | 补丁未生效，需要换方案 |

实测建议：
1. **E04**：读档打到 M1 完成（占领 2 个实验室）→ 对话结束后应出现
   "占领研究设施 + 击杀 Cybran 指挥官"两个新任务
2. **E02**：故意在 M1P1 停留不动，等第二次提醒 → 不应报错
3. **A03**：进入任务后观察 AI 是否正常巡逻（4 处调用）
4. **R06**：同上（2 处调用）

---

## 七、统计

| 类别 | 数量 |
|------|------|
| 确认的真实 BUG | 3 类 |
| 受影响调用点 | 51 处（12 + 37 + 2） |
| 受影响地图 | 14 张（去重） |
| 排除的误报 | 12 类 |
| 修改/新建文件 | 6 个 |
