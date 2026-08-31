---
AIGC:
  ContentProducer: '001191110102MAD55U9H0F10002'
  ContentPropagator: '001191110102MAD55U9H0F10002'
  Label: '1'
  ProduceID: '26a61311-fdb5-4383-a86f-7645a9e3cc2c'
  PropagateID: '26a61311-fdb5-4383-a86f-7645a9e3cc2c'
  ReservedCode1: 'e51c3e74-005d-433b-93e9-441510ca835c'
  ReservedCode2: 'e51c3e74-005d-433b-93e9-441510ca835c'
---

# SC→FA Campaign Audio Rebuild Project: Technical Documentation (English)

> **Purpose**: This document fully records the process of recompiling Supreme Commander (SC) original campaign audio from XACT v41 to Forged Alliance (FA) v43 format. Any technician can independently reproduce the build using this document and the project resources.

---

## 1. Project Overview

### 1.1 Goal

Recompile SC's original XACT v41 audio banks (.xsb/.xwb) to FA-engine-loadable v43 format and deploy them into .scd directories under `gamedata/`, enabling SC campaign audio to play correctly in the FA engine.

### 1.2 Key Constraints

- SC audio is XACT v41 format; FA engine strictly validates version numbers and rejects v41 banks with "Invalid data"
- Microsoft DirectX SDK (November 2007) XactBld.exe is required for compilation
- No FAF or third-party audio resources are used (copyright sensitivity)
- Deployment is via direct .scd directory overlay, not mod-based

### 1.3 XACT Version Differences

| Version | .xsb magic | .xwb magic | .xgs magic |
|---|---|---|---|
| SC (v41) | `SDBK` + 0x29 | `WBND` + 0x29 | `XGSF` + 0x29 |
| FA (v43) | `SDBK` + 0x2B | `WBND` + 0x2B | `XGSF` + 0x2B |

- Version number is stored in 1 byte at offset +4 after the 4-char magic
- v41 and v43 have completely different header structure offsets and field layouts
- Binary-editing bank names is forbidden (breaks header CRC); name changes must be made in the .xap source file and recompiled

---

## 2. Directory Structure

The project resources are located at `SCFA-Original-Campaign/Documents/SoundProjectResources/`:

```
SoundProjectResources/
├── XAP_Engineering/          # 216 .xap XACT project files (build inputs)
├── Build_Scripts/             # 35 Python/PowerShell build scripts
├── Mapping_Data/              # 17 JSON mapping tables + cue name references
├── Build_Outputs/             # 213 build output directories (.xsb + .xgs, no .xwb)
├── Reference_XAP/             # 15 reference XAP files + global settings
├── Tools/                     # unxwb.exe + ffmpeg.exe + source code
└── HANDOFF_SC_FA_Audio_Debug.md  # Original handoff document
```

### 2.1 XAP_Engineering (XACT Project Files)

216 .xap files total, named by build target (`build_{dirname}_{xapname}`), in three categories:

| Category | Count | Example | Description |
|---|---|---|---|
| Root sound banks | 36 | `build_SC_UAL_SC_UAL.xap` | 36 SC_-prefixed sound banks (Explosions, Impacts, faction UAA~URS series) |
| US voice banks | 25 | `build_A01_VO_A01_VO.xap` | 18 mission VO + 7 special VO (COMPUTER_*, Experimental, Instructor, FMV, Ops) |
| Multi-language voice | 155 | `build_DE_A01_VO_A01_VO.xap` | 5 languages × 25 banks + language FMV/Ops variants |

Each .xap file contains a complete XACT project definition: Global Settings + Wave Bank + Sound Bank (with Sound and Cue definitions).

### 2.2 Build_Outputs (Build Outputs)

213 subdirectories, each containing compiled `.xsb` (Sound Bank) and `.xgs` (Global Settings). `.xwb` (Wave Bank, containing audio data) is not included in this resource package. 3 `test_interface*.xap` files are debug test files and were excluded from migration.

