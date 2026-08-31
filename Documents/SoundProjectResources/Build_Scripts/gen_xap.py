#!/usr/bin/env python3
"""
Generate correct SC_Interface.xap with:
- 62 waves in original XWB order (0-61) with correct names
- 112 sounds (one per cue), each pointing to correct wave
- 112 cues with correct names
"""
import json
import os
import csv

BASE = r"I:\SteamLibrary\steamapps\common\Supreme Commander Forged Alliance\AudioProject_2"
OLD_XAP = os.path.join(BASE, ".temp", "build_interface", "SC_Interface.xap")
NEW_XAP = os.path.join(BASE, ".temp", "build_interface", "SC_Interface_correct.xap")
MAPPING_JSON = os.path.join(BASE, ".temp", "wave_mapping.json")
CACHE_CSV = os.path.join(BASE, ".temp", "old_wave_cache.csv")
PCM_DIR = os.path.join(BASE, "Interface_PCM_correct")
BUILD_DIR = os.path.join(BASE, ".temp", "build_interface")

def main():
    # Load mapping
    with open(MAPPING_JSON, 'r', encoding='utf-8') as f:
        mapping = json.load(f)
    
    cue_names = mapping['cue_names']  # 112 cue names
    cue_to_sound_list = mapping['cue_to_sound']  # list of 112 ints
    sound_to_wave = {int(k): v for k, v in mapping['sound_to_wave'].items()}
    wave_to_cue = {int(k): v for k, v in mapping['wave_to_cue'].items()}
    
    # Load cache info from old XAP (keyed by old wrong name = cue_names[wave_idx])
    cache_info = {}  # old_name -> {channels, sample_rate, play_len}
    with open(CACHE_CSV, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            cache_info[row['Name']] = {
                'channels': row['Channels'],
                'sample_rate': row['SampleRate'],
                'play_len': row['PlayLen'],
            }
    
    # Read old XAP for Global Settings section (lines 1-2136, 0-indexed 0-2135)
    with open(OLD_XAP, 'r', encoding='utf-8') as f:
        old_lines = f.readlines()
    
    # Find the end of Global Settings (the closing "}" before "Wave Bank")
    # Wave Bank starts at line 2137 (1-indexed), so line 2136 (0-indexed 2135) is "Wave Bank"
    # Global Settings ends at line 2135 (0-indexed 2134) which is "}"
    global_settings_lines = old_lines[:2135]  # lines 1-2135 (0-indexed 0-2134)
    
    # Build wave entries in original order (0-61)
    # For wave_idx i:
    #   old_wrong_name = cue_names[i]  (the name unxwb gave to wave i)
    #   correct_name = wave_to_cue.get(i, f"Wave_{i:02d}")
    #   cache = cache_info[old_wrong_name]
    #   file = PCM_DIR/correct_name.wav
    
    wave_entries = []
    for wave_idx in range(62):
        old_name = cue_names[wave_idx]
        correct_name = wave_to_cue.get(wave_idx, f"Wave_{wave_idx:02d}")
        ci = cache_info.get(old_name, {'channels': '1', 'sample_rate': '44100', 'play_len': '0'})
        
        wave_entries.append({
            'name': correct_name,
            'file': os.path.join(PCM_DIR, correct_name + ".wav"),
            'channels': ci['channels'],
            'sample_rate': ci['sample_rate'],
            'play_len': ci['play_len'],
            'index': wave_idx,
        })
    
    # Build sound entries: one per cue (112 total)
    # For cues with 0xFFFF: silent sound (no wave event)
    # For cues with valid sound index: sound pointing to correct wave
    sound_entries = []
    for cue_idx in range(112):
        cue_name = cue_names[cue_idx]
        snd_idx = cue_to_sound_list[cue_idx]
        
        if snd_idx == 0xFFFF:
            sound_entries.append({
                'name': cue_name,
                'has_wave': False,
                'wave_name': None,
                'wave_index': None,
            })
        else:
            wave_idx = sound_to_wave.get(snd_idx)
            if wave_idx is not None:
                correct_wave_name = wave_to_cue.get(wave_idx, f"Wave_{wave_idx:02d}")
                sound_entries.append({
                    'name': cue_name,
                    'has_wave': True,
                    'wave_name': correct_wave_name,
                    'wave_index': wave_idx,
                })
            else:
                sound_entries.append({
                    'name': cue_name,
                    'has_wave': False,
                    'wave_name': None,
                    'wave_index': None,
                })
    
    # Build cue entries: one per cue name (112 total)
    cue_entries = []
    for cue_idx in range(112):
        cue_name = cue_names[cue_idx]
        cue_entries.append({
            'name': cue_name,
            'sound_name': cue_name,  # sound has same name as cue
            'sound_index': cue_idx,
        })
    
    # Now generate the XAP
    output = []
    
    # 1. Header + Global Settings (from old XAP)
    for line in global_settings_lines:
        output.append(line.rstrip('\n'))
    
    # 2. Wave Bank
    output.append("")
    output.append("Wave Bank")
    output.append("{")
    output.append("    Name = SC_Interface;")
    output.append(f"    Xbox File = {os.path.join(BUILD_DIR, 'Xbox', 'SC_Interface.xwb')};")
    output.append(f"    Windows File = {os.path.join(BUILD_DIR, 'Win', 'SC_Interface.xwb')};")
    output.append("    Seek Tables = 1;")
    output.append("    Compression Preset Name = ADPCM 128;")
    output.append("")
    
    for we in wave_entries:
        output.append("    Wave")
        output.append("    {")
        output.append(f"        Name = {we['name']};")
        output.append(f"        File = {we['file']};")
        output.append("        Build Settings Last Modified Low = 3129573016;")
        output.append("        Build Settings Last Modified High = 29832812;")
        output.append("        Compression Preset Name = ADPCM 128;")
        output.append("")
        output.append("        Cache")
        output.append("        {")
        output.append("            Format Tag = 0;")
        output.append(f"            Channels = {we['channels']};")
        output.append(f"            Sampling Rate = {we['sample_rate']};")
        output.append("            Bits Per Sample = 1;")
        output.append("            Play Region Offset = 80;")
        output.append(f"            Play Region Length = {we['play_len']};")
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
    
    # 3. Sound Bank
    output.append("Sound Bank")
    output.append("{")
    output.append("    Name = SC_Interface;")
    output.append(f"    Xbox File = {os.path.join(BUILD_DIR, 'Xbox', 'SC_Interface.xsb')};")
    output.append(f"    Windows File = {os.path.join(BUILD_DIR, 'Win', 'SC_Interface.xsb')};")
    output.append("")
    
    for se in sound_entries:
        output.append("    Sound")
        output.append("    {")
        output.append(f"        Name = {se['name']};")
        output.append("        Volume = 0;")
        output.append("        Pitch = 0;")
        output.append("        Priority = 0;")
        output.append("")
        output.append("        Category Entry")
        output.append("        {")
        output.append("            Name = Interface;")
        output.append("        }")
        output.append("")
        
        if se['has_wave']:
            wave_name = se['wave_name']
            wave_index = se['wave_index']
            track_volume = 0
        else:
            # Silent cue: point to wave 0 with very low volume so XactBld keeps the cue
            wave_name = wave_entries[0]['name']
            wave_index = 0
            track_volume = -9600  # -96 dB, effectively silent
        
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
        output.append("                    Bank Name = SC_Interface;")
        output.append("                    Bank Index = 0;")
        output.append(f"                    Entry Name = {wave_name};")
        output.append(f"                    Entry Index = {wave_index};")
        output.append("                    Weight = 255;")
        output.append("                    Weight Min = 0;")
        output.append("                }")
        output.append("            }")
        output.append("        }")
        
        output.append("    }")
        output.append("")
    
    # 4. Cues
    for ce in cue_entries:
        output.append("    Cue")
        output.append("    {")
        output.append(f"        Name = {ce['name']};")
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
        output.append(f"            Name = {ce['sound_name']};")
        output.append(f"            Index = {ce['sound_index']};")
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
    
    # Write output
    with open(NEW_XAP, 'w', encoding='utf-8') as f:
        f.write('\n'.join(output) + '\n')
    
    print(f"Generated XAP: {NEW_XAP}")
    print(f"  Waves: {len(wave_entries)}")
    print(f"  Sounds: {len(sound_entries)} ({sum(1 for s in sound_entries if s['has_wave'])} with wave, {sum(1 for s in sound_entries if not s['has_wave'])} silent)")
    print(f"  Cues: {len(cue_entries)}")
    
    # Verify a few mappings
    print("\n=== Verification (first 5 waves) ===")
    for i in range(5):
        we = wave_entries[i]
        print(f"  Wave {i}: {we['name']} (file: {os.path.basename(we['file'])})")
    
    print("\n=== Verification (first 10 cues) ===")
    for i in range(10):
        ce = cue_entries[i]
        se = sound_entries[i]
        if se['has_wave']:
            print(f"  Cue {i}: {ce['name']} -> Sound {se['name']} -> Wave {se['wave_index']} ({se['wave_name']})")
        else:
            print(f"  Cue {i}: {ce['name']} -> Sound {se['name']} -> SILENT")

if __name__ == '__main__':
    main()
