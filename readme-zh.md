---
AIGC:
  ContentProducer: '001191110102MAD55U9H0F10002'
  ContentPropagator: '001191110102MAD55U9H0F10002'
  Label: '1'
  ProduceID: 'b5a023fa-256c-4e2d-86ac-e1d0d071b521'
  PropagateID: 'b5a023fa-256c-4e2d-86ac-e1d0d071b521'
  ReservedCode1: '931228bf-a286-4327-bbab-23f2d99344dc'
  ReservedCode2: '931228bf-a286-4327-bbab-23f2d99344dc'
---

# SCFA — 原版战役移植

将 2007 年原版《最高指挥官》(Supreme Commander) 的单人战役移植到
《Forged Alliance》(FA)。

本项目在 FA 引擎中忠实复刻了原版战役：三大阵营完整剧情线 —— **UEF / Cybran / Aeon**，每方 **6 关、共 18 关**，包括简报、任务内配音、结算/评分界面、作战勋章以及原版游戏数据。

采用 FA 的 **schook** hook 系统 + **`.scd` 目录挂载**覆盖方式实现，**不改动任何 FA 原版文件**，Forged Alliance 战役完全保留。

---

## 特性

- **完整战役** —— UEF / Cybran / Aeon 共 18 关。
- **忠于原版** —— 游戏数据、文本、简报/结算布局、勋章均复刻自《最高指挥官》(2007) 数据文件。
- **零模组方案** —— 以 `.scd` 文件夹覆盖部署，无需第三方加载器或 exe 补丁。
- **不动 FA 战役** —— 一个对话框即可选择要玩的战役，FA 原版战役照常工作。
- **兼容层** —— FA 缺失的 SC 专属引擎/脚本函数通过 `schook` hook 补齐（如 `PatrolLocationFactoriesAI`、`CDROverchargeBehavior`）。
- **多语言** —— 内置原版游戏的完整语言词典（CN / CZ / DE / ES / FR / IT / PL / RU / US）。

---

## 工作原理

本 Mod 以两个 `.scd` **文件夹**形式提供（在 FA 中，SCD 目录与单文件 SCD 归档作用相同）：

| 文件夹 | 用途 |
|--------|------|
| `SC_Campaign_Main.scd` | 地图（`maps/`）、Lua 脚本、纹理，以及 `schook` 钩子 |
| `SC_Campaign_Main_Localization.scd` | 原版游戏本地化合并（见下文） |

`schook` 是 FA 原生的脚本钩子机制：放在 `schook/lua/<路径>` 下的文件会在同名基础脚本加载后**追加执行**，从而让我们无需改动原文件即可覆盖函数。

```text
SC_Campaign_Main.scd
├── maps/                      # 18 张战役地图（SCCA_*）
├── lua/                       # SC 战役逻辑（campaignmanager、简报等）
├── schook/lua/                # 追加覆盖
│   ├── ScenarioFramework.lua  # EndOperation（兼容 SC 7 参数 + FA 3 参数）
│   ├── ai/AIBehaviors.lua     # CDROverchargeBehavior 转发
│   ├── platoon.lua            # PatrolLocationFactoriesAI 注入
│   └── ui/                    # 主菜单、战役选择、结算界面等
└── textures/
```

本地化钩子将**原版 SC 的 `strings_db.lua`** 与 FA 的合并，然后包装 `LOC()`，使 `<LOC key>` 查询优先命中合并后的词典——让原版战役在 FA 之上获得正确的母语文本。

---

## 安装

### 1. 获取两个源码文件夹

克隆本仓库（或下载发行版）。需要这两个文件夹：

- `SC_Campaign_Main.scd`
- `SC_Campaign_Main_Localization.scd`

### 2. 下载数据文件夹

以下**数据文件夹不随仓库提供**——请从 [Nexus Mods](https://www.nexusmods.com/games/supremecommanderforgedalliance/mods/14) 下载，放到与上面两个源码文件夹相同的目录下：

```
SC_Campaign_Data_Movie.scd
SC_Campaign_Data_Music.scd
SC_Campaign_Data_Sound.scd
SC_Campaign_Data_Voice_[loc].scd
```

> **提示** —— 仅 `SC_Campaign_Data_Movie.scd` 这一个，如果你有原版《最高指挥官》(2007)，可以直接拷贝电影文件而不用下载：
>
> 1. 打开 DLC 游戏文件夹 `Supreme Commander Forged Alliance\gamedata`。
> 2. 新建文件夹 `SC_Campaign_Data_Movie.scd`。
> 3. 打开原版游戏文件夹 `Supreme Commander\`。
> 4. 将 `Supreme Commander\movies` 复制到 `...\gamedata\SC_Campaign_Data_Movie.scd\movies`。
>
> 其余三个数据文件夹仍须从 Nexus Mods 下载。

### 3. 启用 Mod

在 FA 客户端中启用 **SCFA — Original Campaign** Mod（见游戏内 Mod 管理器）。之后从主菜单进入战役即可看到选择对话框（**Campaign** → **Original Campaign** / **Forged Alliance**）。

---

## 反馈问题

由于原版战役自带平衡性数据补丁，移植后存在平衡差异和 BUG 是**必然的**。请务必汇报具体的**场景和情况**；没有上下文的反馈我无法解决！

**获取 `game.log` 至关重要。** 在 Steam 启动项末尾追加以下参数，游戏运行后会在游戏文件夹生成 `game.log`：

```
/log "game.log"
```

反馈崩溃或脚本错误时请一并附上该日志文件。

### 常见问题

1. **崩溃** —— Lua 钩子仍在打磨中。用上面的 `/log` 参数复现，并把 `game.log` 发给我。
2. **语音/字幕错位** —— 表现特征为字幕是 A、语音是 B。请告诉我哪段，修复需要用到 20 年前的 DirectX 工具。
3. **电影播放卡死** —— 将游戏锁定为四核可解决；新系统播放电影时解码器会线程互锁导致卡顿。
4. **塞布兰简报慢** —— 大分辨率同时解码两个视频，解码器性能不够，会是 1/2 速度；这是 FA 引擎级限制（原版游戏在大分辨率下同样如此）。
5. **鼠标有问题** —— NVIDIA 显卡驱动某版本的回归；最新驱动大多已修复。
6. **平衡性有问题** —— 原版和资料片战役都带隐藏平衡性 Mod（打战役必定加载），这部分不打算动，自求多福。
7. **正常玩不下去** —— 单位数据不对（同 FA 开 Mod 第 5 关），联系作者修复。

支持其它 Mod 吗？支持，自己打战役模组解锁器。还有修不好的问题？FAF（Forged Alliance Forever）版本也带原版战役，可作备选。

---

## 链接

- B 站演示：<https://www.bilibili.com/video/BV1bQtb6MEHM/>
- Nexus Mods：<https://www.nexusmods.com/supremecommanderforgedalliance/mods/14>
- 百度盘：<https://pan.baidu.com/s/1Esu9jRmVfjwphoY8QxXvqg>（提取码 `bgpb`）
- QQ 群：`1108454675`

---

## 版权

本项目重新打包了《最高指挥官》/《Forged Alliance》的游戏数据（© Gas Powered Games）。请仅在持有原版游戏的情况下使用数据文件。Mod 化代码仅供个人 / 非商业用途。