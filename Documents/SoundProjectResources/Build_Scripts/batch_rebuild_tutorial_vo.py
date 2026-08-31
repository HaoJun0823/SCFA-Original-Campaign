#!/usr/bin/env python3
"""
Batch rebuild 23 Tutorial Voice banks from v41 to v43.

Each bank has: 1 cue (name=bank_name), 1 wave (wave_index=0).
Target deployment: SC_Campaign_Data_Voice_US.scd/sounds/Voice/US/Tutorials/

Flow per bank:
  1. Parse v41 XSB to confirm cue->wave mapping
  2. Generate XAP with correct wave + Global Settings
  3. Compile with XactBld /WINDOWS
  4. Verify v43 XSB
  5. Deploy to FA Tutorials directory
"""
import os, sys, struct, json, subprocess, shutil

BASE = r"I:\SteamLibrary\steamapps\common\Supreme Commander Forged Alliance"
TEMP = os.path.join(BASE, "AudioProject_2", ".temp")
EXTRACT_DIR = os.path.join(BASE, "AudioProject_2", "extract_all", "Voice", "US", "Tutorials")
SC_TUTORIALS = r"I:\SteamLibrary\steamapps\common\Supreme Commander\sounds\Voice\US\Tutorials"
FA_TUTORIALS = os.path.join(BASE, "gamedata", "SC_Campaign_Data_Voice_US.scd", "sounds", "Voice", "US", "Tutorials")
ORIGINAL_XAP = os.path.join(BASE, "AudioTools", "FA_vanilla_VOs_real_original.xap")
XACTBLD = r"C:\Program Files (x86)\Microsoft DirectX SDK (November 2007)\Utilities\Bin\x86\XactBld.exe"

sys.path.insert(0, TEMP)
from parse_xsb_v41 import XSBv41Parser

BANKS = [
    "TUA100", "TUA200", "TUA400", "TUA500",
    "TUB100", "TUB200", "TUB300", "TUB350", "TUB400",
    "TUB425", "TUB450", "TUB500", "TUB600", "TUB700", "TUB800",
    "TUC100", "TUC115", "TUC200", "TUC250", "TUC300",
    "TUE200",
    "TUF200", "TUF300",
]


def get_wav_info(path):
    """Return (channels, sample_rate, data_chunk_size)."""
    with open(path, 'rb') as f:
        data = f.read(200)
    off = 12
    ch = sr = data_len = None
    while off < len(data) - 8:
        cid = data[off:off+4]
        csz = struct.unpack('<I', data[off+4:off+8])[0]
        if cid == b'fmt ':
            ch = struct.unpack('<H', data[off+10:off+12])[0]
            sr = struct.unpack('<I', data[off+12:off+16])[0]
        elif cid == b'data':
            data_len = csz
        off += 8 + csz + (csz & 1)
    if ch is None or sr is None or data_len is None:
        raise RuntimeError(f"bad wav header: {path}")
    return ch, sr, data_len


