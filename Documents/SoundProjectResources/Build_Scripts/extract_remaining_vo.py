#!/usr/bin/env python3
"""
Extract PCM WAVs for remaining Voice banks:
  COMPUTER_AEON_VO, COMPUTER_CYBRAN_VO, COMPUTER_UEF_VO,
  Experimental_VO, Instructor_VO, FMV, Ops

Flow per bank:
  1. Parse v41 XSB → get cue→wave mapping (wave index order)
  2. unxwb -D extract XWB → 0.wav, 1.wav, ... (ADPCM, by wave index)
  3. Rename to cue name, ffmpeg convert to PCM 16-bit
  4. Save to AudioTools/pcm_wavs/<bank_name>/
"""
import os, sys, json, struct, subprocess, shutil

BASE = r"I:\SteamLibrary\steamapps\common\Supreme Commander Forged Alliance"
SC_SOUND = r"I:\SteamLibrary\steamapps\common\Supreme Commander\sounds"
SC_VOICE = os.path.join(SC_SOUND, "Voice", "US")
TEMP = os.path.join(BASE, "AudioProject_2", ".temp")
PCM_BASE = os.path.join(BASE, "AudioTools", "pcm_wavs")
UNXWB = os.path.join(BASE, "AudioTools", "unxwb", "unxwb.exe")
FFMPEG = r"C:\Users\haojun0823\AppData\Local\Microsoft\WinGet\Links\ffmpeg.exe"

sys.path.insert(0, TEMP)
from parse_xsb_v41 import XSBv41Parser

BANKS = [
    "COMPUTER_AEON_VO",
    "COMPUTER_CYBRAN_VO",
    "COMPUTER_UEF_VO",
    "Experimental_VO",
    "Instructor_VO",
    "FMV",
    "Ops",
]

# Map bank name to (xsb_path, xwb_path)
def get_paths(bank_name):
    xsb = os.path.join(SC_VOICE, f"{bank_name}.xsb")
    # Ops uses Ops_VO.xwb, others use <bank>.xwb
    xwb = os.path.join(SC_VOICE, f"{bank_name}.xwb")
    if not os.path.exists(xwb):
        xwb = os.path.join(SC_VOICE, f"{bank_name}_VO.xwb")
    if not os.path.exists(xwb):
        # Try sounds root
        xwb = os.path.join(SC_SOUND, f"{bank_name}.xwb")
    return xsb, xwb


def extract_xwb(xwb_path, out_dir):
    """Extract waves from XWB using unxwb with -D (decimal index naming)."""
    os.makedirs(out_dir, exist_ok=True)
    # Clear dir first
    for f in os.listdir(out_dir):
        if f.endswith('.wav'):
            os.remove(os.path.join(out_dir, f))

    cmd = [UNXWB, "-d", out_dir, "-D", xwb_path]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
    if result.returncode != 0:
        print(f"    unxwb returned {result.returncode}")
        if result.stderr:
            print(f"    stderr: {result.stderr[:300]}")

    files = sorted(
        [f for f in os.listdir(out_dir) if f.endswith('.wav')],
        key=lambda x: int(x.replace('.wav', ''))
    )
    return files


def convert_to_pcm(input_wav, output_wav):
    """Convert ADPCM WAV to PCM 16-bit WAV using ffmpeg."""
    cmd = [FFMPEG, "-y", "-i", input_wav, "-acodec", "pcm_s16le", output_wav]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
    return result.returncode == 0


def process_bank(bank_name):
    print(f"\n{'='*60}")
    print(f"Processing {bank_name}")
    print(f"{'='*60}")

    xsb_path, xwb_path = get_paths(bank_name)
    print(f"  XSB: {xsb_path}")
    print(f"  XWB: {xwb_path}")

    if not os.path.exists(xsb_path):
        print(f"  ERROR: XSB not found!")
        return False
    if not os.path.exists(xwb_path):
        print(f"  ERROR: XWB not found!")
        return False

    # Step 1: Parse v41 XSB
    parser = XSBv41Parser(xsb_path)
    parser.parse()
    print(f"  v41: {parser.num_total_cues} cues, {parser.num_wave_banks} wave banks")

    # Build wave_index -> cue_name mapping
    wave_to_cue = {}
    for m in parser.cue_mappings:
        for wb_idx, wave_idx in m['wave_refs']:
            if wave_idx not in wave_to_cue:
                wave_to_cue[wave_idx] = m['cue_name']

    max_wave = max(wave_to_cue.keys()) if wave_to_cue else -1
    print(f"  Wave index range: 0..{max_wave} ({max_wave + 1} waves)")
    print(f"  Mapped waves: {len(wave_to_cue)}")

    # Step 2: Extract XWB
    extract_dir = os.path.join(TEMP, f"extract_{bank_name}_v41")
    files = extract_xwb(xwb_path, extract_dir)
    print(f"  Extracted: {len(files)} waves")

    if len(files) < max_wave + 1:
        print(f"  WARNING: extracted {len(files)} < expected {max_wave + 1}")

    # Step 3: Convert to PCM and rename
    pcm_dir = os.path.join(PCM_BASE, bank_name)
    os.makedirs(pcm_dir, exist_ok=True)

    success = 0
    failed = 0
    for wi in range(min(len(files), max_wave + 1)):
        src = os.path.join(extract_dir, files[wi])
        cue_name = wave_to_cue.get(wi, f"{bank_name}_wave_{wi:03d}")
        # Sanitize name for filesystem
        safe_name = cue_name.replace('/', '_').replace('\\', '_')
        dst = os.path.join(pcm_dir, f"{safe_name}.wav")
        if convert_to_pcm(src, dst):
            success += 1
        else:
            print(f"    FAILED to convert wave {wi} ({cue_name})")
            failed += 1

    # Handle unmapped waves (no cue name)
    for wi in range(max_wave + 1, len(files)):
        src = os.path.join(extract_dir, files[wi])
        safe_name = f"{bank_name}_wave_{wi:03d}"
        dst = os.path.join(pcm_dir, f"{safe_name}.wav")
        if convert_to_pcm(src, dst):
            success += 1
        else:
            failed += 1

    print(f"  PCM conversion: {success} OK, {failed} failed")
    print(f"  Output: {pcm_dir}")

    return failed == 0


def main():
    banks = sys.argv[1:] if len(sys.argv) > 1 else BANKS
    print(f"Extracting {len(banks)} banks...")

    results = []
    for bank in banks:
        ok = process_bank(bank)
        results.append({'bank': bank, 'ok': ok})

    print(f"\n{'='*60}")
    print("SUMMARY")
    print(f"{'='*60}")
    for r in results:
        status = "OK" if r['ok'] else "FAILED"
        print(f"  {r['bank']}: {status}")


if __name__ == '__main__':
    main()
