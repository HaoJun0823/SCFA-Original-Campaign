---
AIGC:
  ContentProducer: '001191110102MAD55U9H0F10002'
  ContentPropagator: '001191110102MAD55U9H0F10002'
  Label: '1'
  ProduceID: '095d185d-160d-4e48-a1ca-f1099fb81451'
  PropagateID: '095d185d-160d-4e48-a1ca-f1099fb81451'
  ReservedCode1: 'a1520dbe-d1ff-4859-8f0b-c83801ab42ff'
  ReservedCode2: 'a1520dbe-d1ff-4859-8f0b-c83801ab42ff'
---

# SC→FA 战役音频重建工程：技术文档（中文）

> **文档用途**：完整记录 SC（Supreme Commander）原版战役音频从 XACT v41 重编译为 FA（Forged Alliance）v43 格式的全部流程，确保任何技术人员可凭此文档与工程资源独立复现构建。

---

## 1. 项目概述

### 1.1 目标

将 SC 原版的 XACT v41 音频 bank（.xsb/.xwb）重编译为 FA 引擎可加载的 v43 格式，部署到 `gamedata/` 下的 .scd 目录中，使 SC 战役音频在 FA 引擎中正确播放。

### 1.2 关键约束

- SC 音频为 XACT v41 格式，FA 引擎严格校验版本号，v41 bank 报 "Invalid data" 后跳过加载
- 必须使用 Microsoft DirectX SDK (November 2007) 中的 XactBld.exe 进行编译
- 不使用 FAF 等第三方音频资源（版权敏感）
- 部署方式为 .scd 目录直接覆盖，不走 mod 路线

### 1.3 XACT 版本差异

| 版本 | .xsb magic | .xwb magic | .xgs magic |
|---|---|---|---|
| SC (v41) | `SDBK` + 0x29 | `WBND` + 0x29 | `XGSF` + 0x29 |
| FA (v43) | `SDBK` + 0x2B | `WBND` + 0x2B | `XGSF` + 0x2B |

- 版本号存储在 magic 四字母后的 1 字节（offset +4）
- v41 与 v43 的头部结构偏移、字段布局完全不同
- 禁止二进制改 bank 名（会破坏头部 CRC），要改名必须在 .xap 源文件中改后重新编译

---

## 2. 目录结构

本工程资源位于 `SCFA-Original-Campaign/Documents/SoundProjectResources/`，结构如下：

```
SoundProjectResources/
├── XAP_Engineering/          # 216 个 .xap XACT 工程文件（构建输入）
├── Build_Scripts/             # 35 个 Python/PowerShell 构建脚本
├── Mapping_Data/              # 17 个 JSON 映射表 + cue 名称参考
├── Build_Outputs/             # 213 个构建输出目录（.xsb + .xgs，无 .xwb）
├── Reference_XAP/             # 15 个参考 XAP 文件 + 全局设置
├── Tools/                     # unxwb.exe + ffmpeg.exe + 源码
└── HANDOFF_SC_FA_Audio_Debug.md  # 原始交接文档
```

### 2.1 XAP_Engineering（XACT 工程文件）

共 216 个 .xap 文件，按构建目标命名（`build_{目录名}_{XAP文件名}`），分为三大类：

| 类别 | 数量 | 示例 | 说明 |
|---|---|---|---|
| 根级音效 bank | 36 | `build_SC_UAL_SC_UAL.xap` | 36 个 SC_ 前缀音效 bank（Explosions、Impacts、各阵营 UAA~URS 系列） |
| US 语音 bank | 25 | `build_A01_VO_A01_VO.xap` | 18 个关卡 VO + 7 个特殊 VO（COMPUTER_*、Experimental、Instructor、FMV、Ops） |
| 教程 VO bank | 23 | `build_TUA100_TUA100.xap` | 23 个教程 VO bank（TUA~TUF 系列） |
| 多语言语音 bank | 125 | `build_DE_A01_VO_A01_VO.xap` | 5 语言 × 25 bank（DE/ES/FR/IT/RU） |
| 环境/音乐/Interface/FMV_BG | 7 | `build_SC_AmbientTest_SC_AmbientTest.xap` | AmbientTest、Music、Interface（3 版）、FMV_BG（2 版） |

