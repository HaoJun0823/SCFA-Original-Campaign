#!/usr/bin/env python3
"""
Verify newly compiled v43 XSB: parse via MonoGame-documented structure and
extract every cue -> (waveBankIndex, trackIndex).  Compare with the correct
mapping (absolute merged wave index for Interface; direct index for FMV_BG).
"""
import json
import os
import struct
import sys

BASE = r"I:\SteamLibrary\steamapps\common\Supreme Commander Forged Alliance\AudioProject_2"
TEMP = os.path.join(BASE, ".temp")
INT_MAPPING = os.path.join(TEMP, "interface_mapping_correct.json")
FMV_MAPPING = os.path.join(TEMP, "fmv_bg_mapping_correct.json")

FAIL = [0]

def parse_sound(data, off):
    """Parse an XactSound at absolute offset; return (bank, track) or None."""
    flags = data[off]
    complex_sound = (flags & 0x01) != 0
    has_rpcs = (flags & 0x0E) != 0
    has_effects = (flags & 0x10) != 0
    p = off + 1
    p += 2  # categoryID
    p += 1  # volume
    p += 2  # pitch
    p += 1  # priority
    p += 2  # filter
    if not complex_sound:
        track = struct.unpack_from('<H', data, p)[0]; p += 2
        bank = data[p]; p += 1
    else:
        num_clips = data[p]; p += 1
    if has_rpcs:
        ln = struct.unpack_from('<H', data, p)[0]; p += ln  # rpc_size includes the 2-byte length field
    if has_effects:
        ln = struct.unpack_from('<H', data, p)[0]; p += ln  # same for DSP
    if complex_sound:
        refs = []
        for _ in range(num_clips):
            r = parse_clip(data, p)
            if r:
                refs.extend(r)
            # clip header: volDb(1)+clipOffset(4)+unknown(4)
            p += 9
        return refs or None
    return [(bank, track)]

def parse_clip(data, p):
    """Return list of (bank, track) from an XactClip (event list)."""
    vol_db = data[p]
    clip_offset = struct.unpack_from('<I', data, p + 1)[0]
    # skip unknown 4 bytes
    evp = clip_offset
    if evp >= len(data):
        return []
    num_events = data[evp]; evp += 1
    refs = []
    for _ in range(num_events):
        if evp + 6 > len(data):
            break
        event_info = struct.unpack_from('<I', data, evp)[0]
        evp += 4 + 2  # eventInfo + randomOffset
        event_id = event_info & 0x1F
        if event_id == 1:
            evp += 1 + 1  # unknown + eventFlags
            track = struct.unpack_from('<H', data, evp)[0]; evp += 2
            bank = data[evp]; evp += 1
            evp += 1 + 2 + 2  # loopCount + panAngle + panArc
            refs.append((bank, track))
        elif event_id == 3:
            evp += 1 + 1 + 1 + 2 + 2  # unknown + flags + loop + panA + panArc
            num_tracks = struct.unpack_from('<H', data, evp)[0]; evp += 2
            evp += 1 + 5  # moreFlags + unknown5
            for _ in range(num_tracks):
                trk = struct.unpack_from('<H', data, evp)[0]; evp += 2
                bk = data[evp]; evp += 1
                evp += 2  # weightMin + weightMax
                refs.append((bk, trk))
        elif event_id == 4:
            # SC/FA: NO filter float fields → 17-byte body
            evp += 1 + 1  # unknown + flags
            track = struct.unpack_from('<H', data, evp)[0]; evp += 2
            bank = data[evp]; evp += 1
            evp += 1 + 2 + 2 + 2 + 2 + 1 + 1  # loop + panA + panArc + minPitch + maxPitch + minVol + maxVol
            evp += 1  # unknown (no filter floats in SC/FA)
            refs.append((bank, track))
        elif event_id == 6:
            # SC/FA: NO filter float fields, NO variationFlags byte → 22-byte header
            evp += 1 + 1 + 1 + 2 + 2  # unknown + flags + loop + panA + panArc
            evp += 2 + 2 + 1 + 1  # minPitch + maxPitch + minVol + maxVol
            evp += 1  # unknown (no filter floats, no variationFlags in SC/FA)
            num_tracks = struct.unpack_from('<H', data, evp)[0]; evp += 2
            evp += 1 + 5  # moreFlags + unknown
            for _ in range(num_tracks):
                trk = struct.unpack_from('<H', data, evp)[0]; evp += 2
                bk = data[evp]; evp += 1
                evp += 2
                refs.append((bk, trk))
        else:
            print(f"  !! unsupported event id {event_id} at clip off 0x{clip_offset:X}")
            return refs  # bail out
    return refs