def load_global_settings():
    """Load Global Settings from original XAP."""
    with open(ORIGINAL_XAP, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    brace_count = 0
    in_global = False
    end_line = 0
    for i, line in enumerate(lines):
        stripped = line.strip()
        if stripped == "Global Settings":
            in_global = True
            continue
        if in_global:
            if stripped == "{":
                brace_count += 1
            elif stripped == "}":
                brace_count -= 1
                if brace_count == 0:
                    end_line = i
                    break
    return [l.rstrip('\n') for l in lines[:end_line + 1]]


def parse_v41_bank(bank_name):
    """Parse v41 XSB and return cue mapping."""
    xsb_path = os.path.join(SC_TUTORIALS, f"{bank_name}.xsb")
    parser = XSBv41Parser(xsb_path)
    parser.parse()
    return parser


def generate_xap(bank_name, parser, build_dir):
    """Generate XAP file for a Tutorial Voice bank (1 wave, 1 cue)."""
    global_settings = load_global_settings()
    pcm_dir = os.path.join(EXTRACT_DIR, bank_name)

    # The single wave is named after the bank
    wave_name = bank_name
    wav_path = os.path.join(pcm_dir, f"{wave_name}.wav")
    if not os.path.exists(wav_path):
        print(f"  ERROR: PCM WAV not found: {wav_path}")
        return None

    ch, sr, data_len = get_wav_info(wav_path)

    out = list(global_settings)
    out.append("")

    # ---- Wave Bank ----
    out.append("Wave Bank")
    out.append("{")
    out.append(f"    Name = {bank_name};")
    out.append(f"    Xbox File = {os.path.join(build_dir, 'Xbox', bank_name + '.xwb')};")
    out.append(f"    Windows File = {os.path.join(build_dir, 'Win', bank_name + '.xwb')};")
    out.append("    Xbox Bank Path Edited = 0;")
    out.append("    Windows Bank Path Edited = 0;")
    out.append("    Streaming = 1;")
    out.append("    Seek Tables = 1;")
    out.append("    Compression Preset Name = ADPCM 256;")
    out.append("    Xbox Bank Last Modified Low = 0;")
    out.append("    Xbox Bank Last Modified High = 0;")
    out.append("    PC Bank Last Modified Low = 3921796989;")
    out.append("    PC Bank Last Modified High = 31001778;")
    out.append("    Bank Last Revised Low = 3699536229;")
    out.append("    Bank Last Revised High = 31001778;")
    out.append("")

    # Single wave
    out.append("    Wave")
    out.append("    {")
    out.append(f"        Name = {wave_name};")
    out.append(f"        File = {wav_path};")
    out.append("        Build Settings Last Modified Low = 3699406307;")
    out.append("        Build Settings Last Modified High = 31001778;")
    out.append("        Compression Preset Name = ADPCM 256;")
    out.append("")
    out.append("        Cache")
    out.append("        {")
    out.append("            Format Tag = 0;")
    out.append(f"            Channels = {ch};")
    out.append(f"            Sampling Rate = {sr};")
    out.append("            Bits Per Sample = 1;")
    out.append("            Play Region Offset = 80;")
    out.append(f"            Play Region Length = {data_len};")
    out.append("            Loop Region Offset = 0;")
    out.append("            Loop Region Length = 0;")
    out.append("            File Type = 1;")
    out.append("            Last Modified Low = 3429932417;")
    out.append("            Last Modified High = 31001587;")
    out.append("        }")
    out.append("    }")
    out.append("")
    out.append("}")
    out.append("")

    # ---- Sound Bank ----
    out.append("Sound Bank")
    out.append("{")
    out.append(f"    Name = {bank_name};")
    out.append(f"    Xbox File = {os.path.join(build_dir, 'Xbox', bank_name + '.xsb')};")
    out.append(f"    Windows File = {os.path.join(build_dir, 'Win', bank_name + '.xsb')};")
    out.append("    Xbox Bank Path Edited = 0;")
    out.append("    Windows Bank Path Edited = 0;")
    out.append("    Bank Last Modified Low = 3967693027;")
    out.append("    Bank Last Modified High = 31001778;")
    out.append("    Header Last Modified High = 0;")
    out.append("    Header Last Modified Low = 0;")
    out.append("")

    # Sound entry
    out.append("    Sound")
    out.append("    {")
    out.append(f"        Name = {bank_name};")
    out.append("        Volume = -300;")
    out.append("        Pitch = 0;")
    out.append("        Priority = 0;")
    out.append("")
    out.append("        Category Entry")
    out.append("        {")
    out.append("            Name = US;")
    out.append("        }")
    out.append("")
    out.append("        Track")
    out.append("        {")
    out.append("            Volume = 0;")
    out.append("")
    out.append("            Play Wave Event")
    out.append("            {")
    out.append("                Break Loop = 0;")
    out.append("                Use Speaker Position = 0;")
    out.append("                Use Center Speaker = 1;")
    out.append("                New Speaker Position On Loop = 1;")
    out.append("                Speaker Position Angle = 0.000000;")
    out.append("                Speaer Position Arc = 0.000000;")
    out.append("")
    out.append("                Event Header")
    out.append("                {")
    out.append("                    Timestamp = 0;")
    out.append("                    Relative = 0;")
    out.append("                    Random Recurrence = 0;")
    out.append("                    Random Offset = 0;")
    out.append("                }")
    out.append("")
    out.append("                Wave Entry")
    out.append("                {")
    out.append(f"                    Bank Name = {bank_name};")
    out.append("                    Bank Index = 0;")
    out.append(f"                    Entry Name = {wave_name};")
    out.append("                    Entry Index = 0;")
    out.append("                    Weight = 255;")
    out.append("                    Weight Min = 0;")
    out.append("                }")
    out.append("            }")
    out.append("        }")
    out.append("    }")
    out.append("")

    # Cue block
    cue_idx = parser.cue_mappings[0]['cue_index']  # should be 0
    out.append("    Cue")
    out.append("    {")
    out.append(f"        Name = {bank_name};")
    out.append("")
    out.append("        Variation")
    out.append("        {")
    out.append("            Variation Type = 3;")
    out.append("            Variation Table Type = 1;")
    out.append("            New Variation on Loop = 0;")
    out.append("        }")
    out.append("")
    out.append("        Sound Entry")
    out.append("        {")
    out.append(f"            Name = {bank_name};")
    out.append(f"            Index = {cue_idx};")
    out.append("            Weight Min = 0;")
    out.append("            Weight Max = 255;")
    out.append("        }")
    out.append("")
    out.append("        Instance Limit")
    out.append("        {")
    out.append("            Max Instances = 255;")
    out.append("            Behavior = 0;")
    out.append("")
    out.append("            Crossfade")
    out.append("            {")
    out.append("                Fade In = 0;")
    out.append("                Fade Out = 0;")
    out.append("                Crossfade Type = 0;")
    out.append("            }")
    out.append("        }")
    out.append("    }")
    out.append("")

    out.append("}")

    xap_path = os.path.join(build_dir, f"{bank_name}.xap")
    with open(xap_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(out) + '\n')
    return xap_path


def compile_xap(xap_path, build_dir):
    """Compile XAP with XactBld."""
    win_dir = os.path.join(build_dir, "Win")
    xbox_dir = os.path.join(build_dir, "Xbox")
    os.makedirs(win_dir, exist_ok=True)
    os.makedirs(xbox_dir, exist_ok=True)

    cmd = [XACTBLD, "/WINDOWS", xap_path]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)

    if result.returncode != 0:
        print(f"  XactBld FAILED (exit {result.returncode})")
        if result.stdout:
            lines = result.stdout.strip().split('\n')
            for l in lines[-20:]:
                print(f"    {l}")
        if result.stderr:
            print(f"  STDERR: {result.stderr[:500]}")
        return False

    return True


