#!/usr/bin/env python3
"""
Parse FMV_BG XSB with 3-pass logic and generate XAP for XactBld v43 compilation.
"""
import struct
import json
import os
import sys

# Add py_unxwb to path for import
sys.path.insert(0, r"I:\SteamLibrary\steamapps\common\Supreme Commander Forged Alliance\py_unxwb")
from unxwb import find_xsb_wave_names, _parse_xsb_header, _parse_cue_names, _parse_cue_to_sound, _parse_cue_info_secondary, _parse_sound_table

XSB_PATH = r"I:\SteamLibrary\steamapps\common\Supreme Commander\sounds\FMV_BG.xsb"
XWB_PATH = r"I:\SteamLibrary\steamapps\common\Supreme Commander\sounds\FMV_BG.xwb"
EXTRACT_DIR = r"I:\SteamLibrary\steamapps\common\Supreme Commander Forged Alliance\py_unxwb\extract_FMV_BG_v2"
PCM_DIR = r"I:\SteamLibrary\steamapps\common\Supreme Commander Forged Alliance\py_unxwb\extract_FMV_BG_v2_pcm"
BUILD_DIR = r"I:\SteamLibrary\steamapps\common\Supreme Commander Forged Alliance\AudioProject_2\.temp\build_fmv_bg"
DEPLOY_DIR = r"I:\SteamLibrary\steamapps\common\Supreme Commander Forged Alliance\gamedata\SC_Campaign_Data_Sound.scd\sounds"

def read_file(path):
    with open(path, 'rb') as f:
        return f.read()