def parse_xsb(path):
    data = open(path, 'rb').read()
    magic = data[0:4]
    assert magic == b'SDBK', f"bad magic {magic}"
    tool_ver, fmt_ver = struct.unpack_from('<HH', data, 4)
    # skip crc(2) lastModLow(4) lastModHigh(4) platform(1)
    num_simple, num_complex = struct.unpack_from('<HH', data, 0x13)
    num_total = struct.unpack_from('<H', data, 0x19)[0]
    num_wb = data[0x1B]
    num_sounds = struct.unpack_from('<H', data, 0x1C)[0]
    cue_name_table_len = struct.unpack_from('<H', data, 0x1E)[0]
    # offsets: simpleCues @0x22, complexCues @0x26, cueNames @0x2A, unkn @0x2E,
    # variationTables @0x32, unkn @0x36, waveBankNameTable @0x3A,
    # cueNameHashTable @0x3E, cueNameHashVals @0x42, sounds @0x46
    simple_cues_off = struct.unpack_from('<I', data, 0x22)[0]
    complex_cues_off = struct.unpack_from('<I', data, 0x26)[0]
    cue_names_off = struct.unpack_from('<I', data, 0x2A)[0]
    variation_tables_off = struct.unpack_from('<I', data, 0x32)[0]
    wave_bank_names_off = struct.unpack_from('<I', data, 0x3A)[0]
    cue_hash_off = struct.unpack_from('<I', data, 0x3E)[0]
    cue_hash_vals_off = struct.unpack_from('<I', data, 0x42)[0]
    sounds_off = struct.unpack_from('<I', data, 0x46)[0]

    # wave bank names (64 bytes each)
    wb_names = []
    p = wave_bank_names_off
    for _ in range(num_wb):
        wb_names.append(data[p:p+64].split(b'\0')[0].decode('ascii', 'replace'))
        p += 64

    # cue names table
    cue_names = data[cue_names_off:cue_names_off + cue_name_table_len].decode('utf-8', 'replace').split('\0')
    cue_names = [c for c in cue_names if c]

    def parse_simple_cue(pos):
        flags = data[pos]; pos += 1
        sound_off = struct.unpack_from('<I', data, pos)[0]
        return parse_sound(data, sound_off)

    def parse_complex_cue(pos):
        flags = data[pos]; pos += 1
        if ((flags >> 2) & 1) != 0:
            sound_off = struct.unpack_from('<I', data, pos)[0]
            return parse_sound(data, sound_off)
        var_off = struct.unpack_from('<I', data, pos)[0]
        # variation table
        vp = var_off
        num_entries = struct.unpack_from('<H', data, vp)[0]; vp += 2
        varflags = struct.unpack_from('<H', data, vp)[0]; vp += 2
        vp += 1 + 2 + 1  # unknown byte + unknown u16 + unknown byte
        table_type = (varflags >> 3) & 0x7
        refs = []
        for _ in range(num_entries):
            if table_type == 0:
                track = struct.unpack_from('<H', data, vp)[0]; vp += 2
                bank = data[vp]; vp += 1
                vp += 2  # weightMin/Max
                refs.append((bank, track))
            elif table_type == 1:
                so = struct.unpack_from('<I', data, vp)[0]; vp += 4
                vp += 2  # weights
                r = parse_sound(data, so)
                if r:
                    refs.extend(r)
            elif table_type == 3:
                so = struct.unpack_from('<I', data, vp)[0]; vp += 4
                vp += 4 + 4 + 4  # weightMin(float) weightMax(float) varFlags
                r = parse_sound(data, so)
                if r:
                    refs.extend(r)
            elif table_type == 4:
                track = struct.unpack_from('<H', data, vp)[0]; vp += 2
                bank = data[vp]; vp += 1
                refs.append((bank, track))
            else:
                raise ValueError(f"unsupported table type {table_type}")
        return refs

    def parse_simple(pos):
        flags = data[pos]; pos += 1
        sound_off = struct.unpack_from('<I', data, pos)[0]
        return parse_sound(data, sound_off)

    cues = []
    p = simple_cues_off
    for i in range(num_simple):
        cues.append(parse_simple(p)); p += 5
    p = complex_cues_off
    for i in range(num_complex):
        flags = data[p]; p += 1
        if ((flags >> 2) & 1) != 0:
            cues.append(parse_complex_cue(p - 1))
            p += 4 + 4
        else:
            cues.append(parse_complex_cue(p - 1))
            p += 4 + 4
        p += 1 + 2 + 2 + 1  # instanceLimit + fadeIn + fadeOut + instanceFlags

    return {
        'tool_ver': tool_ver, 'fmt_ver': fmt_ver,
        'num_simple': num_simple, 'num_complex': num_complex,
        'num_total': num_total, 'num_wb': num_wb, 'num_sounds': num_sounds,
        'wb_names': wb_names, 'cue_names': cue_names,
        'cue_refs': cues,
    }

