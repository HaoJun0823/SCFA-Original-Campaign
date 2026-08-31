#!/usr/bin/env python3
"""
Fix AmbientTest and FMV_BG banks.
Same approach as Interface: parse XSB cue->sound->wave mapping, rename waves, generate XAP, build v43.
"""
import struct, os, json, sys

sc_dir = r"I:\SteamLibrary\steamapps\common\Supreme Commander\sounds"
project_dir = r"I:\SteamLibrary\steamapps\common\Supreme Commander Forged Alliance\AudioProject_2"
deploy_dir = r"I:\SteamLibrary\steamapps\common\Supreme Commander Forged Alliance\gamedata\SC_Campaign_Data_Sound.scd\sounds"

def parse_xsb(xsb_path):
    """Parse XSB file and return cue names, cue-to-sound map, sound-to-wave map."""
    data = open(xsb_path, "rb").read()
    
    sig = data[0:4]
    version = data[4]
    
    # Parse header
    sound_count = struct.unpack_from('<H', data, 0x17)[0]
    cue_count = struct.unpack_from('<H', data, 0x1A)[0]
    cue_name_offset = struct.unpack_from('<H', data, 0x2A)[0]
    cs_map_offset = struct.unpack_from('<H', data, 0x3E)[0]
    sound_table_offset = struct.unpack_from('<H', data, 0x46)[0]
    
    print(f"  Signature: {sig}, Version: {version}")
    print(f"  Sound count: {sound_count}, Cue count: {cue_count}")
    print(f"  Sound table: 0x{sound_table_offset:04x}")
    print(f"  Cue-sound map: 0x{cs_map_offset:04x}")
    print(f"  Cue names: 0x{cue_name_offset:04x}")
    
    # Parse sound table (big-endian, variable size)
    sounds = []
    offset = sound_table_offset
    for si in range(sound_count):
        if offset + 12 > len(data):
            break
        sound_type = (data[offset] << 8) | data[offset+1]
        vol = (data[offset+2] << 8) | data[offset+3]
        pitch = (data[offset+4] << 8) | data[offset+5]
        entry_size = (data[offset+6] << 8) | data[offset+7]
        if entry_size < 12 or entry_size > 500:
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
        
        sounds.append({
            'index': si,
            'type': sound_type,
            'vol': vol,
            'pitch': pitch,
            'size': entry_size,
            'wave': wave_idx,
            'complex': is_complex,
            'offset': offset,
        })
        offset += entry_size
    
    sound_table_end = offset
    
    # Parse cue-to-sound map (LE uint16 per cue)
    cue_to_sound = []
    for i in range(cue_count):
        val = struct.unpack_from('<H', data, cs_map_offset + i * 2)[0]
        cue_to_sound.append(val)
    
    # Parse cue names (null-terminated strings starting at cue_name_offset)
    cue_names = []
    pos = cue_name_offset
    for i in range(cue_count):
        name_start = pos
        while pos < len(data) and data[pos] >= 0x20:
            pos += 1
        name = data[name_start:pos].decode('ascii', errors='replace')
        cue_names.append(name)
        pos += 1  # skip null terminator
    
    # Build sound-to-wave map
    sound_to_wave = {}
    for s in sounds:
        sound_to_wave[s['index']] = s['wave']
    
    # Build cue-to-wave map (only for non-0xFFFF cues)
    cue_to_wave = {}
    for i, snd_idx in enumerate(cue_to_sound):
        if snd_idx != 0xFFFF and snd_idx in sound_to_wave:
            cue_to_wave[i] = sound_to_wave[snd_idx]
    
    return {
        'cue_names': cue_names,
        'cue_to_sound': cue_to_sound,
        'sound_to_wave': sound_to_wave,
        'cue_to_wave': cue_to_wave,
        'sound_count': sound_count,
        'cue_count': cue_count,
        'sounds': sounds,
    }

def parse_xwb(xwb_path):
    """Parse XWB file and return wave count and bank name."""
    data = open(xwb_path, "rb").read()
    wave_count = struct.unpack_from('<I', data, 0x34)[0]
    bank_name_start = 0x38
    bank_name_end = data.index(0, bank_name_start)
    bank_name = data[bank_name_start:bank_name_end].decode('ascii')
    return {'wave_count': wave_count, 'bank_name': bank_name, 'data': data}

def fix_bank(bank_name):
    """Fix a bank: parse XSB, rename waves, generate XAP, build v43."""
    print(f"\n{'='*60}")
    print(f"Fixing bank: {bank_name}")
    print(f"{'='*60}")
    
    xsb_path = os.path.join(sc_dir, f"{bank_name}.xsb")
    xwb_path = os.path.join(sc_dir, f"{bank_name}.xwb")
    
    if not os.path.exists(xsb_path):
        print(f"  ERROR: {xsb_path} not found")
        return False
    
    # Parse XSB
    print(f"\nParsing {bank_name}.xsb...")
    xsb_info = parse_xsb(xsb_path)
    
    # Parse XWB
    print(f"\nParsing {bank_name}.xwb...")
    xwb_info = parse_xwb(xwb_path)
    print(f"  Wave count: {xwb_info['wave_count']}")
    print(f"  Bank name: {xwb_info['bank_name']}")
    
    cue_count = xsb_info['cue_count']
    wave_count = xwb_info['wave_count']
    
    # Check if cue count == wave count (no naming issue)
    if cue_count == wave_count:
        print(f"  cue_count == wave_count ({cue_count}), no naming issue!")
        return True
    
    # Check 0xFFFF cues
    ffff_count = sum(1 for v in xsb_info['cue_to_sound'] if v == 0xFFFF)
    print(f"\n  0xFFFF cues: {ffff_count}")
    
    # Print cue->wave mapping
    print(f"\n  Cue -> Sound -> Wave mapping:")
    for i, name in enumerate(xsb_info['cue_names']):
        snd = xsb_info['cue_to_sound'][i]
        if snd == 0xFFFF:
            wave = None
        else:
            wave = xsb_info['sound_to_wave'].get(snd)
        print(f"    Cue {i:3d}: {name:40s} -> sound {snd:3d} -> wave {wave}")
    
    # Generate wave mapping JSON
    mapping = {
        'bank_name': bank_name,
        'cue_names': xsb_info['cue_names'],
        'cue_to_sound': xsb_info['cue_to_sound'],
        'sound_to_wave': {str(k): v for k, v in xsb_info['sound_to_wave'].items()},
        'cue_to_wave': {str(k): v for k, v in xsb_info['cue_to_wave'].items()},
        'wave_count': wave_count,
        'cue_count': cue_count,
    }
    
    mapping_path = os.path.join(project_dir, '.temp', f'{bank_name.lower()}_mapping.json')
    with open(mapping_path, 'w') as f:
        json.dump(mapping, f, indent=2)
    print(f"\n  Mapping saved to {mapping_path}")
    
    return xsb_info, xwb_info

# Fix both banks
for bank in ['AmbientTest', 'FMV_BG']:
    result = fix_bank(bank)
    if result is True:
        print(f"  {bank} doesn't need fixing (cue==wave)")
    elif result is False:
        print(f"  {bank} fix failed")