### 2.3 Mapping_Data (Mapping Data)

| File | Description |
|---|---|
| `all_root_mappings.json` | Cue→wave mappings for 36 root sound banks (435KB) |
| `all_bank_mappings.json` | Complete mappings for all banks (644KB) |
| `interface_mapping_correct.json` | Corrected Interface bank mapping (includes Select sound merge) |
| `fmv_bg_mapping_correct.json` | Corrected FMV background bank mapping |
| `ambienttest_mapping.json` | Ambient sound bank mapping |
| `wave_mapping.json` | Generic wave index mapping |
| `batch_root_rebuild_results.json` | Root bank build result report |
| `vo_rebuild_results.json` | US VO bank build results |
| `vo_rebuild_remaining_results.json` | Remaining VO bank build results |
| `tutorial_rebuild_results.json` | Tutorial VO bank build results |
| `multi_lang_vo_results.json` | Multi-language VO build results |
| `sound_rebuild_results.json` | Sound bank build results |
| `xsb_cue_names.txt` / `xsb_cue_names_all.txt` | Cue name lists for all banks |

---

## 3. Build Tools & Environment

### 3.1 Required Tools

| Tool | Path | Purpose |
|---|---|---|
| XactBld.exe | `C:\Program Files (x86)\Microsoft DirectX SDK (November 2007)\Utilities\Bin\x86\XactBld.exe` | XACT project compilation (v41→v43) |
| Python 3 | System PATH | Running build scripts |
| unxwb.exe | `Tools/unxwb.exe` | XWB extraction/verification (`-l` lists entries, `-b <offset>` extracts by cue name) |
| ffmpeg.exe | `Tools/ffmpeg.exe` | Audio format conversion |

### 3.2 Key Path Constants (Hardcoded in Scripts)

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

### 3.3 Audio Source Files

All WAV source files are in `AudioProject_2/extract_all/`, in two main categories:

```
extract_all/
├── AmbientTest/          # Root sound WAVs (organized by bank name)
├── Explosions/
├── Interface/
├── Music/
├── Op_Briefing/
├── UAL/
├── ... (46 root directories total)
└── Voice/
    └── US/
        ├── A01_VO/       # US voice WAVs
        ├── ... (25 VO directories)
        └── Tutorials/    # 23 tutorial VO directories
```

---

## 4. Build Pipeline

### 4.1 Overview

The audio rebuild consists of **6 build pipelines**, each automated by Python scripts:

| Pipeline | Script | Target | Output Count |
|---|---|---|---|
| Root sounds | `batch_rebuild_root.py` | 36 SC_-prefixed sound banks | 36 |
| US voices | `batch_rebuild_vo.py` | 18 mission VO banks | 18 |
| Remaining VO | `batch_rebuild_remaining_vo.py` | 7 special VO banks | 7 |
| Tutorial VO | `batch_rebuild_tutorial_vo.py` | 23 tutorial VO banks | 23 |
| Multi-language VO | `batch_rebuild_multi_lang_vo.py` | 5 languages × 25 banks | 125 |
| Ambient/Music | `rebuild_sound_banks.py` | AmbientTest + Music | 2 |

### 4.2 Unified Pipeline per Bank

Each bank build follows a 5-step standardized process:

```
Step 1: Parse v41 XSB → Get cue→wave mapping
Step 2: Generate .xap XACT project file
Step 3: Compile with XactBld to v43
Step 4: Verify v43 XSB cue→wave mapping correctness
Step 5: Deploy to FA gamedata directory
```

#### Step 1: Parse v41 XSB

Use the `XSBv41Parser` class from `parse_xsb_v41.py` to parse the SC original .xsb file:

```python
from parse_xsb_v41 import XSBv41Parser

xsb_path = os.path.join(SC_SOUND, f"{bank_name}.xsb")
parser = XSBv41Parser(xsb_path)
parser.parse()

# parser.cue_mappings contains per-cue data:
#   - cue_index: cue index in the XSB
#   - cue_name: cue name
#   - wave_refs: [(wave_bank_idx, wave_idx), ...] referenced waves
#   - sound_offset: offset of sound data in XSB
```

