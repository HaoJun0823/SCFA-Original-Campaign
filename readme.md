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

> 中文说明: [readme-zh.md](readme-zh.md)

---

## Release status (2026-11)

- **All 18 operations play-tested to completion** across UEF / Cybran / Aeon;
  objective checks, mission handovers, debrief / score screens and outro movies
  all verified in-game.
- **Fixes apply to existing saves.** All logic lives in `schook` modules that
  are re-imported on every load; map scripts are untouched. FA campaign saves
  embed the **compiled** map script, so editing a map file alone has no effect
  on a save that already exists.
- **Pre-release validation:** 278 Lua files pass the syntax check with 0 errors;
  every hook file is free of BOM, zero-width characters and mixed line endings;
  the release archive was byte-compared against the working tree.
- The compatibility layer in `schook/lua/ScenarioFramework.lua` covers 14 groups
  of fixes: SC/FA API signature shims (`EndOperation`, `CreateTimerTrigger`),
  restored SC-only globals (`PatrolLocationFactoriesAI`,
  `CDROverchargeBehavior`, `PlayEndGameMovie`), on-screen countdowns, the broken
  FA `CreateUnitNearTypeTrigger` thread, ACU category widening, per-mission
  watchdogs (E05 gate / SMD, R02 evacuation, R05 Hex5, A02 city), one-shot guards
  against duplicated mission handovers (A02 / A05), and save-game re-arming of
  watchers via `OnPostLoad()`.
- **Why only ACUs were widened:** of 772 hard-coded `categories.<blueprint id>`
  checks (219 distinct ids), only ACU ids break under FA / BlackOps commanders.
  Plot-specific units — trucks, gates, Black Sun components — are deliberately
  kept exact so the script cannot misidentify its targets.

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
  provided via `schook` hooks.
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
├── lua/sc_campaign/           # SC campaign logic (manager, briefings, movies)
├── schook/lua/                # appended overrides (all runtime fixes live here)
│   ├── ScenarioFramework.lua  # compat layer, objective fixes, save re-arming
│   ├── ScenarioStrings.lua    # missing dialogue table fallbacks
│   └── ui/                    # main menu, campaign select, score, announcements
└── textures/
```

The localization hook merges the **original SC `strings_db.lua`** with FA's,
then wraps `LOC()` so `<LOC key>` lookups prefer the merged table — giving the
original campaign its proper native-language text on top of FA.

---

## Installation

### Option A — release archive (recommended)

Download `SC_Campaign_Main-2026-11-11.zip` and extract it **into the game root**
(the folder containing `bin` and `gamedata`). The archive top level is
`gamedata/`, so you end up with:

```text
gamedata/
├── SC_Campaign_Main.scd/
├── SC_Campaign_Main_Localization.scd/
├── LICENSE
└── readme.md
```

Do not extract into `gamedata/` itself (that would create `gamedata/gamedata/`).

### Option B — from source

Clone this repository (or download the source) and copy these two folders into
the game's `gamedata\` directory:

- `SC_Campaign_Main.scd`
- `SC_Campaign_Main_Localization.scd`

> The large zip release is not stored in this repository (see `.gitignore`).

### Data folders (required for both options)

The following **data folders are not shipped in this repository or the release
archive** — download them from [Nexus Mods](https://www.nexusmods.com/games/supremecommanderforgedalliance/mods/14)
and place them in `gamedata\`:

- `SC_Campaign_Data_Movie.scd`
- `SC_Campaign_Data_Music.scd`
- `SC_Campaign_Data_Sound.scd`
- `SC_Campaign_Data_Voice_[loc].scd`

> **Hint** — for `SC_Campaign_Data_Movie.scd` only, if you own the original
> *Supreme Commander (2007)* you can copy the movie files directly instead of
> downloading: create `gamedata\SC_Campaign_Data_Movie.scd`, then copy the
> original game's `movies` folder into it as the `movies` subfolder.
> The other three data folders must still be downloaded from Nexus Mods.

### Enable the mod

In the FA client, enable the **SCFA — Original Campaign** mod (see the in-game
mod manager). The campaign-choice dialog appears from the main menu
(**Campaign** → **Original Campaign** / **Forged Alliance**).

---

## Known limitations

1. **FA's own movie subtitles can be pushed off screen.** This is a stock FA
   layout bug, **not caused by this port**: FA pins the subtitle top edge to the
   movie's bottom edge (`nis.Bottom()` / `movie.Bottom()`). With letterboxing,
   a near-16:9 movie leaves only 1–3 px of black bar, so the 6-line subtitle
   block falls entirely below the screen; a ~2.38:1 movie leaves enough room and
   looks fine. The original campaign port uses
   `sc_campaign/campaignmovies.lua`, which pins subtitles to the screen bottom,
   so it does not have this problem. Chinese has no localized voice-over and
   relies entirely on subtitles, so the fix is shipped with the
   [`scfa_i18n_zhcn_fix`](https://github.com/HaoJun0823/SCFA-MOD-CN) Chinese
   patch instead of this campaign release.
2. **Aeon outro subtitles missing once** — could not be reproduced; left as-is.
3. **Movie playback freeze** — lock the game to 4 cores; on modern systems the
   decoder can deadlock when playing movies.
4. **Slow Cybran briefing** — high resolutions decoding two SFD streams at once
   exceeds the decoder throughput; an engine-level FA limitation.
5. **Mouse glitches** — a known NVIDIA driver regression; mostly resolved in
   recent drivers.
6. **Balance issues** — both the base game and expansion apply a hidden balance
   patch during campaign; not something this project compensates for.
7. **Voice/subtitle mismatch** — report the exact line; the fix needs legacy
   DirectX tooling.

---

## Reporting bugs

Because the original campaign ships with its own balance patch, differences in
balance and bugs after the port are **expected**. Please report the exact
**operation, objective and situation**; bug reports without context cannot be
diagnosed.

**Getting a `game.log` is essential.** Append the following to the Steam launch
options so a `game.log` is written to the game folder on each run:

```text
/log "game.log"
```

Please include this log file when reporting crashes or script errors.

Other mods? Supported — use a campaign-mod unlocker. Stuck with an unfixable
issue? The Forged Alliance Forever (FAF) build also ships the original campaign
as an alternative.

---

## Related documents

- `campaign_lua_audit_2026-11-09.md` — full Lua compatibility audit
- `compatibility_audit_report.md` — SC→FA API drift report
- `Documents/SoundProjectResources/` — audio / VO porting notes (EN / ZH)

---

## Links

- Bilibili showcase: <https://www.bilibili.com/video/BV1bQtb6MEHM/>
- Nexus Mods: <https://www.nexusmods.com/supremecommanderforgedalliance/mods/14>
- QQ group: `1108454675`
- Chinese localization patches: <https://github.com/HaoJun0823/SCFA-MOD-CN>

---

## License

This project repackages game data from *Supreme Commander* / *Supreme
Commander: Forged Alliance* (© Gas Powered Games). Use the data files only if
you own the original games. The modding code is provided for personal /
non-commercial use; see `LICENSE`.
Thanks to FA Forever for the community resources.
