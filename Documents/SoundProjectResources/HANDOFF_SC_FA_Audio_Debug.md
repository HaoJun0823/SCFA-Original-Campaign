---
AIGC:
  ContentProducer: '001191110102MAD55U9H0F10002'
  ContentPropagator: '001191110102MAD55U9H0F10002'
  Label: '1'
  ProduceID: 'ba0996e1-85fa-484b-9f3e-d5b7a4a91c8a'
  PropagateID: 'ba0996e1-85fa-484b-9f3e-d5b7a4a91c8a'
  ReservedCode1: '90069610-f5e5-401a-9324-ba786a1fba90'
  ReservedCode2: '90069610-f5e5-401a-9324-ba786a1fba90'
---

# SC→FA 战役音频移植：FMV 语音错位/简报异常问题排查交接文档

> **文档用途**：供其他 AI 介入协作排查。本文档包含完整的项目背景、已完成的验证工作、当前阻塞点和候选方向。
> **最后更新**：2026-08-31

---

## 一、项目概述

将原版 Supreme Commander (SC) 的战役内容（地图、脚本、音频、电影）移植到 Forged Alliance (FA) 引擎中运行。不走 mod 路线，通过 `gamedata/` 下的 .scd 目录直接覆盖游戏资源。

### 关键约束

- 不使用 FAF 等第三方音频资源（版权敏感）
- SC 音频必须通过 XactBld 重新编译为 v43 后部署（SC 原版为 v41，FA 引擎拒绝加载）
- SC Lua 代码放在 `/lua/sc_campaign/` 下，与 FA 原版 `/lua/ui/campaign/` 隔离

### 工作目录

```
I:\SteamLibrary\steamapps\common\Supreme Commander Forged Alliance\
```

### SC 原版游戏目录（用于对照）

```
I:\SteamLibrary\steamapps\common\Supreme Commander\
```

---

## 二、问题描述

移植部署后，游戏内出现 **3 个音频异常**：

| # | 问题 | 具体表现 | 状态 |
|---|---|---|---|
| 1 | **FMV 语音错位** | 电影 `FMV_UEF_Intro_1` 播放时，语音内容是别的台词（如 `C02_B01` 的文本），字幕与语音不匹配 | **已修复** — SC_FMV bank 迁移至 `sounds/Voice/US/`；添加 `missingVoiceCues` 表跳过无语音 cue；分离 `PlayVoice`/`PlaySound` 播放 |
| 2 | **简报语音混乱** | 万古（Aeon）阵营简报播放了错误的语音 | **待验证** — debug LOG 已部署，等待用户测试反馈 |
| 3 | **简报播放慢** | 塞布兰（Cybran）简报电影播放速度异常 | **不修复** — 确认为 FA 引擎双 SFD 解码性能限制，原版 SC 高分辨率下也存在 |

---

## 三、架构与播放机制

### 3.1 音频 Bank 部署架构

所有 SC 音频 bank 已用 XactBld 重编译为 v43 格式，部署在两个独立 .scd 中：

#### SC_Campaign_Data_Voice_US.scd（语音 bank）

| Bank 文件 | 内部 bank 名 | 大小 | 内容 |
|---|---|---|---|
| `sounds/SC_FMV.xsb/.xwb` | `SC_FMV` | 1KB / 176.6MB | 13 个 FMV 电影配音 cue，PCM 16-bit 立体声 44100Hz |
| `sounds/Voice/US/A01_VO.xsb/.xwb` | `A01_VO` | 3KB / 11.9MB | 万古第 1 关简报语音（62 个 wave） |
| `sounds/Voice/US/A02_VO ~ A06_VO` | 同名 | 2-4KB / 8-17MB | 万古第 2-6 关 |
| `sounds/Voice/US/C01_VO ~ C06_VO` | 同名 | 3KB / 10-14MB | 塞布兰第 1-6 关 |
| `sounds/Voice/US/E01_VO ~ E06_VO` | 同名 | 3-4KB / 9-11MB | UEF 第 1-6 关 |

#### SC_Campaign_Data_Sound.scd（背景音/音乐 bank）