For root sound banks, **category** and **volume** are also extracted from the v41 XSB sound data:

```python
# Read from sound_offset
flags = data[off]; off += 1
cat_id = struct.unpack_from('<H', d, off)[0]; off += 2
vol_byte = d[off]

# Category ID → name mapping (24 categories)
CAT_NAMES = [
    'Global', 'Default', 'Music', 'World', 'Units', 'Ambient', 'Weapons', 'Destroy',
    'Rumble', 'Interface', 'UnitsUEF', 'UnitsAEON', 'UnitsCYBRAN',
    'UnitsUEFAir', 'UnitsCYBRANAir', 'UnitsAEONAir',
    'ActiveLoopsUEF', 'ActiveLoopsCYBRAN', 'ActiveLoopsAEON',
    'Unit Select', 'FMV', 'Op_Briefing', 'VO', 'US',
]

# Volume byte → XAP centibels conversion (nonlinear)
def byte_to_xap_volume(vol_byte):
    if vol_byte == 255: return -9600  # silence
    a = -96.0; b = 0.432254984608615; c = 80.1748600297963; d = 67.7385212334047
    db = ((a - d) / (1 + (math.pow(vol_byte / c, b)))) + d
    return round(db * 100)
```

#### Step 2: Generate .xap File

The .xap file is the text source for XactBld, containing three main blocks:

```
Global Settings { ... }    ← Extracted from FA_vanilla_VOs_real_original.xap
Wave Bank { ... }          ← Defines wave list (each wave references a WAV file)
Sound Bank { ... }         ← Defines Sound + Cue (with category, volume, track event)
```

**Global Settings**: Extracted from `FA_vanilla_VOs_real_original.xap` (line 1 to end of Global Settings block); shared across all banks.

**Wave Bank generation**:

```python
out.append("Wave Bank")
out.append("{")
out.append(f"    Name = {deploy_name};")
out.append(f"    Windows File = {build_dir}\\Win\\{deploy_name}.xwb;")
out.append("    Streaming = 1;")
out.append("    Seek Tables = 1;")
out.append("    Compression Preset Name = ADPCM 256;")

for merged_idx, wb_name, orig_idx, wav_file in merged_waves:
    ch, sr, data_len = get_wav_info(wav_path)  # Parse WAV header
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

**Sound Bank generation** (one Sound + one Cue block per cue):

```python
out.append("    Sound")
out.append("    {")
out.append(f"        Name = {cue_name};")
out.append(f"        Volume = {xap_vol};")  # Extracted from v41 XSB
out.append("        Category Entry")
out.append("        {")
out.append(f"            Name = {cat_name};")  # Extracted from v41 XSB
out.append("        }")
out.append("        Track")
out.append("    {")
out.append("            Play Wave Event")
out.append("            {")
out.append("                Wave Entry")
out.append("                {")
out.append(f"                    Bank Name = {deploy_name};")
out.append(f"                    Entry Index = {merged_idx};")  # Merged wave index
out.append("                }")
out.append("            }")
out.append("        }")
out.append("    }")
```

**Multi wave bank merging for root sound banks**:

Root banks may merge multiple original wave banks (e.g., Explosions = Explosions + ExplosionsStream). The merge logic:

```python
def build_merged_wave_list(bank_name, mapping):
    """
    Merges waves from multiple original wave banks into a continuous index list.
    Returns: [(merged_index, wave_bank_name, original_wave_index, wav_filename), ...]
    """
    # Handles two WAV naming formats:
    # - wave_NNN.wav: wave_index = NNN (parsed from filename)
    # - cue_name.wav: wave_index looked up from JSON mapping
    # Unmatched files are assigned to available index gaps
