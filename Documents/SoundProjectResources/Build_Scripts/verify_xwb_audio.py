#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Verify: does the deployed v43 XWB have the correct audio at each wave index?

Strategy: 
1. Extract wave 0 from v41 XWB (original SC) -> should be A01_Berry_M07_00774
2. Extract wave 0 from v43 XWB (deployed) -> should also be A01_Berry_M07_00774
3. Compare their audio data (PCM samples)
"""
import os, struct, subprocess, sys, shutil

BASE = r"I:\SteamLibrary\steamapps\common\Supreme Commander Forged Alliance"
SC_VOICE = r"I:\SteamLibrary\steamapps\common\Supreme Commander\sounds\Voice\US"
FA_VOICE = os.path.join(BASE, "gamedata", "SC_Campaign_Data_Voice_US.scd", "sounds", "Voice", "US")
UNXWB = os.path.join(BASE, "AudioTools", "unxwb", "unxwb.exe")
FFMPEG = os.path.join(BASE, "AudioTools", "ffmpeg.exe")
TEMP = os.path.join(BASE, "AudioProject_2", ".temp")

bank = "A01_VO"

# Step 1: Extract wave 0 from v41 XWB (original SC)
v41_xwb = os.path.join(SC_VOICE, f"{bank}.xwb")
v41_work = os.path.join(TEMP, "verify_v41_xwb")
if os.path.exists(v41_work):
    shutil.rmtree(v41_work)
os.makedirs(v41_work)
subprocess.run([UNXWB, "-D", "-d", v41_work, v41_xwb], capture_output=True, timeout=60)
v41_waves = {}
for f in os.listdir(v41_work):
    if f.endswith('.wav'):
        idx = int(f.replace('.wav', ''))
        v41_waves[idx] = os.path.join(v41_work, f)
print(f"v41 XWB: {len(v41_waves)} waves extracted")
print(f"  wave 0: {os.path.basename(v41_waves[0])} ({os.path.getsize(v41_waves[0])} bytes)")

# Convert v41 wave 0 to PCM for comparison
v41_w0_pcm = os.path.join(v41_work, "wave0_pcm.wav")
subprocess.run([FFMPEG, "-y", "-i", v41_waves[0], "-acodec", "pcm_s16le", v41_w0_pcm], 
               capture_output=True, timeout=30)

# Step 2: Extract wave 0 from v43 XWB (deployed)
v43_xwb = os.path.join(FA_VOICE, f"{bank}.xwb")
v43_work = os.path.join(TEMP, "verify_v43_xwb")
if os.path.exists(v43_work):
    shutil.rmtree(v43_work)
os.makedirs(v43_work)
subprocess.run([UNXWB, "-D", "-d", v43_work, v43_xwb], capture_output=True, timeout=60)
v43_waves = {}
for f in os.listdir(v43_work):
    if f.endswith('.wav'):
        idx = int(f.replace('.wav', ''))
        v43_waves[idx] = os.path.join(v43_work, f)
print(f"v43 XWB: {len(v43_waves)} waves extracted")
print(f"  wave 0: {os.path.basename(v43_waves[0])} ({os.path.getsize(v43_waves[0])} bytes)")

# Convert v43 wave 0 to PCM for comparison
v43_w0_pcm = os.path.join(v43_work, "wave0_pcm.wav")
subprocess.run([FFMPEG, "-y", "-i", v43_waves[0], "-acodec", "pcm_s16le", v43_w0_pcm],
               capture_output=True, timeout=30)

# Step 3: Compare audio data
def get_wav_data(path):
    with open(path, 'rb') as f:
        data = f.read()
    off = 12
    while off < len(data) - 8:
        cid = data[off:off+4]
        csz = struct.unpack('<I', data[off+4:off+8])[0]
        if cid == b'data':
            return data[off+8:off+8+csz]
        off += 8 + csz + (csz & 1)
    return None

v41_data = get_wav_data(v41_w0_pcm)
v43_data = get_wav_data(v43_w0_pcm)

print(f"\nv41 wave 0 PCM data: {len(v41_data)} bytes")
print(f"v43 wave 0 PCM data: {len(v43_data)} bytes")

if v41_data == v43_data:
    print("MATCH: wave 0 audio is identical!")
else:
    print("DIFFERENT: wave 0 audio does NOT match!")
    # Find first difference
    min_len = min(len(v41_data), len(v43_data))
    for i in range(min_len):
        if v41_data[i] != v43_data[i]:
            print(f"  First diff at byte {i}: v41=0x{v41_data[i]:02X} v43=0x{v43_data[i]:02X}")
            break

# Also check: what cue_name does wave 0 map to?
sys.path.insert(0, TEMP)
from parse_xsb_v41 import XSBv41Parser
parser = XSBv41Parser(os.path.join(SC_VOICE, f"{bank}.xsb"))
parser.parse_header()
parser.parse_wave_bank_names()
parser.parse_cue_names()
parser.parse_simple_cues()
parser.parse_complex_cues()

wave_to_cue = {}
for m in parser.cue_mappings:
    for wb_idx, wave_idx in m['wave_refs']:
        if wave_idx not in wave_to_cue:
            wave_to_cue[wave_idx] = m['cue_name']

print(f"\nExpected: wave 0 = '{wave_to_cue[0]}'")

# Check a few more waves
for check_idx in [0, 1, 5, 10, 30, 50]:
    if check_idx not in v41_waves or check_idx not in v43_waves:
        continue
    
    v41_pcm = os.path.join(v41_work, f"w{check_idx}_pcm.wav")
    v43_pcm = os.path.join(v43_work, f"w{check_idx}_pcm.wav")
    subprocess.run([FFMPEG, "-y", "-i", v41_waves[check_idx], "-acodec", "pcm_s16le", v41_pcm],
                   capture_output=True, timeout=30)
    subprocess.run([FFMPEG, "-y", "-i", v43_waves[check_idx], "-acodec", "pcm_s16le", v43_pcm],
                   capture_output=True, timeout=30)
    
    d41 = get_wav_data(v41_pcm)
    d43 = get_wav_data(v43_pcm)
    
    expected_cue = wave_to_cue.get(check_idx, "?")
    match = "MATCH" if d41 == d43 else "DIFF"
    print(f"  wave[{check_idx}] '{expected_cue}': v41={len(d41)}B v43={len(d43)}B {match}")