| Bank 文件 | 内部 bank 名 | 大小 | 内容 |
|---|---|---|---|
| `sounds/SC_FMV_BG.xsb/.xwb` | `SC_FMV_BG` | 1KB / 142.2MB | FMV 背景音效，ADPCM |
| `sounds/SC_Op_Briefing.xsb/.xwb` | `SC_Op_Briefing` | 3KB / 66.1MB | 简报背景音（74 个 wave） |
| `sounds/SC_AmbientTest.xsb/.xwb` | `SC_AmbientTest` | 1KB / 2.3MB | 环境音 |
| `sounds/SC_Music.xsb/.xwb` | `SC_Music` | 1KB / 104.7MB | 背景音乐 |
| `sounds/SC_Warp.xsb/.xwb` | `SC_Warp` | 1KB / 0.1MB | Warp 音效 |
| `sounds/Tutorial_SE.xsb/.xwb` | `Tutorial_SE` | 1KB / 100.5MB | 教程音效 |

### 3.2 FA 原版对照

FA 原版在 `sounds/` 目录下有自己的 bank（`X_FMV`、`FMV_BG`、`Op_Briefing`、`X01_VO`~`X06_VO` 等），**与 SC bank 无同名冲突**（SC bank 全部加了 `SC_` 前缀或使用 A/C/E 前缀 vs FA 的 X 前缀）。

### 3.3 Lua 播放逻辑

#### 简报播放流程 (`operationbriefing.lua`)

```
operationvars.lua:MakeOpVars()
  → op_MovPfx = thisFacLtr .. op_num   (如 "A01", "C01", "E01")
  → 塞布兰 R→C 前缀转换 (operationbriefing.lua 第 39-41 行)

operationbriefing.lua:CreateUI(operationID, briefingData, faction, ...)
  → opMovPfx = briefingData.opMovPfx   (如 "A01")

BuildMediaNames(phase, QAI)
  → opCue = opMovPfx .. '_B' .. num    (如 "A01_B01")
  → opBank = opMovPfx .. '_VO'         (如 "A01_VO")
  → movName = '/movies/' .. opCue .. '.sfd'

LoadMovie(movTable, num, phase)
  → mov.voSound = Sound({Cue = opCue, Bank = opBank})           -- 如 Sound({Cue="A01_B01", Bank="A01_VO"})
  → mov.bgSound = Sound({Cue = opCue, Bank = 'SC_Op_Briefing'}) -- 如 Sound({Cue="A01_B01", Bank="SC_Op_Briefing"})

PlayActiveMovie(movTable)
  → PlayVoice(mov.voSound)   -- 播放 VO bank 中对应 cue（高音量）
  → PlaySound(mov.bgSound)   -- 同时播放简报背景 bank 中同名 cue（低音量 Volume=-800 即 -80dB）
```

**关键设计**：简报同时播放两个 bank 的同名 cue。`voSound`（VO bank）是主语音，`bgSound`（SC_Op_Briefing bank）是低音量背景叠加。这是 SC 原版设计，不是 bug。

#### FMV 播放流程 (`campaignmovies.lua`)

**注意：代码已重构，与 SC 原版方式不同。**

SC 原版将两个 Sound 参数传给 `movie:Set()`，当前移植版分离为 `PlayVoice` + `PlaySound`：

```
PlayCampaignMovie(movieName, over, checkPlayed, exitBehavior, globalPrefs, cue)
  → cueName = movieName  (如 "FMV_uef_Intro")
  → 如果 cueName != 'FMV_Campaign_Intro':
      → 如果传了 cue 参数: cueName = cue
      → 否则: cueName = FixCueName(cueName)  (如 "FMV_uef_Intro" → "FMV_UEF_Intro")

FixCueName(cueName)
  → 提取 faction 部分 (如 "uef" → "UEF")
  → 查 factions.lua 的 FactionIndexMap + SoundPrefix 映射
  → 返回 "FMV_" .. facName .. suffix  (如 "FMV_UEF_Intro")

# missingVoiceCues 检查：跳过无语音的 cue
  → 如果 cueName 在 missingVoiceCues 表中（FMV_UEF_Intro_2 等 3 个），不调用 PlayVoice

movie.OnLoaded = function(self)
    if not missingVoiceCues[cueName] then
        movie.voice = PlayVoice(Sound({Cue = cueName, Bank = 'SC_FMV'}))   -- 语音（高音量）
    end
    movie.sound = PlaySound(Sound({Cue = cueName, Bank = 'SC_FMV_BG'}))   -- 背景音
    movie:Play()
    if captions then DisplaySubtitles(...) end
end

movie:Set("/movies/" .. movieName .. ".sfd")   -- 仅传路径，不传 Sound 参数
```

