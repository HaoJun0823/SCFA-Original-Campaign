#!/usr/bin/env python3
"""
Generate correct SC_FMV_BG.xap (v43) using correct mapping.

- 20 waves in source order (wave index = source wave index, confirmed by
  ground truth: wave0=GPG, wave1=THQ, wave2=NVIDIA).
- One Sound per Cue (named after cue), pointing at correct wave.
- Global Settings reused from old FMV_BG xap (full category tree + presets).
"""
import json
import os
import struct

BASE = r"I:\SteamLibrary\steamapps\common\Supreme Commander Forged Alliance\AudioProject_2"
TEMP = os.path.join(BASE, ".temp")
BUILD_FMV = os.path.join(TEMP, "build_fmv_bg")
PCM_FMV = os.path.join(BASE, "correct_extract", "FMV_BG", "pcm")
FMV_MAPPING = os.path.join(TEMP, "fmv_bg_mapping_correct.json")
OLD_FMV_XAP = os.path.join(BUILD_FMV, "SC_FMV_BG.xap")

def load_mapping(path):
    with open(path, 'r', encoding='utf-8') as f:
        return json.load(f)

def get_wav_info(path):
    with open(path, 'rb') as f:
        data = f.read(200)
    off = 12
    ch = sr = data_len = None
    while off < len(data) - 8:
        cid = data[off:off+4]
        csz = struct.unpack('<I', data[off+4:off+8])[0]
        if cid == b'fmt ':
            ch = struct.unpack('<H', data[off+10:off+12])[0]
            sr = struct.unpack('<I', data[off+12:off+16])[0]
        elif cid == b'data':
            data_len = csz
        off += 8 + csz + (csz & 1)
    if ch is None or sr is None or data_len is None:
        raise RuntimeError(f"bad wav header: {path}")
    return ch, sr, data_len

