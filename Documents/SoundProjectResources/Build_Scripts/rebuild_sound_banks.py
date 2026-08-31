#!/usr/bin/env python3
"""
Rebuild AmbientTest and Music banks from v41 XSB correct mappings.

Key differences from VO rebuild:
- Different categories per cue (World, Interface, Ambient, Op_Briefing, Music)
- Different volumes per cue (non-linear byte encoding)
- AmbientTest has shared waves across cues
- Music bank has 17 large streaming waves
"""
import os, sys, struct, json, subprocess, shutil, math

BASE = r"I:\SteamLibrary\steamapps\common\Supreme Commander Forged Alliance"
TEMP = os.path.join(BASE, "AudioProject_2", ".temp")
PCM_BASE = os.path.join(BASE, "AudioTools", "pcm_wavs")
SC_SOUND = r"I:\SteamLibrary\steamapps\common\Supreme Commander\sounds"
FA_SOUND = os.path.join(BASE, "gamedata", "SC_Campaign_Data_Sound.scd", "sounds")
ORIGINAL_XAP = os.path.join(BASE, "AudioTools", "FA_vanilla_VOs_real_original.xap")
XACTBLD = r"C:\Program Files (x86)\Microsoft DirectX SDK (November 2007)\Utilities\Bin\x86\XactBld.exe"

sys.path.insert(0, TEMP)
from parse_xsb_v41 import XSBv41Parser


def parse_decibels(byte_val):
    """MonoGame XactHelpers.ParseDecibels - byte to dB."""
    a = -96.0
    b = 0.432254984608615
    c = 80.1748600297963
    d = 67.7385212334047
    return ((a - d) / (1 + (math.pow(byte_val / c, b)))) + d


def byte_to_xap_volume(vol_byte):
    """Convert XSB volume byte to XAP Volume (centibels)."""
    if vol_byte == 255:
        return -9600  # silence
    db = parse_decibels(vol_byte)
    return round(db * 100)


def get_wav_info(path):
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
        raise RuntimeError("bad wav header: %s" % path)
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


# Category ID → name (from FA_vanilla_VOs_real_original.xap order, 0-indexed)
CAT_NAMES = [
    'Global', 'Default', 'Music', 'World', 'Units', 'Ambient', 'Weapons', 'Destroy',
    'Rumble', 'Interface', 'UnitsUEF', 'UnitsAEON', 'UnitsCYBRAN',
    'UnitsUEFAir', 'UnitsCYBRANAir', 'UnitsAEONAir',
    'ActiveLoopsUEF', 'ActiveLoopsCYBRAN', 'ActiveLoopsAEON',
    'Unit Select', 'FMV', 'Op_Briefing', 'VO', 'US',
]


def parse_v41_bank(bank_name):
    """Parse v41 XSB and return cue mappings with full details."""
    xsb_path = os.path.join(SC_SOUND, "%s.xsb" % bank_name)
    parser = XSBv41Parser(xsb_path)
    parser.parse()
    
    d = parser.data
    # Extract per-cue details from sound data
    for m in parser.cue_mappings:
        so = m.get('sound_offset', 0)
        if so == 0 or so >= len(d):
            m['cat_name'] = 'Default'
            m['xap_volume'] = 0
            continue
        
        off = so
        flags = d[off]; off += 1
        cat_id = struct.unpack_from('<H', d, off)[0]; off += 2
        vol_byte = d[off]; off += 1
        pitch = struct.unpack_from('<h', d, off)[0]; off += 2
        
        m['cat_name'] = CAT_NAMES[cat_id] if cat_id < len(CAT_NAMES) else 'cat_%d' % cat_id
        m['xap_volume'] = byte_to_xap_volume(vol_byte)
        m['cat_id'] = cat_id
        m['vol_byte'] = vol_byte
    
    # Build wave list: wave_index → wave_name (first cue that references it)
    wave_to_cue = {}
    for m in parser.cue_mappings:
        for wb_idx, wave_idx in m['wave_refs']:
            if wave_idx not in wave_to_cue:
                wave_to_cue[wave_idx] = m['cue_name']
    
    max_wave = max(wave_to_cue.keys()) if wave_to_cue else -1
    wave_list = []
    for wi in range(max_wave + 1):
        name = wave_to_cue.get(wi, "%s_wave_%03d" % (bank_name, wi))
        wave_list.append((wi, name))
    
    return parser, wave_list


