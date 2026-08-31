---
AIGC:
  ContentProducer: '001191110102MAD55U9H0F10002'
  ContentPropagator: '001191110102MAD55U9H0F10002'
  Label: '1'
  ProduceID: '71f43065-9530-4464-8975-de99d7e4743e'
  PropagateID: '71f43065-9530-4464-8975-de99d7e4743e'
  ReservedCode1: 'c4f84524-113e-4621-a48d-fe22152c0cab'
  ReservedCode2: 'c4f84524-113e-4621-a48d-fe22152c0cab'
---

# SC→FA 战役移植兼容性审计报告

## 审计范围

- SC 原版 `lua.scd` vs FA `lua.scd` 中所有系统 Lua 文件的函数差异
- SC 战役地图脚本（`SC_Campaign_Main.scd/maps/`）中对缺失函数的调用
- 20 个 `*_script.lua` 文件 + 259 个 `.lua` 文件全量扫描

---

## 一、platoon.lua 方法对比

### SC 有但 FA 没有的方法（11 个）

| # | 方法名 | 地图脚本调用 | 状态 |
|---|--------|------------|------|
| 1 | `AirCraftStagingAI` | 无 | 安全 |
| 2 | `ClosestUnitAI` | 无 | 安全 |
| 3 | `EngineerAI` | 无 | 安全 |
| 4 | `HighestThreatAI` | 无 | 安全 |
| 5 | `LandFactoryInfiniteBuild` | 无 | 安全 |
| 6 | `MassExtractorHunterAI` | 无 | 安全 |
| 7 | `NavalPatrolAI` | 无 | 安全 |
| 8 | **`PatrolLocationFactoriesAI`** | **12 处调用，7 个地图** | **已知，已修复** |
| 9 | `PatrolNearbyDefensiveAreaAI` | 无 | 安全 |
| 10 | `ScoutStartLocations` | 无 | 安全 |
| 11 | `SubCommanderAssistAI` | 无 | 安全 |

### PatrolLocationFactoriesAI 调用位置（已修复）

| 文件 | 行号 |
|------|------|
| `SCCA_A03/SCCA_A03_script.lua` | 707, 765, 774, 813 |
| `SCCA_A05/SCCA_A05_script.lua` | 969, 1138 |
| `SCCA_A06/SCCA_A06_script.lua` | 1080 |
| `SCCA_E01/SCCA_E01_script.lua` | 869 |
| `SCCA_E02/SCCA_E02_script.lua` | 2079 |
| `SCCA_E03/SCCA_E03_script.lua` | 141 |
| `SCCA_R06/SCCA_R06_script.lua` | 166, 263 |

---

## 二、ai/aibehaviors.lua 函数对比

### SC 有但 FA 没有的函数（17 个）

| # | 函数名 | 地图脚本调用 | 状态 |
|---|--------|------------|------|
| 1 | **`CDROverchargeBehavior`** | **3 处调用** | **已修复（schook 转发）** |
| 2-17 | `CDRCallForHelp`, `CDRCallForHelpThread`, `CDRGiveUpBehavior`, `CDRGiveUpThread`, `CDRLeash`, `CDRLeashThread`, `CDROverChargeThread`, `CDRRepairBuildingUnit`, `CDRRunAwayBehavior`, `CDRRunAwayThread`, `FatBoy_uel0111AIThread`, `FatBoy_uel0202AIThread`, `FatBoy_uel0205AIThread`, `FatBoy_uel0307AIThread`, `FatBoy_uel0309AIThread`, `FatBoyUnitDeath` | `CDRLeashThread`/`CDROverChargeThread`/`CDRRunAwayThread` 在 SCCA_E05 中通过 `opbehaviors.lua` 调用（安全） | 安全 |

### CDROverchargeBehavior 调用详情

| 文件 | 行号 | import 路径 | FA 中是否存在 | 状态 |
|------|------|------------|-------------|------|
| `SCCA_E04/SCCA_E04_script.lua` | 483 | `/lua/ai/AIBehaviors.lua` | **否** | **已修复（schook 转发）** |
| `SCCA_R01/SCCA_R01_script.lua` | 1182 | `/lua/ai/opai/opbehaviors.lua` | 是 | 安全 |
| `SCCA_R05/SCCA_R05_script.lua` | 1148 | `/lua/ai/AIBehaviors.lua` | **否** | **已修复（schook 转发）** |