def main():
    xsb_data = read_file(XSB_PATH)
    
    # Parse XSB header
    hdr = _parse_xsb_header(xsb_data)
    print(f"FMV_BG XSB Header:")
    print(f"  sound_count={hdr['sound_count']}, cue_count={hdr['cue_count']}")
    print(f"  cue_name_off=0x{hdr['cue_name_off']:X}")
    print(f"  cs_map_off=0x{hdr['cs_map_off']:X}")
    print(f"  cue_info_off=0x{hdr.get('cue_info_off', 0):X}")
    print(f"  sound_tbl_off=0x{hdr['sound_tbl_off']:X}")
    
    sound_count = hdr['sound_count']
    cue_count = hdr['cue_count']
    
    # Parse all tables
    cue_names = _parse_cue_names(xsb_data, hdr['cue_name_off'], cue_count)
    cue_to_sound = _parse_cue_to_sound(xsb_data, hdr['cs_map_off'], cue_count)
    sound_to_wave = _parse_sound_table(xsb_data, hdr['sound_tbl_off'], sound_count, 20)
    cue_secondary = _parse_cue_info_secondary(xsb_data, hdr['cue_info_off'], cue_count) if hdr.get('cue_info_off') else [0xFFFF]*cue_count
    
    print(f"\n  cue_names: {cue_names}")
    print(f"  cue_to_sound: {cue_to_sound}")
    print(f"  sound_to_wave: {sound_to_wave}")
    print(f"  cue_secondary: {cue_secondary}")
    
    # Build wave_to_name using 3-pass logic (same as find_xsb_wave_names)
    # But we need more detail for XAP generation
    wave_to_name = {}
    
    # Pass 1: Primary
    for ci in range(cue_count):
        snd = cue_to_sound[ci]
        if snd == 0xFFFF or snd >= sound_count:
            continue
        wave = sound_to_wave.get(snd)
        if wave is not None and wave not in wave_to_name:
            wave_to_name[wave] = cue_names[ci]
    
    # Pass 2: Secondary for 0xFFFF cues
    for ci in range(cue_count):
        if cue_to_sound[ci] != 0xFFFF:
            continue
        snd = cue_secondary[ci]
        if snd == 0xFFFF or snd >= sound_count:
            continue
        wave = sound_to_wave.get(snd)
        if wave is not None and wave not in wave_to_name:
            wave_to_name[wave] = cue_names[ci]
    
    # Pass 3: Tertiary for remaining
    for wave_idx in range(20):
        if wave_idx in wave_to_name:
            continue
        for ci in range(cue_count):
            snd = cue_secondary[ci]
            if snd == 0xFFFF or snd >= sound_count:
                continue
            if sound_to_wave.get(snd) == wave_idx:
                alt_name = cue_names[ci] + "_alt"
                if alt_name not in wave_to_name.values():
                    wave_to_name[wave_idx] = alt_name
                    break
    
    print(f"\n  wave_to_name ({len(wave_to_name)}/20):")
    for w in range(20):
        print(f"    wave {w:2d} -> {wave_to_name.get(w, 'UNMAPPED')}")
    
    # Build cue -> wave mapping (for sound/cue entries in XAP)
    cue_to_wave = {}
    for ci in range(cue_count):
        snd = cue_to_sound[ci]
        if snd == 0xFFFF:
            # Try secondary
            snd = cue_secondary[ci]
            if snd == 0xFFFF or snd >= sound_count:
                continue
        wave = sound_to_wave.get(snd)
        if wave is not None:
            cue_to_wave[ci] = wave
    
    print(f"\n  cue_to_wave: {cue_to_wave}")
    
    # Now generate XAP
    os.makedirs(BUILD_DIR, exist_ok=True)
    os.makedirs(os.path.join(BUILD_DIR, "Win"), exist_ok=True)
    
    # List wave files in order
    wave_files = []
    for w in range(20):
        name = wave_to_name.get(w, f"Wave_{w:02d}")
        wav_path = os.path.join(PCM_DIR, name + ".wav")
        wave_files.append((w, name, wav_path))
    
    # Check all files exist
    print("\n=== Wave files ===")
    for w, name, path in wave_files:
        exists = os.path.exists(path)
        size = os.path.getsize(path) if exists else 0
        print(f"  wave {w:2d}: {name}.wav ({size} bytes) {'OK' if exists else 'MISSING!'}")
    
    # Generate XAP
    xap_path = os.path.join(BUILD_DIR, "SC_FMV_BG.xap")
    output = []
    
    # Header (required by XactBld)
    output.append("Signature = XACT2;")
    output.append("Version = 17;")
    output.append("Content Version = 43;")
    output.append("")
    output.append("Options")
    output.append("{")
    output.append("}")
    output.append("")
    
    # Global Settings
    output.append("Global Settings")
    output.append("{")
    output.append(f"    Xbox File = {os.path.join(BUILD_DIR, 'Xbox', 'SC_FMV_BG.xgs')};")
    output.append(f"    Windows File = {os.path.join(BUILD_DIR, 'Win', 'SC_FMV_BG.xgs')};")
    output.append("    Header File = " + os.path.join(BUILD_DIR, "SC_FMV_BG.h") + ";")
    output.append("    Exclude Category Names = 0;")
    output.append("    Exclude Variable Names = 0;")
    output.append("    Last Modified Low = 29832817;")
    output.append("    Last Modified High = 2408622204;")
    output.append("")
    output.append("    Category")
    output.append("    {")
    output.append("        Name = Default;")
    output.append("        Public = 1;")
    output.append("        Background Music = 0;")
    output.append("        Volume = 0;")
    output.append("")
    output.append("        Instance Limit")
    output.append("        {")
    output.append("            Max Instances = 255;")
    output.append("            Behavior = 0;")
    output.append("")
    output.append("            Crossfade")
    output.append("            {")
    output.append("                Fade In = 0;")
    output.append("                Fade Out = 0;")
    output.append("                Crossfade Type = 0;")
    output.append("            }")
    output.append("        }")
    output.append("    }")
    output.append("")
    output.append("    Category")
    output.append("    {")
    output.append("        Name = FMV;")
    output.append("        Public = 1;")
    output.append("        Background Music = 0;")
    output.append("        Volume = 0;")
    output.append("")
    output.append("        Category Entry")
    output.append("        {")
    output.append("            Name = Default;")
    output.append("        }")
    output.append("")
    output.append("        Instance Limit")
    output.append("        {")
    output.append("            Max Instances = 255;")
    output.append("            Behavior = 0;")
    output.append("")
    output.append("            Crossfade")
    output.append("            {")
    output.append("                Fade In = 0;")
    output.append("                Fade Out = 0;")
    output.append("                Crossfade Type = 0;")
    output.append("            }")
    output.append("        }")
    output.append("    }")
    output.append("")
    output.append("    Compression Preset")
    output.append("    {")
    output.append("        Name = ADPCM 128;")
    output.append("        Xbox Format Tag = 357;")
    output.append("        Target Sample Rate = 48000;")
    output.append("        Quality = 60;")
    output.append("        Find Best Quality = 0;")
    output.append("        High Freq Cut = 0;")
    output.append("        Loop = 0;")
    output.append("        PC Format Tag = 2;")
    output.append("        Samples Per Block = 128;")
    output.append("    }")
    output.append("}")
    output.append("")
    
    # Wave Bank
    output.append("Wave Bank")
    output.append("{")
    output.append("    Name = SC_FMV_BG;")
    output.append(f"    Xbox File = {os.path.join(BUILD_DIR, 'Xbox', 'SC_FMV_BG.xwb')};")
    output.append(f"    Windows File = {os.path.join(BUILD_DIR, 'Win', 'SC_FMV_BG.xwb')};")
    output.append("    Seek Tables = 1;")
    output.append("    Compression Preset Name = ADPCM 128;")
    output.append("")
    
    for w, name, path in wave_files:
        output.append("    Wave")
        output.append("    {")
        output.append(f"        Name = {name};")
        output.append(f"        File = {path};")
        output.append("        Build Settings Last Modified Low = 3129573016;")
        output.append("        Build Settings Last Modified High = 29832812;")
        output.append("        Compression Preset Name = ADPCM 128;")
        output.append("")
        output.append("        Cache")
        output.append("        {")
        output.append("            Format Tag = 0;")
        output.append("            Channels = 2;")
        output.append("            Sampling Rate = 44100;")
        output.append("            Bits Per Sample = 1;")
        output.append("            Play Region Offset = 80;")
        output.append(f"            Play Region Length = {os.path.getsize(path) - 80 if os.path.exists(path) else 0};")
        output.append("            Loop Region Offset = 0;")
        output.append("            Loop Region Length = 0;")
        output.append("            File Type = 1;")
        output.append("            Last Modified Low = 3129573016;")
        output.append("            Last Modified High = 29832812;")
        output.append("        }")
        output.append("    }")
        output.append("")
    
    output.append("}")
    output.append("")
    
    # Sound Bank
    output.append("Sound Bank")
    output.append("{")
    output.append("    Name = SC_FMV_BG;")
    output.append(f"    Xbox File = {os.path.join(BUILD_DIR, 'Xbox', 'SC_FMV_BG.xsb')};")
    output.append(f"    Windows File = {os.path.join(BUILD_DIR, 'Win', 'SC_FMV_BG.xsb')};")
    output.append("")
    
    # Generate one sound per cue (only for valid, non-empty cues)
    valid_cues = []
    for ci in range(cue_count):
        if ci >= len(cue_names) or not cue_names[ci]:
            continue
        wave_idx = cue_to_wave.get(ci)
        if wave_idx is not None:
            wave_name = wave_to_name.get(wave_idx, f"Wave_{wave_idx:02d}")
            valid_cues.append((ci, cue_names[ci], wave_idx, wave_name))
        else:
            valid_cues.append((ci, cue_names[ci], None, None))
    
    for ci, cue_name, wave_idx, wave_name in valid_cues:
        output.append("    Sound")
        output.append("    {")
        output.append(f"        Name = {cue_name};")
        output.append("        Volume = 0;")
        output.append("        Pitch = 0;")
        output.append("        Priority = 0;")
        output.append("")
        output.append("        Category Entry")
        output.append("        {")
        output.append("            Name = FMV;")
        output.append("        }")
        output.append("")
        
        if wave_idx is not None:
            track_volume = 0
            wn = wave_name
            wi = wave_idx
        else:
            # Silent: point to wave 0 with -96dB
            track_volume = -9600
            wn = wave_to_name.get(0, "Wave_00")
            wi = 0
        
        output.append("        Track")
        output.append("        {")
        output.append(f"            Volume = {track_volume};")
        output.append("")
        output.append("            Play Wave Event")
        output.append("            {")
        output.append("                Break Loop = 0;")
        output.append("                Use Speaker Position = 0;")
        output.append("                Use Center Speaker = 1;")
        output.append("                New Speaker Position On Loop = 1;")
        output.append("                Speaker Position Angle = 0.000000;")
        output.append("                Speaer Position Arc = 360.000000;")
        output.append("")
        output.append("                Event Header")
        output.append("                {")
        output.append("                    Timestamp = 0;")
        output.append("                    Relative = 0;")
        output.append("                    Random Recurrence = 0;")
        output.append("                    Random Offset = 0;")
        output.append("                }")
        output.append("")
        output.append("                Wave Entry")
        output.append("                {")
        output.append("                    Bank Name = SC_FMV_BG;")
        output.append("                    Bank Index = 0;")
        output.append(f"                    Entry Name = {wn};")
        output.append(f"                    Entry Index = {wi};")
        output.append("                    Weight = 255;")
        output.append("                    Weight Min = 0;")
        output.append("                }")
        output.append("            }")
        output.append("        }")
        output.append("    }")
        output.append("")
    
    # Cues
    for ci, cue_name, wave_idx, wave_name in valid_cues:
        output.append("    Cue")
        output.append("    {")
        output.append(f"        Name = {cue_name};")
        output.append("")
        output.append("        Variation")
        output.append("        {")
        output.append("            Variation Type = 3;")
        output.append("            Variation Table Type = 1;")
        output.append("            New Variation on Loop = 0;")
        output.append("        }")
        output.append("")
        output.append("        Sound Entry")
        output.append("        {")
        output.append(f"            Name = {cue_name};")
        output.append(f"            Index = {ci};")
        output.append("            Weight Min = 0;")
        output.append("            Weight Max = 255;")
        output.append("        }")
        output.append("")
        output.append("        Instance Limit")
        output.append("        {")
        output.append("            Max Instances = 255;")
        output.append("            Behavior = 0;")
        output.append("")
        output.append("            Crossfade")
        output.append("            {")
        output.append("                Fade In = 0;")
        output.append("                Fade Out = 0;")
        output.append("                Crossfade Type = 0;")
        output.append("            }")
        output.append("        }")
        output.append("    }")
        output.append("")
    
    output.append("}")
    
    with open(xap_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(output) + '\n')
    
    print(f"\nXAP generated: {xap_path}")
    print(f"  Waves: {len(wave_files)}")
    print(f"  Sounds/Cues: {len(valid_cues)} ({sum(1 for v in valid_cues if v[2] is not None)} with wave, {sum(1 for v in valid_cues if v[2] is None)} silent)")

if __name__ == '__main__':
    main()