```

#### Step 3: Compile

```python
cmd = [XACTBLD, "/WINDOWS", xap_path]
result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
# Output: build_dir/Win/{bank_name}.xsb, .xwb, SupCom.xgs
```

XactBld compilation caveats:
1. .xap files must not have UTF-8 BOM
2. Do not merge multiple Wave Banks into a single .xap (causes compilation errors)
3. Missing Cache block causes XactBld to fall back from ADPCM to PCM output

#### Step 4: Verify

Use `verify_xsb_v43.py` to parse the compiled v43 XSB and cross-validate against v41 mappings:

```python
from verify_xsb_v43 import parse_xsb
info = parse_xsb(xsb_path)

# Compare v43 cue→wave mapping with v41 expected mapping
for cue_name, expected_waves in expected.items():
    v43_waves = info['cue_refs'][i]
    if not v43_waves.issubset(expected_waves):
        mismatches += 1
```

#### Step 5: Deploy

```python
# Sound banks → SC_Campaign_Data_Sound.scd/sounds/
shutil.copy2(src_xsb, os.path.join(FA_SOUND, deploy_name + ".xsb"))
shutil.copy2(src_xwb, os.path.join(FA_SOUND, deploy_name + ".xwb"))

# Voice banks → SC_Campaign_Data_Voice_US.scd/sounds/Voice/US/
shutil.copy2(src_xsb, os.path.join(FA_VOICE, bank_name + ".xsb"))
shutil.copy2(src_xwb, os.path.join(FA_VOICE, bank_name + ".xwb"))
```

---

## 5. Deployment Path Rules

### 5.1 Sound Banks (PlaySound calls)

```
gamedata/SC_Campaign_Data_Sound.scd/sounds/
├── SC_AmbientTest.xsb/.xwb     # Ambient sounds
├── SC_Music.xsb/.xwb           # Background music
├── SC_FMV_BG.xsb/.xwb          # FMV background audio
├── SC_Op_Briefing.xsb/.xwb     # Briefing background audio
├── SC_Interface.xsb/.xwb       # UI sounds
├── Tutorial_SE.xsb/.xwb        # Tutorial sound effects
├── SC_Explosions.xsb/.xwb      # Explosion sounds
├── SC_Impacts.xsb/.xwb         # Impact sounds
└── ... (42 banks total)
```

### 5.2 Voice Banks (PlayVoice calls)

```
gamedata/SC_Campaign_Data_Voice_US.scd/sounds/Voice/US/
├── A01_VO.xsb/.xwb ~ A06_VO.xsb/.xwb    # Aeon mission voices
├── C01_VO.xsb/.xwb ~ C06_VO.xsb/.xwb    # Cybran mission voices
├── E01_VO.xsb/.xwb ~ E06_VO.xsb/.xwb    # UEF mission voices
├── COMPUTER_AEON_VO.xsb/.xwb            # Aeon AI voice
├── COMPUTER_CYBRAN_VO.xsb/.xwb          # Cybran AI voice
├── COMPUTER_UEF_VO.xsb/.xwb             # UEF AI voice
├── Experimental_VO.xsb/.xwb             # Experimental unit voices
├── Instructor_VO.xsb/.xwb               # Instructor voice
├── SC_FMV.xsb/.xwb                      # FMV movie voices
├── Ops_VO.xsb/.xwb                      # Ops voices
└── Tutorials/
    ├── TUA100.xsb/.xwb ~ TUF300.xsb/.xwb  # 23 tutorial VO banks
    └── ...
