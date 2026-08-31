#!/usr/bin/env python3
"""
Extract ALL root sound-bank audio from original SC into playable PCM WAV.
Output: AudioProject_2\extract_all\<bank>\

Strategy (lossless completeness - no mapping required):
1. unxwb -D extracts every wave as N.wav (decimal index)
2. If v41 XSB parses OK, rename waves by cue name (best effort)
3. Always convert ADPCM -> PCM 16-bit so files are playable
4. Preserve every wave, even unmapped ones
"""
import os, sys, subprocess, shutil

BASE = r"I:\SteamLibrary\steamapps\common\Supreme Commander Forged Alliance"
TEMP = os.path.join(BASE, "AudioProject_2", ".temp")
OUT_BASE = os.path.join(BASE, "AudioProject_2", "extract_all")
SC_SOUNDS = r"I:\SteamLibrary\steamapps\common\Supreme Commander\sounds"
UNXWB = os.path.join(BASE, "AudioTools", "unxwb", "unxwb.exe")
FFMPEG = os.path.join(BASE, "AudioTools", "ffmpeg.exe")

sys.path.insert(0, TEMP)

# All root XWB banks to extract (48)
ROOT_BANKS = [
    "AEONSelect", "CYBRANSelect", "UEFSelect",
    "CYBRANStream", "ExplosionsStream",
    "AmbientTest", "Explosions", "FMV_BG", "Group_Move", "Impacts",
    "Interface", "Music", "Op_Briefing", "TestBank", "Tutorial_SE",
    "UnitRumble", "UnitsGlobal",
    "UAA", "UAADestroy", "UAAWeapon", "UAB", "UAL", "UALDestroy", "UALWeapon",
    "UAS", "UASDestroy", "UASWeapon",
    "UEA", "UEADestroy", "UEAWeapon", "UEB", "UEL", "UELDestroy", "UELWeapon",
    "UES", "UESDestroy", "UESWeapon",
    "URA", "URADestroy", "URAWeapon", "URB", "URL", "URLDestroy", "URLWeapon",
    "URS", "URSDestroy", "URSStream", "URSWeapon",
]


def extract_waves(xwb_path, work_dir):
    """unxwb -D extract all waves as decimal .wav, return dict idx->path."""
    os.makedirs(work_dir, exist_ok=True)
    subprocess.run([UNXWB, "-d", work_dir, "-D", xwb_path],
                   capture_output=True, text=True, timeout=300)
    waves = {}
    for f in os.listdir(work_dir):
        if f.endswith('.wav'):
            try:
                idx = int(f.replace('.wav', ''))
            except ValueError:
                continue
            waves[idx] = os.path.join(work_dir, f)
    return waves


def convert_pcm(src, dst):
    r = subprocess.run([FFMPEG, "-y", "-i", src, "-acodec", "pcm_s16le", dst],
                       capture_output=True, text=True, timeout=300)
    return r.returncode == 0


def get_parse_mapping(xsb_path):
    """Parse v41 XSB; return dict wave_index->cue_name (first cue that uses wave)."""
    try:
        from parse_xsb_v41 import XSBv41Parser
        p = XSBv41Parser(xsb_path)
        p.parse()
        wave_to_cue = {}
        for m in p.cue_mappings:
            for wb_idx, wave_idx in m['wave_refs']:
                if wave_idx not in wave_to_cue:
                    wave_to_cue[wave_idx] = m['cue_name']
        return wave_to_cue
    except Exception as e:
        print("    (parse failed: %s)" % str(e)[:60])
        return {}


def process_bank(bank, xwb_path):
    out_dir = os.path.join(OUT_BASE, bank)
    os.makedirs(out_dir, exist_ok=True)

    work = os.path.join(TEMP, "work_extract_%s" % bank)
    if os.path.exists(work):
        shutil.rmtree(work)
    waves = extract_waves(xwb_path, work)
    if not waves:
        print("  [WARN] %s: no waves" % bank)
        return 0
    n = len(waves)

    # mapping (best effort): standalone XWB -> upstream XSB
    mapping = {}
    xsb_path = os.path.join(SC_SOUNDS, bank + ".xsb")
    if os.path.exists(xsb_path):
        mapping = get_parse_mapping(xsb_path)
    elif bank in ("ExplosionsStream",):
        mapping = get_parse_mapping(os.path.join(SC_SOUNDS, "Explosions.xsb"))

    done = 0
    for idx in sorted(waves.keys()):
        src = waves[idx]
        name = mapping.get(idx, "wave_%03d" % idx)
        dst = os.path.join(out_dir, "%s.wav" % name)
        c = 1
        while os.path.exists(dst):
            dst = os.path.join(out_dir, "%s_%d.wav" % (name, c))
            c += 1
        if convert_pcm(src, dst):
            done += 1
        else:
            print("  !! pcm fail %s wave %d" % (bank, idx))
    shutil.rmtree(work, ignore_errors=True)
    print("  [OK] %-16s %3d waves -> %s" % (bank, done, out_dir))
    return done


def main():
    os.makedirs(OUT_BASE, exist_ok=True)
    print("Extracting %d root sound banks -> %s" % (len(ROOT_BANKS), OUT_BASE))
    total = 0
    for bank in ROOT_BANKS:
        xwb = os.path.join(SC_SOUNDS, bank + ".xwb")
        if not os.path.exists(xwb):
            print("  [SKIP] %s: no xwb" % bank)
            continue
        try:
            total += process_bank(bank, xwb)
        except Exception as e:
            import traceback
            print("  [ERR] %s: %s" % (bank, str(e)[:80]))
    print("\nDONE. Total waves: %d" % total)


if __name__ == '__main__':
    main()