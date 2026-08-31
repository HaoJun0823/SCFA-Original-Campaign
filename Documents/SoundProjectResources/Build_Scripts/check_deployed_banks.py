#!/usr/bin/env python3
"""
Check the currently deployed SC_AmbientTest and SC_FMV_BG banks.
Are they also v43? Do they have the same unxwb naming bug?
"""
import struct, os

deploy_dir = r"I:\SteamLibrary\steamapps\common\Supreme Commander Forged Alliance\gamedata\SC_Campaign_Data_Sound.scd\sounds"
sc_dir = r"I:\SteamLibrary\steamapps\common\Supreme Commander\sounds"

for bank in ['AmbientTest', 'FMV_BG']:
    print(f"\n{'='*60}")
    print(f"Bank: {bank}")
    print(f"{'='*60}")
    
    # Deployed version
    xsb_path = os.path.join(deploy_dir, f"SC_{bank}.xsb")
    xwb_path = os.path.join(deploy_dir, f"SC_{bank}.xwb")
    
    if not os.path.exists(xsb_path):
        print(f"  Deployed XSB not found: {xsb_path}")
        continue
    
    data = open(xsb_path, "rb").read()
    print(f"  Deployed SC_{bank}.xsb: {len(data)} bytes")
    print(f"  Signature: {data[0:4]}, Version: {data[4]}")
    
    # Parse header
    sound_count = struct.unpack_from('<H', data, 0x17)[0]
    cue_count = struct.unpack_from('<H', data, 0x1A)[0]
    cue_name_off = struct.unpack_from('<H', data, 0x2A)[0]
    cs_map_off = struct.unpack_from('<H', data, 0x3E)[0]
    sound_tbl_off = struct.unpack_from('<H', data, 0x46)[0]
    
    print(f"  Sound count: {sound_count}, Cue count: {cue_count}")
    
    # Parse cue names
    pos = cue_name_off
    cue_names = []
    for i in range(cue_count + 3):
        if pos >= len(data):
            break
        name_start = pos
        while pos < len(data) and data[pos] >= 0x20:
            pos += 1
        name = data[name_start:pos].decode('ascii', errors='replace')
        cue_names.append(name)
        pos += 1
    
    print(f"  Cue names found: {len(cue_names)}")
    for i, name in enumerate(cue_names):
        print(f"    Cue {i}: '{name}'")
    
    # Parse cue-sound map
    print(f"\n  Cue-sound map at 0x{cs_map_off:04x}:")
    for i in range(min(cue_count, len(cue_names))):
        val = struct.unpack_from('<H', data, cs_map_off + i * 2)[0]
        indicator = " (0xFFFF - no sound)" if val == 0xFFFF else ""
        print(f"    Cue {i} ({cue_names[i] if i < len(cue_names) else '?'}): {val}{indicator}")
    
    # Parse sound table
    print(f"\n  Sound table at 0x{sound_tbl_off:04x}:")
    offset = sound_tbl_off
    for si in range(sound_count):
        if offset + 12 > len(data):
            break
        sound_type = (data[offset] << 8) | data[offset+1]
        entry_size = (data[offset+6] << 8) | data[offset+7]
        if entry_size < 12 or entry_size > 500:
            print(f"    Sound {si}: INVALID size={entry_size} at 0x{offset:04x}")
            break
        
        is_complex = (sound_type & 0xFF00) != 0
        wave_idx = None
        if not is_complex:
            wave_ref = (data[offset+8] << 8) | data[offset+9]
            wave_idx = wave_ref & 0xFF
        else:
            snd_data = data[offset:offset+entry_size]
            for j in range(8, len(snd_data)-2):
                if snd_data[j] == 0xFF and snd_data[j+1] == 0x0C:
                    wave_idx = snd_data[j+2]
                    break
        
        print(f"    Sound {si}: type=0x{sound_type:04x} wave={wave_idx} size={entry_size}")
        offset += entry_size
    
    # Check XWB
    xwb = open(xwb_path, "rb").read()
    wave_count = struct.unpack_from('<I', xwb, 0x34)[0]
    print(f"\n  XWB: {len(xwb)} bytes, wave count: {wave_count}")
    
    # Original SC version
    orig_xsb = open(os.path.join(sc_dir, f"{bank}.xsb"), "rb").read()
    orig_xwb = open(os.path.join(sc_dir, f"{bank}.xwb"), "rb").read()
    orig_wave_count = struct.unpack_from('<I', orig_xwb, 0x34)[0]
    print(f"\n  Original SC: XSB={len(orig_xsb)} bytes, XWB wave count: {orig_wave_count}")
