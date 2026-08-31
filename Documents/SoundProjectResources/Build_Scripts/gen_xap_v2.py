#!/usr/bin/env python3
"""
Generate correct SC_Interface.xap (v43) using correct mappings.

Key decisions:
- Merge 4 source wave banks (Interface 62 + UEFSelect 13 + CYBRANSelect 14
  + AEONSelect 13 = 102 waves) into a single SC_Interface wave bank, absolute
  wave indices 0..101. All Sounds reference Bank Index = 0.
- Global Settings reused from the OLD xap (full category tree + presets).
- One Sound per Cue (named after cue), each with a Track + Play Wave Event.
"""
import json
import os
import struct

BASE = r"I:\SteamLibrary\steamapps\common\Supreme Commander Forged Alliance\AudioProject_2"
TEMP = os.path.join(BASE, ".temp")
BUILD_INTERFACE = os.path.join(TEMP, "build_interface")
PCM_INT = os.path.join(BASE, "correct_extract", "Interface", "pcm")
INT_MAPPING = os.path.join(TEMP, "interface_mapping_correct.json")
OLD_INT_XAP = os.path.join(BUILD_INTERFACE, "SC_Interface.xap")

WAVE_BANK_ORDER = [
    ("Interface",    0),
    ("UEFSelect",    1),
    ("CYBRANSelect", 2),
    ("AEONSelect",   3),
]

def load_mapping(path):
    with open(path, 'r', encoding='utf-8') as f:
        return json.load(f)

def get_wav_info(path):
    """Return (channels, sample_rate, data_chunk_size)."""
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

def gen_interface():
    mapping = load_mapping(INT_MAPPING)
    cues = mapping['cue_mappings']
    assert len(cues) == 112, f"expected 112 cues, got {len(cues)}"

    # bank -> {wave_idx: cue_name} (first cue that references it wins)
    wave_names_by_bank = {name: {} for name, _ in WAVE_BANK_ORDER}
    for cm in cues:
        for ref in cm['wave_refs']:
            wb_name = ref['wave_bank']
            w_idx = ref['wave_index']
            if w_idx not in wave_names_by_bank[wb_name]:
                wave_names_by_bank[wb_name][w_idx] = cm['cue_name']

    # merged wave list: (abs_idx, bank_name, wave_idx, cue_name)
    merged_waves = []
    abs_idx = 0
    bank_base = {}  # bank_name -> base abs index
    for bank_name, _ in WAVE_BANK_ORDER:
        names = wave_names_by_bank[bank_name]
        max_idx = max(names.keys()) if names else -1
        bank_base[bank_name] = abs_idx
        for wi in range(max_idx + 1):
            cue_name = names.get(wi) or f"{bank_name}_Wave_{wi:02d}"
            merged_waves.append((abs_idx, bank_name, wi, cue_name))
            abs_idx += 1

    print(f"Merged wave bank: {len(merged_waves)} waves")
    for bank_name, _ in WAVE_BANK_ORDER:
        print(f"  {bank_name}: base abs index {bank_base[bank_name]}")

    # resolve each cue -> absolute wave index
    cue_abs_wave = {}
    for cm in cues:
        ref = cm['wave_refs'][0]
        wb = ref['wave_bank']
        wi = ref['wave_index']
        abs_i = bank_base[wb] + wi
        cue_abs_wave[cm['cue_index']] = (abs_i, merged_waves[abs_i][3])

    # sanity: files exist
    missing = []
    for abs_i, bank_name, wi, cue_name in merged_waves:
        fp = os.path.join(PCM_INT, cue_name + ".wav")
        if not os.path.exists(fp):
            missing.append((abs_i, bank_name, wi, cue_name))
    if missing:
        print("MISSING wave files:")
        for m in missing:
            print(f"  abs {m[0]} bank {m[1]} wave {m[2]} file {m[3]}.wav")
        raise SystemExit(1)

    # Global Settings from old xap: lines 1..2134 (0-indexed 0..2133)
    with open(OLD_INT_XAP, 'r', encoding='utf-8') as f:
        old_lines = f.readlines()
    global_settings = old_lines[:2134]

    out = [l.rstrip('\n') for l in global_settings]
    out.append("")

    # ---- Wave Bank ----
    out.append("Wave Bank")
    out.append("{")
    out.append("    Name = SC_Interface;")
    out.append(f"    Xbox File = {os.path.join(BUILD_INTERFACE, 'Xbox', 'SC_Interface.xwb')};")
    out.append(f"    Windows File = {os.path.join(BUILD_INTERFACE, 'Win', 'SC_Interface.xwb')};")
    out.append("    Seek Tables = 1;")
    out.append("    Compression Preset Name = ADPCM 128;")
    out.append("")
    for abs_i, bank_name, wi, cue_name in merged_waves:
        fp = os.path.join(PCM_INT, cue_name + ".wav")
        ch, sr, data_len = get_wav_info(fp)
        out.append("    Wave")
        out.append("    {")
        out.append(f"        Name = {cue_name};")
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
    out.append("    Name = SC_Interface;")
    out.append(f"    Xbox File = {os.path.join(BUILD_INTERFACE, 'Xbox', 'SC_Interface.xsb')};")
    out.append(f"    Windows File = {os.path.join(BUILD_INTERFACE, 'Win', 'SC_Interface.xsb')};")
    out.append("")
    for cm in cues:
        abs_i, wname = cue_abs_wave[cm['cue_index']]
        out.append("    Sound")
        out.append("    {")
        out.append(f"        Name = {cm['cue_name']};")
        out.append("        Volume = 0;")
        out.append("        Pitch = 0;")
        out.append("        Priority = 0;")
        out.append("")
        out.append("        Category Entry")
        out.append("        {")
        out.append("            Name = Interface;")
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
        out.append("                    Bank Name = SC_Interface;")
        out.append("                    Bank Index = 0;")
        out.append(f"                    Entry Name = {wname};")
        out.append(f"                    Entry Index = {abs_i};")
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

    xap = os.path.join(BUILD_INTERFACE, "SC_Interface_v2.xap")
    with open(xap, 'w', encoding='utf-8') as f:
        f.write('\n'.join(out) + '\n')
    print(f"Written {xap}")
    print(f"  waves={len(merged_waves)} sounds={len(cues)} cues={len(cues)}")

if __name__ == '__main__':
    gen_interface()