每个 .xap 文件包含完整的 XACT 工程定义：Global Settings + Wave Bank + Sound Bank（含 Sound、Cue 定义）。

### 2.2 Build_Outputs（构建输出）

共 213 个子目录，每个包含编译后的 `.xsb`（Sound Bank）和 `.xgs`（Global Settings）。`.xwb`（Wave Bank，含音频数据）不在本资源包中。3 个 `test_interface*.xap` 为调试测试文件，未纳入迁移。3 个 `test_interface*.xap` 为调试测试文件，未纳入迁移。

### 2.3 Mapping_Data（映射数据）

| 文件 | 说明 |
|---|---|
| `all_root_mappings.json` | 根级音效 bank 的 cue→wave 映射（36 个 bank，435KB） |
| `all_bank_mappings.json` | 全部 bank 的完整映射（644KB） |
| `interface_mapping_correct.json` | Interface bank 的修正映射（含 Select 音效合并） |
| `fmv_bg_mapping_correct.json` | FMV 背景音 bank 的修正映射 |
| `ambienttest_mapping.json` | 环境音 bank 映射 |
| `wave_mapping.json` | 通用 wave 索引映射 |
| `batch_root_rebuild_results.json` | 根级 bank 构建结果报告 |
| `vo_rebuild_results.json` | US VO bank 构建结果 |
| `vo_rebuild_remaining_results.json` | 剩余 VO bank 构建结果 |
| `tutorial_rebuild_results.json` | 教程 VO bank 构建结果 |
| `multi_lang_vo_results.json` | 多语言 VO 构建结果 |
| `sound_rebuild_results.json` | 音效 bank 构建结果 |
| `xsb_cue_names.txt` / `xsb_cue_names_all.txt` | 全部 bank 的 cue 名称列表 |

---

## 3. 构建工具与环境

### 3.1 必需工具

| 工具 | 路径 | 用途 |
|---|---|---|
| XactBld.exe | `C:\Program Files (x86)\Microsoft DirectX SDK (November 2007)\Utilities\Bin\x86\XactBld.exe` | XACT 工程编译（v41→v43） |
| Python 3 | 系统 PATH | 运行构建脚本 |
| unxwb.exe | `Tools/unxwb.exe` | XWB 解包/验证（`-l` 列出条目，`-b <offset>` 按 cue 提取） |
| ffmpeg.exe | `Tools/ffmpeg.exe` | 音频格式转换 |

### 3.2 关键路径常量（脚本中硬编码）

```python
BASE = r"I:\SteamLibrary\steamapps\common\Supreme Commander Forged Alliance"
SC_SOUND = r"I:\SteamLibrary\steamapps\common\Supreme Commander\sounds"
TEMP = os.path.join(BASE, "AudioProject_2", ".temp")
EXTRACT_DIR = os.path.join(BASE, "AudioProject_2", "extract_all")
FA_SOUND = os.path.join(BASE, "gamedata", "SC_Campaign_Data_Sound.scd", "sounds")
FA_VOICE = os.path.join(BASE, "gamedata", "SC_Campaign_Data_Voice_US.scd", "sounds", "Voice", "US")
XACTBLD = r"C:\Program Files (x86)\Microsoft DirectX SDK (November 2007)\Utilities\Bin\x86\XactBld.exe"
ORIGINAL_XAP = os.path.join(BASE, "AudioTools", "FA_vanilla_VOs_real_original.xap")
```

### 3.3 音频源文件

所有 WAV 源文件位于 `AudioProject_2/extract_all/`，分两大类：