> **说明**：FA 的 `ai/opai/OpBehaviors.lua` 中**有** `CDROverchargeBehavior` 函数，但 FA 的 `ai/AIBehaviors.lua` 中**没有**。SCCA_E04 和 SCCA_R05 从 AIBehaviors.lua 导入该函数，会导致运行时错误。

---

## 三、其他系统文件对比

### ScenarioFramework.lua
- SC: 123 个函数，FA: 139 个函数
- **SC-only 函数: 0 个** — FA 是 SC 的超集，完全兼容

### ScenarioPlatoonAI.lua
- SC: 44 个函数，FA: 47 个函数
- **SC-only 函数: 0 个** — 完全兼容

### aibrain.lua
- SC: 142 个函数，FA: 174 个函数
- SC-only 函数 9 个：`EvaluateArmies`, `FindWeakestEnemyFromCat`, `ForceNewEnemy`, `ForceNewVectors`, `GetBrainStrengthTable`, `GetHighestInfluence`, `GetInfluenceAtPosition`, `GetNearestInfluencePoint`, `InfluenceThreadFunction`
- **地图脚本调用: 0 个** — 安全

### ai/aiutilities.lua
- SC: 40 个函数，FA: 61 个函数
- SC-only 函数 1 个：`CheckUnitPathing`（FA 改名为 `CheckUnitPathingEx`）
- **地图脚本调用: 0 个** — 安全

### ai/aibuildstructures.lua
- SC: 18 个函数，FA: 24 个函数
- **SC-only 函数: 0 个** — 完全兼容

### defaultunits.lua
- SC: 69 个函数，FA: 70 个函数
- SC-only 函数 4 个：`ApplyAdjacencyBonus`, `CanRecieveAdjacencyBonus`, `GetAdjacentBonus`, `SetAdjacencyBonus`
- **地图脚本调用: 0 个** — 安全（FA 用 Buff 系统替代了邻接加成）

### ai/opai/OpBehaviors.lua
- SC 和 FA 均有 5 个相同函数：`CDROverchargeBehavior`, `CDROverChargeThread`, `CDRRepairBuildingUnit`, `CDRLeashThread`, `CDRRunAwayThread`
- **完全兼容**

---

## 四、地图脚本中所有 `:Method()` 调用 vs FA platoon.lua

从 259 个地图 Lua 文件中提取了 122 个唯一的 `:MethodName()` 调用。

其中只有 **`PatrolLocationFactoriesAI`** 是 SC platoon.lua 有而 FA platoon.lua 没有的方法。其余 121 个方法均为 C++ moho.platoon_methods 引擎方法或其他类（Unit、Brain 等）的方法，在 FA 中均存在。

---

## 五、需修复的地图汇总

| 地图 | 问题 | 修复方式 |
|------|------|---------|
| SCCA_A03 | `PatrolLocationFactoriesAI` (4处) | 已修复 |
| SCCA_A05 | `PatrolLocationFactoriesAI` (2处) | 已修复 |
| SCCA_A06 | `PatrolLocationFactoriesAI` (1处) | 已修复 |
| SCCA_E01 | `PatrolLocationFactoriesAI` (1处) | 已修复 |
| SCCA_E02 | `PatrolLocationFactoriesAI` (1处) | 已修复 |
| SCCA_E03 | `PatrolLocationFactoriesAI` (1处) | 已修复 |
| SCCA_R06 | `PatrolLocationFactoriesAI` (2处) | 已修复 |
| **SCCA_E04** | **`CDROverchargeBehavior` (1处, 行483)** | **已修复** |
| **SCCA_R05** | **`CDROverchargeBehavior` (1处, 行1148)** | **已修复** |
| SCCA_R01 | `CDROverchargeBehavior` (1处, 行1182) | 安全（从 opai/opbehaviors.lua 导入） |

---

## 六、推荐修复方案

### 方案 A：通用兼容层（推荐）

在 `SC_Campaign_Main.scd/lua/` 或 `schook/lua/` 中创建兼容补丁，将 SC 原版缺失的函数添加到 FA 的对应文件中：

