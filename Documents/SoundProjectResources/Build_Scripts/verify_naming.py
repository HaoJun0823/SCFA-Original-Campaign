#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Verify that cue_name -> filename mapping is consistent."""
import json, os

BASE = r"I:\SteamLibrary\steamapps\common\Supreme Commander Forged Alliance"
EXTRACT_DIR = os.path.join(BASE, "AudioProject_2", "extract_all")
TEMP = os.path.join(BASE, "AudioProject_2", ".temp")

with open(os.path.join(TEMP, "all_root_mappings.json"), "r", encoding="utf-8") as f:
    all_mappings = json.load(f)

# Check all banks that use cue-name format
cue_name_banks = []
wave_idx_banks = []
mixed_banks = []

for bank_name, mapping in sorted(all_mappings.items()):
    if bank_name in ("AmbientTest", "FMV_BG", "Interface", "Music", "Op_Briefing", "Tutorial_SE", "TestBank"):
        continue  # skip already deployed

    wave_banks = mapping["wave_banks"]
    all_cue_name = True
    all_wave_idx = True

    for wb_name in wave_banks:
        wb_dir = os.path.join(EXTRACT_DIR, wb_name)
        if not os.path.exists(wb_dir):
            continue
        files = [f for f in os.listdir(wb_dir) if f.endswith(".wav")]
        for f in files:
            if not f.startswith("wave_"):
                all_wave_idx = False
            if f.startswith("wave_"):
                all_cue_name = False

    if all_cue_name and not all_wave_idx:
        cue_name_banks.append(bank_name)
    elif all_wave_idx and not all_cue_name:
        wave_idx_banks.append(bank_name)
    else:
        mixed_banks.append(bank_name)

print("=== CUE-NAME FORMAT banks ===")
for b in cue_name_banks:
    print(f"  {b}")
print(f"\n=== WAVE_IDX FORMAT banks ===")
for b in wave_idx_banks:
    print(f"  {b}")
print(f"\n=== MIXED FORMAT banks ===")
for b in mixed_banks:
    print(f"  {b}")

# Now verify mapping for cue-name banks
print("\n\n=== VERIFYING CUE-NAME BANKS ===")
for bank_name in cue_name_banks:
    mapping = all_mappings[bank_name]
    wave_banks = mapping["wave_banks"]

    # Collect all files from all wave banks
    all_files = {}  # filename -> (wb_name, sort_index)
    for wb_name in wave_banks:
        wb_dir = os.path.join(EXTRACT_DIR, wb_name)
        if not os.path.exists(wb_dir):
            continue
        files = sorted([f for f in os.listdir(wb_dir) if f.endswith(".wav")])
        for idx, f in enumerate(files):
            all_files[f] = (wb_name, idx)

    # For each cue, check if cue_name.wav exists in the files
    matched = 0
    unmatched = 0
    for cm in mapping["cue_mappings"]:
        if not cm["wave_refs"]:
            continue
        name = cm["cue_name"]
        # Check if cue_name.wav exists
        fname = name + ".wav"
        if fname in all_files:
            wb_name, sort_idx = all_files[fname]
            # Verify the wave_index in mapping matches the sort index? NO!
            # The sort index is alphabetical, not wave_index
            # We need to build: wave_index -> filename mapping
            matched += 1
        else:
            unmatched += 1
            if unmatched <= 5:
                print(f"  {bank_name}: UNMATCHED cue '{name}'")

    print(f"  {bank_name}: {matched} matched, {unmatched} unmatched")

    # Build wave_index -> filename mapping
    # Strategy: for cue-name files, build a reverse map from cue_name -> wave_index
    # using the JSON mapping data
    wave_idx_to_file = {}  # (wb_name, wave_index) -> filename
    file_to_wave_idx = {}  # filename -> (wb_name, wave_index)

    for cm in mapping["cue_mappings"]:
        if not cm["wave_refs"]:
            continue
        name = cm["cue_name"]
        fname = name + ".wav"
        for ref in cm["wave_refs"]:
            wb_name = ref["wave_bank"]
            wi = ref["wave_index"]
            key = (wb_name, wi)
            if key not in wave_idx_to_file:
                wave_idx_to_file[key] = fname
                file_to_wave_idx[fname] = key

    # Check: are there wave indices not covered by cue names?
    # Count total waves in each wave bank
    for wb_name in wave_banks:
        wb_dir = os.path.join(EXTRACT_DIR, wb_name)
        if not os.path.exists(wb_dir):
            continue
        total_waves = len([f for f in os.listdir(wb_dir) if f.endswith(".wav")])
        covered = sum(1 for (wb, wi) in wave_idx_to_file if wb == wb_name)
        max_wi = max((wi for (wb, wi) in wave_idx_to_file if wb == wb_name), default=-1)
        print(f"    {wb_name}: {total_waves} files, {covered} wave_indices mapped, max_wi={max_wi}")

        # List unmapped files
        mapped_files = set()
        for (wb, wi), fn in wave_idx_to_file.items():
            if wb == wb_name:
                mapped_files.add(fn)
        all_files_wb = set(f for f in os.listdir(wb_dir) if f.endswith(".wav"))
        unmapped_files = all_files_wb - mapped_files
        if unmapped_files:
            print(f"      Unmapped files: {sorted(unmapped_files)[:10]}")
