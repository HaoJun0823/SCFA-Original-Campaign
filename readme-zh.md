# SCFA — 原版战役移植

将 2007 年原版《最高指挥官》(Supreme Commander) 的单人战役移植到
《Supreme Commander: Forged Alliance》(FA)。

三大阵营完整剧情线 —— **UEF / Cybran / Aeon**，每方 **6 关、共 18 关**，
包含简报、任务内旁白、结算/评分界面、作战勋章以及原版游戏数据。

采用 FA 原生的 **`schook` 脚本钩子** + **`.scd` 目录挂载**覆盖方式实现，
**不改动任何 FA 原版文件**，资料片自带战役完全保留。

> English version: [readme.md](readme.md)

---

## 当前版本状态（2026-11）

- **18 关全部实测通关**：UEF / Cybran / Aeon 三条线逐关边测边修，通关结算、
  任务目标判定、过场影片与结局影片均已跑通。
- **修复对旧存档有效**：所有逻辑修复都放在每次读档都会重新加载的 `schook`
  模块里，没有改动地图脚本。原因是 FA 的战役存档会把地图脚本**编译后的字节码**
  一起保存，只改地图源文件对已经存在的存档不起作用；凡是旧字节码仍可能踩到的
  兼容问题，必须在兼容层修。
- **发行前已做全量校验**：278 个 Lua 文件语法检查 0 错误；所有 hook 文件无 BOM、
  无零宽字符、无混合行尾；发行包与工作区源码逐字节核对一致。

---

## 特性

- **完整战役** —— UEF / Cybran / Aeon 共 18 关。
- **忠于原版** —— 游戏数据、文本、简报/结算布局、勋章均复刻自《最高指挥官》(2007) 数据文件。
- **零侵入方案** —— 以 `.scd` 文件夹覆盖部署，无需第三方加载器或 exe 补丁。
- **不动 FA 战役** —— 主菜单一个对话框即可选择要玩的战役，FA 原版战役照常工作。
- **兼容层** —— FA 缺失或改过签名的 SC 专属函数由 `schook` 补齐（见下节）。
- **多语言** —— 内置原版游戏的完整语言词典（CN / CZ / DE / ES / FR / IT / PL / RU / US）。

---

## 工作原理

本 Mod 以两个 `.scd` **文件夹**形式提供（在 FA 中，SCD 目录与单文件 SCD 归档作用相同）：

| 文件夹 | 用途 |
|--------|------|
| `SC_Campaign_Main.scd` | 地图（`maps/`）、Lua 脚本、纹理，以及 `schook` 钩子 |
| `SC_Campaign_Main_Localization.scd` | 原版游戏本地化合并 |

`schook` 是 FA 原生的脚本钩子机制：放在 `schook/lua/<路径>` 下的文件会在同名
基础脚本加载后**追加执行**，因此可以在不改动原文件的前提下覆盖函数。

```text
SC_Campaign_Main.scd
├── maps/                          # 18 张战役地图（SCCA_*）
├── lua/sc_campaign/               # SC 战役主逻辑（战役管理、简报、影片表等）
├── schook/lua/                    # 追加覆盖（本次修复的集中位置）
│   ├── ScenarioFramework.lua      # 兼容层 + 目标判定 + 读档兜底（14 组修复）
│   ├── ScenarioStrings.lua        # 缺失对话表兜底
│   └── ui/                        # 主菜单、战役选择、结算、公告、结局影片
└── textures/
```

本地化钩子把**原版 SC 的 `strings_db.lua`** 与 FA 的合并，再包装 `LOC()`，
使 `<LOC key>` 查询优先命中合并后的词典 —— 让原版战役在 FA 之上获得正确的母语文本。

### 本次发行包含的修复

| 类别 | 症状 | 原因 | 处理 |
|------|------|------|------|
| API 兼容 | 结算/倒计时/AI 报错或功能缺失 | SC 与 FA 同名函数签名、实现不同 | `EndOperation` 7/3 参兼容、`CreateTimerTrigger` 3→5 参、`PatrolLocationFactoriesAI` / `CDROverchargeBehavior` / `PlayEndGameMovie` 补回、`Timer = n` 倒计时补回 |
| 目标判定 | ACU 到达量子闸门、Hex5 却不完成任务 | SC 用 `categories.uel0001` 这类 **blueprint-id 类别**认 ACU；FA / BlackOps 的 ACU 是 `erl0001` 等，通常只有 `COMMAND` | 把 **8 个 ACU id** 在 `categories` 里别名到 `categories.COMMAND`，并补 API 级兜底；E05 闸门、E05 反导、R02 撤离、R05 Hex5 另有独立 watcher |
| 目标判定 | 万古第二关摧毁城市后卡关 | FA 重做过的单位销毁回调会让城市存活计数停更 | 用真实单位句柄重算存活数并补一次任务交接 |
| 重复触发 | 万古第二关单位/交接两份、第五关二阶段影片播两遍 | 地图的两个不同回调都进入同一个没有一次性保护的函数 | 在 `ScenarioInfo.Env` 里包一层幂等守卫，只让第一次交接生效 |
| 读档 | 读档后 watcher 失效、旧脚本触发不到 | 线程恢复按**函数名**解析；闭包/upvalue 会丢失 | watcher 入口统一为命名全局函数，`OnPostLoad()` 重新布防 |
| UI | 公告控件全屏后消失、结局影片无法进入评分 | FA 控件布局差异、SC 专属函数缺失 | 隐形锚点排版、`PlayEndGameMovie` shim、主菜单战役选择壳恢复 |