```
extract_all/
├── AmbientTest/          # 根级音效 WAV（按 bank 名分目录）
├── Explosions/
├── Interface/
├── Music/
├── Op_Briefing/
├── UAL/
├── ...（共 46 个根级目录）
└── Voice/
    └── US/
        ├── A01_VO/       # US 语音 WAV
        ├── ...（25 个 VO 目录）
        └── Tutorials/    # 23 个教程 VO 目录
```

---

## 4. 构建流程

### 4.1 总览

整个音频重建分为 **6 条构建管线**，每条管线由 Python 脚本自动化完成：

| 管线 | 脚本 | 目标 | 输出数量 |
|---|---|---|---|
| 根级音效 | `batch_rebuild_root.py` | 36 个 SC_ 前缀音效 bank | 36 |
| US 语音 | `batch_rebuild_vo.py` | 18 个关卡 VO bank | 18 |
| 剩余 VO | `batch_rebuild_remaining_vo.py` | 7 个特殊 VO bank | 7 |
| 教程 VO | `batch_rebuild_tutorial_vo.py` | 23 个教程 VO bank | 23 |
| 多语言 VO | `batch_rebuild_multi_lang_vo.py` | 5 语言 × 25 bank | 125 |
| 环境/音乐 | `rebuild_sound_banks.py` | AmbientTest + Music | 2 |

### 4.2 每条管线的统一流程

每个 bank 的构建遵循 5 步标准化流程：

```
步骤 1: 解析 v41 XSB → 获取 cue→wave 映射
步骤 2: 生成 .xap XACT 工程文件
步骤 3: 用 XactBld 编译为 v43
步骤 4: 验证 v43 XSB 的 cue→wave 映射正确性
步骤 5: 部署到 FA gamedata 目录
```

#### 步骤 1：解析 v41 XSB

使用 `parse_xsb_v41.py` 中的 `XSBv41Parser` 类解析 SC 原版 .xsb 文件：

```python
from parse_xsb_v41 import XSBv41Parser

xsb_path = os.path.join(SC_SOUND, f"{bank_name}.xsb")
parser = XSBv41Parser(xsb_path)
parser.parse()

# parser.cue_mappings 包含每个 cue 的：
#   - cue_index: cue 在 XSB 中的索引
#   - cue_name: cue 名称
#   - wave_refs: [(wave_bank_idx, wave_idx), ...] 引用的 wave
#   - sound_offset: sound 数据在 XSB 中的偏移
```

对于根级音效 bank，还需从 v41 XSB 的 sound 数据中提取 **category** 和 **volume**：

```python
# 从 sound_offset 处读取
flags = data[off]; off += 1
cat_id = struct.unpack_from('<H', d, off)[0]; off += 2
vol_byte = d[off]

# Category ID → 名称映射（24 个类别）
CAT_NAMES = [
    'Global', 'Default', 'Music', 'World', 'Units', 'Ambient', 'Weapons', 'Destroy',
    'Rumble', 'Interface', 'UnitsUEF', 'UnitsAEON', 'UnitsCYBRAN',
    'UnitsUEFAir', 'UnitsCYBRANAir', 'UnitsAEONAir',
    'ActiveLoopsUEF', 'ActiveLoopsCYBRAN', 'ActiveLoopsAEON',
    'Unit Select', 'FMV', 'Op_Briefing', 'VO', 'US',
]

# Volume byte → XAP centibels 转换（非线性）
def byte_to_xap_volume(vol_byte):
    if vol_byte == 255: return -9600  # silence
    a = -96.0; b = 0.432254984608615; c = 80.1748600297963; d = 67.7385212334047
    db = ((a - d) / (1 + (math.pow(vol_byte / c, b)))) + d
    return round(db * 100)
```

#### 步骤 2：生成 .xap 文件

.xap 文件是 XactBld 的输入源文件，纯文本格式，包含三大块：

```
Global Settings { ... }    ← 从 FA_vanilla_VOs_real_original.xap 提取
Wave Bank { ... }          ← 定义 wave 列表（每个 wave 引用一个 WAV 文件）
Sound Bank { ... }         ← 定义 Sound + Cue（含 category、volume、track event）
```