```

### 5.3 Special Naming Rules

| Bank | XSB filename | XWB filename | Internal bank name | Notes |
|---|---|---|---|---|
| FMV | SC_FMV.xsb | SC_FMV.xwb | SC_FMV | Lua references `Bank='SC_FMV'`; must use SC_ prefix |
| Ops | Ops.xsb | Ops_VO.xwb | Ops | XSB and XWB filenames differ (preserves SC original naming) |
| Root sounds | SC_{name}.xsb | SC_{name}.xwb | SC_{name} | Unified SC_ prefix to avoid FA original conflicts |

### 5.4 Multi-language Deployment

```
gamedata/
├── SC_Campaign_Data_Voice_US.scd/sounds/Voice/US/
├── SC_Campaign_Data_Voice_DE.scd/sounds/Voice/DE/
├── SC_Campaign_Data_Voice_ES.scd/sounds/Voice/ES/
├── SC_Campaign_Data_Voice_FR.scd/sounds/Voice/FR/
├── SC_Campaign_Data_Voice_IT.scd/sounds/Voice/IT/
└── SC_Campaign_Data_Voice_RU.scd/sounds/Voice/RU/
```

SC original voice directory suffix mapping (`LANG_SC_MAP`):

| Deploy language | SC original directory suffix |
|---|---|
| US | US |
| DE | DE_BAK |
| ES | ES_BAK |
| FR | FR_BAK |
| IT | IT_BAK |
| RU | RU_BAK |

---

## 6. Lua Playback Mechanism

### 6.1 Briefing Playback (operationbriefing.lua)

```
operationvars.lua:MakeOpVars()
  → op_MovPfx = thisFacLtr .. op_num   (e.g., "A01", "C01", "E01")
  → Cybran R→C prefix conversion

operationbriefing.lua:CreateUI(operationID, briefingData, faction, ...)
  → opCue = opMovPfx .. '_B' .. num    (e.g., "A01_B01")
  → opBank = opMovPfx .. '_VO'         (e.g., "A01_VO")

LoadMovie(movTable, num, phase)
  → mov.voSound = Sound({Cue = opCue, Bank = opBank})           # Main voice (loud)
  → mov.bgSound = Sound({Cue = opCue, Bank = 'SC_Op_Briefing'}) # Background overlay (quiet)
```

**Key design**: Briefings simultaneously play two banks' same-named cues. voSound is the main voice; bgSound is a low-volume background overlay (Volume=-800, i.e., -80dB). This is SC original design, not a bug.

### 6.2 FMV Playback (campaignmovies.lua)

```
PlayCampaignMovie(movieName, ...)
  → cueName = movieName  (e.g., "FMV_uef_Intro")
  → cueName = FixCueName(cueName)  (e.g., "FMV_uef_Intro" → "FMV_UEF_Intro")

movie:Set("/movies/" .. movieName .. ".sfd",
    Sound({Cue = cueName, Bank = 'SC_FMV_BG'}),   # Background audio
    Sound({Cue = cueName, Bank = 'SC_FMV'}))       # Voice