def generate_xap(bank_name, parser, wave_list, build_dir, deploy_prefix="SC_"):
    """Generate XAP file for a sound bank."""
    global_settings = load_global_settings()
    pcm_dir = os.path.join(PCM_BASE, bank_name)
    deploy_name = deploy_prefix + bank_name
    
    out = list(global_settings)
    out.append("")
    
    # ---- Wave Bank ----
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
    
    for wi, wname in wave_list:
        fp = os.path.join(pcm_dir, wname + ".wav")
        if not os.path.exists(fp):
            fp_alt = os.path.join(pcm_dir, wname.replace(" ", "_") + ".wav")
            if os.path.exists(fp_alt):
                fp = fp_alt
            else:
                print("  WARNING: missing wave %s, skipping" % wname)
                continue
        
        ch, sr, data_len = get_wav_info(fp)
        out.append("    Wave")
        out.append("    {")
        out.append("        Name = %s;" % wname)
        out.append("        File = %s;" % fp)
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
    
    # Sound blocks: one per cue, in cue index order
    # Each cue has its own sound (even if wave is shared, category/volume differs)
    for m in parser.cue_mappings:
        if not m['wave_refs']:
            continue
        
        wb_idx, wave_idx = m['wave_refs'][0]
        # Find wave name for this wave index
        wname = None
        for wi, wn in wave_list:
            if wi == wave_idx:
                wname = wn
                break
        if wname is None:
            wname = m['cue_name']
        
        out.append("    Sound")
        out.append("    {")
        out.append("        Name = %s;" % m['cue_name'])
        out.append("        Volume = %d;" % m['xap_volume'])
        out.append("        Pitch = 0;")
        out.append("        Priority = 0;")
        out.append("")
        out.append("        Category Entry")
        out.append("        {")
        out.append("            Name = %s;" % m['cat_name'])
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
        out.append("                    Entry Name = %s;" % wname)
        out.append("                    Entry Index = %d;" % wave_idx)
        out.append("                    Weight = 255;")
        out.append("                    Weight Min = 0;")
        out.append("                }")
        out.append("            }")
        out.append("        }")
        out.append("    }")
        out.append("")
    
    # Cue blocks
    sound_idx = 0
    for m in parser.cue_mappings:
        if not m['wave_refs']:
            continue
        out.append("    Cue")
        out.append("    {")
        out.append("        Name = %s;" % m['cue_name'])
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
        out.append("            Name = %s;" % m['cue_name'])
        out.append("            Index = %d;" % sound_idx)
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
        sound_idx += 1
    
    out.append("}")
    
    xap_path = os.path.join(build_dir, "%s.xap" % deploy_name)
    with open(xap_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(out) + '\n')
    return xap_path


def compile_xap(xap_path, build_dir):
    """Compile XAP with XactBld /WINDOWS."""
    win_dir = os.path.join(build_dir, "Win")
    xbox_dir = os.path.join(build_dir, "Xbox")
    os.makedirs(win_dir, exist_ok=True)
    os.makedirs(xbox_dir, exist_ok=True)
    
    cmd = [XACTBLD, "/WINDOWS", xap_path]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
    
    if result.returncode != 0:
        print("  XactBld FAILED (exit %d)" % result.returncode)
        if result.stdout:
            lines = result.stdout.strip().split('\n')
            for l in lines[-20:]:
                print("    %s" % l)
        if result.stderr:
            print("  STDERR: %s" % result.stderr[:500])
        return False
    return True