**Global Settings**：从 `FA_vanilla_VOs_real_original.xap` 中提取（第 1 行到 Global Settings 块结束），所有 bank 共享同一份。

**Wave Bank 生成**：

```python
out.append("Wave Bank")
out.append("{")
out.append(f"    Name = {deploy_name};")
out.append(f"    Windows File = {build_dir}\\Win\\{deploy_name}.xwb;")
out.append("    Streaming = 1;")
out.append("    Seek Tables = 1;")
out.append("    Compression Preset Name = ADPCM 256;")

for merged_idx, wb_name, orig_idx, wav_file in merged_waves:
    ch, sr, data_len = get_wav_info(wav_path)  # 解析 WAV 头
    out.append("    Wave")
    out.append("    {")
    out.append(f"        Name = {wave_name};")
    out.append(f"        File = {wav_path};")
    out.append("        Compression Preset Name = ADPCM 256;")
    out.append("        Cache")
    out.append("        {")
    out.append(f"            Channels = {ch};")
    out.append(f"            Sampling Rate = {sr};")
    out.append(f"            Play Region Length = {data_len};")
    out.append("        }")
    out.append("    }")
```

**Sound Bank 生成**（每个 cue 对应一个 Sound + 一个 Cue 块）：

```python
out.append("    Sound")
out.append("    {")
out.append(f"        Name = {cue_name};")
out.append(f"        Volume = {xap_vol};")  # 从 v41 XSB 提取
out.append("        Category Entry")
out.append("        {")
out.append(f"            Name = {cat_name};")  # 从 v41 XSB 提取
out.append("        }")
out.append("        Track")
out.append("    {")
out.append("            Play Wave Event")
out.append("            {")
out.append("                Wave Entry")
out.append("                {")
out.append(f"                    Bank Name = {deploy_name};")
out.append(f"                    Entry Index = {merged_idx};")  # 合并后的 wave 索引
out.append("                }")
out.append("            }")
out.append("        }")
out.append("    }")
```

**根级音效 bank 的多 wave bank 合并**：

根级 bank 可能由多个原版 wave bank 合并而来（如 Explosions = Explosions + ExplosionsStream）。合并逻辑：

```python
def build_merged_wave_list(bank_name, mapping):
    """
    将多个原版 wave bank 的 wave 合并为一个连续索引列表。
    返回: [(merged_index, wave_bank_name, original_wave_index, wav_filename), ...]
    """
    # 处理两种 WAV 命名格式：
    # - wave_NNN.wav: wave_index = NNN（直接从文件名解析）
    # - cue_name.wav: 从 JSON 映射查找 wave_index
    # 未匹配的文件分配到可用索引间隙
```

#### 步骤 3：编译

```python
cmd = [XACTBLD, "/WINDOWS", xap_path]
result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
# 输出: build_dir/Win/{bank_name}.xsb, .xwb, SupCom.xgs
```

XactBld 编译关键注意事项：
1. .xap 文件必须无 UTF-8 BOM
2. 不要合并多个 Wave Bank 到同一 .xap（会导致编译异常）
3. Cache 块缺失时 XactBld 会将 ADPCM 声明回退为 PCM 产物

#### 步骤 4：验证

使用 `verify_xsb_v43.py` 解析编译后的 v43 XSB，与 v41 映射交叉验证：

```python
from verify_xsb_v43 import parse_xsb
info = parse_xsb(xsb_path)

# 对比 v43 cue→wave 映射与 v41 期望映射
for cue_name, expected_waves in expected.items():
    v43_waves = info['cue_refs'][i]
    if not v43_waves.issubset(expected_waves):
        mismatches += 1
```

#### 步骤 5：部署