**为什么只放宽 ACU，不放宽卡车/闸门等剧情单位**：全战役共审计 772 处写死的
`categories.<固定ID>`，涉及 219 个 ID，其中真正因为单位替换而失效的只有 ACU。
卡车、闸门、黑日组件等是任务脚本用来精确识别目标的，放宽会误判、误触发剧情，
因此这 216 个剧情单位保持原样。

---

## 安装

### 方式 A：发行包（推荐）

下载 `SC_Campaign_Main-2026-11-11.zip`，**解压到游戏根目录**
（即 `Supreme Commander Forged Alliance\`，与 `bin`、`gamedata` 同级）。
压缩包顶层是 `gamedata/`，解压后会得到：

```text
gamedata/
├── SC_Campaign_Main.scd/
├── SC_Campaign_Main_Localization.scd/
├── LICENSE
└── readme.md
```

注意不要多套一层目录变成 `gamedata/gamedata/`。

### 方式 B：从源码安装

克隆本仓库，把这两个文件夹复制到游戏的 `gamedata\` 目录：

- `SC_Campaign_Main.scd`
- `SC_Campaign_Main_Localization.scd`

> 仓库不含体积大的 zip 发行包（见 `.gitignore`）。

### 数据文件夹（两种方式都需要）

下面 4 个数据文件夹**不随本仓库/发行包提供**，请从
[Nexus Mods](https://www.nexusmods.com/games/supremecommanderforgedalliance/mods/14)
下载，放到 `gamedata\` 下：

```text
SC_Campaign_Data_Movie.scd
SC_Campaign_Data_Music.scd
SC_Campaign_Data_Sound.scd
SC_Campaign_Data_Voice_[loc].scd
```

> **提示** —— 仅 `SC_Campaign_Data_Movie.scd` 可自制：如果你拥有原版
> 《最高指挥官》(2007)，在 `gamedata\` 下新建 `SC_Campaign_Data_Movie.scd`，
> 把原版游戏目录的 `movies` 整个复制进去作为 `movies` 子目录即可。其余三个仍须下载。

### 启用

在游戏内 Mod 管理器启用本 Mod。之后从主菜单进入战役即可看到选择对话框
（**Campaign** → **Original Campaign** / **Forged Alliance**）。

---

## 已知限制

1. **FA 自带过场影片的字幕可能被顶出屏幕** —— 这是 FA 资料片本来就有的
   排版问题，**与本移植包无关**：FA 把字幕顶边接在影片底边
   (`nis.Bottom()` / `movie.Bottom()`)，影片按宽高比缩放后上下留黑边；
   接近 16:9 的影片黑边只有 1~3 像素，6 行字幕整块落在屏幕外，
   而约 2.38:1 的影片黑边够高就能看见。原版移植走的是
   `sc_campaign/campaignmovies.lua`，字幕钉在屏幕底，因此反而是正常的。
   中文没有本地化配音、剧情全靠字幕，受这个问题影响最大；修复放在
   [`SCFA-MOD-CN/mods/scfa_i18n_zhcn_fix`](https://github.com/HaoJun0823/SCFA-MOD-CN)
   （简体中文修复补丁）里随中文玩家分发，不塞进战役发行包。
2. **万古结局影片偶发无字幕** —— 只出现过一次、未能复现，暂不处理。
3. **电影播放卡死** —— 将游戏锁定为四核；新系统播放影片时解码器可能线程互锁。
4. **塞布兰简报慢** —— 高分辨率同时解码两个视频超出解码器吞吐，属 FA 引擎级限制
   （原版游戏在高分辨率下同样如此）。
5. **鼠标异常** —— NVIDIA 某版驱动回归，较新驱动大多已修复。
6. **平衡性差异** —— 原版与资料片战役都会加载隐藏平衡性补丁，本项目不做补偿。
7. **语音/字幕错位** —— 若某句字幕是 A 语言、配音是 B 语言，请告知具体哪句；
   修复需要旧版 DirectX 工具链。

---

## 反馈问题

请务必描述**具体关卡、任务阶段和触发条件**；没有上下文的反馈无法定位。

**`game.log` 是关键。** 在 Steam 启动项末尾追加：

```text
/log "game.log"
```

游戏会在安装目录生成 `game.log`，反馈崩溃或脚本错误时请一并附上。

其它 Mod 可以共存，需自行使用战役模组解锁器。仍遇到无法解决的问题时，
FAF（Forged Alliance Forever）也自带原版战役，可作备选。

---

## 相关文档

- `campaign_lua_audit_2026-11-09.md` —— 战役 Lua 兼容性全面检查（含误报排除过程）
- `compatibility_audit_report.md` —— SC→FA API 差异审计
- `Documents/SoundProjectResources/` —— 声音/配音移植技术文档（中英）

---

## 链接

- B 站演示：<https://www.bilibili.com/video/BV1bQtb6MEHM/>
- Nexus Mods：<https://www.nexusmods.com/supremecommanderforgedalliance/mods/14>
- 百度盘：<https://pan.baidu.com/s/1Esu9jRmVfjwphoY8QxXvqg>（提取码 `bgpb`）
- QQ 群：`1108454675`
- 简体中文修复补丁：<https://github.com/HaoJun0823/SCFA-MOD-CN>

---

## 版权

本项目重新打包了《最高指挥官》/《Forged Alliance》的游戏数据
（© Gas Powered Games）。请仅在持有原版游戏的情况下使用数据文件。
Mod 化代码仅供个人 / 非商业用途，详见 `LICENSE`。