def verify_v43(xsb_path, parser_v41):
    """Verify v43 XSB cue->wave mapping against v41."""
    with open(xsb_path, 'rb') as f:
        data = f.read()
    
    if data[0:4] != b'SDBK':
        return False, "bad magic"
    
    # v43 uses v46 header layout
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
    cue_names_raw = data[cue_names_off:cue_names_off + cue_name_table_len]
    cue_names = [n for n in cue_names_raw.decode('utf-8', 'replace').split('\0') if n]
    
    # Build cue→wave mapping for v43
    # Parse sounds table to find what each sound references
    # For each sound: flags(1) + catID(2) + vol(1) + pitch(2) + prio(1) + filt(2) = 9 bytes header
    # If simple: trackIndex(2) + waveBankIndex(1) = 3 bytes
    # If complex: numClips(1) + [skip RPC] + [skip effects] + clips
    
    def parse_v43_sound(off):
        """Parse a v43 sound, return list of (wb_idx, track_idx)."""
        flags = data[off]
        is_complex = (flags & 0x01) != 0
        has_rpcs = (flags & 0x0E) != 0
        has_effects = (flags & 0x10) != 0
        p = off + 9  # skip header
        
        results = []
        num_clips = 0
        if not is_complex:
            track = struct.unpack_from('<H', data, p)[0]
            bank = data[p + 2]
            results.append((bank, track))
        else:
            num_clips = data[p]; p += 1
        
        # Skip RPC
        if has_rpcs:
            cur = p
            dl = struct.unpack_from('<H', data, p)[0]
            p = cur + dl
        
        # Skip effects
        if has_effects:
            cur = p
            dl = struct.unpack_from('<H', data, p)[0]
            p = cur + dl
        
        # Read clips
        if is_complex:
            for c in range(num_clips):
                # Clip inline: volDb(1) + clipOffset(4) + unkn(4) = 9 bytes
                clip_offset = struct.unpack_from('<I', data, p + 1)[0]
                p += 9
                
                if clip_offset < len(data):
                    ev_off = clip_offset
                    num_events = data[ev_off]; ev_off += 1
                    for e in range(num_events):
                        event_info = struct.unpack_from('<I', data, ev_off)[0]; ev_off += 4
                        rand_offset = struct.unpack_from('<H', data, ev_off)[0]; ev_off += 2
                        event_id = event_info & 0x1F
                        
                        if event_id == 1:
                            ev_off += 1  # unknown
                            ev_off += 1  # flags
                            track = struct.unpack_from('<H', data, ev_off)[0]; ev_off += 2
                            bank = data[ev_off]; ev_off += 1
                            ev_off += 1  # loop count
                            ev_off += 4  # pan angle + arc
                            results.append((bank, track))
                        elif event_id == 3:
                            ev_off += 1  # unknown
                            ev_off += 1  # flags
                            ev_off += 1  # loop count
                            ev_off += 4  # pan angle + arc
                            num_tracks = struct.unpack_from('<H', data, ev_off)[0]; ev_off += 2
                            ev_off += 1  # more flags
                            ev_off += 5  # unknown
                            for t in range(num_tracks):
                                track = struct.unpack_from('<H', data, ev_off)[0]; ev_off += 2
                                bank = data[ev_off]; ev_off += 1
                                ev_off += 2  # weights
                                results.append((bank, track))
                        elif event_id == 4:
                            ev_off += 1  # unknown
                            ev_off += 1  # flags
                            track = struct.unpack_from('<H', data, ev_off)[0]; ev_off += 2
                            bank = data[ev_off]; ev_off += 1
                            ev_off += 1  # loop count
                            ev_off += 4  # pan angle + arc
                            ev_off += 2 + 2  # pitch range
                            ev_off += 2  # volume range
                            ev_off += 16  # filter range
                            ev_off += 1  # unknown
                            results.append((bank, track))
                        elif event_id == 6:
                            ev_off += 1  # unknown
                            ev_off += 1  # flags
                            ev_off += 1  # loop count
                            ev_off += 4  # pan angle + arc
                            ev_off += 2 + 2  # pitch range
                            ev_off += 2  # volume range
                            ev_off += 16  # filter range
                            ev_off += 1  # unknown
                            ev_off += 1  # variation flags
                            num_tracks = struct.unpack_from('<H', data, ev_off)[0]; ev_off += 2
                            ev_off += 1  # more flags
                            ev_off += 5  # unknown
                            for t in range(num_tracks):
                                track = struct.unpack_from('<H', data, ev_off)[0]; ev_off += 2
                                bank = data[ev_off]; ev_off += 1
                                ev_off += 2  # weights
                                results.append((bank, track))
                        elif event_id == 8:
                            ev_off += 2  # unknown
                            ev_off += 1  # flags
                            ev_off += 4  # decibels
                            ev_off += 9  # unknown
                        elif event_id == 0:
                            pass  # stop event
                        else:
                            break  # unknown event
        
        return results
    
    # Parse v43 cues
    v43_mappings = {}
    
    # Simple cues
    p = simple_cues_off
    for i in range(num_simple):
        if p + 5 > len(data):
            break
        flags = data[p]
        sound_off = struct.unpack_from('<I', data, p + 1)[0]
        refs = parse_v43_sound(sound_off)
        v43_mappings[i] = refs
        p += 5
    
    # Complex cues
    p = complex_cues_off
    for i in range(num_complex):
        cue_idx = num_simple + i
        if p + 9 > len(data):
            break
        flags = data[p]; p += 1
        
        if (flags & 0x04) != 0:
            sound_off = struct.unpack_from('<I', data, p)[0]; p += 4
            unkn = struct.unpack_from('<I', data, p)[0]; p += 4
            refs = parse_v43_sound(sound_off)
            v43_mappings[cue_idx] = refs
        else:
            var_off = struct.unpack_from('<I', data, p)[0]; p += 4
            trans_off = struct.unpack_from('<I', data, p)[0]; p += 4
            v43_mappings[cue_idx] = []  # variation table - TODO
        
        # Instance limiting (6 bytes)
        p += 6
    
    # Compare
    mismatches = 0
    total = 0
    for m in parser_v41.cue_mappings:
        ci = m['cue_index']
        v41_refs = m['wave_refs']
        v43_refs = v43_mappings.get(ci, None)
        
        if v43_refs is None:
            continue
        
        total += 1
        # Compare wave indices (ignore bank index - both use bank 0)
        v41_waves = sorted(set(wi for _, wi in v41_refs))
        v43_waves = sorted(set(wi for _, wi in v43_refs))
        
        if v41_waves != v43_waves:
            mismatches += 1
            print("    MISMATCH [%d] %s: v41=%s v43=%s" % 
                  (ci, m['cue_name'], v41_waves, v43_waves))
    
    return mismatches == 0, "%d mismatches / %d cues" % (mismatches, total)


