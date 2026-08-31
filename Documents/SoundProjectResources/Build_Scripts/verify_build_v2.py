#!/usr/bin/env python3
"""Verify newly built v43 XSB/XWB match correct mappings."""
import json
import os
import struct

BASE = r"I:\SteamLibrary\steamapps\common\Supreme Commander Forged Alliance\AudioProject_2"
TEMP = os.path.join(BASE, ".temp")
BUILD_DIRS = {
    "SC_FMV_BG": os.path.join(TEMP, "build_fmv_bg", "Win"),
    "SC_Interface": os.path.join(TEMP, "build_interface", "Win"),
}
INT_MAPPING = os.path.join(TEMP, "interface_mapping_correct.json")
FMV_MAPPING = os.path.join(TEMP, "fmv_bg_mapping_correct.json")

def check_bank(bank_name, mapping_path, expected_waves):
    with open(mapping_path, 'r', encoding='utf-8') as f:
        mapping = json.load(f)
    cue_names = [cm['cue_name'] for cm in mapping['cue_mappings']]

    bdir = BUILD_DIRS[bank_name]
    xsb_path = os.path.join(bdir, bank_name + ".xsb")
    xwb_path = os.path.join(bdir, bank_name + ".xwb")

    print(f"\n{'='*60}")
    print(f"Bank: {bank_name}")
    print(f"{'='*60}")

    xsb = open(xsb_path, 'rb').read()
    print(f"XSB: {len(xsb)} bytes")
    # v43 layout
    num_total = struct.unpack_from('<H', xsb, 0x19)[0]
    num_wb = xsb[0x1B]
    num_sounds = struct.unpack_from('<H', xsb, 0x1C)[0]
    print(f"  numTotalCues={num_total} numWaveBanks={num_wb} numSounds={num_sounds}")

    # search cue names
    text = xsb.decode('latin-1', errors='replace')
    missing = [n for n in cue_names if n not in text]
    print(f"  Cue names in XSB: {len(cue_names) - len(missing)}/{len(cue_names)}")
    if missing:
        for m in missing:
            print(f"    MISSING: {m}")

    # wave names search (wave bank entry names are embedded in xwb as strings too)
    xwb = open(xwb_path, 'rb').read()
    print(f"XWB: {len(xwb)} bytes")
    # wave count: v43 XWB has header; wave count at offset depends on format
    # Simple check: count via XSB cue->wave is done by the mapping itself.
    # Check wave name presence in XWB binary
    wave_names = sorted({ref['wave_bank'] + '_' + str(ref['wave_index']) for cm in mapping['cue_mappings'] for ref in cm['wave_refs']})
    # Instead verify expected distinct wave names from correct_extract file names
    import glob
    pcm_dir = os.path.join(BASE, "correct_extract", "Interface" if "Interface" in bank_name else "FMV_BG", "pcm")
    files = {os.path.splitext(os.path.basename(p))[0] for p in glob.glob(os.path.join(pcm_dir, "*.wav"))}
    # wave names embedded in XWB (they may be present as ASCII)
    xwb_text = xwb.decode('latin-1', errors='replace')
    present = sum(1 for fn in files if fn in xwb_text)
    print(f"  Wave names (from pcm dir) found in XWB: {present}/{len(files)}")

if __name__ == '__main__':
    check_bank("SC_FMV_BG", FMV_MAPPING, 20)
    check_bank("SC_Interface", INT_MAPPING, 102)