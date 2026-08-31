#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Batch rebuild all remaining root-level SC sound banks to v43.
Handles multi-wave-bank merging (e.g., Explosions has Explosions + ExplosionsStream).
Uses all_root_mappings.json for correct cue→wave mappings.
"""
import os, sys, struct, json, subprocess, shutil, math, traceback

BASE = r"I:\SteamLibrary\steamapps\common\Supreme Commander Forged Alliance"
TEMP = os.path.join(BASE, "AudioProject_2", ".temp")
EXTRACT_DIR = os.path.join(BASE, "AudioProject_2", "extract_all")
SC_SOUND = r"I:\SteamLibrary\steamapps\common\Supreme Commander\sounds"
FA_SOUND = os.path.join(BASE, "gamedata", "SC_Campaign_Data_Sound.scd", "sounds")
ORIGINAL_XAP = os.path.join(BASE, "AudioTools", "FA_vanilla_VOs_real_original.xap")
XACTBLD = r"C:\Program Files (x86)\Microsoft DirectX SDK (November 2007)\Utilities\Bin\x86\XactBld.exe"

# Banks already deployed (skip these)
ALREADY_DEPLOYED = {
    'AmbientTest', 'FMV_BG', 'Interface', 'Music', 'Op_Briefing', 'Tutorial_SE'
}

# Banks to skip (TestBank is just a test, Group_Move is minimal)
SKIP_BANKS = {'TestBank'}


def parse_decibels(byte_val):
    a = -96.0; b = 0.432254984608615; c = 80.1748600297963; d = 67.7385212334047
    return ((a - d) / (1 + (math.pow(byte_val / c, b)))) + d

def byte_to_xap_volume(vol_byte):
    if vol_byte == 255: return -9600
    return round(parse_decibels(vol_byte) * 100)

def get_wav_info(path):
    with open(path, 'rb') as f:
        data = f.read(200)
    off = 12; ch = sr = data_len = None
    while off < len(data) - 8:
        cid = data[off:off+4]; csz = struct.unpack('<I', data[off+4:off+8])[0]
        if cid == b'fmt ':
            ch = struct.unpack('<H', data[off+10:off+12])[0]
            sr = struct.unpack('<I', data[off+12:off+16])[0]
        elif cid == b'data':
            data_len = csz
        off += 8 + csz + (csz & 1)
    if ch is None or sr is None or data_len is None:
        raise RuntimeError("bad wav header: %s" % path)
    return ch, sr, data_len


CAT_NAMES = [
    'Global', 'Default', 'Music', 'World', 'Units', 'Ambient', 'Weapons', 'Destroy',
    'Rumble', 'Interface', 'UnitsUEF', 'UnitsAEON', 'UnitsCYBRAN',
    'UnitsUEFAir', 'UnitsCYBRANAir', 'UnitsAEONAir',
    'ActiveLoopsUEF', 'ActiveLoopsCYBRAN', 'ActiveLoopsAEON',
    'Unit Select', 'FMV', 'Op_Briefing', 'VO', 'US',
]


def load_global_settings():
    with open(ORIGINAL_XAP, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    brace_count = 0; in_global = False; end_line = 0
    for i, line in enumerate(lines):
        stripped = line.strip()
        if stripped == "Global Settings":
            in_global = True; continue
        if in_global:
            if stripped == "{": brace_count += 1
            elif stripped == "}":
                brace_count -= 1
                if brace_count == 0:
                    end_line = i; break
    return [l.rstrip('\n') for l in lines[:end_line + 1]]


def get_cat_and_volume(bank_name, cue_mapping):
    """Extract category and volume from v41 XSB for a cue."""
    xsb_path = os.path.join(SC_SOUND, f"{bank_name}.xsb")
    d = open(xsb_path, 'rb').read()
    
    so = cue_mapping.get('sound_offset', 0)
    # For variation-type cues, sound_offset may not be set
    if so == 0 or so >= len(d):
        return 'Default', 0
    
    off = so
    flags = d[off]; off += 1
    cat_id = struct.unpack_from('<H', d, off)[0]; off += 2
    vol_byte = d[off]
    
    cat_name = CAT_NAMES[cat_id] if cat_id < len(CAT_NAMES) else 'Default'
    xap_vol = byte_to_xap_volume(vol_byte)
    return cat_name, xap_vol


def build_merged_wave_list(bank_name, mapping):
    """
    Build a merged wave list from potentially multiple wave banks.
    Returns: list of (merged_index, wave_bank_name, original_wave_index, wav_filename)
    
    Handles two WAV naming formats in extract_all/:
    - wave_NNN.wav: wave_index = NNN (unmapped waves not referenced by any cue)
    - cue_name.wav: wave_index looked up from JSON mapping (cue_name → wave_index)
    
    For files not matched to any wave_index (unmapped cue-name files),
    assigns them to available indices in the gaps.
    """
    wave_banks = mapping['wave_banks']
    merged_list = []
    current_idx = 0
    
    for wb_name in wave_banks:
        wb_dir = os.path.join(EXTRACT_DIR, wb_name)
        if not os.path.exists(wb_dir):
            print(f"    WARNING: extract dir not found for wave bank {wb_name}")
            continue
        
        all_files = [f for f in os.listdir(wb_dir) if f.endswith('.wav')]
        wave_idx_to_file = {}  # wave_index → filename
        
        # 1. wave_NNN.wav files: wave_index = NNN directly
        for f in all_files:
            if f.startswith('wave_') and f.endswith('.wav'):
                try:
                    idx = int(f.replace('wave_', '').replace('.wav', ''))
                    wave_idx_to_file[idx] = f
                except ValueError:
                    pass
        
        # 2. cue_name.wav files: look up wave_index from JSON mapping
        # Build cue_name → wave_index lookup for this specific wave bank
        cue_name_to_wave_idx = {}
        for cm in mapping['cue_mappings']:
            for ref in cm['wave_refs']:
                if ref['wave_bank'] == wb_name:
                    cn = cm['cue_name']
                    wi = ref['wave_index']
                    if cn not in cue_name_to_wave_idx:
                        cue_name_to_wave_idx[cn] = wi
        
        for f in all_files:
            if not f.startswith('wave_'):
                cue_name = f.replace('.wav', '')
                if cue_name in cue_name_to_wave_idx:
                    wi = cue_name_to_wave_idx[cue_name]
                    if wi not in wave_idx_to_file:  # don't overwrite wave_NNN entries
                        wave_idx_to_file[wi] = f
        
        # 3. Handle unmatched files (cue-name files not in JSON mapping)
        # These are waves that the extraction parser found names for but
        # the batch JSON parser didn't include. Assign to available indices.
        matched_files = set(wave_idx_to_file.values())
        unmatched_files = sorted([f for f in all_files if f not in matched_files])
        
        if unmatched_files:
            # Determine expected total waves (max wave_index + 1, or file count)
            max_wi = max(wave_idx_to_file.keys()) if wave_idx_to_file else -1
            expected_total = max(max_wi + 1, len(all_files))
            used_indices = set(wave_idx_to_file.keys())
            available_indices = sorted(set(range(expected_total)) - used_indices)
            
            for f, idx in zip(unmatched_files, available_indices):
                wave_idx_to_file[idx] = f
            
            remaining = len(unmatched_files) - len(available_indices)
            if remaining > 0:
                # Not enough available indices, append at end
                next_idx = expected_total
                for f in unmatched_files[len(available_indices):]:
                    wave_idx_to_file[next_idx] = f
                    next_idx += 1
        
        # Sort by wave_index and add to merged list
        for wi in sorted(wave_idx_to_file.keys()):
            merged_list.append((current_idx, wb_name, wi, wave_idx_to_file[wi]))
            current_idx += 1
    
    return merged_list


def generate_xap(bank_name, mapping, merged_waves, build_dir):
    """Generate XAP file for a sound bank with merged wave bank."""
    global_settings = load_global_settings()
    deploy_name = "SC_" + bank_name
    
    out = list(global_settings)
    out.append("")
    
    # ---- Wave Bank (single merged) ----
    out.append("Wave Bank")
    out.append("{")
    out.append("    Name = %s;" % deploy_name)
    out.append("    Xbox File = %s;" % os.path.join(build_dir, "Xbox", deploy_name + ".xwb"))
    out.append("    Windows File = %s;" % os.path.join(build_dir, "Win", deploy_name + ".xwb"))
    out.append("    Xbox Bank Path Edited = 0;")
    out.append("    Windows Bank Path Edited = 0;")
    out.append("    Streaming = 1;")
    out.append("    Seek Tables = 1;")
    out.append("    Compression Preset Name = ADPCM 256;")
    out.append("    Xbox Bank Last Modified Low = 0;")
    out.append("    Xbox Bank Last Modified High = 0;")
    out.append("    PC Bank Last Modified Low = 0;")
    out.append("    PC Bank Last Modified High = 0;")
    out.append("    Bank Last Revised Low = 0;")
    out.append("    Bank Last Revised High = 0;")
    out.append("")
    
    # Build wave bank base offsets for remapping
    wb_bases = {}
    current_base = 0
    for wb_name in mapping['wave_banks']:
        wb_bases[wb_name] = current_base
        wb_dir = os.path.join(EXTRACT_DIR, wb_name)
        if os.path.exists(wb_dir):
            current_base += len([f for f in os.listdir(wb_dir) if f.endswith('.wav')])
    
    # Write all waves in merged order
    for merged_idx, wb_name, orig_idx, wav_file in merged_waves:
        wav_path = os.path.join(EXTRACT_DIR, wb_name, wav_file)
        wave_name = f"{wb_name}_{orig_idx:03d}"
        
        ch, sr, data_len = get_wav_info(wav_path)
        out.append("    Wave")
        out.append("    {")
        out.append("        Name = %s;" % wave_name)
        out.append("        File = %s;" % wav_path)
        out.append("        Build Settings Last Modified Low = 0;")
        out.append("        Build Settings Last Modified High = 0;")
        out.append("        Compression Preset Name = ADPCM 256;")
        out.append("")
        out.append("        Cache")
        out.append("        {")
        out.append("            Format Tag = 0;")
        out.append("            Channels = %d;" % ch)
        out.append("            Sampling Rate = %d;" % sr)
        out.append("            Bits Per Sample = 1;")
        out.append("            Play Region Offset = 80;")
        out.append("            Play Region Length = %d;" % data_len)
        out.append("            Loop Region Offset = 0;")
        out.append("            Loop Region Length = 0;")
        out.append("            File Type = 1;")
        out.append("            Last Modified Low = 0;")
        out.append("            Last Modified High = 0;")
        out.append("        }")
        out.append("    }")
        out.append("")
    out.append("}")
    out.append("")
    
    # ---- Sound Bank ----
    out.append("Sound Bank")
    out.append("{")
    out.append("    Name = %s;" % deploy_name)
    out.append("    Xbox File = %s;" % os.path.join(build_dir, "Xbox", deploy_name + ".xsb"))
    out.append("    Windows File = %s;" % os.path.join(build_dir, "Win", deploy_name + ".xsb"))
    out.append("    Xbox Bank Path Edited = 0;")
    out.append("    Windows Bank Path Edited = 0;")
    out.append("    Bank Last Modified Low = 0;")
    out.append("    Bank Last Modified High = 0;")
    out.append("    Header Last Modified High = 0;")
    out.append("    Header Last Modified Low = 0;")
    out.append("")
    
    # Build a lookup: (wb_name, orig_wave_idx) → merged_idx
    wave_lookup = {}
    for merged_idx, wb_name, orig_idx, _ in merged_waves:
        wave_lookup[(wb_name, orig_idx)] = (merged_idx, f"{wb_name}_{orig_idx:03d}")
    
    # Sound blocks
    sound_idx = 0
    sound_names = []
    for cm in mapping['cue_mappings']:
        if not cm['wave_refs']:
            continue
        
        # Take first wave ref for the sound
        ref = cm['wave_refs'][0]
        wb_name = ref['wave_bank']
        orig_wave_idx = ref['wave_index']
        
        key = (wb_name, orig_wave_idx)
        if key not in wave_lookup:
            print(f"    WARNING: wave {wb_name}[{orig_wave_idx}] not found for cue {cm['cue_name']}")
            continue
        
        merged_idx, wave_name = wave_lookup[key]
        cat_name, xap_vol = get_cat_and_volume(bank_name, cm)
        sound_name = cm['cue_name']
        sound_names.append(sound_name)
        
        out.append("    Sound")
        out.append("    {")
        out.append("        Name = %s;" % sound_name)
        out.append("        Volume = %d;" % xap_vol)
        out.append("        Pitch = 0;")
        out.append("        Priority = 0;")
        out.append("")
        out.append("        Category Entry")
        out.append("        {")
        out.append("            Name = %s;" % cat_name)
        out.append("        }")
        out.append("")
        out.append("        Track")
        out.append("    {")
        out.append("            Volume = 0;")
        out.append("")
        out.append("            Play Wave Event")
        out.append("            {")
        out.append("                Break Loop = 0;")
        out.append("                Use Speaker Position = 0;")
        out.append("                Use Center Speaker = 1;")
        out.append("                New Speaker Position on Loop = 1;")
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
        out.append("                    Bank Name = %s;" % deploy_name)
        out.append("                    Bank Index = 0;")
        out.append("                    Entry Name = %s;" % wave_name)
        out.append("                    Entry Index = %d;" % merged_idx)
        out.append("                    Weight = 255;")
        out.append("                    Weight Min = 0;")
        out.append("                }")
        out.append("            }")
        out.append("        }")
        out.append("    }")
        out.append("")
    
    # Cue blocks
    for i, sound_name in enumerate(sound_names):
        out.append("    Cue")
        out.append("    {")
        out.append("        Name = %s;" % sound_name)
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
        out.append("            Name = %s;" % sound_name)
        out.append("            Index = %d;" % i)
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
    
    xap_path = os.path.join(build_dir, "%s.xap" % deploy_name)
    with open(xap_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(out) + '\n')
    return xap_path


def compile_xap(xap_path, build_dir):
    win_dir = os.path.join(build_dir, "Win")
    xbox_dir = os.path.join(build_dir, "Xbox")
    os.makedirs(win_dir, exist_ok=True)
    os.makedirs(xbox_dir, exist_ok=True)
    
    cmd = [XACTBLD, "/WINDOWS", xap_path]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
    
    if result.returncode != 0:
        print("  XactBld FAILED (exit %d)" % result.returncode)
        if result.stdout:
            for l in result.stdout.strip().split('\n')[-20:]:
                print("    %s" % l)
        if result.stderr:
            print("  STDERR: %s" % result.stderr[:500])
        return False
    return True


def verify_v43_corrected(xsb_path, mapping):
    """Verify v43 XSB using corrected event layout (22-byte event 0x06, 17-byte event 0x04)."""
    sys.path.insert(0, TEMP)
    # Use the corrected verify_xsb_v43 parser
    from verify_xsb_v43 import parse_xsb
    
    try:
        info = parse_xsb(xsb_path)
    except Exception as e:
        return False, f"parse error: {e}"
    
    # Build expected mapping from v41 data
    # Build wave bank base offsets (same as in generate_xap)
    wb_bases = {}
    current_base = 0
    for wb_name in mapping['wave_banks']:
        wb_bases[wb_name] = current_base
        wb_dir = os.path.join(EXTRACT_DIR, wb_name)
        if os.path.exists(wb_dir):
            current_base += len([f for f in os.listdir(wb_dir) if f.endswith('.wav')])
    
    # Build expected: cue_name → set of merged wave indices
    expected = {}
    for cm in mapping['cue_mappings']:
        if not cm['wave_refs']:
            continue
        merged_indices = set()
        for ref in cm['wave_refs']:
            wb_name = ref['wave_bank']
            orig_idx = ref['wave_index']
            merged_idx = wb_bases.get(wb_name, 0) + orig_idx
            merged_indices.add(merged_idx)
        expected[cm['cue_name']] = merged_indices
    
    # Parse v43 cues
    cue_names = info['cue_names']
    cue_refs = info['cue_refs']
    
    mismatches = 0
    total = 0
    for i, name in enumerate(cue_names):
        if name not in expected:
            continue
        total += 1
        v43_refs = cue_refs[i] if i < len(cue_refs) else None
        if v43_refs is None:
            mismatches += 1
            print(f"    MISMATCH [{i}] {name}: no refs in v43")
            continue
        
        v43_waves = set(t for _, t in v43_refs)
        exp_waves = expected[name]
        
        # Check if v43 waves are a subset of expected (we only built first ref)
        if not v43_waves.issubset(exp_waves):
            mismatches += 1
            print(f"    MISMATCH [{i}] {name}: v43={v43_waves} expected_subset={exp_waves}")
    
    return mismatches == 0, f"{mismatches} mismatches / {total} cues"


def deploy_bank(bank_name, build_dir):
    deploy_name = "SC_" + bank_name
    src_xsb = os.path.join(build_dir, "Win", deploy_name + ".xsb")
    src_xwb = os.path.join(build_dir, "Win", deploy_name + ".xwb")
    dst_xsb = os.path.join(FA_SOUND, deploy_name + ".xsb")
    dst_xwb = os.path.join(FA_SOUND, deploy_name + ".xwb")
    
    backup_dir = os.path.join(TEMP, "backup_sound_rebuild")
    os.makedirs(backup_dir, exist_ok=True)
    for dst in [dst_xsb, dst_xwb]:
        if os.path.exists(dst):
            shutil.copy2(dst, os.path.join(backup_dir, os.path.basename(dst)))
    
    shutil.copy2(src_xsb, dst_xsb)
    shutil.copy2(src_xwb, dst_xwb)
    return True


def main():
    # Load mappings
    mappings_path = os.path.join(TEMP, "all_root_mappings.json")
    with open(mappings_path, 'r', encoding='utf-8') as f:
        all_mappings = json.load(f)
    
    # Determine which banks to rebuild
    banks_to_rebuild = []
    for bank_name in sorted(all_mappings.keys()):
        if bank_name in ALREADY_DEPLOYED:
            print(f"  SKIP {bank_name} (already deployed)")
            continue
        if bank_name in SKIP_BANKS:
            print(f"  SKIP {bank_name} (in skip list)")
            continue
        banks_to_rebuild.append(bank_name)
    
    print(f"\n=== Rebuilding {len(banks_to_rebuild)} sound banks ===\n")
    
    results = []
    for bank_name in banks_to_rebuild:
        print(f"--- {bank_name} ---")
        mapping = all_mappings[bank_name]
        deploy_name = "SC_" + bank_name
        build_dir = os.path.join(TEMP, f"build_{deploy_name}")
        os.makedirs(build_dir, exist_ok=True)
        
        # Step 1: Build merged wave list
        try:
            merged_waves = build_merged_wave_list(bank_name, mapping)
            n_cues = len([cm for cm in mapping['cue_mappings'] if cm['wave_refs']])
            print(f"  {n_cues} cues, {len(merged_waves)} waves, banks={mapping['wave_banks']}")
        except Exception as e:
            traceback.print_exc()
            results.append({'name': bank_name, 'status': 'error', 'detail': str(e)})
            continue
        
        # Step 2: Generate XAP
        try:
            xap_path = generate_xap(bank_name, mapping, merged_waves, build_dir)
            print(f"  XAP generated")
        except Exception as e:
            traceback.print_exc()
            results.append({'name': bank_name, 'status': 'error', 'detail': str(e)})
            continue
        
        # Step 3: Compile
        try:
            if compile_xap(xap_path, build_dir):
                print(f"  Compiled OK")
            else:
                results.append({'name': bank_name, 'status': 'compile_failed'})
                continue
        except Exception as e:
            traceback.print_exc()
            results.append({'name': bank_name, 'status': 'error', 'detail': str(e)})
            continue
        
        # Step 4: Verify
        xsb_path = os.path.join(build_dir, "Win", deploy_name + ".xsb")
        ok, detail = verify_v43_corrected(xsb_path, mapping)
        if ok:
            print(f"  Verify: PASS ({detail})")
        else:
            print(f"  Verify: MISMATCH ({detail})")
        
        # Step 5: Deploy
        if ok:
            try:
                deploy_bank(bank_name, build_dir)
                print(f"  Deployed")
                results.append({'name': bank_name, 'status': 'ok', 'detail': detail})
            except Exception as e:
                traceback.print_exc()
                results.append({'name': bank_name, 'status': 'deploy_error', 'detail': str(e)})
        else:
            results.append({'name': bank_name, 'status': 'mismatch', 'detail': detail})
        
        print()
    
    # Summary
    print("=" * 70)
    print("SUMMARY")
    print("=" * 70)
    for r in results:
        print(f"  {r['name']:25s}  {r['status']:15s}  {r.get('detail', '')}")
    
    ok_count = sum(1 for r in results if r['status'] == 'ok')
    fail_count = sum(1 for r in results if r['status'] != 'ok')
    print(f"\n{ok_count} OK, {fail_count} FAIL out of {len(results)}")
    
    results_path = os.path.join(TEMP, 'batch_root_rebuild_results.json')
    with open(results_path, 'w', encoding='utf-8') as f:
        json.dump(results, f, indent=2, ensure_ascii=False)
    print(f"Results: {results_path}")


if __name__ == '__main__':
    main()
