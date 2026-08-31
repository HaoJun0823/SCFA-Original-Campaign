#!/usr/bin/env python3
"""
Re-verify the XSB cue-to-sound mapping table for Interface.xsb.
The user says UI_Warp_Aeon_Commander (cue 14) and UI_Warp_Cybran_Commander (cue 15)
should have sound, but our parse says they're 0xFFFF.
We need to check if the cue-to-sound table offset (0x0DE5) is correct,
or if the table format is different (e.g., uint32 instead of uint16).
"""
import struct, os

def read_file(path):
    with open(path, 'rb') as f:
        return f.read()

sc_dir = r"I:\SteamLibrary\steamapps\common\Supreme Commander\sounds"
data = read_file(os.path.join(sc_dir, "Interface.xsb"))

cue_count = struct.unpack('<H', data[0x1A:0x1C])[0]  # 112
sound_count = struct.unpack('<H', data[0x17:0x19])[0]  # 112

# Read header offsets as LE uint16
cue_name_off = struct.unpack('<H', data[0x2A:0x2C])[0]
cue_sound_map_off = struct.unpack('<H', data[0x3E:0x40])[0]
sound_table_off = struct.unpack('<H', data[0x46:0x48])[0]

# Also check 0x22 and 0x26
off_22 = struct.unpack('<H', data[0x22:0x24])[0]
off_26 = struct.unpack('<H', data[0x26:0x28])[0]

print(f"Interface.xsb: cues={cue_count}, sounds={sound_count}")
print(f"Header offsets:")
print(f"  0x22 = {hex(off_22)} = {off_22}")
print(f"  0x26 = {hex(off_26)} = {off_26}")
print(f"  0x2A (cue names) = {hex(cue_name_off)}")
print(f"  0x3E (cue-sound map) = {hex(cue_sound_map_off)}")
print(f"  0x46 (sound table) = {hex(sound_table_off)}")
print()

# Check: cue-sound map at 0x0DE5, each entry LE uint16
# But what if it's actually at a different offset?
# Let's also check 0x22 and 0x26:
# Interface: 0x22=0x7FF, 0x26=0x854
# 0x854 - 0x7FF = 0x55 = 85... doesn't divide evenly by 2 or 4

# Let me dump the raw hex at the cue-sound map area
print(f"Raw hex at cue-sound map area ({hex(cue_sound_map_off)} - {hex(cue_sound_map_off + 64)}):")
for i in range(0, 64, 16):
    off = cue_sound_map_off + i
    hex_part = ' '.join(f'{data[off+j]:02x}' for j in range(min(16, len(data)-off)))
    print(f"  {off:04x}: {hex_part}")

print()

# Read cue-to-sound map as LE uint16 (our current approach)
print("Cue-to-sound map as LE uint16 (first 20 entries):")
for i in range(20):
    val = struct.unpack('<H', data[cue_sound_map_off + i*2 : cue_sound_map_off + i*2 + 2])[0]
    print(f"  Cue {i}: sound={val} ({'0xFFFF' if val == 65535 else val})")

print()

# What if the map is LE uint32 instead of uint16?
print("Cue-to-sound map as LE uint32 (first 20 entries):")
for i in range(20):
    val = struct.unpack('<I', data[cue_sound_map_off + i*4 : cue_sound_map_off + i*4 + 4])[0]
    print(f"  Cue {i}: sound={val} ({'0xFFFF' if val == 65535 else val})")

print()

# What if the map is at offset 0x26 (0x0854)?
print(f"Alt map at 0x0854 as LE uint16 (first 20 entries):")
for i in range(20):
    off = 0x0854 + i*2
    if off + 2 <= len(data):
        val = struct.unpack('<H', data[off:off+2])[0]
        print(f"  Cue {i}: sound={val}")

print()

# What if the map is at offset 0x22 (0x07FF)?
print(f"Alt map at 0x07FF as LE uint16 (first 20 entries):")
for i in range(20):
    off = 0x07FF + i*2
    if off + 2 <= len(data):
        val = struct.unpack('<H', data[off:off+2])[0]
        print(f"  Cue {i}: sound={val}")

print()

# Let me also check: maybe the sound table starts at a different offset
# We know 0x46 = 0x0192 for Interface
# But earlier analysis said sound table at 0x0192
# Let me verify by checking what's at 0x0192
print(f"Data at sound table start (0x0192, first 48 bytes):")
for i in range(0, 48, 16):
    off = 0x0192 + i
    hex_part = ' '.join(f'{data[off+j]:02x}' for j in range(min(16, len(data)-off)))
    print(f"  {off:04x}: {hex_part}")

# Also check what's at 0x92 (the 0x3A value)
print(f"\nData at 0x0092 (first 48 bytes):")
for i in range(0, 48, 16):
    off = 0x0092 + i
    hex_part = ' '.join(f'{data[off+j]:02x}' for j in range(min(16, len(data)-off)))
    print(f"  {off:04x}: {hex_part}")

# Check: the cue-sound map should map cue_index -> sound_index
# We know cue 1 (UI_Comm_UEF_In) -> sound 1 -> wave 1
# And cue 16 (UI_Warp_UEF_Commander) -> sound 109 -> wave 61
# Let's search for 0x006D (=109) in the cue-sound map area
# 109 = 0x006D as LE uint16 = bytes 6D 00
print()
print("Searching for sound index 109 (0x006D) in cue-sound map area:")
for i in range(112):
    off = cue_sound_map_off + i*2
    if off + 2 <= len(data):
        val = struct.unpack('<H', data[off:off+2])[0]
        if val == 109:
            print(f"  Found at cue index {i} (offset {hex(off)})")

# Also search for sound index 1 
print("Searching for sound index 1 in cue-sound map area:")
for i in range(112):
    off = cue_sound_map_off + i*2
    if off + 2 <= len(data):
        val = struct.unpack('<H', data[off:off+2])[0]
        if val == 1:
            print(f"  Found at cue index {i} (offset {hex(off)})")
