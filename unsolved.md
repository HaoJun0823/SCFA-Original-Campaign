---
AIGC:
  ContentProducer: '001191110102MAD55U9H0F10002'
  ContentPropagator: '001191110102MAD55U9H0F10002'
  Label: '1'
  ProduceID: '1569fc91-342d-432f-8efa-a217320b2a05'
  PropagateID: '1569fc91-342d-432f-8efa-a217320b2a05'
  ReservedCode1: '420b14e7-30d0-4304-9381-8461a9fa2264'
  ReservedCode2: '420b14e7-30d0-4304-9381-8461a9fa2264'
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