```python
# 音效 bank → SC_Campaign_Data_Sound.scd/sounds/
shutil.copy2(src_xsb, os.path.join(FA_SOUND, deploy_name + ".xsb"))
shutil.copy2(src_xwb, os.path.join(FA_SOUND, deploy_name + ".xwb"))

# 语音 bank → SC_Campaign_Data_Voice_US.scd/sounds/Voice/US/
shutil.copy2(src_xsb, os.path.join(FA_VOICE, bank_name + ".xsb"))
shutil.copy2(src_xwb, os.path.join(FA_VOICE, bank_name + ".xwb"))
```

---

## 5. 部署路径规则

### 5.1 音效 bank（PlaySound 调用）

```
gamedata/SC_Campaign_Data_Sound.scd/sounds/
├── SC_AmbientTest.xsb/.xwb     # 环境音
├── SC_Music.xsb/.xwb           # 背景音乐
├── SC_FMV_BG.xsb/.xwb          # FMV 背景音效
├── SC_Op_Briefing.xsb/.xwb     # 简报背景音
├── SC_Interface.xsb/.xwb       # UI 音效
├── Tutorial_SE.xsb/.xwb        # 教程音效
├── SC_Explosions.xsb/.xwb      # 爆炸音效
├── SC_Impacts.xsb/.xwb         # 撞击音效
└── ...（共 42 个 bank）
```

### 5.2 语音 bank（PlayVoice 调用）

```
gamedata/SC_Campaign_Data_Voice_US.scd/sounds/Voice/US/
├── A01_VO.xsb/.xwb ~ A06_VO.xsb/.xwb    # Aeon 关卡语音
├── C01_VO.xsb/.xwb ~ C06_VO.xsb/.xwb    # Cybran 关卡语音
├── E01_VO.xsb/.xwb ~ E06_VO.xsb/.xwb    # UEF 关卡语音
├── COMPUTER_AEON_VO.xsb/.xwb            # Aeon AI 语音
├── COMPUTER_CYBRAN_VO.xsb/.xwb          # Cybran AI 语音
├── COMPUTER_UEF_VO.xsb/.xwb            # UEF AI 语音
├── Experimental_VO.xsb/.xwb             # 实验单位语音
├── Instructor_VO.xsb/.xwb               # 教官语音
├── SC_FMV.xsb/.xwb                      # FMV 电影配音
├── Ops_VO.xsb/.xwb                      # Ops 语音
└── Tutorials/
    ├── TUA100.xsb/.xwb ~ TUF300.xsb/.xwb  # 23 个教程 VO
    └── ...
```

### 5.3 特殊命名规则

| Bank | XSB 文件名 | XWB 文件名 | 内部 bank 名 | 说明 |
|---|---|---|---|---|
| FMV | SC_FMV.xsb | SC_FMV.xwb | SC_FMV | Lua 引用 `Bank='SC_FMV'`，必须用 SC_ 前缀 |
| Ops | Ops.xsb | Ops_VO.xwb | Ops | XSB 和 XWB 文件名不同（沿用 SC 原版命名） |
| 根级音效 | SC_{名称}.xsb | SC_{名称}.xwb | SC_{名称} | 统一加 SC_ 前缀避免与 FA 原版冲突 |

### 5.4 多语言部署

```
gamedata/
├── SC_Campaign_Data_Voice_US.scd/sounds/Voice/US/
├── SC_Campaign_Data_Voice_DE.scd/sounds/Voice/DE/
├── SC_Campaign_Data_Voice_ES.scd/sounds/Voice/ES/
├── SC_Campaign_Data_Voice_FR.scd/sounds/Voice/FR/
├── SC_Campaign_Data_Voice_IT.scd/sounds/Voice/IT/
└── SC_Campaign_Data_Voice_RU.scd/sounds/Voice/RU/
```

SC 原版各语言 voice 目录后缀映射（`LANG_SC_MAP`）：

| 部署语言 | SC 原版目录后缀 |
|---|---|
| US | US |
| DE | DE_BAK |
| ES | ES_BAK |
| FR | FR_BAK |
| IT | IT_BAK |
| RU | RU_BAK |

---

## 6. Lua 播放机制

### 6.1 简报播放（operationbriefing.lua）