```

### 6.3 Deployed Lua Bank Name Changes

SC original Lua references bare names (e.g., `Bank='Op_Briefing'`); the deployed version uses `SC_` prefix (e.g., `Bank='SC_Op_Briefing'`). Only the bank name differs; all other logic is identical.

---

## 7. Bank Name Matching Mechanism

- Lua's `Bank = 'SC_FMV'` matches the **internal bank name** stored in the .xsb, not the filename
- Bank name is a null-terminated ASCII string stored in a 64-byte slot
- In .xsb, bank name is stored at offsets 82 and 146
- In .xwb, bank name is stored at offset 56

---

## 8. Audio Bank Classification & Counts

### 8.1 Sound Banks (SC_Campaign_Data_Sound.scd)

| Category | Bank Count | Description |
|---|---|---|
| Core (campaign-referenced) | 6 | SC_Interface, SC_AmbientTest, SC_Music, SC_FMV_BG, SC_Op_Briefing, Tutorial_SE |
| Unit sounds | 30 | UAA~URS series (9 per faction + Destroy/Weapon splits) |
| General sounds | 6 | SC_Explosions, SC_Impacts, SC_Group_Move, SC_UnitRumble, SC_UnitsGlobal |
| Total | 42 | |

### 8.2 Voice Banks (SC_Campaign_Data_Voice_US.scd)

| Category | Bank Count | Description |
|---|---|---|
| Mission VO | 18 | A01~A06, C01~C06, E01~E06 |
| AI VO | 3 | COMPUTER_AEON/CYBRAN/UEF_VO |
| Special VO | 4 | Experimental_VO, Instructor_VO, SC_FMV, Ops_VO |
| Tutorial VO | 23 | TUA100~TUF300 |
| Total | 48 | |

### 8.3 Multi-language Grand Total

6 languages (US/DE/ES/FR/IT/RU) × 48 banks = **288 voice banks** + 42 sound banks = **330 banks total**

---

## 9. XAP Project File Structure

### 9.1 Global Settings

Extracted from `FA_vanilla_VOs_real_original.xap`; shared across all banks. Contains XACT global configuration (category definitions, compression presets, RPCs, etc.).

### 9.2 Wave Bank Block

```
Wave Bank
{
    Name = SC_UAL;                              // Deploy name (SC_ prefix)
    Windows File = ...\Win\SC_UAL.xwb;          // Output path
    Streaming = 1;                              // Streaming playback
    Seek Tables = 1;                            // Seek tables
    Compression Preset Name = ADPCM 256;        // Compression format

    Wave
    {
        Name = UAL_000;                         // Wave name
        File = ...\extract_all\UAL\wave_000.wav; // Source WAV path
        Compression Preset Name = ADPCM 256;
        Cache
        {
            Channels = 1;                       // Parsed from WAV header
            Sampling Rate = 44100;
            Play Region Length = 12345;          // data chunk size
        }
    }
    // ... more waves
}
```

### 9.3 Sound Bank Block

```
Sound Bank
{
    Name = SC_UAL;
    Windows File = ...\Win\SC_UAL.xsb;

    Sound
    {
        Name = UAL_Bot_Select;                  // Matches cue name
        Volume = -300;                          // Extracted from v41 XSB (centibels)
        Category Entry
        {
            Name = Units;                       // Extracted from v41 XSB
        }
        Track
        {
            Play Wave Event
            {
                Wave Entry
                {
                    Bank Name = SC_UAL;
                    Entry Index = 0;            // Merged wave index
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
            Index = 0;                          // Sound index
        }
    }
}
```

---

## 10. Known Issues & Solutions

### 10.1 SC_FMV Format Fallback

**Issue**: SC_FMV .xap declares ADPCM 256, but the actual output is PCM 16-bit.
**Cause**: Missing Cache block in .xap causes XactBld to fall back to PCM.
**Impact**: FA's original X_FMV also uses PCM; format itself is not the issue. However, SC_FMV is stereo while FA's original is mono.

### 10.2 FMV Voice Mismatch (Resolved)

**Issue**: FMV movie playback had voice content not matching subtitles.
**Root cause**: Lua references `Bank='SC_FMV'`, but early rebuild deployed as `Voice\US\FMV` (bank name 'FMV'); the game actually loaded a leftover PCM version SC_FMV.
**Fix**: Modified `BANK_NAME_MAP={"FMV":"SC_FMV"}`, recompiled and deployed ADPCM version over PCM version (185MB→48MB), wave bank name set to SC_FMV.

### 10.3 FMV Streaming Flag

**Issue**: FA engine recognizes SC_FMV as streaming=true (Streaming=1 in XAP), while SC_FMV_BG is non-streaming and works correctly.
**Fix**: Changed FMV's Streaming to 0 (non-streaming), recompiled and deployed.

### 10.4 Interface Bank Select Sound Merge

**Issue**: SC_Interface.xwb merges original Interface(62) + UEFSelect(13) + CYBRANSelect(14) + AEONSelect(13) = 102 waves; Select sounds are merged by engineering decision.
**Impact**: FA root already has bare-name AEONSelect/CYBRANSelect/UEFSelect banks; the merge is redundant but does not affect functionality.

### 10.5 Orphan Waves in Root Banks

**Issue**: SC_UAL.xwb has 170 waves = original UAL(83) + UEL(87), of which 19 waves have no cue reference.
**Cause**: `batch_rebuild_root.py`'s multi-bank merge design includes all waves in the merged list, including those not referenced by any cue.
**Impact**: Does not affect functionality; only increases XWB file size.

---

## 11. Reproduction Guide

### 11.1 Prerequisites

1. Install Microsoft DirectX SDK (November 2007); ensure XactBld.exe is available
2. Install Python 3 (3.8+ recommended)
3. Ensure SC original game is installed (provides v41 XSB/XWB source files)
4. Ensure WAV source files are extracted to `AudioProject_2/extract_all/`

### 11.2 Rebuild All Banks

```bash
# 1. Build root sound banks (36)
python batch_rebuild_root.py

# 2. Build US voice banks (18 mission VO)
python batch_rebuild_vo.py

# 3. Build remaining US VO banks (7 special VO)
python batch_rebuild_remaining_vo.py

# 4. Build tutorial VO banks (23)
python batch_rebuild_tutorial_vo.py

# 5. Build AmbientTest + Music (2)
python rebuild_sound_banks.py

# 6. Build multi-language VO (5 languages × 25 banks)
python batch_rebuild_multi_lang_vo.py
```

### 11.3 Verification

Each build script has a built-in verification step (Step 4) that automatically compares v43 vs v41 cue→wave mappings. Manual verification:

```bash
# List wave entries in XWB
unxwb.exe -l SC_UAL.xwb

# Extract wave by cue name
unxwb.exe -b SC_UAL.xsb SC_UAL.xwb
```

### 11.4 Deployment

Build scripts auto-deploy to gamedata directories. For manual deployment, note:

- Sound banks → `SC_Campaign_Data_Sound.scd/sounds/` (root directory)
- Voice banks → `SC_Campaign_Data_Voice_US.scd/sounds/Voice/US/` (Voice/US subdirectory)
- FMV banks → Voice .scd's `sounds/` root directory (NOT the Voice/US subdirectory)
- Ops banks → XSB filename `Ops.xsb`, XWB filename `Ops_VO.xwb`

---

## 12. File Inventory

### 12.1 Build Scripts (Build_Scripts/)

| Script | Lines | Function |
|---|---|---|
| batch_rebuild_root.py | 554 | Batch rebuild 36 root sound banks |
| batch_rebuild_vo.py | 499 | Batch rebuild 18 mission VO banks |
| batch_rebuild_remaining_vo.py | 461 | Batch rebuild 7 special VO banks |
| batch_rebuild_tutorial_vo.py | 362 | Batch rebuild 23 tutorial VO banks |
| batch_rebuild_multi_lang_vo.py | 438 | Batch rebuild 5 languages x 25 VO banks |
| rebuild_sound_banks.py | 619 | Rebuild AmbientTest + Music |
| parse_xsb_v41.py | - | v41 XSB parser (core library) |
| verify_xsb_v43.py | - | v43 XSB verifier |
| gen_xap.py / gen_xap_v2.py | - | XAP generator |
| gen_fmv_bg_xap.py | - | FMV background XAP generator |
| fix_interface.py | - | Interface bank fix script |
| fix_ambient_fmv.py | - | Ambient/FMV fix script |
| extract_all_root.py | - | Root sound WAV extraction |
| extract_all_voice.py | - | Voice WAV extraction |
| extract_all_lang_voice.py | - | Multi-language voice WAV extraction |

### 12.2 Reference Files (Reference_XAP/)

| File | Description |
|---|---|
| FA_vanilla_VOs_real_original.xap | FA original VO XAP (Global Settings source) |
| FA_vanilla_VOs.xap | FA original VO XAP (modified) |
| FA_vanilla_VOs_fixed.xap | FA original VO XAP (fixed) |
| SE_FORGED_ALLIANCE_SupCom_SE_FORGED_ALLIANCE.xap | FA global settings XAP |
| SE_SUPCOM_SupCom_SE_build.xap | SC build settings XAP |
| sc_shared_SC_shared_banks_correct.xap | SC shared bank definitions (Op_Briefing + all VO) |
| global_settings.txt | Global settings text reference |
| SupCom_from_Sound.xgs | XGS backup extracted from Sound |