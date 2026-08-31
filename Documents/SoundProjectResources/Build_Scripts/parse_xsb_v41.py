#!/usr/bin/env python3
"""
XSB v41 Complete Parser - based on MonoGame SoundBank.cs / XactSound.cs / XactClip.cs
Handles the v41 header difference: lastModifiedHigh is 2 bytes (not 4 as in v46),
shifting count fields -2 bytes. Offset fields remain at v46 positions (0x22+).

Produces a complete Cue → Sound → [WaveBankName, WaveIndex] mapping.
"""

import struct
import json
import os
import sys

class XSBv41Parser:
    def __init__(self, xsb_path):
        self.data = open(xsb_path, 'rb').read()
        self.path = xsb_path
        self.name = os.path.basename(xsb_path).replace('.xsb', '')
        self.wave_bank_names = []
        self.cue_names = []
        self.cue_mappings = []  # list of {cue_name, cue_index, type, sounds: [{wave_bank, wave_index}]}
        
    def u8(self, off):
        return self.data[off]
    
    def u16(self, off):
        return struct.unpack_from('<H', self.data, off)[0]
    
    def u32(self, off):
        return struct.unpack_from('<I', self.data, off)[0]
    
    def i16(self, off):
        return struct.unpack_from('<h', self.data, off)[0]
    
    def f32(self, off):
        return struct.unpack_from('<f', self.data, off)[0]
    
    def read_string(self, off, max_len=64):
        end = self.data.find(b'\x00', off, off + max_len)
        if end == -1:
            end = off + max_len
        return self.data[off:end].decode('ascii', errors='replace')
    
    def parse_header(self):
        d = self.data
        magic = d[0:4]
        assert magic == b'SDBK', f"Bad magic: {magic}"
        self.tool_version = self.u16(0x04)
        self.format_version = self.u16(0x06)
        self.crc = self.u16(0x08)
        self.last_modified_low = self.u32(0x0A)
        
        # KEY DIFFERENCE: v41 has 2-byte lastModifiedHigh instead of 4
        self.last_modified_high = self.u16(0x0E)
        self.platform = self.u8(0x10)
        
        # Count fields (shifted -2 from v46)
        self.num_simple_cues = self.u16(0x11)
        self.num_complex_cues = self.u16(0x13)
        self.unkn_cue = self.u16(0x15)
        self.num_total_cues = self.u16(0x17)
        self.num_wave_banks = self.u8(0x19)
        self.num_sounds = self.u16(0x1A)
        self.cue_name_table_len = self.u16(0x1E)
        self.unkn2 = self.u16(0x20)
        
        # Offset fields (same as v46, starting at 0x22)
        self.simple_cues_offset = self.u32(0x22)
        self.complex_cues_offset = self.u32(0x26)
        self.cue_names_offset = self.u32(0x2A)
        self.unkn3 = self.u32(0x2E)
        self.variation_tables_offset = self.u32(0x32)
        self.unkn4 = self.u32(0x36)
        self.wave_bank_name_table_offset = self.u32(0x3A)
        self.cue_name_hash_table_offset = self.u32(0x3E)
        self.cue_name_hash_vals_offset = self.u32(0x42)
        self.sounds_offset = self.u32(0x46)
        
        print(f"=== {self.name}.xsb Header ===")
        print(f"  toolVersion={self.tool_version}, formatVersion={self.format_version}")
        print(f"  platform={self.platform}")
        print(f"  numSimpleCues={self.num_simple_cues}, numComplexCues={self.num_complex_cues}")
        print(f"  numTotalCues={self.num_total_cues}, numWaveBanks={self.num_wave_banks}")
        print(f"  numSounds={self.num_sounds}, cueNameTableLen={self.cue_name_table_len}")
        print(f"  simpleCuesOff=0x{self.simple_cues_offset:X}, complexCuesOff=0x{self.complex_cues_offset:X}")
        print(f"  cueNamesOff=0x{self.cue_names_offset:X}, soundsOff=0x{self.sounds_offset:X}")
        print(f"  wbNameTblOff=0x{self.wave_bank_name_table_offset:X}")
        
        # Verify: simpleCuesOff + numSimpleCues*5 == complexCuesOff
        expected = self.simple_cues_offset + self.num_simple_cues * 5
        if expected != self.complex_cues_offset:
            print(f"  WARNING: simpleCuesOff + {self.num_simple_cues}*5 = 0x{expected:X} != complexCuesOff=0x{self.complex_cues_offset:X}")
        else:
            print(f"  [OK] simpleCuesOff + {self.num_simple_cues}*5 = complexCuesOff")
        
        total = self.num_simple_cues + self.num_complex_cues
        if total != self.num_total_cues:
            print(f"  WARNING: {self.num_simple_cues}+{self.num_complex_cues}={total} != numTotalCues={self.num_total_cues}")
        else:
            print(f"  [OK] simple+complex = total cues")
    
    def parse_wave_bank_names(self):
        """Read wave bank name table (each name is 64 bytes, null-padded)"""
        off = self.wave_bank_name_table_offset
        self.wave_bank_names = []
        for i in range(self.num_wave_banks):
            name = self.read_string(off + i * 64, 64)
            self.wave_bank_names.append(name)
        print(f"\n  WaveBanks ({len(self.wave_bank_names)}):")
        for i, wb in enumerate(self.wave_bank_names):
            print(f"    [{i}] {wb}")
    
    def parse_cue_names(self):
        """Read cue name table (null-separated strings)"""
        off = self.cue_names_offset
        raw = self.data[off:off + self.cue_name_table_len]
        names = raw.decode('ascii', errors='replace').split('\x00')
        self.cue_names = [n for n in names if n]
        print(f"\n  Cue names ({len(self.cue_names)}):")
        for i, cn in enumerate(self.cue_names):
            print(f"    [{i}] {cn}")
    
    def parse_xact_sound(self, sound_offset):
        """
        Parse an XactSound at the given offset.
        Returns list of (wave_bank_index, track_index) tuples.
        
        Based on MonoGame XactSound.cs:
        - flags (1 byte): bit0=complex, bits1-3=hasRPCs, bit4=hasEffects
        - categoryID (2 bytes)
        - volume (1 byte)
        - pitch (2 bytes, signed)
        - priority (1 byte)
        - filter (2 bytes)
        - if complex: numClips (1 byte)
        - if simple: trackIndex (2 bytes) + waveBankIndex (1 byte)
        
        CRITICAL: MonoGame reads RPC/Effects BEFORE clips:
          numClips → skipRPC → skipEffects → readClips
        """
        d = self.data
        off = sound_offset
        flags = d[off]
        is_complex = (flags & 0x01) != 0
        has_rpcs = (flags & 0x0E) != 0
        has_effects = (flags & 0x10) != 0
        off += 1
        
        category_id = self.u16(off); off += 2
        volume = d[off]; off += 1
        pitch = self.i16(off); off += 2
        priority = d[off]; off += 1
        filter_val = self.u16(off); off += 2
        
        results = []
        num_clips = 0
        
        if not is_complex:
            # Simple sound: trackIndex + waveBankIndex
            track_index = self.u16(off); off += 2
            wave_bank_index = d[off]; off += 1
            results.append((wave_bank_index, track_index))
        else:
            # Complex sound: read numClips (BEFORE RPC/Effects skip per MonoGame)
            num_clips = d[off]; off += 1
        
        # Skip RPC data (MonoGame: save current, read 2-byte length, seek to current+length)
        if has_rpcs:
            current = off
            data_len = self.u16(off)
            off = current + data_len
        
        # Skip effects data
        if has_effects:
            current = off
            data_len = self.u16(off)
            off = current + data_len
        
        # Read clips AFTER RPC/Effects skip (MonoGame order)
        if is_complex:
            for c in range(num_clips):
                clip_waves = self.parse_xact_clip(off)
                results.extend(clip_waves)
                off = self._skip_clip(off)
        
        return results
    
    def _skip_clip(self, off):
        """
        Skip past an XactClip in the sound data stream.
        XactClip inline: volumeDb(1) + clipOffset(4) + unkn(4) = 9 bytes
        But the clip data itself is at clipOffset, not inline.
        So inline size is always 9 bytes.
        """
        return off + 9
    
    def parse_xact_clip(self, clip_inline_off):
        """
        Parse an XactClip. The inline data is:
        - volumeDb (1 byte)
        - clipOffset (4 bytes) - absolute offset in file to clip data
        - unkn (4 bytes)
        
        At clipOffset:
        - numEvents (1 byte)
        - For each event: eventInfo (4 bytes) + randomOffset (2 bytes) + event-type-specific data
        """
        d = self.data
        off = clip_inline_off
        volume_db = d[off]; off += 1
        clip_offset = self.u32(off); off += 4
        unkn = self.u32(off); off += 4
        
        if clip_offset >= len(d):
            return []
        
        # Read events at clip_offset
        ev_off = clip_offset
        num_events = d[ev_off]; ev_off += 1
        
        wave_refs = []
        for e in range(num_events):
            event_info = self.u32(ev_off); ev_off += 4
            random_offset = self.u16(ev_off); ev_off += 2
            
            event_id = event_info & 0x1F
            
            if event_id == 1:
                # PLAY event (single wave)
                ev_off += 1  # unknown
                event_flags = d[ev_off]; ev_off += 1
                track_index = self.u16(ev_off); ev_off += 2
                wave_bank_index = d[ev_off]; ev_off += 1
                loop_count = d[ev_off]; ev_off += 1
                pan_angle = self.u16(ev_off); ev_off += 2
                pan_arc = self.u16(ev_off); ev_off += 2
                wave_refs.append((wave_bank_index, track_index))
                
            elif event_id == 3:
                # PLAY with variations
                ev_off += 1  # unknown
                event_flags = d[ev_off]; ev_off += 1
                loop_count = d[ev_off]; ev_off += 1
                pan_angle = self.u16(ev_off); ev_off += 2
                pan_arc = self.u16(ev_off); ev_off += 2
                num_tracks = self.u16(ev_off); ev_off += 2
                more_flags = d[ev_off]; ev_off += 1
                ev_off += 5  # unknown 5 bytes
                for t in range(num_tracks):
                    track_index = self.u16(ev_off); ev_off += 2
                    wave_bank_index = d[ev_off]; ev_off += 1
                    weight_min = d[ev_off]; ev_off += 1
                    weight_max = d[ev_off]; ev_off += 1
                    wave_refs.append((wave_bank_index, track_index))
                    
            elif event_id == 4:
                # PLAY with pitch/volume variation (single wave)
                # SC v41: NO filter float fields → 17-byte body
                ev_off += 1  # unknown
                event_flags = d[ev_off]; ev_off += 1
                track_index = self.u16(ev_off); ev_off += 2
                wave_bank_index = d[ev_off]; ev_off += 1
                loop_count = d[ev_off]; ev_off += 1
                pan_angle = self.u16(ev_off); ev_off += 2
                pan_arc = self.u16(ev_off); ev_off += 2
                min_pitch = self.i16(ev_off); ev_off += 2
                max_pitch = self.i16(ev_off); ev_off += 2
                min_volume = d[ev_off]; ev_off += 1
                max_volume = d[ev_off]; ev_off += 1
                # NO filter floats (minFreq/maxFreq/minQ/maxQ) in SC v41
                ev_off += 1  # unknown
                wave_refs.append((wave_bank_index, track_index))
                
            elif event_id == 6:
                # PLAY with all variations (multiple waves)
                # SC v41: NO filter float fields, NO variationFlags byte
                # → 22-byte header (verified via diag_v41_correct_layout.py)
                # Layout:
                # 00(1): unknown, 01(1): flags, 02(1): loopCount,
                # 03(2): panAngle, 05(2): panArc,
                # 07(2): minPitch, 09(2): maxPitch,
                # 0B(1): minVolume, 0C(1): maxVolume,
                # 0D(1): unknown, 0E(2): numTracks, 10(1): moreFlags, 11(5): unknown
                ev_off += 1  # unknown
                event_flags = d[ev_off]; ev_off += 1
                loop_count = d[ev_off]; ev_off += 1
                pan_angle = self.u16(ev_off); ev_off += 2
                pan_arc = self.u16(ev_off); ev_off += 2
                min_pitch = self.i16(ev_off); ev_off += 2
                max_pitch = self.i16(ev_off); ev_off += 2
                min_volume = d[ev_off]; ev_off += 1
                max_volume = d[ev_off]; ev_off += 1
                ev_off += 1  # unknown
                # NO filter floats, NO variationFlags in SC v41
                num_tracks = self.u16(ev_off); ev_off += 2
                more_flags = d[ev_off]; ev_off += 1
                ev_off += 5  # unknown 5 bytes
                for t in range(num_tracks):
                    track_index = self.u16(ev_off); ev_off += 2
                    wave_bank_index = d[ev_off]; ev_off += 1
                    weight_min = d[ev_off]; ev_off += 1
                    weight_max = d[ev_off]; ev_off += 1
                    wave_refs.append((wave_bank_index, track_index))
                    
            elif event_id == 8:
                # Volume event
                ev_off += 2  # unknown
                event_flags = d[ev_off]; ev_off += 1
                decibels = self.f32(ev_off); ev_off += 4
                ev_off += 9  # unknown
                
            elif event_id == 0:
                # Stop event - no additional data?
                pass
                
            else:
                print(f"    WARNING: Unknown event ID {event_id} at 0x{ev_off:X}")
                break
        
        return wave_refs
    
    def parse_simple_cues(self):
        """Parse simple cues: 1 byte flags + 4 bytes soundOffset"""
        off = self.simple_cues_offset
        for i in range(self.num_simple_cues):
            flags = self.u8(off)
            sound_offset = self.u32(off + 1)
            off += 5
            
            cue_name = self.cue_names[i] if i < len(self.cue_names) else f"<simple_{i}>"
            wave_refs = self.parse_xact_sound(sound_offset)
            
            self.cue_mappings.append({
                'cue_index': i,
                'cue_name': cue_name,
                'type': 'simple',
                'sound_offset': sound_offset,
                'wave_refs': wave_refs,
                'wave_bank_names': [self.wave_bank_names[wb] if wb < len(self.wave_bank_names) else f'<wb{wb}>' 
                                   for wb, _ in wave_refs]
            })
    
    def parse_complex_cues(self):
        """Parse complex cues"""
        off = self.complex_cues_offset
        for i in range(self.num_complex_cues):
            cue_idx = self.num_simple_cues + i
            cue_name = self.cue_names[cue_idx] if cue_idx < len(self.cue_names) else f'<complex_{i}>'
            
            flags = self.u8(off); off += 1
            
            if (flags & 0x04) != 0:
                # Sound reference: soundOffset(4) + unkn(4)
                sound_offset = self.u32(off); off += 4
                unkn = self.u32(off); off += 4
                wave_refs = self.parse_xact_sound(sound_offset)
                
                self.cue_mappings.append({
                    'cue_index': cue_idx,
                    'cue_name': cue_name,
                    'type': 'complex_soundref',
                    'sound_offset': sound_offset,
                    'wave_refs': wave_refs,
                    'wave_bank_names': [self.wave_bank_names[wb] if wb < len(self.wave_bank_names) else f'<wb{wb}>' 
                                       for wb, _ in wave_refs]
                })
            else:
                # Variation table: varTableOffset(4) + transitionTableOffset(4)
                var_table_offset = self.u32(off); off += 4
                trans_table_offset = self.u32(off); off += 4
                
                wave_refs = self.parse_variation_table(var_table_offset)
                
                self.cue_mappings.append({
                    'cue_index': cue_idx,
                    'cue_name': cue_name,
                    'type': 'complex_variation',
                    'var_table_offset': var_table_offset,
                    'wave_refs': wave_refs,
                    'wave_bank_names': [self.wave_bank_names[wb] if wb < len(self.wave_bank_names) else f'<wb{wb}>' 
                                       for wb, _ in wave_refs]
                })
            
            # Instance limiting (6 bytes) - always present for complex cues
            inst_limit = self.u8(off); off += 1
            fade_in = self.u16(off); off += 2
            fade_out = self.u16(off); off += 2
            inst_flags = self.u8(off); off += 1
    
    def parse_variation_table(self, var_table_offset):
        """Parse a variation table"""
        off = var_table_offset
        num_entries = self.u16(off); off += 2
        variation_flags = self.u16(off); off += 2
        off += 1  # unknown byte
        off += 2  # unknown u16
        off += 1  # unknown byte
        
        table_type = (variation_flags >> 3) & 0x7
        
        wave_refs = []
        for j in range(num_entries):
            if table_type == 0:  # Wave
                track_index = self.u16(off); off += 2
                wave_bank_index = self.u8(off); off += 1
                weight_min = self.u8(off); off += 1
                weight_max = self.u8(off); off += 1
                wave_refs.append((wave_bank_index, track_index))
            elif table_type == 1:  # Sound
                sound_offset = self.u32(off); off += 4
                weight_min = self.u8(off); off += 1
                weight_max = self.u8(off); off += 1
                refs = self.parse_xact_sound(sound_offset)
                wave_refs.extend(refs)
            elif table_type == 3:  # Sound float
                sound_offset = self.u32(off); off += 4
                weight_min = self.f32(off); off += 4
                weight_max = self.f32(off); off += 4
                var_flags = self.u32(off); off += 4
                refs = self.parse_xact_sound(sound_offset)
                wave_refs.extend(refs)
            elif table_type == 4:  # CompactWave
                track_index = self.u16(off); off += 2
                wave_bank_index = self.u8(off); off += 1
                wave_refs.append((wave_bank_index, track_index))
            else:
                print(f"    WARNING: Unknown variation table type {table_type}")
                break
        
        return wave_refs
    
    def parse(self):
        self.parse_header()
        self.parse_wave_bank_names()
        self.parse_cue_names()
        self.parse_simple_cues()
        self.parse_complex_cues()
        return self
    
    def print_mappings(self):
        print(f"\n=== {self.name} Cue → Wave Mapping ===")
        for m in self.cue_mappings:
            refs_str = ', '.join(f'{wbn}[{wi}]' for wbn, wi in 
                                 zip(m['wave_bank_names'], [r[1] for r in m['wave_refs']]))
            print(f"  [{m['cue_index']:3d}] {m['cue_name']:40s} → {refs_str}")
    
    def to_json(self):
        """Export mapping as JSON"""
        result = {
            'bank_name': self.name,
            'tool_version': self.tool_version,
            'format_version': self.format_version,
            'num_simple_cues': self.num_simple_cues,
            'num_complex_cues': self.num_complex_cues,
            'num_total_cues': self.num_total_cues,
            'num_wave_banks': self.num_wave_banks,
            'num_sounds': self.num_sounds,
            'wave_banks': self.wave_bank_names,
            'cue_mappings': []
        }
        for m in self.cue_mappings:
            entry = {
                'cue_index': m['cue_index'],
                'cue_name': m['cue_name'],
                'type': m['type'],
                'wave_refs': [
                    {
                        'wave_bank': m['wave_bank_names'][i] if i < len(m['wave_bank_names']) else f'<wb{wb}>',
                        'wave_bank_index': wb,
                        'wave_index': wi
                    }
                    for i, (wb, wi) in enumerate(m['wave_refs'])
                ]
            }
            result['cue_mappings'].append(entry)
        return result