```
operationvars.lua:MakeOpVars()
  → op_MovPfx = thisFacLtr .. op_num   (如 "A01", "C01", "E01")
  → 塞布兰 R→C 前缀转换

operationbriefing.lua:CreateUI(operationID, briefingData, faction, ...)
  → opCue = opMovPfx .. '_B' .. num    (如 "A01_B01")
  → opBank = opMovPfx .. '_VO'         (如 "A01_VO")

LoadMovie(movTable, num, phase)
  → mov.voSound = Sound({Cue = opCue, Bank = opBank})           # 主语音（高音量）
  → mov.bgSound = Sound({Cue = opCue, Bank = 'SC_Op_Briefing'}) # 背景叠加（低音量）
```

**关键设计**：简报同时播放两个 bank 的同名 cue。voSound 是主语音，bgSound 是低音量背景叠加（Volume=-800 即 -80dB）。这是 SC 原版设计，不是 bug。

### 6.2 FMV 播放（campaignmovies.lua）

```
PlayCampaignMovie(movieName, ...)
  → cueName = movieName  (如 "FMV_uef_Intro")
  → cueName = FixCueName(cueName)  (如 "FMV_uef_Intro" → "FMV_UEF_Intro")

movie:Set("/movies/" .. movieName .. ".sfd",
    Sound({Cue = cueName, Bank = 'SC_FMV_BG'}),   # 背景音
    Sound({Cue = cueName, Bank = 'SC_FMV'}))       # 语音
```

### 6.3 部署版 Lua 的 Bank 名变更

SC 原版 Lua 引用裸名（如 `Bank='Op_Briefing'`），部署版改为 `SC_` 前缀（如 `Bank='SC_Op_Briefing'`），仅 bank 名不同，其余逻辑完全一致。

---

## 7. Bank 名匹配机制

- Lua 的 `Bank = 'SC_FMV'` 匹配的是 .xsb **内部存储的 bank 名**，不是文件名
- bank 名为 null-terminated ASCII 字符串，存储在 64 字节槽位中
- .xsb 中 bank 名存储在 offset 82 和 146 两处
- .xwb 中 bank 名存储在 offset 56

---

## 8. 音频 bank 分类与数量

### 8.1 音效 bank（SC_Campaign_Data_Sound.scd）

| 分类 | Bank 数量 | 说明 |
|---|---|---|
| 核心（战役引用） | 6 | SC_Interface, SC_AmbientTest, SC_Music, SC_FMV_BG, SC_Op_Briefing, Tutorial_SE |
| 单位音效 | 30 | UAA~URS 系列（每族 9 个 + Destroy/Weapon 拆分） |
| 通用音效 | 6 | SC_Explosions, SC_Impacts, SC_Group_Move, SC_UnitRumble, SC_UnitsGlobal |
| 合计 | 42 | |

### 8.2 语音 bank（SC_Campaign_Data_Voice_US.scd）

| 分类 | Bank 数量 | 说明 |
|---|---|---|
| 关卡 VO | 18 | A01~A06, C01~C06, E01~E06 |
| AI VO | 3 | COMPUTER_AEON/CYBRAN/UEF_VO |
| 特殊 VO | 4 | Experimental_VO, Instructor_VO, SC_FMV, Ops_VO |
| 教程 VO | 23 | TUA100~TUF300 |
| 合计 | 48 | |

### 8.3 多语言总计

6 语言（US/DE/ES/FR/IT/RU）× 48 bank = **288 个语音 bank** + 42 个音效 bank = **330 个 bank 总计**

---

## 9. XAP 工程文件结构详解

### 9.1 Global Settings

从 `FA_vanilla_VOs_real_original.xap` 提取，所有 bank 共享。包含 XACT 全局配置（类别定义、压缩预设、RPC 等）。

### 9.2 Wave Bank 块