def main():
    bank = sys.argv[1] if len(sys.argv) > 1 else 'SC_Interface'
    if bank == 'SC_Interface':
        xsb = os.path.join(TEMP, 'build_interface', 'Win', 'SC_Interface.xsb')
        mapping = json.load(open(INT_MAPPING, encoding='utf-8'))
        # expected absolute index per cue
        wb_order = {'Interface': 0, 'UEFSelect': 62, 'CYBRANSelect': 75, 'AEONSelect': 89}
        expected = {}
        for cm in mapping['cue_mappings']:
            ref = cm['wave_refs'][0]
            expected[cm['cue_index']] = wb_order[ref['wave_bank']] + ref['wave_index']
    else:
        xsb = os.path.join(TEMP, 'build_fmv_bg', 'Win', 'SC_FMV_BG.xsb')
        mapping = json.load(open(FMV_MAPPING, encoding='utf-8'))
        expected = {}
        for cm in mapping['cue_mappings']:
            ref = cm['wave_refs'][0]
            expected[cm['cue_index']] = ref['wave_index']

    info = parse_xsb(xsb)
    print(f"XSB {os.path.basename(xsb)}: tool={info['tool_ver']} fmt={info['fmt_ver']}")
    print(f"  cues: {info['num_simple']} simple + {info['num_complex']} complex = {info['num_total']}")
    print(f"  wavebanks: {info['num_wb']} ({', '.join(info['wb_names'])})  sounds={info['num_sounds']}")
    print(f"  parsed cue names: {len(info['cue_names'])}  parsed refs: {len(info['cue_refs'])}")

    if len(info['cue_names']) != info['num_total']:
        print(f"  WARNING: cue name count mismatch")

    bad = 0
    for i, name in enumerate(info['cue_names'][:info['num_total']]):
        refs = info['cue_refs'][i] if i < len(info['cue_refs']) else None
        exp = expected.get(i)
        exp_str = f"bank0/track{exp}" if exp is not None else "?"
        if refs is None:
            print(f"  {i:3d} {name:40s} refs=None  expected={exp_str}  [NO REF]")
            bad += 1
            continue
        refs_str = ','.join(f"b{b}/t{t}" for b, t in refs)
        if len(refs) == 1 and exp is not None and refs[0] == (0, exp):
            print(f"  {i:3d} {name:40s} {refs_str}  OK")
        else:
            print(f"  {i:3d} {name:40s} {refs_str}  expected={exp_str}  [MISMATCH]")
            bad += 1
    print(f"\nResult: {'PASS' if bad == 0 else f'{bad} mismatches'}")
    if bad:
        sys.exit(1)

if __name__ == '__main__':
    main()