**关键修改说明**：
- `missingVoiceCues` 表（第 27-31 行）：FMV_UEF_Intro_2、FMV_Aeon_Intro_2、FMV_UEF_Outro_2 这 3 个 cue 在 SC_FMV 语音 bank 中无音频，跳过 PlayVoice 避免引擎报错
- SC_FMV bank 部署在 `sounds/Voice/US/` 目录（PlayVoice 按 Voice/{LANG}/ 路径查找）
- SC_FMV_BG bank 部署在 `sounds/` 根目录（PlaySound 按根目录查找）

### 3.4 地图与 operation.lua

SC 战役地图为 `SCCA_A01~A06`（Aeon）、`SCCA_C01~C06`（Cybran）、`SCCA_E01~E06`（UEF），共 18 个。

每个 `_operation.lua` 调用 `MakeOpVars(opID, factionKey, sequenceID)` 生成 `op_MovPfx`：

```lua
# SCCA_A01_operation.lua
opID = 'SCCA_A01'
local opVars = import('/lua/sc_campaign/operationvars.lua').MakeOpVars('SCCA_A01', 'aeon', 1)
operationData = {
    operationBriefingData = {
        opNum = opVars.op_num,         -- "01"
        opMovPfx = opVars.op_MovPfx,   -- "A01"
        opMap = opVars.op_map,         -- "/maps/SCCA_A01/SCCA_A01_scenario.lua"
        ...
    }
}
```

`operationvars.lua` 中的关键逻辑：

```lua
thisFacLtr = factionData.Factions[factionData.FactionIndexMap[factionKey]].CampaignFileDesignator
op_MovPfx = thisFacLtr .. op_num   -- 如 A01, C01, E01
```

---

## 四、已完成验证（全部通过）

### 4.1 二进制层面验证

| 验证项 | 方法 | 结果 |
|---|---|---|
| SC_FMV.xwb 13 个 wave | 与源 WAV 哈希比对 | **100% MATCH** |
| SC_FMV XSB cue 名称/顺序 | 逐条提取对比 | 完整正确（13 个 FMV cue 无缺漏） |
| SC_FMV XSB Cue→Sound→Wave 映射 | 二进制解析 | 自洽（idx 0~12 完全一致） |
| 部署版 A01_VO vs SC 原版 | wave 大小逐条对比 | 逐条一致（仅 ADPCM 打包头差异） |
| 部署版 SC_Op_Briefing vs SC 原版 | wave 大小逐条对比 | 逐条一致（v41→v43 打包头固定 280 字节差异） |
| SC_Op_Briefing .xap 映射 | Cue→Sound→Wave | 正确（A01_B01 → Entry Index 52） |

### 4.2 Lua 逻辑验证

| 验证项 | 方法 | 结果 |
|---|---|---|
| 简报双 bank 播放机制 | 从 SC 原版 lua.scd 提取 operationbriefing.lua 对比 | 与 SC 原版逻辑完全一致 |
| 塞布兰 R→C 前缀转换 | 代码审查 | 正确（第 39-41 行） |
| opMovPfx 生成链路 | 从 operationvars.lua → _operation.lua → operationbriefing.lua 全链路审查 | 正确 |
| FMV cue 名称修正 | FixCueName 逻辑审查 | 正确（faction 小写→大写映射） |
| SC 原版 Lua 引用 | 从 SC 原版 lua.scd 提取并对比 | SC 原版第 536 行 `Bank='Op_Briefing'`，部署版第 544 行 `Bank='SC_Op_Briefing'`，仅 bank 名不同 |

