# SCFA — Original Campaign

Bring the original **Supreme Commander (2007)** single-player campaign into
**Supreme Commander: Forged Alliance**.

This project faithfully re-creates the original campaign in the FA engine:
all three faction storylines — **UEF**, **Cybran**, **Aeon** — with **6
operations each (18 in total)**, including briefings, in-mission narration,
debriefing / score screens, operation medals, and the original game data.

Built with FA's **schook** hook system and **`.scd` directory-mount** overlay,
so **no stock FA files are modified** and the Forged Alliance campaign remains
fully intact.

---

## Features

- **Complete campaign** — 18 operations across UEF / Cybran / Aeon.
- **Faithful to the original** — game data, text, briefing / score layouts and
  medals are recreated from the Supreme Commander (2007) data files.
- **Zero-mod approach** — deployed as `.scd` folder overlays; no third-party
  mod loader or exe patching required.
- **FA campaign untouched** — a single dialog lets you choose which campaign to
  play, and FA's own campaign keeps working as before.
- **Compatibility layer** — SC-only engine/script functions that FA lacks are
  provided via `schook` hooks (e.g. `PatrolLocationFactoriesAI`,
  `CDROverchargeBehavior`).
- **Multilingual** — ships with full language dictionaries for the original
  game (CN / CZ / DE / ES / FR / IT / PL / RU / US).

---

## How it works

The mod is delivered as two `.scd` **folders** (SCD directories work the same as
single-file SCD archives in FA):

| Folder | Purpose |
|--------|---------|
| `SC_Campaign_Main.scd` | Maps (`maps/`), Lua scripts, textures, and `schook` hooks |
| `SC_Campaign_Main_Localization.scd` | Original-game localization merge (see below) |

`schook` is FA's native script-hook mechanism: a file placed under
`schook/lua/<path>` is **appended** to the base script of the same path after it
loads, letting us override functions without touching the original files.

```text
SC_Campaign_Main.scd
├── maps/                      # 18 campaign maps (SCCA_*)
├── lua/                       # SC campaign logic (campaignmanager, briefings, ...)
├── schook/lua/                # appended overrides
│   ├── ScenarioFramework.lua  # EndOperation (SC 7-arg + FA 3-arg signatures)
│   ├── ai/AIBehaviors.lua     # CDROverchargeBehavior forwarder
│   ├── platoon.lua            # PatrolLocationFactoriesAI injector
│   └── ui/                    # main menu, campaign select, score screen, ...
└── textures/
```

The localization hook merges the **original SC `strings_db.lua`** with FA's,
then wraps `LOC()` so `<LOC key>` lookups prefer the merged table — giving the
original campaign its proper native-language text on top of FA.

---

## Installation

### 1. Get the two source folders

Clone this repository (or download the release). The two required folders are:

- `SC_Campaign_Main.scd`
- `SC_Campaign_Main_Localization.scd`

### 2. Copy the data folders

The following **data folders are intentionally not shipped** — copy them from a
Supreme Commander (2007) install, or make them empty:

- `SC_Campaign_Data_Movie.scd`
- `SC_Campaign_Data_Music.scd`
- `SC_Campaign_Data_Sound.scd`
- `SC_Campaign_Data_Voice_[loc].scd`

> **Hint** — if you own the original game you do **not** need to download the
> movies:
>
> 1. Open the DLC game folder `Supreme Commander Forged Alliance\gamedata`.
> 2. Create a folder `SC_Campaign_Data_Movie.scd`.
> 3. Open the original game folder `Supreme Commander\`.
> 4. Copy `Supreme Commander\movies` → `...\gamedata\SC_Campaign_Data_Movie.scd\movies`.

### 3. Enable the mod

In the FA client, enable the **SCFA — Original Campaign** mod (see the in-game
mod manager). The campaign-choice dialog appears from the main menu
(**Campaign** → **Original Campaign** / **Forged Alliance**).

---

## Reporting bugs

Because the original campaign ships with its own balance patch, differences in
balance and bugs after the port are **expected**. Please report the exact
**scene and situation**; bug reports without context cannot be diagnosed.

**Getting a `game.log` is essential.** Append the following to the Steam launch
options so a `game.log` is written to the game folder on each run:

```text
/log "game.log"
```

Please include this log file when reporting crashes or script errors.

### Common issues

1. **Crash** — the Lua hooks are still being hardened. Reproduce with the
   `/log` option above and share `game.log`.
2. **Voice/subtitle mismatch** — subtitle shows language A while audio plays B.
   Report which line; the fix needs legacy DirectX tooling.
3. **Movie playback freeze** — lock the game to 4 cores; on modern systems the
   decoder can deadlock when playing movies.
4. **Slow Cybran briefing** — high resolutions decoding two SFD streams at once
   exceeds the decoder throughput; an engine-level FA limitation (the original
   game behaves the same at high resolutions).
5. **Mouse glitches** — a known NVIDIA driver regression; mostly resolved in
   recent drivers.
6. **Balance issues** — both the base game and expansion apply a hidden balance
   patch during campaign; not something this project can fully compensate for.
7. **Unplayable** — broken unit data (same as FA mission 5 with mods); contact
   the author.

Other mods? Supported — use a campaign-mod unlocker. Stuck with an unfixable
issue? The Forged Alliance Forever (FAF) build also ships the original campaign
as an alternative.

---

## Links

- Bilibili showcase: <https://www.bilibili.com/video/BV1bQtb6MEHM/>
- Nexus Mods: <https://www.nexusmods.com/supremecommanderforgedalliance/mods/14>
- QQ group: `1108454675`

---

## License

This project repackages game data from *Supreme Commander* / *Supreme
Commander: Forged Alliance* (© Gas Powered Games). Use the data files only if
you own the original games. The modding code is provided for personal /
non-commercial use.
Thanks to FA Forever for the community resources.