#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Verify: does the deployed v43 SC_FMV.xwb have the correct audio at each wave index
compared to the SC original v41 FMV.xwb?
"""
import os, struct, subprocess, sys, shutil

BASE = r"I:\SteamLibrary\steamapps\common\Supreme Commander Forged Alliance"
SC_FMV_XWB = r"I:\SteamLibrary\steamapps\common\Supreme Commander\sounds\Voice\US\FMV.xwb"
DEPLOY_SC_FMV_XWB = os.path.join(BASE, "gamedata", "SC_Campaign_Data_Voice_US.scd", "sounds", "SC_FMV.xwb")
UNXWB = os.path.join(BASE, "AudioTools", "unxwb", "unxwb.exe")
FFMPEG = os.path.join(BASE, "AudioTools", "ffmpeg.exe")
TEMP = os.path.join(BASE, "AudioProject_2", ".temp")

work1 = os.path.join(TEMP, "verify_fmv_v41")
work2 = os.path.join(TEMP, "verify_fmv_v43")
for w in (work1, work2):
    if os.path.exists(w):
        shutil.rmtree(w)
    os.makedirs(w)

def extract(xwb, work):
    subprocess.run([UNXWB, "-D", "-d", work, xwb], capture_output=True, timeout=120)
    waves = {}
    for f in os.listdir(work):
        if f.endswith('.wav'):
            try:
                idx = int(f.replace('.wav', ''))
                waves[idx] = os.path.join(work, f)
            except ValueError:
                pass
    return waves

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

print("Extracting SC original v41 FMV.xwb...")
w41 = extract(SC_FMV_XWB, work1)
print(f"  v41 waves: {len(w41)}")
print("Extracting deployed v43 SC_FMV.xwb...")
w43 = extract(DEPLOY_SC_FMV_XWB, work2)
print(f"  v43 waves: {len(w43)}")

cue_names = [
    'FMV_Aeon_Credits',    # 0
    'FMV_Aeon_Intro_1',    # 1
    'FMV_Aeon_Outro_1',    # 2
    'FMV_Aeon_Outro_2',    # 3
    'FMV_Campaign_Intro',  # 4
    'FMV_Cybran_Credits',  # 5
    'FMV_Cybran_Intro_1',  # 6
    'FMV_Cybran_Intro_2',  # 7
    'FMV_Cybran_Outro_1',  # 8
    'FMV_Cybran_Outro_2',  # 9
    'FMV_UEF_Credits',     # 10
    'FMV_UEF_Intro_1',     # 11
    'FMV_UEF_Outro_1',     # 12
]

def to_pcm(src, dst):
    subprocess.run([FFMPEG, "-y", "-i", src, "-acodec", "pcm_s16le", dst],
                   capture_output=True, timeout=60)
    return get_wav_data(dst)

print("\n=== Wave-by-wave comparison (v41 original vs v43 deployed) ===")
all_ok = True
for idx in range(13):
    if idx not in w41:
        print(f"  wave[{idx}] {cue_names[idx]}: MISSING in v41!"); all_ok = False; continue
    if idx not in w43:
        print(f"  wave[{idx}] {cue_names[idx]}: MISSING in v43!"); all_ok = False; continue
    p41 = os.path.join(work1, f"w{idx}_pcm.wav")
    p43 = os.path.join(work2, f"w{idx}_pcm.wav")
    d41 = to_pcm(w41[idx], p41)
    d43 = to_pcm(w43[idx], p43)
    s41 = os.path.getsize(w41[idx])
    s43 = os.path.getsize(w43[idx])
    if d41 == d43:
        print(f"  wave[{idx}] {cue_names[idx]:28s} v41={s41:>9}B v43={s43:>9}B  MATCH")
    else:
        m = min(len(d41), len(d43))
        diff = sum(1 for i in range(m) if d41[i] != d43[i])
        ratio = diff / max(1, m)
        status = "MATCH" if ratio < 0.001 else "DIFF"
        if status == "DIFF":
            all_ok = False
        print(f"  wave[{idx}] {cue_names[idx]:28s} v41={s41:>6}B v43={s43:>6}B  {status} (diff_ratio={ratio:.4f})")

print(f"\nResult: {'PASS - all waves match by index' if all_ok else 'FAIL - wave order/content mismatch'}")