1. **PatrolLocationFactoriesAI** — 已通过通用兼容层修复（将 SC 的实现注入 FA 的 platoon.lua）

2. **CDROverchargeBehavior** — 已在 `schook/lua/ai/AIBehaviors.lua` 中添加兼容入口，转发到 FA 的 `ai/opai/OpBehaviors.lua` 中的同名增强版函数：
   ```lua
   -- schook/lua/ai/AIBehaviors.lua
   CDROverchargeBehavior = import('/lua/ai/opai/OpBehaviors.lua').CDROverchargeBehavior
   ```

### 方案 B：逐个修补地图脚本

将 SCCA_E04:483 和 SCCA_R05:1148 的 import 路径从 `/lua/ai/AIBehaviors.lua` 改为 `/lua/ai/opai/opbehaviors.lua`：
```lua
-- 修改前
import('/lua/ai/AIBehaviors.lua').CDROverchargeBehavior(cdrPlatoon)
-- 修改后
import('/lua/ai/opai/opbehaviors.lua').CDROverchargeBehavior(cdrPlatoon)
```

### 推荐选择

**方案 A（通用兼容层）** 更稳健，因为：
- 不需要修改每个地图脚本
- 未来若发现更多类似问题，可统一在兼容层处理
- 与已有的 `PatrolLocationFactoriesAI` 修复方式一致
- schook 机制是 FA 原生支持的 hook 方式，不会覆盖 FA 原文件

---

## 七、已确认安全的系统文件

以下文件 SC 战役脚本会 import，且 FA 中完全兼容（无 SC-only 函数缺失）：

- `/lua/ScenarioFramework.lua` — 完全兼容
- `/lua/ScenarioPlatoonAI.lua` — 完全兼容
- `/lua/ai/aibuildstructures.lua` — 完全兼容
- `/lua/ai/opai/OpBehaviors.lua` — 完全兼容
- `/lua/sim/ScenarioUtilities.lua` — 由 `mohodata.scd` 提供，SC 和 FA 均有
- `/lua/sim/VizMarker.lua` — 由 `mohodata.scd` 提供，SC 和 FA 均有
- `/lua/ai/opai/basemanager.lua` — FA 独有，SC 没有（由 FA lua.scd 提供）

---

## 八、修复执行记录

### 已完成的修复

1. **PatrolLocationFactoriesAI**（之前已修复）
   - 7 个地图、12 处调用，通过通用兼容层注入 SC 实现到 FA 的 platoon.lua

2. **CDROverchargeBehavior**（本次修复）
   - 创建 `schook/lua/ai/AIBehaviors.lua`，转发到 FA 的 `ai/opai/OpBehaviors.lua` 中的增强版实现
   - 覆盖 SCCA_E04:483 和 SCCA_R05:1148 两处调用
   - 转发到的 FA 版本支持 CDRData（LeashPosition/LeashRadius/RunAway），比 SC 原版仅启动 OverchargeThread 功能更完整

### 补充审计结论

- **mohodata.scd 中的文件**：`sim/VizMarker.lua`、`sim/ScenarioUtilities.lua` 等文件位于 `mohodata.scd` 而非 `lua.scd`，SC 和 FA 均提供，无需修复
- **SCCA_E05_aeonplan1.lua**：使用 `/lua/modules/` 路径导入，但该文件是孤立文件（不被任何 planlist 或 save 引用），不会在运行时加载，无需修复
- **SCCA_E05 的 CDR 线程函数**：`CDROverChargeThread`、`CDRLeashThread`、`CDRRunAwayThread` 通过 `opbehaviors.lua` 导入，FA 的 OpBehaviors.lua 包含这些函数，安全
- **所有 259 个地图 Lua 文件全量扫描**：除已修复的 `PatrolLocationFactoriesAI` 和 `CDROverchargeBehavior` 外，无其他 SC-only 函数被调用

### 修复文件清单

| 文件 | 说明 |
|------|------|
| `schook/lua/ScenarioFramework.lua` | 已有：EndOperation SC/FA 签名兼容 |
| `schook/lua/ai/AIBehaviors.lua` | **新增**：CDROverchargeBehavior 转发到 OpBehaviors.lua |
| `schook/lua/platoon.lua` | **新增**：PatrolLocationFactoriesAI 注入到 FA Platoon 类 |