```
Wave Bank
{
    Name = SC_UAL;                              // 部署名（SC_ 前缀）
    Windows File = ...\Win\SC_UAL.xwb;          // 输出路径
    Streaming = 1;                              // 流式播放
    Seek Tables = 1;                            // 查找表
    Compression Preset Name = ADPCM 256;        // 压缩格式

    Wave
    {
        Name = UAL_000;                         // wave 名称
        File = ...\extract_all\UAL\wave_000.wav; // 源 WAV 路径
        Compression Preset Name = ADPCM 256;
        Cache
        {
            Channels = 1;                       // 从 WAV 头解析
            Sampling Rate = 44100;
            Play Region Length = 12345;          // data chunk 大小
        }
    }
    // ... 更多 wave
}
```

### 9.3 Sound Bank 块

```
Sound Bank
{
    Name = SC_UAL;
    Windows File = ...\Win\SC_UAL.xsb;

    Sound
    {
        Name = UAL_Bot_Select;                  // 与 cue 名一致
        Volume = -300;                          // 从 v41 XSB 提取（centibels）
        Category Entry
        {
            Name = Units;                       // 从 v41 XSB 提取
        }
        Track
        {
            Play Wave Event
            {
                Wave Entry
                {
                    Bank Name = SC_UAL;
                    Entry Index = 0;            // 合并后的 wave 索引
                }
            }
        }
    }

    Cue
    {
        Name = UAL_Bot_Select;
        Variation
        {
            Variation Type = 3;
            Variation Table Type = 1;
        }
        Sound Entry
        {
            Name = UAL_Bot_Select;
            Index = 0;                          // Sound 索引
        }
    }
}
```

---

## 10. 已知问题与解决方案

### 10.1 SC_FMV 格式回退

**问题**：SC_FMV 的 .xap 声明为 ADPCM 256，但实际产物为 PCM 16-bit。
**原因**：.xap 中 Cache 块缺失导致 XactBld 回退为 PCM。
**影响**：FA 原版 X_FMV 也用 PCM，格式本身不是问题。但 SC_FMV 是立体声而 FA 原版是单声道。

### 10.2 FMV 语音错位（已解决）

**问题**：FMV 电影播放时语音内容与字幕不匹配。
**根因**：Lua 引用 `Bank='SC_FMV'`，但早期重建版部署为 `Voice\US\FMV`（bank 名 'FMV'），游戏实际加载的是遗留的 PCM 版 SC_FMV。
**解决**：修改 `BANK_NAME_MAP={"FMV":"SC_FMV"}`，重新编译部署 ADPCM 版覆盖 PCM 版（185MB→48MB），wave bank 名设为 SC_FMV。

### 10.3 FMV streaming 标志

**问题**：FA 引擎将 SC_FMV 识别为 streaming=true（XAP 中 Streaming=1），而 SC_FMV_BG 为 non-streaming 且正常。
**解决**：修改 FMV 的 Streaming 为 0（非流式），重新编译部署。

### 10.4 Interface bank 的 Select 音效合并

**问题**：SC_Interface.xwb 合并了原版 Interface(62) + UEFSelect(13) + CYBRANSelect(14) + AEONSelect(13) = 102 wave，其中 Select 音效是工程决策造成的合并。
**影响**：FA 根目录已有同名裸名 AEONSelect/CYBRANSelect/UEFSelect bank，合并是冗余的但不影响功能。

### 10.5 根级 bank 的孤儿 wave

**问题**：如 SC_UAL.xwb 为 170 wave = 原版 UAL(83) + UEL(87)，其中 19 个 wave 无 cue 引用。
**原因**：`batch_rebuild_root.py` 的多 bank 合并设计将所有 wave 纳入合并列表，包括未被任何 cue 引用的。
**影响**：不影响功能，仅增加 XWB 文件体积。

---

## 11. 复现指南

### 11.1 前置条件

1. 安装 Microsoft DirectX SDK (November 2007)，确保 XactBld.exe 可用
2. 安装 Python 3（建议 3.8+）
3. 确保 SC 原版游戏安装（提供 v41 XSB/XWB 源文件）
4. 确保 WAV 源文件已提取到 `AudioProject_2/extract_all/`