def deploy_bank(bank_name, build_dir, deploy_prefix="SC_"):
    """Deploy compiled bank to FA sound directory."""
    deploy_name = deploy_prefix + bank_name
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
    banks = ['AmbientTest']  # Music already done
    
    print("=== Rebuilding %d sound banks ===\n" % len(banks))
    
    results = []
    for bank_name in banks:
        print("--- %s ---" % bank_name)
        deploy_name = "SC_" + bank_name
        build_dir = os.path.join(TEMP, "build_%s" % deploy_name)
        os.makedirs(build_dir, exist_ok=True)
        
        # Step 1: Parse v41 XSB
        try:
            parser, wave_list = parse_v41_bank(bank_name)
            print("  v41: %d cues, %d waves" % (len(parser.cue_mappings), len(wave_list)))
            for m in parser.cue_mappings:
                waves = ', '.join(str(wi) for _, wi in m['wave_refs'])
                print("    [%d] %-35s cat=%-12s vol=%-5d waves=[%s]" %
                      (m['cue_index'], m['cue_name'], m['cat_name'], m['xap_volume'], waves))
        except Exception as e:
            import traceback
            traceback.print_exc()
            results.append({'name': bank_name, 'status': 'error'})
            continue
        
        # Step 2: Generate XAP
        try:
            xap_path = generate_xap(bank_name, parser, wave_list, build_dir)
            print("  XAP generated: %s" % os.path.basename(xap_path))
        except Exception as e:
            import traceback
            traceback.print_exc()
            results.append({'name': bank_name, 'status': 'error'})
            continue
        
        # Step 3: Compile
        try:
            if compile_xap(xap_path, build_dir):
                print("  Compiled OK")
            else:
                results.append({'name': bank_name, 'status': 'compile_failed'})
                continue
        except Exception as e:
            import traceback
            traceback.print_exc()
            results.append({'name': bank_name, 'status': 'error'})
            continue
        
        # Step 4: Verify
        xsb_path = os.path.join(build_dir, "Win", deploy_name + ".xsb")
        ok, detail = verify_v43(xsb_path, parser)
        if ok:
            print("  Verify: PASS (%s)" % detail)
        else:
            print("  Verify: MISMATCH (%s)" % detail)
        
        # Step 5: Deploy
        if ok:
            deploy_bank(bank_name, build_dir)
            print("  Deployed to %s" % FA_SOUND)
            results.append({'name': bank_name, 'status': 'ok', 'detail': detail})
        else:
            results.append({'name': bank_name, 'status': 'mismatch', 'detail': detail})
        
        print()
    
    # Summary
    print("=" * 70)
    print("SUMMARY")
    print("=" * 70)
    for r in results:
        print("  %s: %s (%s)" % (r['name'], r['status'], r.get('detail', '')))
    
    results_path = os.path.join(TEMP, 'sound_rebuild_results.json')
    with open(results_path, 'w', encoding='utf-8') as f:
        json.dump(results, f, indent=2, ensure_ascii=False)
    print("\nResults: %s" % results_path)


if __name__ == '__main__':
    main()
