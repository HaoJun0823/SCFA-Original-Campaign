#!/usr/bin/env python3
"""Verify deployed SC_FMV_BG.xsb has all expected cue names."""
import struct

XSB_PATH = r"I:\SteamLibrary\steamapps\common\Supreme Commander Forged Alliance\gamedata\SC_Campaign_Data_Sound.scd\sounds\SC_FMV_BG.xsb"

with open(XSB_PATH, 'rb') as f:
    data = f.read()

print(f"XSB size: {len(data)} bytes")
print(f"Magic: {data[0:4]}")

# v43 header might differ slightly, but let's try the same offsets
sound_count = struct.unpack_from('<H', data, 0x17)[0]
cue_count = struct.unpack_from('<H', data, 0x1A)[0]
cue_name_off = struct.unpack_from('<H', data, 0x2A)[0]

print(f"sound_count: {sound_count}")
print(f"cue_count: {cue_count}")
print(f"cue_name_off: 0x{cue_name_off:X}")

# Read cue names
pos = cue_name_off
cue_names = []
for _ in range(cue_count):
    if pos >= len(data):
        break
    end = data.index(0, pos)
    name = data[pos:end].decode('ascii', errors='replace')
    cue_names.append(name)
    pos = end + 1

print(f"\nCue names ({len(cue_names)}):")
for i, name in enumerate(cue_names):
    print(f"  {i:2d}: {name}")

# Expected cue names
expected = [
    "FMV_Cybran_Outro_2", "FMV_Cybran_Intro_1", "FMV_Cybran_Intro_2",
    "FMV_Cybran_Outro_1", "FMV_UEF_Credits", "FMV_Cybran_Credits",
    "Menu_Credits", "FMV_Aeon_Credits", "THQ_Logo", "GPG_introLogo_HD",
    "NVIDIA", "FMV_Aeon_Intro_1", "FMV_Aeon_Intro_2", "FMV_Aeon_Outro_1",
    "FMV_Aeon_Outro_2", "FMV_Campaign_Intro", "FMV_UEF_Intro_1",
    "FMV_UEF_Intro_2", "FMV_UEF_Outro_1", "FMV_UEF_Outro_2"
]

missing = [e for e in expected if e not in cue_names]
print(f"\nMissing cues: {missing if missing else 'NONE - all present!'}")