def verify_v43(xsb_path, bank_name):
    """Verify v43 XSB for a Tutorial bank (expect 1 named cue = bank_name)."""
    with open(xsb_path, 'rb') as f:
        data = f.read()

    if data[0:4] != b'SDBK':
        return False, "bad magic"

    num_simple = struct.unpack_from('<H', data, 0x13)[0]
    num_complex = struct.unpack_from('<H', data, 0x15)[0]
    num_total = struct.unpack_from('<H', data, 0x19)[0]
    num_wb = data[0x1B]
    cue_name_table_len = struct.unpack_from('<H', data, 0x1E)[0]

    cue_names_off = struct.unpack_from('<I', data, 0x2A)[0]
    cue_names = data[cue_names_off:cue_names_off + cue_name_table_len].decode('utf-8', 'replace').split('\x00')
    cue_names = [c for c in cue_names if c]

    # Check: at least 1 cue name, and it matches bank_name
    name_ok = len(cue_names) >= 1 and cue_names[0] == bank_name
    has_simple = num_simple >= 1

    detail = f"v43={num_total} cues ({num_simple}S+{num_complex}C), {num_wb} WB, names={cue_names}"
    return name_ok and has_simple, detail


def deploy_bank(bank_name, build_dir):
    """Deploy compiled bank to FA Tutorials directory."""
    src_xsb = os.path.join(build_dir, "Win", f"{bank_name}.xsb")
    src_xwb = os.path.join(build_dir, "Win", f"{bank_name}.xwb")
    dst_xsb = os.path.join(FA_TUTORIALS, f"{bank_name}.xsb")
    dst_xwb = os.path.join(FA_TUTORIALS, f"{bank_name}.xwb")

    os.makedirs(FA_TUTORIALS, exist_ok=True)

    # Backup old files if they exist
    backup_dir = os.path.join(TEMP, "backup_tutorial_rebuild")
    os.makedirs(backup_dir, exist_ok=True)
    for dst in [dst_xsb, dst_xwb]:
        if os.path.exists(dst):
            shutil.copy2(dst, os.path.join(backup_dir, os.path.basename(dst)))

    shutil.copy2(src_xsb, dst_xsb)
    shutil.copy2(src_xwb, dst_xwb)
    return True