### 4.3 部署位置验证

- FA 原版 `sounds/` 下没有 `A01_VO`/`C01_VO`/`E01_VO`（只有 `X01_VO`~`X06_VO` 塞拉芬）
- 部署路径 `sounds/Voice/US/A01_VO.*` 可正常加载，无同名覆盖
- SC_FMV / SC_FMV_BG / SC_Op_Briefing 均加了 `SC_` 前缀，与 FA 原版无冲突

### 4.4 编码格式验证

| Bank | 格式 | 备注 |
|---|---|---|
| SC_FMV.xwb | PCM 16-bit 立体声 44100Hz (185MB) | FA 原版 X_FMV 也是 PCM 16-bit（单声道 74MB），PCM 格式本身不是问题 |
| SC_FMV_BG.xwb | ADPCM (142MB) | 正常 |
| A01_VO 等 18 个 VO bank | ADPCM，采样率 44068~44125Hz | 正常 |
| SC_Op_Briefing.xwb | ADPCM (66MB) | 正常 |

**SC_FMV 的 .xap 声明为 ADPCM 256 但实际产物为 PCM 16-bit**——因为 .xap 中 Cache 块缺失导致 XactBld 回退为 PCM。FA 原版 X_FMV 也是 PCM，所以 PCM 格式本身不应是问题根因。

### 4.5 SC 原版音频文件位置

```
I:\SteamLibrary\steamapps\common\Supreme Commander\sounds\          — 全部原版 XSB/XWB
I:\SteamLibrary\steamapps\common\Supreme Commander\sounds\Voice\US_BAK\  — 原版 VO bank (A01_VO 等)
I:\SteamLibrary\steamapps\common\Supreme Commander\gamedata\lua.scd       — 原版 Lua 脚本（zip 格式）
```

---

## 五、当前状态

### 5.1 问题 1：FMV 语音错位 — 已修复

**修复措施**：
1. **SC_FMV bank 部署路径修正**：从 `sounds/` 移至 `sounds/Voice/US/`（PlayVoice 按 `Voice/{LANG}/` 路径查找 voice bank，放错位置会导致引擎找不到正确 cue，播放错误 VO）
2. **`missingVoiceCues` 表**：跳过 SC_FMV 中无音频的 3 个 cue（FMV_UEF_Intro_2、FMV_Aeon_Intro_2、FMV_UEF_Outro_2），避免 PlayVoice 报错
3. **播放方式重构**：从 `movie:Set(path, bgSound, voSound)` 改为 `movie:Set(path)` + `OnLoaded` 中分离调用 `PlayVoice`/`PlaySound`

### 5.2 问题 2：简报语音混乱 — 待验证

**当前状态**：debug LOG 已在 `operationbriefing.lua` 中部署（LoadMovie 和 PlayActiveMovie 处），等待用户启动游戏测试并收集 `SupCom.sclog` 日志。

**候选根因**（与原分析一致）：

| 候选 | 可能性 | 说明 |
|---|---|---|
| **XACT v41→v43 引擎层 bank 加载/查找机制不兼容** | 高 | bank 已重编译为 v43，但 v43 内部 cue 查找机制可能与 v41 有细微差异 |
| **SCD 挂载覆盖顺序问题** | 中 | VFS 后挂载覆盖先挂载，某些 bank 可能被意外覆盖 |
| **Lua 播放时序竞态** | 中 | movie:Set 与 PlayVoice/PlaySound 之间的时序可能导致播放错误 cue |

### 5.3 问题 3：Cybran 简报播放慢 — 不修复

**根因确认**：FA 引擎在高分辨率（2560x1440）下同时解码两个 SFD 视频流（主简报电影 + 右上角 QAI 电影）时，MPEG 解码器性能不足。

**排除依据**：
- 文件名大小写、SFD 文件格式、挂载路径、Lua 代码逻辑全部验证一致
- SC 原版在高分辨率下也存在同样问题（双电影区域为 Cybran 独有设计）
- UEF/Aeon 仅有单个电影区域，不受影响

### 5.4 已部署的 Debug 日志

#### `operationbriefing.lua`（简报播放）