def gen_fmv():
    mapping = load_mapping(FMV_MAPPING)
    cues = mapping['cue_mappings']
    assert len(cues) == 20, f"expected 20 cues, got {len(cues)}"

    # wave index -> cue name (first ref wins; but FMV_BG all waves referenced once)
    wave_names = {}
    for cm in cues:
        for ref in cm['wave_refs']:
            wi = ref['wave_index']
            if wi not in wave_names:
                wave_names[wi] = cm['cue_name']

    # 20 waves in order
    waves = []
    for wi in range(20):
        name = wave_names.get(wi, f"Wave_{wi:02d}")
        waves.append((wi, name))

    # sanity: files exist
    missing = []
    for wi, name in waves:
        fp = os.path.join(PCM_FMV, name + ".wav")
        if not os.path.exists(fp):
            missing.append((wi, name))
    if missing:
        print("MISSING wave files:")
        for wi, name in missing:
            print(f"  wave {wi} file {name}.wav")
        raise SystemExit(1)

    # cue -> wave mapping (for sounds)
    cue_to_wave = {}
    for cm in cues:
        ref = cm['wave_refs'][0]
        cue_to_wave[cm['cue_index']] = (ref['wave_index'], wave_names[ref['wave_index']])

    # Global Settings from old FMV xap: lines 1..78
    with open(OLD_FMV_XAP, 'r', encoding='utf-8') as f:
        old_lines = f.readlines()
    global_settings = old_lines[:78]

    out = [l.rstrip('\n') for l in global_settings]
    out.append("")

    # ---- Wave Bank ----
    out.append("Wave Bank")
    out.append("{")
    out.append("    Name = SC_FMV_BG;")
    out.append(f"    Xbox File = {os.path.join(BUILD_FMV, 'Xbox', 'SC_FMV_BG.xwb')};")
    out.append(f"    Windows File = {os.path.join(BUILD_FMV, 'Win', 'SC_FMV_BG.xwb')};")
    out.append("    Seek Tables = 1;")
    out.append("    Compression Preset Name = ADPCM 128;")
    out.append("")
    for wi, name in waves:
        fp = os.path.join(PCM_FMV, name + ".wav")
        ch, sr, data_len = get_wav_info(fp)
        out.append("    Wave")
        out.append("    {")
        out.append(f"        Name = {name};")
        out.append(f"        File = {fp};")
        out.append("        Build Settings Last Modified Low = 3129573016;")
        out.append("        Build Settings Last Modified High = 29832812;")
        out.append("        Compression Preset Name = ADPCM 128;")
        out.append("")
        out.append("        Cache")
        out.append("        {")
        out.append("            Format Tag = 0;")
        out.append(f"            Channels = {ch};")
        out.append(f"            Sampling Rate = {sr};")
        out.append("            Bits Per Sample = 1;")
        out.append("            Play Region Offset = 80;")
        out.append(f"            Play Region Length = {data_len};")
        out.append("            Loop Region Offset = 0;")
        out.append("            Loop Region Length = 0;")
        out.append("            File Type = 1;")
        out.append("            Last Modified Low = 3129573016;")
        out.append("            Last Modified High = 29832812;")
        out.append("        }")
        out.append("    }")
        out.append("")
    out.append("}")
    out.append("")

    # ---- Sound Bank ----
    out.append("Sound Bank")
    out.append("{")
    out.append("    Name = SC_FMV_BG;")
    out.append(f"    Xbox File = {os.path.join(BUILD_FMV, 'Xbox', 'SC_FMV_BG.xsb')};")
    out.append(f"    Windows File = {os.path.join(BUILD_FMV, 'Win', 'SC_FMV_BG.xsb')};")
    out.append("")
    for cm in cues:
        wi, wname = cue_to_wave[cm['cue_index']]
        out.append("    Sound")
        out.append("    {")
        out.append(f"        Name = {cm['cue_name']};")
        out.append("        Volume = 0;")
        out.append("        Pitch = 0;")
        out.append("        Priority = 0;")
        out.append("")
        out.append("        Category Entry")
        out.append("        {")
        out.append("            Name = FMV;")
        out.append("        }")
        out.append("")
        out.append("        Track")
        out.append("        {")
        out.append("            Volume = 0;")
        out.append("")
        out.append("            Play Wave Event")
        out.append("            {")
        out.append("                Break Loop = 0;")
        out.append("                Use Speaker Position = 0;")
        out.append("                Use Center Speaker = 1;")
        out.append("                New Speaker Position On Loop = 1;")
        out.append("                Speaker Position Angle = 0.000000;")
        out.append("                Speaer Position Arc = 360.000000;")
        out.append("")
        out.append("                Event Header")
        out.append("                {")
        out.append("                    Timestamp = 0;")
        out.append("                    Relative = 0;")
        out.append("                    Random Recurrence = 0;")
        out.append("                    Random Offset = 0;")
        out.append("                }")
        out.append("")
        out.append("                Wave Entry")
        out.append("                {")
        out.append("                    Bank Name = SC_FMV_BG;")
        out.append("                    Bank Index = 0;")
        out.append(f"                    Entry Name = {wname};")
        out.append(f"                    Entry Index = {wi};")
        out.append("                    Weight = 255;")
        out.append("                    Weight Min = 0;")
        out.append("                }")
        out.append("            }")
        out.append("        }")
        out.append("    }")
        out.append("")
    # Cues
    for cm in cues:
        out.append("    Cue")
        out.append("    {")
        out.append(f"        Name = {cm['cue_name']};")
        out.append("")
        out.append("        Variation")
        out.append("        {")
        out.append("            Variation Type = 3;")
        out.append("            Variation Table Type = 1;")
        out.append("            New Variation on Loop = 0;")
        out.append("        }")
        out.append("")
        out.append("        Sound Entry")
        out.append("        {")
        out.append(f"            Name = {cm['cue_name']};")
        out.append(f"            Index = {cm['cue_index']};")
        out.append("            Weight Min = 0;")
        out.append("            Weight Max = 255;")
        out.append("        }")
        out.append("")
        out.append("        Instance Limit")
        out.append("        {")
        out.append("            Max Instances = 255;")
        out.append("            Behavior = 0;")
        out.append("")
        out.append("            Crossfade")
        out.append("            {")
        out.append("                Fade In = 0;")
        out.append("                Fade Out = 0;")
        out.append("                Crossfade Type = 0;")
        out.append("            }")
        out.append("        }")
        out.append("    }")
        out.append("")
    out.append("}")

    xap = os.path.join(BUILD_FMV, "SC_FMV_BG_v2.xap")
    with open(xap, 'w', encoding='utf-8') as f:
        f.write('\n'.join(out) + '\n')
    print(f"Written {xap}")
    print(f"  waves={len(waves)} sounds={len(cues)} cues={len(cues)}")

if __name__ == '__main__':
    gen_fmv()