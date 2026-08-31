#!/usr/bin/env python3
"""
Extract ALL other-language voice audio from original SC into playable PCM WAV.
Output: AudioProject_2/extract_all/Voice/<lang>/<bank>/

Same lossless strategy as extract_all_voice.py.
"""
import os, sys, subprocess, shutil

BASE = r"I:\SteamLibrary\steamapps\common\Supreme Commander Forged Alliance"
TEMP = os.path.join(BASE, "AudioProject_2", ".temp")
OUT_BASE = os.path.join(BASE, "AudioProject_2", "extract_all")
SC_VOICE = r"I:\SteamLibrary\steamapps\common\Supreme Commander\sounds\Voice"
UNXWB = os.path.join(BASE, "AudioTools", "unxwb", "unxwb.exe")
FFMPEG = os.path.join(BASE, "AudioTools", "ffmpeg.exe")

sys.path.insert(0, TEMP)

# (output_lang_subdir, source_dir_name)
LANGUAGES = [
    ("DE", "DE_BAK"),
    ("ES", "ES_BAK"),
    ("FR", "FR_BAK"),
    ("IT", "IT_BAK"),
    ("RU", "RU_BAK"),
]


def extract_waves(xwb_path, work_dir):
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
        return {}


def process_bank(rel_out, bank, xwb_path):
    out_dir = os.path.join(OUT_BASE, "Voice", rel_out, bank)
    os.makedirs(out_dir, exist_ok=True)

    work = os.path.join(TEMP, "work_lang_%s_%s" % (rel_out, bank))
    if os.path.exists(work):
        shutil.rmtree(work)
    waves = extract_waves(xwb_path, work)
    if not waves:
        print("  [WARN] %s/%s: no waves" % (rel_out, bank))
        return 0

    mapping = {}
    xsb_path = os.path.join(os.path.dirname(xwb_path), bank + ".xsb")
    if os.path.exists(xsb_path):
        mapping = get_parse_mapping(xsb_path)

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
            print("  !! pcm fail %s/%s wave %d" % (rel_out, bank, idx))
    shutil.rmtree(work, ignore_errors=True)
    print("  [OK] %-4s/%-18s %3d waves" % (rel_out, bank, done))
    return done


def process_dir(rel_out, src_dir):
    total = 0
    # Main voice banks
    xwbs = sorted(f for f in os.listdir(src_dir) if f.lower().endswith('.xwb'))
    for xwb in xwbs:
        bank = os.path.splitext(xwb)[0]
        try:
            total += process_bank(rel_out, bank, os.path.join(src_dir, xwb))
        except Exception as e:
            print("  [ERR] %s/%s: %s" % (rel_out, bank, str(e)[:80]))
    # Tutorials subdirectory (if exists)
    tut_dir = os.path.join(src_dir, "Tutorials")
    if os.path.isdir(tut_dir):
        tut_rel = rel_out + "\\Tutorials"
        tut_xwbs = sorted(f for f in os.listdir(tut_dir) if f.lower().endswith('.xwb'))
        for xwb in tut_xwbs:
            bank = os.path.splitext(xwb)[0]
            try:
                total += process_bank(tut_rel, bank, os.path.join(tut_dir, xwb))
            except Exception as e:
                print("  [ERR] %s/%s: %s" % (tut_rel, bank, str(e)[:80]))
    return total


def main():
    os.makedirs(OUT_BASE, exist_ok=True)
    print("Extracting other-language voice banks -> %s" % OUT_BASE)
    grand_total = 0
    for out_lang, src_name in LANGUAGES:
        src_dir = os.path.join(SC_VOICE, src_name)
        if not os.path.isdir(src_dir):
            print("  [SKIP] %s: dir not found" % src_name)
            continue
        print("  --- %s (%s) ---" % (out_lang, src_name))
        grand_total += process_dir(out_lang, src_dir)
    print("\nDONE. Total waves: %d" % grand_total)


if __name__ == '__main__':
    main()