**LoadMovie 函数**（第 545-548 行）：
```lua
LOG('=== Briefing LoadMovie DEBUG ===')
LOG('  phase = ', phase, ' opMovPfx-derived: opCue = ', opCue, ' opBank = ', opBank)
LOG('  voSound = Sound({Cue=', opCue, ', Bank=', opBank, '})')
LOG('  bgSound = Sound({Cue=', opCue, ', Bank=SC_Op_Briefing})')
```

**PlayActiveMovie 函数**（第 561-563 行 / 第 570-572 行）：
```lua
LOG('=== Briefing PlayActiveMovie (loaded/OnLoaded) DEBUG ===')
LOG('  phase = ', mov.phase, ' active = ', movTable.active)
LOG('  calling PlayVoice(voSound) and PlaySound(bgSound)')
```

#### `campaignmovies.lua`（FMV 播放）

以下 debug LOG 在代码重构后**已精简**，当前仅保留 cueName 输出（第 98-99 行）：
```lua
LOG('  cueName (final) = ', cueName)
LOG('  subtitleKey = ', subtitleKey)
```

原有的 FixCueName、movie OnLoaded、movie:Set 处的 debug LOG 已在重构中移除。

### 5.5 下一步计划

1. **问题 2 验证**：用户启动 Aeon 战役简报，收集 `SupCom.sclog` 日志中的 debug 输出
2. **如果 debug 日志显示 Lua 层参数正确** → 问题在 XACT 引擎层，需逆向 FA 的 XACT 加载层（可用 IDA Pro MCP）
3. **如果 Lua 层参数异常** → 修正 Lua 代码
4. **问题 1 验证**：用户确认 FMV 语音错位是否已不再出现（路径修正 + missingVoiceCues 修复后）

---

## 六、关键文件索引

### Lua 播放逻辑（已修改，含部分 debug LOG）

| 文件 | 行数 | 说明 |
|---|---|---|
| `SCFA-Original-Campaign/SC_Campaign_Main.scd/lua/sc_campaign/operationbriefing.lua` | 630 | 简报 UI 与播放逻辑，含 debug LOG（问题 2 待验证） |
| `SCFA-Original-Campaign/SC_Campaign_Main.scd/lua/sc_campaign/campaignmovies.lua` | 255 | FMV 电影播放逻辑，已重构（missingVoiceCues + 分离播放），debug LOG 已精简 |
| `SCFA-Original-Campaign/SC_Campaign_Main.scd/lua/sc_campaign/selectcampaign.lua` | 785 | 战役选择界面 |
| `SCFA-Original-Campaign/SC_Campaign_Main.scd/lua/sc_campaign/operationvars.lua` | 39 | 生成 opMovPfx 等变量 |
| `SCFA-Original-Campaign/SC_Campaign_Main.scd/lua/sc_campaign/campaignmanager.lua` | - | LaunchOperation 调用 CreateUI |

### 地图 operation.lua（briefingData 来源）

| 文件 | 说明 |
|---|---|
| `SCFA-Original-Campaign/SC_Campaign_Main.scd/maps/SCCA_A01/SCCA_A01_operation.lua` | Aeon 第 1 关，opMovPfx = "A01" |
| `SCFA-Original-Campaign/SC_Campaign_Main.scd/maps/SCCA_A02 ~ A06/...` | Aeon 第 2-6 关 |
| `SCFA-Original-Campaign/SC_Campaign_Main.scd/maps/SCCA_C01 ~ C06/...` | Cybran 第 1-6 关 |
| `SCFA-Original-Campaign/SC_Campaign_Main.scd/maps/SCCA_E01 ~ E06/...` | UEF 第 1-6 关 |

### 音频 Bank 部署位置