if __name__ == '__main__':
    sounds_dir = r"I:\SteamLibrary\steamapps\common\Supreme Commander\sounds"
    
    # Parse FMV_BG (for verification)
    print("=" * 70)
    print("PARSING FMV_BG.xsb")
    print("=" * 70)
    fmv_parser = XSBv41Parser(os.path.join(sounds_dir, "FMV_BG.xsb"))
    fmv_parser.parse()
    fmv_parser.print_mappings()
    
    # Verify against ground truth
    print("\n=== GROUND TRUTH VERIFICATION (FMV_BG) ===")
    gt = {'GPG_introLogo_HD': 0, 'THQ_Logo': 1, 'NVIDIA': 2}
    for m in fmv_parser.cue_mappings:
        if m['cue_name'] in gt:
            wave_idx = m['wave_refs'][0][1]
            expected = gt[m['cue_name']]
            status = "OK" if wave_idx == expected else "FAIL"
            print(f"  [{status}] {m['cue_name']}: wave_idx={wave_idx}, expected={expected}")
    
    # Save FMV_BG mapping
    fmv_json = fmv_parser.to_json()
    with open(os.path.join(os.path.dirname(__file__), 'fmv_bg_mapping_correct.json'), 'w', encoding='utf-8') as f:
        json.dump(fmv_json, f, indent=2, ensure_ascii=False)
    print(f"\n  Saved: fmv_bg_mapping_correct.json")
    
    # Parse Interface
    print("\n" + "=" * 70)
    print("PARSING Interface.xsb")
    print("=" * 70)
    iface_parser = XSBv41Parser(os.path.join(sounds_dir, "Interface.xsb"))
    iface_parser.parse()
    iface_parser.print_mappings()
    
    # Save Interface mapping
    iface_json = iface_parser.to_json()
    with open(os.path.join(os.path.dirname(__file__), 'interface_mapping_correct.json'), 'w', encoding='utf-8') as f:
        json.dump(iface_json, f, indent=2, ensure_ascii=False)
    print(f"\n  Saved: interface_mapping_correct.json")
    
    # Summary
    print("\n" + "=" * 70)
    print("SUMMARY")
    print("=" * 70)
    print(f"FMV_BG: {len(fmv_parser.cue_mappings)} cues, {fmv_parser.num_wave_banks} wave bank(s)")
    print(f"  WaveBanks: {fmv_parser.wave_bank_names}")
    print(f"Interface: {len(iface_parser.cue_mappings)} cues, {iface_parser.num_wave_banks} wave bank(s)")
    print(f"  WaveBanks: {iface_parser.wave_bank_names}")
