---
AIGC:
  ContentProducer: '001191110102MAD55U9H0F10002'
  ContentPropagator: '001191110102MAD55U9H0F10002'
  Label: '1'
  ProduceID: 'bcf5300d-cafb-42cf-8516-4a7be38fa726'
  PropagateID: 'bcf5300d-cafb-42cf-8516-4a7be38fa726'
  ReservedCode1: '6797251c-b54d-48a9-8a0f-6affbe56ea67'
  ReservedCode2: '6797251c-b54d-48a9-8a0f-6affbe56ea67'
---

# The FMV is missing a cue
- FMV_UEF_Intro_2
- FMV_UEF_Outro_2
- FMV_Aeon_Intro_2

Is this something that actually exists?

## 结论

SC 原版 SC_FMV.xsb（语音 bank）只有 13 个 cue，缺少上述 3 个。
背景音 bank SC_FMV_BG.xsb 有全部 18 个 cue，但语音 bank 没有。
这是 SC 原版数据的固有缺失，不是重建错误。

已修复：campaignmovies.lua 中对这 3 个 cue 跳过 PlayVoice，仅播放背景音。

# Cybran briefing movies play in slow motion (won't fix)

## Symptom

During Cybran campaign operation briefing, movie playback is noticeably slow (slow-motion effect). The QAI movie area in the upper right is also affected. UEF and Aeon factions play normally.

## Root cause

The Cybran briefing screen uniquely renders two SFD movie regions simultaneously: the main briefing movie (center) and the QAI movie (upper right bracket). The FA engine's MPEG decoder cannot keep up with decoding two video streams at high resolutions (e.g. 2560x1440), causing frame drops that manifest as slow-motion playback.

## Why this is not fixed

- This is an engine-level performance limitation of FA, not a bug in the ported code
- The ported code is identical to the SC original logic, and the SFD file format is the same
- **The original Supreme Commander game also exhibits this behavior at high resolutions** — it triggers whenever the Cybran briefing renders two movie areas at once
- The filename case mismatch (code references `QAI_loop.sfd` vs disk file `QAI_LOOP.sfd`) is not the cause; SC original has the same mismatch and works fine