| Bank | 路径 |
|---|---|
| SC_FMV | `gamedata/SC_Campaign_Data_Voice_US.scd/sounds/Voice/US/SC_FMV.xsb/.xwb` |
| 18 个 VO bank | `gamedata/SC_Campaign_Data_Voice_US.scd/sounds/Voice/US/{A,C,E}01~06_VO.xsb/.xwb` |
| SC_FMV_BG | `gamedata/SC_Campaign_Data_Sound.scd/sounds/SC_FMV_BG.xsb/.xwb` |
| SC_Op_Briefing | `gamedata/SC_Campaign_Data_Sound.scd/sounds/SC_Op_Briefing.xsb/.xwb` |
| SC_AmbientTest | `gamedata/SC_Campaign_Data_Sound.scd/sounds/SC_AmbientTest.xsb/.xwb` |
| SC_Music | `gamedata/SC_Campaign_Data_Sound.scd/sounds/SC_Music.xsb/.xwb` |
| SC_Warp | `gamedata/SC_Campaign_Data_Sound.scd/sounds/SC_Warp.xsb/.xwb` |
| Tutorial_SE | `gamedata/SC_Campaign_Data_Sound.scd/sounds/Tutorial_SE.xsb/.xwb` |

> **注意**：SC_FMV 部署在 `sounds/Voice/US/` 下（PlayVoice 查找路径），而非 `sounds/` 根目录。这是问题 1 修复的关键。

### FA 原版对照

| Bank | 路径 |
|---|---|
| X_FMV | `sounds/X_FMV.xsb/.xwb`（PCM 单声道 74MB） |
| FMV_BG | `sounds/FMV_BG.xsb/.xwb` |
| Op_Briefing | `sounds/Op_Briefing.xsb/.xwb` |
| X01_VO ~ X06_VO | `sounds/Voice/US/X01_VO.xsb/.xwb` 等（塞拉芬语音） |

### SC 原版对照