def main():
    banks_to_process = sys.argv[1:] if len(sys.argv) > 1 else BANKS
    print(f"=== Batch rebuilding {len(banks_to_process)} Tutorial Voice banks ===\n")

    results = []
    for bank_name in banks_to_process:
        print(f"--- {bank_name} ---")
        build_dir = os.path.join(TEMP, f"build_{bank_name}")
        os.makedirs(build_dir, exist_ok=True)

        # Step 1: Parse v41 XSB
        try:
            parser = parse_v41_bank(bank_name)
            print(f"  v41: {parser.num_total_cues} cues, {parser.num_wave_banks} WB")
            m = parser.cue_mappings[0]
            print(f"  cue: idx={m['cue_index']}, name={m['cue_name']}, waves={m['wave_refs']}")
        except Exception as e:
            print(f"  PARSE ERROR: {e}")
            results.append({'name': bank_name, 'status': 'error', 'error': str(e)})
            continue

        # Step 2: Generate XAP
        try:
            xap_path = generate_xap(bank_name, parser, build_dir)
            if xap_path:
                print(f"  XAP generated")
            else:
                print(f"  XAP generation failed")
                results.append({'name': bank_name, 'status': 'error', 'error': 'no XAP'})
                continue
        except Exception as e:
            print(f"  XAP ERROR: {e}")
            results.append({'name': bank_name, 'status': 'error', 'error': str(e)})
            continue

        # Step 3: Compile
        try:
            if compile_xap(xap_path, build_dir):
                print(f"  Compiled OK")
            else:
                print(f"  COMPILE FAILED")
                results.append({'name': bank_name, 'status': 'compile_failed'})
                continue
        except Exception as e:
            print(f"  COMPILE ERROR: {e}")
            results.append({'name': bank_name, 'status': 'error', 'error': str(e)})
            continue

        # Step 4: Verify
        xsb_path = os.path.join(build_dir, "Win", f"{bank_name}.xsb")
        ok, detail = verify_v43(xsb_path, bank_name)
        if ok:
            print(f"  Verify: PASS ({detail})")
        else:
            print(f"  Verify: CHECK ({detail})")

        # Step 5: Deploy
        deploy_bank(bank_name, build_dir)
        print(f"  Deployed to Tutorials/")
        results.append({'name': bank_name, 'status': 'ok' if ok else 'mismatch', 'detail': detail})

        print()

    # Summary
    print("=" * 70)
    print("SUMMARY")
    print("=" * 70)
    ok_count = sum(1 for r in results if r['status'] == 'ok')
    mismatch_count = sum(1 for r in results if r['status'] == 'mismatch')
    error_count = sum(1 for r in results if r['status'] in ('error', 'compile_failed'))

    print(f"  OK: {ok_count}")
    print(f"  MISMATCH: {mismatch_count}")
    print(f"  ERROR: {error_count}")

    if error_count > 0:
        print(f"\nErrors:")
        for r in results:
            if r['status'] in ('error', 'compile_failed'):
                print(f"  - {r['name']}: {r.get('error', r['status'])}")

    results_path = os.path.join(TEMP, 'tutorial_rebuild_results.json')
    with open(results_path, 'w', encoding='utf-8') as f:
        json.dump(results, f, indent=2, ensure_ascii=False)
    print(f"\nResults saved: {results_path}")


if __name__ == '__main__':
    main()