### 11.2 重新构建全部 bank

```bash
# 1. 构建根级音效 bank（36 个）
python batch_rebuild_root.py

# 2. 构建 US 语音 bank（18 个关卡 VO）
python batch_rebuild_vo.py

# 3. 构建剩余 US VO bank（7 个特殊 VO）
python batch_rebuild_remaining_vo.py

# 4. 构建教程 VO bank（23 个）
python batch_rebuild_tutorial_vo.py

# 5. 构建 AmbientTest + Music（2 个）
python rebuild_sound_banks.py

# 6. 构建多语言 VO（5 语言 × 25 bank）
python batch_rebuild_multi_lang_vo.py
```

### 11.3 验证

每个构建脚本内置验证步骤（步骤 4），自动对比 v43 与 v41 的 cue→wave 映射。也可手动验证：

```bash
# 列出 XWB 中的 wave 条目
unxwb.exe -l SC_UAL.xwb

# 按 cue 名提取 wave
unxwb.exe -b SC_UAL.xsb SC_UAL.xwb
```

### 11.4 部署

构建脚本自动部署到 gamedata 目录。手动部署时注意：

- 音效 bank → `SC_Campaign_Data_Sound.scd/sounds/`（根目录）
- 语音 bank → `SC_Campaign_Data_Voice_US.scd/sounds/Voice/US/`（Voice/US 子目录）
- FMV bank → 语音 .scd 的 `sounds/` 根目录（非 Voice/US 子目录）
- Ops bank → XSB 文件名 `Ops.xsb`，XWB 文件名 `Ops_VO.xwb`

---

## 12. 文件清单

### 12.1 构建脚本（Build_Scripts/）

| 脚本 | 行数 | 功能 |
|---|---|---|
| batch_rebuild_root.py | 554 | 批量重建 36 个根级音效 bank |
| batch_rebuild_vo.py | 499 | 批量重建 18 个关卡 VO bank |
| batch_rebuild_remaining_vo.py | 461 | 批量重建 7 个特殊 VO bank |
| batch_rebuild_tutorial_vo.py | 362 | 批量重建 23 个教程 VO bank |
| batch_rebuild_multi_lang_vo.py | 438 | 批量重建 5 语言 × 25 VO bank |
| rebuild_sound_banks.py | 619 | 重建 AmbientTest + Music |
| parse_xsb_v41.py | - | v41 XSB 解析器（核心库） |
| verify_xsb_v43.py | - | v43 XSB 验证器 |
| gen_xap.py / gen_xap_v2.py | - | XAP 生成器 |
| gen_fmv_bg_xap.py | - | FMV 背景音 XAP 生成器 |
| fix_interface.py | - | Interface bank 修正脚本 |
| fix_ambient_fmv.py | - | 环境音/FMV 修正脚本 |
| extract_all_root.py | - | 根级音效 WAV 提取 |
| extract_all_voice.py | - | 语音 WAV 提取 |
| extract_all_lang_voice.py | - | 多语言语音 WAV 提取 |

### 12.2 参考文件（Reference_XAP/）

| 文件 | 说明 |
|---|---|
| FA_vanilla_VOs_real_original.xap | FA 原版 VO XAP（Global Settings 来源） |
| FA_vanilla_VOs.xap | FA 原版 VO XAP（修改版） |
| FA_vanilla_VOs_fixed.xap | FA 原版 VO XAP（修正版） |
| SE_FORGED_ALLIANCE_SupCom_SE_FORGED_ALLIANCE.xap | FA 全局设置 XAP |
| SE_SUPCOM_SupCom_SE_build.xap | SC 构建设置 XAP |
| sc_shared_SC_shared_banks_correct.xap | SC 共享 bank 定义（含 Op_Briefing + 全部 VO） |
| global_settings.txt | 全局设置文本参考 |
| SupCom_from_Sound.xgs | 从 Sound 提取的 XGS 备份 |