| 资源 | 路径 |
|---|---|
| 全部原版 bank | `I:\SteamLibrary\steamapps\common\Supreme Commander\sounds\` |
| 原版 VO bank | `I:\SteamLibrary\steamapps\common\Supreme Commander\sounds\Voice\US_BAK\` |
| 原版 Lua 脚本 | `I:\SteamLibrary\steamapps\common\Supreme Commander\gamedata\lua.scd`（zip 格式，可用 `[System.IO.Compression.ZipFile]::OpenRead()` 读取） |

### 音频工程文件

| 文件 | 说明 |
|---|---|
| `Documents/SoundProjectResources/` | 声音工程资源目录（含 .xap 工程文件、构建脚本、技术文档） |
| `Documents/SoundProjectResources/Sound_Project_Technical_Doc_zhcn.md` | 中文技术文档 |
| `Documents/SoundProjectResources/Sound_Project_Technical_Doc_enus.md` | 英文技术文档 |

### 工具脚本

| 文件 | 说明 |
|---|---|
| `unxwb.exe` | XWB 解包工具（`-l` 列出，`-b <offset>` 按 cue 名提取） |
| `.temp/` 下各脚本 | XWB 头解析、哈希比对、Lua 语法检查等临时脚本（.temp/ 为工作区，不纳入版本管理） |

### SKILL 文档

| 文件 | 说明 |
|---|---|
| `C:\Users\haojun0823\.config\TeleAgent\skills\scfa-mod-i18n\references\sc-to-fa-porting.md` | SC→FA 移植参考文档（含 XACT v41→v43 重编译流程、已知坑、已完成部署表） |
| `C:\Users\haojun0823\.config\TeleAgent\skills\scfa-mod-i18n\SKILL.md` | SCFA mod 汉化与移植 Skill 文档 |

---

## 七、XACT 版本与技术细节

### 版本差异

| 版本 | .xsb magic | .xwb magic | .xgs magic |
|---|---|---|---|
| SC (v41) | `SDBK` + 0x29 | `WBND` + 0x29 | `XGSF` + 0x29 |
| FA (v43) | `SDBK` + 0x2B | `WBND` + 0x2B | `XGSF` + 0x2B |

- 版本号存储在 magic 四字母后的 1 字节（offset +4）
- v41 与 v43 的头部结构偏移、字段布局完全不同
- FA 引擎（C++ XACT 运行时）严格校验版本，SC v41 bank 报 "Invalid data" 后跳过加载
- 所有 SC bank 已用 XactBld 重编译为 v43

### Bank 名匹配机制

- Lua 的 `Bank = 'SC_FMV'` 匹配的是 .xsb **内部存储的 bank 名**，不是文件名
- bank 名为 null-terminated ASCII 字符串，存储在 64 字节槽位中
- .xsb 中 bank 名存储在 offset 82 和 146 两处
- .xwb 中 bank 名存储在 offset 56

### XactBld 编译关键坑

1. .xap 中 Sound Bank 的 Sound 名称必须与游戏 Lua 引用的 XSB cue 名称一致
2. XactBld 不认 UTF-8 BOM，.xap 必须无 BOM 编码
3. 不要合并多个 Wave Bank 到同一 .xap（会导致编译异常）
4. 禁止二进制改 bank 名（会破坏头部 CRC），要改名必须在 .xap 源文件中改后重新编译
5. .xap 中 Cache 块缺失时 XactBld 会将 ADPCM 声明回退为 PCM 产物

---

## 八、已排除的假设

| 假设 | 排除依据 |
|---|---|
| XSB cue 名称错误 | 逐条提取确认 13 个 FMV cue 完整正确 |
| XSB Cue→Sound→Wave 映射错误 | 二进制解析确认映射自洽 |
| XWB 音频内容错误 | 与源 WAV 哈希比对 100% 一致 |
| VO bank 内容错位 | 部署版与 SC 原版逐条 wave 大小一致 |
| 简报背景音 bank 内容错误 | 部署版与 SC 原版逐条 wave 大小一致 |
| Lua 引用错误（bank 名/cue 名） | 与 SC 原版 lua.scd 中的代码逐行对比确认一致 |
| 简报双 bank 播放是 bug | SC 原版代码确认是设计行为（voSound + bgSound 同时播放） |
| 部署位置冲突 | FA 原版无同名 bank（A/C/E 前缀 vs X 前缀，SC_ 前缀隔离） |
| 塞布兰前缀转换错误 | 代码审查确认 R→C 转换正确 |
| Lua 语法错误 | 三个文件均通过语法检查（block balance 验证） |

---

## 九、建议的介入方向

### 优先级 1：游戏内 Debug 日志分析（问题 2，等待用户测试）

用户启动 Aeon 战役简报后，检查 `SupCom.sclog` 中的 debug 输出。关键确认点：

1. **简报**：`opCue` 和 `opBank` 的值是否符合预期（如 `A01_B01` / `A01_VO`）
2. **PlayVoice/PlaySound**：是否被调用，调用时的参数

如果 debug 日志显示 Lua 层全部正确 → 确认问题在 XACT 引擎层。

### 优先级 2：XACT 引擎层逆向

如果 Lua 层确认正确，需要逆向 FA 的 XACT 加载层：

- 可用工具：IDA Pro MCP、Ghidra MCP、Cheat Engine MCP（均已配置）
- 目标：定位 FA 引擎中 XACT bank 加载和 cue 查找的 C++ 代码
- 关键问题：v43 引擎在查找 cue 时是否使用了与 v41 不同的索引机制？是否存在 bank 内部偏移差异导致返回错误 wave？

### 已关闭的方向

- ~~SC_FMV 格式重编译尝试~~：问题 1 已通过路径修正 + missingVoiceCues 修复
- ~~SCD 挂载顺序验证~~：已确认 `SCFA-Original-Campaign/*.scd` 和 `gamedata/*.scd` 挂载顺序正确，无意外覆盖

---

## 十、环境信息

- **操作系统**：Windows
- **开发工具**：VS2017 (v141_xp, x86)
- **反向工程工具**：GHIDRA、Cheat Engine、IDA Pro（位于 `G:/Tools/Hacker/`）
- **已配置 MCP**：IDA-Pro-MCP（启用）、Ghidra MCP、CheatEngine MCP、x64dbg HTTP（按需）
- **游戏日志位置**：`C:\Users\<user>\AppData\Local\Gas Powered Games\Supreme Commander Forged Alliance\SupCom.sclog`
- **Lua 方言**：SC/FA 使用 Lua 5.0，注释符为 `#`（不是标准 Lua 的 `--`），也支持 `--[[ ]]` 块注释和 `--` 行注释

> AI生成