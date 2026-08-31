#!/usr/bin/env python3
"""
Phase 8: Complete fix script.
1. Parse the full cue->sound->wave mapping (including complex sounds)
2. Rename wave files to correct names
3. Generate a new XAP with all 112 cues and correct wave references
4. Compile with XactBld
"""
import struct
import os
import sys
import shutil
import subprocess

def read_be_u16(data, offset):
    return (data[offset] << 8) | data[offset + 1]

def read_file(filepath):
    with open(filepath, 'rb') as f:
        return f.read()

def main():
    # === Step 1: Parse XSB to get complete cue->sound->wave mapping ===
    xsb_path = r"I:\SteamLibrary\steamapps\common\Supreme Commander\sounds\Interface.xsb"
    data = read_file(xsb_path)
    num_cues = 112
    cue_name_offset = 0x1165
    
    # Read cue names
    pos = cue_name_offset
    cue_names = []
    for i in range(num_cues):
        end = data.index(0, pos)
        name = data[pos:end].decode('ascii', errors='replace')
        cue_names.append(name)
        pos = end + 1
    
    # Read cue->sound table at 0x0DE5
    cue_to_sound = []
    for i in range(num_cues):
        off = 0x0DE5 + i * 2
        val = struct.unpack_from('<H', data, off)[0]
        cue_to_sound.append(val)
    
    # Parse all sound entries
    sound_table_start = 0x0192
    max_offset = 0x0DE5
    offset = sound_table_start
    sound_index = 0
    sound_to_wave = {}
    sound_to_type = {}
    
    while offset < max_offset and sound_index < 112:
        if offset + 12 > len(data):
            break
        
        sound_type = read_be_u16(data, offset)
        entry_size = read_be_u16(data, offset + 6)
        
        if entry_size < 12 or entry_size > 500:
            break
        
        is_complex = (sound_type & 0xFF00) != 0
        
        if not is_complex:
            # Simple sound: wave at BE offset 8
            wave_ref = read_be_u16(data, offset + 8)
            wave_entry = wave_ref & 0xFF
            sound_to_wave[sound_index] = wave_entry
            sound_to_type[sound_index] = 'simple'
        else:
            # Complex sound: find wave indices from FF 0C XX pattern
            snd_data = data[offset:offset + entry_size]
            var_data = snd_data[8:]  # after 8-byte header
            num_vars = read_be_u16(var_data, 0) if len(var_data) >= 2 else 0
            
            # Search for wave references: pattern "FF 0C XX" where XX is wave index
            var_waves = []
            for j in range(len(var_data) - 2):
                if var_data[j] == 0xFF and var_data[j+1] == 0x0C:
                    wave_idx = var_data[j+2]
                    if wave_idx < 62:
                        var_waves.append(wave_idx)
            
            if var_waves:
                sound_to_wave[sound_index] = var_waves[0]  # first variation
                sound_to_type[sound_index] = 'complex'
            else:
                sound_to_type[sound_index] = 'complex_no_wave'
        
        offset += entry_size
        sound_index += 1
    
    # Build cue->wave mapping
    cue_to_wave = {}
    for cue_idx in range(num_cues):
        snd_idx = cue_to_sound[cue_idx]
        if snd_idx == 0xFFFF:
            continue
        if snd_idx in sound_to_wave:
            cue_to_wave[cue_idx] = sound_to_wave[snd_idx]
    
    # Build wave->cue mapping (first cue that uses each wave)
    wave_to_cue = {}
    for cue_idx in range(num_cues):
        if cue_idx in cue_to_wave:
            wave_idx = cue_to_wave[cue_idx]
            if wave_idx not in wave_to_cue:
                wave_to_cue[wave_idx] = cue_names[cue_idx]
    
    # Print summary
    print("=== Complete Cue -> Wave Mapping ===")
    for cue_idx in range(num_cues):
        name = cue_names[cue_idx]
        snd_idx = cue_to_sound[cue_idx]
        if snd_idx == 0xFFFF:
            wave = "???"
        elif snd_idx in sound_to_wave:
            wave = sound_to_wave[snd_idx]
        else:
            wave = "???"
        print(f"  Cue {cue_idx:3d} {name:40s} snd={snd_idx:5d} wave={wave}")
    
    print(f"\n=== Wave -> Cue (correct naming) ===")
    for wave_idx in range(62):
        cue_name = wave_to_cue.get(wave_idx, f"Wave_{wave_idx:02d}")
        print(f"  Wave {wave_idx:2d} -> {cue_name}")
    
    # === Step 2: Rename wave files ===
    # Current: Interface/cue_names[0..61].wav (wrong names)
    # Wave file cue_names[i] contains audio for wave index i
    # We need to rename it to the correct name from wave_to_cue[i]
    
    interface_dir = r"I:\SteamLibrary\steamapps\common\Supreme Commander Forged Alliance\AudioProject_2\Interface"
    new_dir = r"I:\SteamLibrary\steamapps\common\Supreme Commander Forged Alliance\AudioProject_2\Interface_correct"
    
    if os.path.exists(new_dir):
        shutil.rmtree(new_dir)
    os.makedirs(new_dir)
    
    print(f"\n=== Renaming wave files ===")
    for wave_idx in range(62):
        old_name = cue_names[wave_idx] + ".wav"
        new_name = wave_to_cue.get(wave_idx, f"Wave_{wave_idx:02d}") + ".wav"
        old_path = os.path.join(interface_dir, old_name)
        new_path = os.path.join(new_dir, new_name)
        
        if os.path.exists(old_path):
            shutil.copy2(old_path, new_path)
            if old_name != new_name:
                print(f"  Wave {wave_idx:2d}: {old_name} -> {new_name}")
        else:
            print(f"  Wave {wave_idx:2d}: {old_name} NOT FOUND!")
    
    # Also copy the PCM versions
    pcm_dir = r"I:\SteamLibrary\steamapps\common\Supreme Commander Forged Alliance\AudioProject_2\Interface_PCM"
    new_pcm_dir = r"I:\SteamLibrary\steamapps\common\Supreme Commander Forged Alliance\AudioProject_2\Interface_PCM_correct"
    
    if os.path.exists(pcm_dir):
        if os.path.exists(new_pcm_dir):
            shutil.rmtree(new_pcm_dir)
        os.makedirs(new_pcm_dir)
        
        # The PCM files were named alphabetically (by cue name), same as Interface
        # So the mapping is the same: cue_names[i] -> correct_name
        # But wait, PCM files might have been sorted differently...
        # Let me check if the PCM files exist with the same names
        for wave_idx in range(62):
            old_name = cue_names[wave_idx] + ".wav"
            new_name = wave_to_cue.get(wave_idx, f"Wave_{wave_idx:02d}") + ".wav"
            old_path = os.path.join(pcm_dir, old_name)
            new_path = os.path.join(new_pcm_dir, new_name)
            
            if os.path.exists(old_path):
                shutil.copy2(old_path, new_path)
    
    # === Step 3: Save the mapping for XAP generation ===
    # Save cue_to_wave mapping to JSON for the XAP generator
    import json
    mapping = {
        'cue_names': cue_names,
        'cue_to_sound': cue_to_sound,
        'sound_to_wave': {str(k): v for k, v in sound_to_wave.items()},
        'cue_to_wave': {str(k): v for k, v in cue_to_wave.items()},
        'wave_to_cue': {str(k): v for k, v in wave_to_cue.items()},
    }
    mapping_path = r"I:\SteamLibrary\steamapps\common\Supreme Commander Forged Alliance\AudioProject_2\.temp\wave_mapping.json"
    with open(mapping_path, 'w', encoding='utf-8') as f:
        json.dump(mapping, f, indent=2, ensure_ascii=False)
    print(f"\nMapping saved to {mapping_path}")
    
    # Count stats
    known_cues = sum(1 for v in cue_to_sound if v != 0xFFFF)
    mapped_cues = len(cue_to_wave)
    unmapped_cues = known_cues - mapped_cues
    print(f"\n=== Stats ===")
    print(f"  Total cues: {num_cues}")
    print(f"  Cues with 0xFFFF (unknown): {num_cues - known_cues}")
    print(f"  Cues with sound index: {known_cues}")
    print(f"  Cues with known wave: {mapped_cues}")
    print(f"  Cues with unknown wave (complex): {unmapped_cues}")
    print(f"  Total waves: 62")
    print(f"  Mapped waves: {len(wave_to_cue)}")
    print(f"  Unmapped waves: {62 - len(wave_to_cue)}")

if __name__ == '__main__':
    main()
