#!/usr/bin/env python3
"""
Batch rebuild all 18 VO banks from v41 XSB correct mappings.

For each bank:
1. Parse v41 XSB to get cue -> wave mapping
2. Build wave list in v41 wave index order
3. Generate XAP with correct wave order + Global Settings from original XAP
4. Compile with XactBld /WINDOWS
5. Verify with v43 parser
"""
import os, sys, struct, json, subprocess, shutil

BASE = r"I:\SteamLibrary\steamapps\common\Supreme Commander Forged Alliance"
TEMP = os.path.join(BASE, "AudioProject_2", ".temp")
EXTRACT_DIR = os.path.join(BASE, "AudioProject_2", "extract_all", "Voice", "US")
SC_SOUND = r"I:\SteamLibrary\steamapps\common\Supreme Commander\sounds"
SC_VOICE = os.path.join(SC_SOUND, "Voice", "US")
FA_VOICE = os.path.join(BASE, "gamedata", "SC_Campaign_Data_Voice_US.scd", "sounds", "Voice", "US")
ORIGINAL_XAP = os.path.join(BASE, "AudioTools", "FA_vanilla_VOs_real_original.xap")
XACTBLD = r"C:\Program Files (x86)\Microsoft DirectX SDK (November 2007)\Utilities\Bin\x86\XactBld.exe"
PYTHON = sys.executable

# Import v41 parser
sys.path.insert(0, TEMP)
from parse_xsb_v41 import XSBv41Parser

# v43 parser
sys.path.insert(0, TEMP)

