#!/usr/bin/env python3
"""
Extract PCM WAVs for 23 Tutorial Voice banks.
Each bank has 1 wave entry (PCM format already), 1 cue.

Flow per bank:
  1. unxwb -D extract XWB → 0.wav (by wave index)
  2. ffmpeg convert to PCM 16-bit
  3. Save to AudioTools/pcm_wavs/<bank_name>/
"""
import os, sys, subprocess

BASE = r"I:\SteamLibrary\steamapps\common\Supreme Commander Forged Alliance"
SC_TUTORIALS = r"I:\SteamLibrary\steamapps\common\Supreme Commander\sounds\Voice\US\Tutorials"
TEMP = os.path.join(BASE, "AudioProject_2", ".temp")
PCM_BASE = os.path.join(BASE, "AudioTools", "pcm_wavs")
UNXWB = os.path.join(BASE, "AudioTools", "unxwb", "unxwb.exe")
FFMPEG = r"C:\Users\haojun0823\AppData\Local\Microsoft\WinGet\Links\ffmpeg.exe"

BANKS = [
    "TUA100", "TUA200", "TUA400", "TUA500",
    "TUB100", "TUB200", "TUB300", "TUB350", "TUB400",
    "TUB425", "TUB450", "TUB500", "TUB600", "TUB700", "TUB800",
    "TUC100", "TUC115", "TUC200", "TUC250", "TUC300",
    "TUE200",
    "TUF200", "TUF300",
]


def extract_xwb(xwb_path, out_dir):
    """Extract waves from XWB using unxwb with -D (decimal index naming)."""
    os.makedirs(out_dir, exist_ok=True)
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
    """Convert WAV to PCM 16-bit WAV using ffmpeg."""
    cmd = [FFMPEG, "-y", "-i", input_wav, "-acodec", "pcm_s16le", output_wav]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    return result.returncode == 0


def process_bank(bank_name):
    print(f"\n{'='*60}")
    print(f"Processing {bank_name}")
    print(f"{'='*60}")

    xsb_path = os.path.join(SC_TUTORIALS, f"{bank_name}.xsb")
    xwb_path = os.path.join(SC_TUTORIALS, f"{bank_name}.xwb")

    if not os.path.exists(xwb_path):
        print(f"  ERROR: XWB not found: {xwb_path}")
        return False

    # Step 1: Extract XWB
    extract_dir = os.path.join(TEMP, f"extract_{bank_name}_v41")
    files = extract_xwb(xwb_path, extract_dir)
    print(f"  Extracted: {len(files)} waves")
    print(f"  Files: {files}")

    if len(files) != 1:
        print(f"  WARNING: expected 1 wave, got {len(files)}")

    # Step 2: Convert to PCM
    pcm_dir = os.path.join(PCM_BASE, bank_name)
    os.makedirs(pcm_dir, exist_ok=True)

    # The single wave is named after the bank (cue name = bank name)
    success = 0
    failed = 0
    for fi, fname in enumerate(files):
        src = os.path.join(extract_dir, fname)
        dst = os.path.join(pcm_dir, f"{bank_name}.wav")
        if convert_to_pcm(src, dst):
            success += 1
            print(f"  PCM: {bank_name}.wav OK")
        else:
            print(f"  PCM: FAILED to convert {fname}")
            failed += 1

    print(f"  Result: {success} OK, {failed} failed")
    return failed == 0


def main():
    banks = sys.argv[1:] if len(sys.argv) > 1 else BANKS
    print(f"Extracting {len(banks)} Tutorial banks...")

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
