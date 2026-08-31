#!/usr/bin/env python3
"""
Parse SC original Interface.xsb to extract the full cue -> sound -> wave index mapping.
This is critical to determine if unxwb's wave naming is correct.
"""
import struct
import sys
import os

def read_xsb(filepath):
    with open(filepath, 'rb') as f:
        return f.read()

def parse_xsb(data):
    # Header
    sig = data[0:4].decode('ascii', errors='replace')
    tool_version = data[4]
    format_version = data[5]
    header_version = struct.unpack_from('<H', data, 6)[0]
    crc = struct.unpack_from('<I', data, 8)[0]
    build_time = struct.unpack_from('<I', data, 12)[0]

    print(f"=== XSB Header ===")
    print(f"Signature: {sig}")
    print(f"ToolVersion: {tool_version}")
    print(f"FormatVersion: {format_version}")
    print(f"HeaderVersion: {header_version}")
    print(f"CRC: 0x{crc:08X}")
    print(f"BuildTime: 0x{build_time:08X}")

    # The header from 0x10 onwards is a series of uint16 values
    # Based on XSB format v41:
    # We need to figure out the exact layout

    # Let's dump the header as uint16 array for analysis
    print(f"\n=== Full header as uint16 array (0x10 to 0x50) ===")
    for off in range(0x10, 0x50, 2):
        val = struct.unpack_from('<H', data, off)[0]
        print(f"  0x{off:04X}: 0x{val:04X} ({val})")

    # XSB format (v41) structure based on research:
    # After the 0x10 fixed header, the structure contains:
    # - Cue count
    # - Sound count
    # - Various table offsets

    # Key fields identified from prior analysis:
    # 0x1A = numCues = 112 (0x70)
    # 0x28 = cue name table offset = 0x1165

    # Let's try to identify all table offsets
    # Looking at the header more carefully...

    # Known from prior analysis:
    num_cues = struct.unpack_from('<H', data, 0x1A)[0]
    print(f"\nnumCues (0x1A) = {num_cues}")

    # 0x1E seems to be another count
    val_1e = struct.unpack_from('<H', data, 0x1E)[0]
    print(f"val_1E (0x1E) = {val_1e}")

    # 0x22 = 0xFF (255) - could be max or -1
    val_22 = struct.unpack_from('<H', data, 0x22)[0]
    print(f"val_22 (0x22) = {val_22}")

    # 0x26 = 84
    val_26 = struct.unpack_from('<H', data, 0x26)[0]
    print(f"val_26 (0x26) = {val_26}")

    # 0x2A = 101
    val_2a = struct.unpack_from('<H', data, 0x2A)[0]
    print(f"val_2A (0x2A) = {val_2a}")

    # 0x2E onwards = 0xFFFF (-1)
    val_2e = struct.unpack_from('<H', data, 0x2E)[0]
    print(f"val_2E (0x2E) = {val_2e}")

    # Let's try reading as 32-bit values too
    print(f"\n=== Header as uint32 array (0x10 to 0x40) ===")
    for off in range(0x10, 0x40, 4):
        val = struct.unpack_from('<I', data, off)[0]
        print(f"  0x{off:04X}: 0x{val:08X} ({val})")

    # After the header, there are typically:
    # 1. Cue table (each entry maps cue to sound)
    # 2. Sound table (each entry describes a sound and its wave references)
    # 3. Cue name table (cue name strings)
    # 4. Sound name table (if present)
    # 5. Extra data (variation tables, etc.)

    # The header likely contains offsets to these tables.
    # Let's look at the raw bytes more carefully around the header area

    # Let's look at bytes 0x38 onwards (after the 0xFFFF block)
    print(f"\n=== Bytes 0x38 to 0x60 ===")
    for off in range(0x38, 0x60, 2):
        val = struct.unpack_from('<H', data, off)[0]
        print(f"  0x{off:04X}: 0x{val:04X} ({val})")

    # Let's try a different approach - look at the XSB format specification
    # XSB v41 header:
    # 0x00: "SDBK" (4 bytes)
    # 0x04: tool version (1 byte)
    # 0x05: format version (1 byte)
    # 0x06: header version (2 bytes)
    # 0x08: CRC (4 bytes)
    # 0x0C: build time (4 bytes)
    # 0x10: content flags? (2 bytes)
    # 0x12: language ID? (2 bytes)
    # ... more header fields ...

    # Actually, let me try to find the cue name table directly
    # We know cue name table is at 0x1165
    cue_name_offset = 0x1165
    print(f"\n=== Cue Name Table (offset 0x{cue_name_offset:X}) ===")
    # Read null-terminated strings until we get 112 names
    pos = cue_name_offset
    cue_names = []
    for i in range(num_cues):
        if pos >= len(data):
            break
        end = data.index(0, pos) if 0 in data[pos:] else len(data)
        name = data[pos:end].decode('ascii', errors='replace')
        cue_names.append(name)
        pos = end + 1

    for i, name in enumerate(cue_names):
        print(f"  Cue {i:3d}: {name}")

    # Now we need to find the cue table (which maps cue index -> sound index)
    # and the sound table (which maps sound index -> wave index)

    # In XSB format, the cue table typically comes right after the header
    # Let's look at the data structure between header and cue name table

    # The header seems to end somewhere around 0x40-0x50
    # Let's look at the data from ~0x38 onwards to find structure

    # Actually, let me try reading the header as the XSB v2 format:
    # After the 16-byte fixed header (0x00-0x0F), there's a structure:
    # Offset 0x10: contentFlags (1 byte) + padding
    # Then a series of 2-byte fields

    # Let me try to interpret based on known XSB v41 layout
    # From xactengine / DirectX SDK documentation research:

    # XSB header fields (after 0x0C):
    # 0x10: (2 bytes) - contentFlags? = 1
    # 0x12: (2 bytes) - 0
    # 0x14: (2 bytes) - 0
    # 0x16: (2 bytes) - 0
    # 0x18: (2 bytes) - 0
    # 0x1A: (2 bytes) - numCues = 112
    # 0x1C: (2 bytes) - 0
    # 0x1E: (2 bytes) - numSounds? = 107
    # 0x20: (2 bytes) - 0
    # 0x22: (2 bytes) - 255 (could be numWaveBanks or variation count?)
    # 0x24: (2 bytes) - 0
    # 0x26: (2 bytes) - 84 (could be an offset or count)
    # 0x28: (2 bytes) - 0
    # 0x2A: (2 bytes) - 101 (could be an offset or count)
    # 0x2C: (2 bytes) - 0
    # 0x2E-0x37: 0xFFFF (6x FFFF = padding/reserved)

    # Hmm, let me look at 32-bit values:
    # 0x10: 0x00000001 - flags
    # 0x14: 0x00000000
    # 0x18: 0x00000000
    # 0x1C: 0x006B0000 -> 0x1A=0x0070(112), 0x1C=0x0000
    # Wait, these are little-endian uint16 pairs

    # Let me try: numSounds = 107 (at 0x1E)
    num_sounds_guess = val_1e  # 107
    print(f"\n=== Guessing numSounds = {num_sounds_guess} ===")

    # If 0x26 = 84 and 0x2A = 101, these might be offsets to tables
    # divided by 2 (since XSB uses uint16 indices)
    # 84 * 2 = 168, 101 * 2 = 202

    # Or they could be direct offsets within the data area

    # Let me try to find the sound table by looking at the structure
    # The header ends and tables begin somewhere after 0x37

    # Let me look at data from 0x38 to find table boundaries
    print(f"\n=== Data from 0x38 (potential table start) ===")
    # Dump first 128 bytes from 0x38
    for off in range(0x38, 0x38 + 128, 16):
        hexbytes = ' '.join(f'{data[off+j]:02X}' for j in range(16) if off+j < len(data))
        ascii_str = ''.join(chr(data[off+j]) if 32 <= data[off+j] < 127 else '.' for j in range(16) if off+j < len(data))
        print(f"  0x{off:04X}: {hexbytes}  {ascii_str}")

    return cue_names

if __name__ == '__main__':
    xsb_path = r"I:\SteamLibrary\steamapps\common\Supreme Commander\sounds\Interface.xsb"
    data = read_xsb(xsb_path)
    cue_names = parse_xsb(data)