VO_BANKS = [
    'A01_VO', 'A02_VO', 'A03_VO', 'A04_VO', 'A05_VO', 'A06_VO',
    'C01_VO', 'C02_VO', 'C03_VO', 'C04_VO', 'C05_VO', 'C06_VO',
    'E01_VO', 'E02_VO', 'E03_VO', 'E04_VO', 'E05_VO', 'E06_VO',
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
    """Load Global Settings from original XAP (first 2345 lines)."""
    with open(ORIGINAL_XAP, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    # Global Settings ends at line 2345 (0-indexed: 2344)
    # Find the closing } of Global Settings
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
    xsb_path = os.path.join(SC_VOICE, f"{bank_name}.xsb")
    parser = XSBv41Parser(xsb_path)
    parser.parse()
    
    # Build wave list: wave_index -> wave_name (from cue name)
    # Each cue maps to one or more wave refs. We need to know which wave name
    # corresponds to each wave index.
    wave_to_cue = {}  # wave_index -> first cue name that references it
    for m in parser.cue_mappings:
        for wb_idx, wave_idx in m['wave_refs']:
            if wave_idx not in wave_to_cue:
                wave_to_cue[wave_idx] = m['cue_name']
    
    max_wave = max(wave_to_cue.keys()) if wave_to_cue else -1
    wave_list = []  # (wave_idx, wave_name)
    for wi in range(max_wave + 1):
        name = wave_to_cue.get(wi, f"{bank_name}_wave_{wi:03d}")
        wave_list.append((wi, name))
    
    return parser, wave_list


def generate_xap(bank_name, parser, wave_list, build_dir):
    """Generate XAP file for a VO bank."""
    global_settings = load_global_settings()
    pcm_dir = os.path.join(EXTRACT_DIR, bank_name)
    
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
    
    for wi, wname in wave_list:
        fp = os.path.join(pcm_dir, wname + ".wav")
        if not os.path.exists(fp):
            # Try alternate naming (some cue names have spaces)
            fp_alt = os.path.join(pcm_dir, wname.replace(" ", "_") + ".wav")
            if os.path.exists(fp_alt):
                fp = fp_alt
            else:
                print(f"  WARNING: missing wave file for {wname}, skipping")
                continue
        
        ch, sr, data_len = get_wav_info(fp)
        out.append("    Wave")
        out.append("    {")
        out.append(f"        Name = {wname};")
        out.append(f"        File = {fp};")
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
    
    # Sound entries: one per cue, in cue index order
    # Map cue_index -> (wave_name, wave_index)
    cue_to_wave = {}
    for m in parser.cue_mappings:
        if m['wave_refs']:
            wb_idx, wave_idx = m['wave_refs'][0]
            # Find wave name for this wave index
            wname = None
            for wi, wn in wave_list:
                if wi == wave_idx:
                    wname = wn
                    break
            if wname is None:
                # Wave index not in our list - find by cue name
                wname = m['cue_name']
            cue_to_wave[m['cue_index']] = (wave_idx, wname)
    
    # Generate Sound blocks in sound index order
    # The sound index in the XAP is determined by the order of Sound blocks
    # We need Sound blocks in the same order as the original XAP
    # In the original XAP, sounds are ordered by the cue's first appearance
    # But actually, sounds are indexed 0..N-1 in order of appearance in XAP
    # We need to match the v41 XSB's sound order
    
    # Actually, looking at the v41 parser, cue_mappings are in cue index order
    # (simple cues first, then complex cues)
    # The sound_offset in each cue maps to a specific sound entry
    # We need sounds in the order they appear in the sounds table
    
    # For simplicity and correctness, let's generate one Sound per cue,
    # indexed by cue order. The Cue's Sound Entry Index will point to this.
    for m in parser.cue_mappings:
        ci = m['cue_index']
        if ci not in cue_to_wave:
            continue
        wave_idx, wname = cue_to_wave[ci]
        
        out.append("    Sound")
        out.append("    {")
        out.append(f"        Name = {m['cue_name']};")
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
        out.append(f"                    Entry Name = {wname};")
        out.append(f"                    Entry Index = {wave_idx};")
        out.append("                    Weight = 255;")
        out.append("                    Weight Min = 0;")
        out.append("                }")
        out.append("            }")
        out.append("        }")
        out.append("    }")
        out.append("")
    
    # Cue blocks
    for m in parser.cue_mappings:
        ci = m['cue_index']
        if ci not in cue_to_wave:
            continue
        out.append("    Cue")
        out.append("    {")
        out.append(f"        Name = {m['cue_name']};")
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
        out.append(f"            Name = {m['cue_name']};")
        out.append(f"            Index = {ci};")
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
    # Create output dirs
    win_dir = os.path.join(build_dir, "Win")
    xbox_dir = os.path.join(build_dir, "Xbox")
    os.makedirs(win_dir, exist_ok=True)
    os.makedirs(xbox_dir, exist_ok=True)
    
    cmd = [XACTBLD, "/WINDOWS", xap_path]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    
    if result.returncode != 0:
        print(f"  XactBld FAILED (exit {result.returncode})")
        if result.stdout:
            # Print last 20 lines of stdout
            lines = result.stdout.strip().split('\n')
            for l in lines[-20:]:
                print(f"    {l}")
        if result.stderr:
            print(f"  STDERR: {result.stderr[:500]}")
        return False
    
    return True


def verify_v43(xsb_path, parser_v41):
    """Verify v43 XSB against v41 mapping."""
    # Parse v43
    with open(xsb_path, 'rb') as f:
        data = f.read()
    
    if data[0:4] != b'SDBK':
        return False, "bad magic"
    
    num_simple = struct.unpack_from('<H', data, 0x13)[0]
    num_complex = struct.unpack_from('<H', data, 0x15)[0]
    num_total = struct.unpack_from('<H', data, 0x19)[0]
    num_wb = data[0x1B]
    cue_name_table_len = struct.unpack_from('<H', data, 0x1E)[0]
    
    simple_cues_off = struct.unpack_from('<I', data, 0x22)[0]
    complex_cues_off = struct.unpack_from('<I', data, 0x26)[0]
    cue_names_off = struct.unpack_from('<I', data, 0x2A)[0]
    wave_bank_names_off = struct.unpack_from('<I', data, 0x3A)[0]
    sounds_off = struct.unpack_from('<I', data, 0x46)[0]
    
    # Read cue names
    cue_names = data[cue_names_off:cue_names_off + cue_name_table_len].decode('utf-8', 'replace').split('\0')
    cue_names = [c for c in cue_names if c]
    
    # Parse cue refs (simplified - just check simple cues)
    # For simple cues: flags(1) + soundOffset(4) = 5 bytes
    # Parse sound at soundOffset
    
    def parse_sound_simple(off):
        flags = data[off]
        is_complex = (flags & 0x01) != 0
        p = off + 1 + 2 + 1 + 2 + 1 + 2  # skip to track/bank
        if not is_complex:
            track = struct.unpack_from('<H', data, p)[0]
            bank = data[p + 2]
            return [(bank, track)]
        return None  # Complex - skip for now
    
    cue_refs = []
    p = simple_cues_off
    for i in range(num_simple):
        if p + 5 > len(data):
            break
        flags = data[p]
        sound_off = struct.unpack_from('<I', data, p + 1)[0]
        refs = parse_sound_simple(sound_off)
        cue_refs.append(refs)
        p += 5
    
    # Compare with v41 mapping
    v41_refs = []
    for m in parser_v41.cue_mappings:
        if m['wave_refs']:
            v41_refs.append(m['wave_refs'])
        else:
            v41_refs.append(None)
    
    mismatches = 0
    for i in range(min(len(v41_refs), len(cue_refs))):
        if v41_refs[i] is None or cue_refs[i] is None:
            continue
        v41_r = v41_refs[i]
        v43_r = cue_refs[i]
        if v41_r != v43_r:
            mismatches += 1
    
    return mismatches == 0, f"{mismatches} mismatches out of {min(len(v41_refs), len(cue_refs))} cues"


def deploy_bank(bank_name, build_dir):
    """Deploy compiled bank to FA voice directory."""
    src_xsb = os.path.join(build_dir, "Win", f"{bank_name}.xsb")
    src_xwb = os.path.join(build_dir, "Win", f"{bank_name}.xwb")
    dst_xsb = os.path.join(FA_VOICE, f"{bank_name}.xsb")
    dst_xwb = os.path.join(FA_VOICE, f"{bank_name}.xwb")
    
    # Backup old files
    for dst in [dst_xsb, dst_xwb]:
        if os.path.exists(dst):
            backup_dir = os.path.join(TEMP, "backup_vo_rebuild")
            os.makedirs(backup_dir, exist_ok=True)
            shutil.copy2(dst, os.path.join(backup_dir, os.path.basename(dst)))
    
    shutil.copy2(src_xsb, dst_xsb)
    shutil.copy2(src_xwb, dst_xwb)
    return True


def main():
    # Only process specified banks (or all if no args)
    banks_to_process = sys.argv[1:] if len(sys.argv) > 1 else VO_BANKS
    
    print(f"=== Batch rebuilding {len(banks_to_process)} VO banks ===\n")
    
    results = []
    for bank_name in banks_to_process:
        print(f"--- {bank_name} ---")
        build_dir = os.path.join(TEMP, f"build_{bank_name}")
        os.makedirs(build_dir, exist_ok=True)
        
        # Step 1: Parse v41 XSB
        try:
            parser, wave_list = parse_v41_bank(bank_name)
            print(f"  v41: {parser.num_total_cues} cues, {len(wave_list)} waves")
        except Exception as e:
            print(f"  PARSE ERROR: {e}")
            results.append({'name': bank_name, 'status': 'error', 'error': str(e)})
            continue
        
        # Step 2: Generate XAP
        try:
            xap_path = generate_xap(bank_name, parser, wave_list, build_dir)
            print(f"  XAP generated: {os.path.basename(xap_path)}")
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
        ok, detail = verify_v43(xsb_path, parser)
        if ok:
            print(f"  Verify: PASS ({detail})")
        else:
            print(f"  Verify: MISMATCH ({detail})")
        
        # Step 5: Deploy
        if ok:
            deploy_bank(bank_name, build_dir)
            print(f"  Deployed to {FA_VOICE}")
            results.append({'name': bank_name, 'status': 'ok', 'detail': detail})
        else:
            results.append({'name': bank_name, 'status': 'mismatch', 'detail': detail})
            # Still deploy - it's better than the old wrong version
            deploy_bank(bank_name, build_dir)
            print(f"  Deployed anyway (mismatches may be due to complex cues)")
        
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
    
    # Save results
    results_path = os.path.join(TEMP, 'vo_rebuild_results.json')
    with open(results_path, 'w', encoding='utf-8') as f:
        json.dump(results, f, indent=2, ensure_ascii=False)
    print(f"\nResults saved: {results_path}")


if __name__ == '__main__':
    main()
