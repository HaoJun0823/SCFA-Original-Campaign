#!/usr/bin/env python3
"""
Parse SC original Interface.xwb to check if it has entry names (WAVEBANK_FLAGS_ENTRYNAMES).
If yes, those are the correct wave names.
Also parse the XWB structure fully to understand wave entry order.
"""
import struct
import os

def read_file(filepath):
    with open(filepath, 'rb') as f:
        return f.read()

def parse_xwb(data):
    # XWB Header
    sig = data[0:4].decode('ascii', errors='replace')
    version = struct.unpack_from('<I', data, 4)[0]
    
    print(f"=== XWB Header ===")
    print(f"Signature: {sig}")
    print(f"Version: {version}")
    
    # For version >= 42, there's an extra dwHeaderVersion field
    offset = 8
    if version >= 42:
        header_version = struct.unpack_from('<I', data, offset)[0]
        print(f"HeaderVersion: {header_version} (0x{header_version:08X})")
        offset += 4
    
    # Segments (5 for v42+, 4 for older)
    last_segment = 4 if version >= 42 else 3
    if version <= 3:
        last_segment = 3
    
    segments = []
    print(f"\n=== Segments (last_segment={last_segment}) ===")
    for i in range(last_segment + 1):
        seg_offset = struct.unpack_from('<I', data, offset)[0]
        seg_length = struct.unpack_from('<I', data, offset + 4)[0]
        segments.append((seg_offset, seg_length))
        print(f"  Segment {i}: offset=0x{seg_offset:08X}, length={seg_length} (0x{seg_length:08X})")
        offset += 8
    
    # WAVEBANKDATA at segments[0].offset
    bankdata_offset = segments[0][0]
    flags = struct.unpack_from('<I', data, bankdata_offset)[0]
    entry_count = struct.unpack_from('<I', data, bankdata_offset + 4)[0]
    
    # Bank name (64 chars for v42+, 16 for v2/v3)
    if version == 2 or version == 3:
        bank_name = data[bankdata_offset + 8:bankdata_offset + 24].decode('ascii', errors='replace').rstrip('\0')
        meta_size_offset = bankdata_offset + 24
    else:
        bank_name = data[bankdata_offset + 8:bankdata_offset + 72].decode('ascii', errors='replace').rstrip('\0')
        meta_size_offset = bankdata_offset + 72
    
    entry_meta_size = struct.unpack_from('<I', data, meta_size_offset)[0]
    entry_name_size = struct.unpack_from('<I', data, meta_size_offset + 4)[0]
    alignment = struct.unpack_from('<I', data, meta_size_offset + 8)[0]
    compact_format = None
    if flags & 0x00020000:  # WAVEBANK_FLAGS_COMPACT
        compact_format = struct.unpack_from('<I', data, meta_size_offset + 12)[0]
    
    print(f"\n=== WAVEBANKDATA ===")
    print(f"Flags: 0x{flags:08X}")
    print(f"  BUFFER (in-memory): {bool(flags & 0x01)}")
    print(f"  STREAMING: {bool(flags & 0x01)}")
    print(f"  ENTRYNAMES: {bool(flags & 0x00010000)}")
    print(f"  COMPACT: {bool(flags & 0x00020000)}")
    print(f"  SYNC_DISABLED: {bool(flags & 0x00040000)}")
    print(f"  SEEKTABLES: {bool(flags & 0x00080000)}")
    print(f"EntryCount: {entry_count}")
    print(f"BankName: '{bank_name}'")
    print(f"EntryMetaSize: {entry_meta_size}")
    print(f"EntryNameSize: {entry_name_size}")
    print(f"Alignment: {alignment}")
    if compact_format is not None:
        print(f"CompactFormat: 0x{compact_format:08X}")
    
    # Entry metadata at segments[1].offset
    entry_meta_offset = segments[1][0]
    
    # Entry names at segments[3].offset (for v42+) or segments[2].offset (for older)
    # unxwb: segidx_entry_name = 2 for old, 3 for v42+
    if version >= 42:
        segidx_entry_name = 3
    else:
        segidx_entry_name = 2
    
    entry_names_offset = segments[segidx_entry_name][0]
    entry_names_length = segments[segidx_entry_name][1]
    
    print(f"\n=== Entry Names Segment (idx={segidx_entry_name}) ===")
    print(f"Offset: 0x{entry_names_offset:08X}")
    print(f"Length: {entry_names_length}")
    
    # Check if entry names exist
    has_entry_names = bool(flags & 0x00010000) and entry_names_offset > 0 and entry_names_length > 0
    print(f"Has Entry Names: {has_entry_names}")
    
    if has_entry_names:
        print(f"\n=== Wave Entry Names (from XWB) ===")
        for i in range(entry_count):
            name_start = entry_names_offset + i * entry_name_size
            name = data[name_start:name_start + entry_name_size].decode('ascii', errors='replace').rstrip('\0')
            print(f"  Wave {i:2d}: '{name}'")
    
    # Parse wave entries (metadata)
    print(f"\n=== Wave Entry Metadata ===")
    wave_entries = []
    for i in range(entry_count):
        entry_offset = entry_meta_offset + i * entry_meta_size
        if entry_meta_size >= 4:
            flags_duration = struct.unpack_from('<I', data, entry_offset)[0]
        if entry_meta_size >= 8:
            fmt = struct.unpack_from('<I', data, entry_offset + 4)[0]
        if entry_meta_size >= 12:
            play_offset = struct.unpack_from('<I', data, entry_offset + 8)[0]
        if entry_meta_size >= 16:
            play_length = struct.unpack_from('<I', data, entry_offset + 12)[0]
        else:
            play_length = 0
        
        # Decode format (for v2+, i.e., versions 2, 3, 37, 42, 43, 44)
        if version >= 2:
            codec = fmt & 0x3
            chans = (fmt >> 2) & 0x7
            rate = (fmt >> 5) & 0x3FFFF
            block_align = (fmt >> 23) & 0xFF
            bits = (fmt >> 31) & 0x1
        else:
            codec = fmt & 0x1
            chans = (fmt >> 1) & 0x7
            rate = (fmt >> 5) & 0x3FFFF
            block_align = (fmt >> 23) & 0xFF
            bits = (fmt >> 31) & 0x1
        
        codec_names = {0: 'PCM', 1: 'XMA', 2: 'ADPCM', 3: 'WMA'}
        wave_entries.append({
            'index': i,
            'play_offset': play_offset if entry_meta_size >= 12 else 0,
            'play_length': play_length,
            'codec': codec_names.get(codec, f'?({codec})'),
            'channels': chans + 1,  # 0-based
            'rate': rate,
            'block_align': block_align,
            'bits': 16 if bits else 8,
        })
        
        if i < 10 or i >= entry_count - 5:  # first 10 and last 5
            print(f"  Wave {i:2d}: len={play_length:>8d}, {codec_names.get(codec, '?')}, {rate}Hz, {chans+1}ch, align={block_align}")
        elif i == 10:
            print(f"  ... ({entry_count - 15} more) ...")
    
    return wave_entries, has_entry_names

def main():
    # SC original
    sc_xwb = r"I:\SteamLibrary\steamapps\common\Supreme Commander\sounds\Interface.xwb"
    print("=" * 60)
    print("SC ORIGINAL Interface.xwb")
    print("=" * 60)
    sc_data = read_file(sc_xwb)
    print(f"File size: {len(sc_data)} bytes (0x{len(sc_data):X})")
    sc_waves, sc_has_names = parse_xwb(sc_data)
    
    # Compiled version
    print("\n\n")
    comp_xwb = r"I:\SteamLibrary\steamapps\common\Supreme Commander Forged Alliance\AudioProject_2\.temp\build_interface\Win\SC_Interface.xwb"
    if os.path.exists(comp_xwb):
        print("=" * 60)
        print("COMPILED SC_Interface.xwb")
        print("=" * 60)
        comp_data = read_file(comp_xwb)
        print(f"File size: {len(comp_data)} bytes (0x{len(comp_data):X})")
        comp_waves, comp_has_names = parse_xwb(comp_data)

if __name__ == '__main__':
    main()
