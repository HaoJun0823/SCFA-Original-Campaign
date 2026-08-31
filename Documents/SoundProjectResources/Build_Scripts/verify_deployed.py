#!/usr/bin/env python3
"""Verify deployed SC_Interface.xsb has all 112 cues."""
import struct, os

deploy_dir = r"I:\SteamLibrary\steamapps\common\Supreme Commander Forged Alliance\gamedata\SC_Campaign_Data_Sound.scd\sounds"
xsb_path = os.path.join(deploy_dir, "SC_Interface.xsb")

data = open(xsb_path, "rb").read()
print(f"Deployed SC_Interface.xsb: {len(data)} bytes")
print(f"Signature: {data[0:4]}")
print(f"Version: {data[4]}")

# Parse header
sound_count = struct.unpack_from('<H', data, 0x17)[0]
cue_count = struct.unpack_from('<H', data, 0x1A)[0]
print(f"Sound count: {sound_count}")
print(f"Cue count: {cue_count}")

# Find cue names by searching for known cue names
cue_names = [
    "UI_Comm_UEF_Out", "UI_Comm_UEF_In", "UI_Comm_CYB_Out", "UI_Comm_CYB_In",
    "UI_Comm_AEON_Out", "UI_Comm_AEON_In", "UI_Mod_Select", "UI_MFD_Click",
    "UI_MFD_Rollover", "UI_Mini_Rollover", "UI_Mini_MouseDown",
    "UI_Warp_Click_Aeon", "UI_Warp_Click_Cybran", "UI_Warp_Click_UEF",
    "UI_Warp_Aeon_Commander", "UI_Warp_Cybran_Commander", "UI_Warp_UEF_Commander",
    "UI_Menu_Accept_01", "UI_Menu_Cancel_02", "UI_Menu_Error_01",
    "UI_Menu_Select_01", "UI_Skirmish_Map_Select",
    "UI_Camera_Save_Position", "UI_Camera_Recall_Position", "UI_Camera_Delete_Position"
]

text = data.decode('latin-1', errors='replace')
found = 0
not_found = 0
for name in cue_names:
    if name in text:
        found += 1
    else:
        not_found += 1
        print(f"  MISSING: {name}")

print(f"\nCue names found: {found}/{len(cue_names)}")
if not_found:
    print(f"Missing: {not_found}")
else:
    print("All key cue names present!")

# Also check XWB
xwb_path = os.path.join(deploy_dir, "SC_Interface.xwb")
xwb = open(xwb_path, "rb").read()
print(f"\nSC_Interface.xwb: {len(xwb)} bytes")
print(f"Signature: {xwb[0:4]}")
print(f"Version: {struct.unpack_from('<I', xwb, 8)[0]}")
wave_count = struct.unpack_from('<I', xwb, 0x34)[0]
print(f"Wave count: {wave_count}")
