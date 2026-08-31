#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Check the generated XAP to see wave entry order, then compare with v43 XWB."""
import os, struct, subprocess, sys, shutil

BASE = r"I:\SteamLibrary\steamapps\common\Supreme Commander Forged Alliance"
TEMP = os.path.join(BASE, "AudioProject_2", ".temp")
FA_VOICE = os.path.join(BASE, "gamedata", "SC_Campaign_Data_Voice_US.scd", "sounds", "Voice", "US")
UNXWB = os.path.join(BASE, "AudioTools", "unxwb", "unxwb.exe")
FFMPEG = os.path.join(BASE, "AudioTools", "ffmpeg.exe")

bank = "A01_VO"

# 1. Read the XAP file and extract wave names in order
xap_path = os.path.join(TEMP, f"build_{bank}", f"{bank}.xap")
if not os.path.exists(xap_path):
    print(f"XAP not found: {xap_path}")
    sys.exit(1)

with open(xap_path, 'r', encoding='utf-8') as f:
    xap_lines = f.readlines()

# Extract wave names and entry indices from XAP
wave_names_xap = []
in_wave_bank = False
current_wave_name = None
for line in xap_lines:
    stripped = line.strip()
    if stripped == "Wave Bank":
        in_wave_bank = True
        continue
    if in_wave_bank and stripped == "}":
        break
    if in_wave_bank and stripped.startswith("Name = ") and stripped.endswith(";"):
        name = stripped.replace("Name = ", "").rstrip(";")
        if name != bank:  # Skip the bank name itself
            wave_names_xap.append(name)

print(f"XAP wave order ({len(wave_names_xap)} waves):")
for i, name in enumerate(wave_names_xap[:10]):
    print(f"  [{i}] {name}")
print(f"  ...")
for i, name in enumerate(wave_names_xap[-3:], len(wave_names_xap)-3):
    print(f"  [{i}] {name}")

# 2. Extract waves from v43 XWB and get their sizes
v43_xwb = os.path.join(FA_VOICE, f"{bank}.xwb")
v43_work = os.path.join(TEMP, "verify_v43_order")
if os.path.exists(v43_work):
    shutil.rmtree(v43_work)
os.makedirs(v43_work)
subprocess.run([UNXWB, "-D", "-d", v43_work, v43_xwb], capture_output=True, timeout=60)

v43_sizes = []
for i in range(100):
    f = os.path.join(v43_work, f"{i}.wav")
    if os.path.exists(f):
        v43_sizes.append(os.path.getsize(f))
    else:
        break

print(f"\nv43 XWB wave sizes ({len(v43_sizes)} waves):")
for i in range(min(10, len(v43_sizes))):
    print(f"  [{i}] {v43_sizes[i]} bytes")

# 3. Get original PCM file sizes for comparison
pcm_dir = os.path.join(BASE, "AudioTools", "pcm_wavs", bank)
print(f"\nPCM file sizes (from pcm_wavs, in XAP order):")
for i, name in enumerate(wave_names_xap[:10]):
    pcm_path = os.path.join(pcm_dir, f"{name}.wav")
    if os.path.exists(pcm_path):
        sz = os.path.getsize(pcm_path)
        # Get data chunk size
        with open(pcm_path, 'rb') as f:
            data = f.read(200)
        off = 12
        data_sz = 0
        while off < len(data) - 8:
            cid = data[off:off+4]
            csz = struct.unpack('<I', data[off+4:off+8])[0]
            if cid == b'data':
                data_sz = csz
                break
            off += 8 + csz + (csz & 1)
        print(f"  [{i}] {name}: file={sz} data={data_sz}")
    else:
        print(f"  [{i}] {name}: MISSING")
