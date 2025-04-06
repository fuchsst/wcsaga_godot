#!/usr/bin/env python3
import logging
import json
import struct
import math
from pathlib import Path
from PIL import Image, ImagePalette
from typing import Optional, List, Tuple, Dict, Any
from .base_converter import BaseConverter

logger = logging.getLogger(__name__)

class ANIConverter(BaseConverter):
    """
    Converter for Volition's ANI animation files.
    Handles both standalone ANI files and sequences potentially
    associated with EFF files for metadata like FPS.
    Outputs a PNG spritesheet and a JSON metadata file.
    """

    def __init__(self, input_dir: str = "extracted", output_dir: str = "assets/animations", force: bool = False):
        # Override default input/output directories specifically for ANI/EFF
        super().__init__(input_dir, output_dir, force)
        self.logger = logging.getLogger(__name__)

    @property
    def source_extension(self) -> str:
        """Extension of source files this converter handles"""
        return ".ani"

    @property
    def target_extension(self) -> str:
        """Extension of converted files this converter produces (spritesheet)"""
        return ".png"

    # Constants from original analysis
    DEFAULT_FPS = 30
    DEFAULT_TRANSPARENT = (0, 255, 0)  # Green
    TRANSPARENT_PIXEL = 254 # Index often used for transparency in paletted images
    PACKER_CODE = 0xEE # Original RLE marker byte
    STD_RLE_CODE = 0x80 # Standard RLE marker byte
    PACKING_METHOD_RLE = 0
    PACKING_METHOD_RLE_KEY = 1
    PACKING_METHOD_STD_RLE = 2
    PACKING_METHOD_STD_RLE_KEY = 3

    def _check_dimensions(self, width: int, height: int, filename: str):
        """Debug check for power-of-2 dimensions"""
        if width <= 16: # Ignore small animations
            return

        # Find nearest power of 2 for height
        if height > 0 and (height & (height - 1) != 0): # Check if not power of 2
             floor_pow = math.floor(math.log2(height))
             floor_size = 2 ** floor_pow
             diff = height - floor_size
             # waste = (diff / height) * 100 # Calculation seems off, focus on logging non-optimal size
             self.logger.debug(f"Non-optimal ANI height in {filename}: {width}x{height}")


    def _read_header(self, data: bytes, filename: str) -> tuple:
        """Parse ANI header data"""
        offset = 0
        width = struct.unpack("<H", data[offset:offset+2])[0]; offset += 2

        if width == 0:
            # Extended header (version 2+)
            version = struct.unpack("<H", data[offset:offset+2])[0]; offset += 2
            fps = struct.unpack("<H", data[offset:offset+2])[0]; offset += 2
            transp_r, transp_g, transp_b = struct.unpack("BBB", data[offset:offset+3]); offset += 3
            width, height, total_frames = struct.unpack("<HHH", data[offset:offset+6]); offset += 6
            packer_code = data[offset]; offset += 1
        else:
            # Original header (version 0)
            version = 0
            fps = self.DEFAULT_FPS
            transp_r, transp_g, transp_b = self.DEFAULT_TRANSPARENT
            height = struct.unpack("<H", data[offset:offset+2])[0]; offset += 2
            total_frames = struct.unpack("<H", data[offset:offset+2])[0]; offset += 2
            packer_code = data[offset]; offset += 1

        # Read palette (256 RGB colors = 768 bytes)
        palette_data = data[offset:offset+768]; offset += 768
        num_keys = struct.unpack("<H", data[offset:offset+2])[0]; offset += 2

        self.logger.debug(
            f"ANI header for {filename}: version={version}, fps={fps}, size={width}x{height}, "
            f"frames={total_frames}, keys={num_keys}, packer=0x{packer_code:X}, "
            f"transparency=({transp_r},{transp_g},{transp_b})"
        )
        self._check_dimensions(width, height, filename)

        return (version, fps, (transp_r, transp_g, transp_b), width, height,
                total_frames, packer_code, palette_data, num_keys, offset)

    def _read_keyframes(self, data: bytes, offset: int, num_keys: int) -> tuple[list, int, int]:
        """Read keyframe definitions and endcount"""
        keyframes = []
        cur_offset = offset
        for _ in range(num_keys):
            frame_num = struct.unpack("<H", data[cur_offset:cur_offset+2])[0]
            frame_offset = struct.unpack("<I", data[cur_offset+2:cur_offset+6])[0]
            keyframes.append({'frame_num': frame_num, 'offset': frame_offset})
            cur_offset += 6
        endcount = struct.unpack("<I", data[cur_offset:cur_offset+4])[0]; cur_offset += 4
        return keyframes, endcount, cur_offset

    def _decode_frame(self, data: bytes, offset: int, width: int, height: int,
                      packer_code_header: int, prev_frame_data: Optional[bytes] = None,
                      is_keyframe: bool = False) -> tuple[bytes, int]:
        """Decode a single frame using RLE or STD_RLE compression"""
        frame_data = bytearray(width * height)
        current_offset = offset
        packing_method = data[current_offset]; current_offset += 1
        dest_pos = 0
        total_size = width * height

        # Determine the actual packer code to use based on the method byte
        packer_code_to_use = self.PACKER_CODE if packing_method in [self.PACKING_METHOD_RLE, self.PACKING_METHOD_RLE_KEY] else self.STD_RLE_CODE

        try:
            if packing_method == self.PACKING_METHOD_RLE_KEY or packing_method == self.PACKING_METHOD_RLE:
                while dest_pos < total_size:
                    value = data[current_offset]; current_offset += 1
                    if value != packer_code_to_use:
                        if not is_keyframe and value == self.TRANSPARENT_PIXEL and prev_frame_data:
                            frame_data[dest_pos] = prev_frame_data[dest_pos]
                        else:
                            frame_data[dest_pos] = value
                        dest_pos += 1
                    else:
                        run_count = data[current_offset]; current_offset += 1
                        if run_count < 2: # Packer code itself
                            value = packer_code_to_use
                            run_count = 1 # Treat as a single literal packer code
                        else:
                            value = data[current_offset]; current_offset += 1
                            run_count += 1 # Adjust count as per original logic

                        if dest_pos + run_count > total_size:
                            self.logger.warning(f"RLE run exceeds frame boundary (pos={dest_pos}, run={run_count}, size={total_size}), truncating.")
                            run_count = total_size - dest_pos

                        if not is_keyframe and value == self.TRANSPARENT_PIXEL and prev_frame_data:
                            frame_data[dest_pos : dest_pos + run_count] = prev_frame_data[dest_pos : dest_pos + run_count]
                        else:
                            frame_data[dest_pos : dest_pos + run_count] = bytes([value] * run_count)
                        dest_pos += run_count

            elif packing_method == self.PACKING_METHOD_STD_RLE_KEY or packing_method == self.PACKING_METHOD_STD_RLE:
                 while dest_pos < total_size:
                    value = data[current_offset]; current_offset += 1
                    if not (value & self.STD_RLE_CODE): # Literal pixel
                        if not is_keyframe and value == self.TRANSPARENT_PIXEL and prev_frame_data:
                             frame_data[dest_pos] = prev_frame_data[dest_pos]
                        else:
                             frame_data[dest_pos] = value
                        dest_pos += 1
                    else: # Run
                        run_count = value & (~self.STD_RLE_CODE)
                        value = data[current_offset]; current_offset += 1
                        if dest_pos + run_count > total_size:
                            self.logger.warning(f"STD RLE run exceeds frame boundary (pos={dest_pos}, run={run_count}, size={total_size}), truncating.")
                            run_count = total_size - dest_pos
                        if not is_keyframe and value == self.TRANSPARENT_PIXEL and prev_frame_data:
                            frame_data[dest_pos : dest_pos + run_count] = prev_frame_data[dest_pos : dest_pos + run_count]
                        else:
                            frame_data[dest_pos : dest_pos + run_count] = bytes([value] * run_count)
                        dest_pos += run_count
            else:
                self.logger.error(f"Unsupported packing method {packing_method} at offset {current_offset-1}")
                return bytes(frame_data), current_offset # Return what we have, likely corrupted

        except IndexError:
            self.logger.error(f"IndexError during frame decoding at offset {current_offset}. Frame data might be incomplete or corrupt.")
            # Fill remaining with transparency or previous frame data if possible
            if prev_frame_data and not is_keyframe:
                 remaining = total_size - dest_pos
                 if remaining > 0:
                     frame_data[dest_pos:] = prev_frame_data[dest_pos:]
            # No easy way to determine the 'next' offset after corruption

        return bytes(frame_data), current_offset


    def _extract_frames(self, ani_data: bytes, filename: str) -> tuple[list[Image.Image], float]:
        """Extract all frames from ANI data"""
        (version, fps, transp_color, width, height, total_frames, packer_code_header,
         palette_data, num_keys, header_offset) = self._read_header(ani_data, filename)

        keyframes, endcount, frame_data_start = self._read_keyframes(ani_data, header_offset, num_keys)

        keyframe_offsets = {kf['frame_num']: frame_data_start + kf['offset'] for kf in keyframes}

        frames = []
        prev_frame_data = None
        current_offset = frame_data_start # Start reading from the first frame data

        # Create Pillow palette
        pil_palette = ImagePalette.ImagePalette("RGB", palette_data)

        # Find the index of the transparent color
        transp_index = -1
        for idx in range(256):
            r, g, b = pil_palette.palette[idx*3 : idx*3+3]
            if (r, g, b) == transp_color:
                transp_index = idx
                break
        if transp_index == -1:
             self.logger.warning(f"Transparency color {transp_color} not found in palette for {filename}. Using index 0.")
             transp_index = 0 # Fallback

        for i in range(total_frames):
            is_keyframe = i in keyframe_offsets
            frame_offset = keyframe_offsets.get(i, -1)

            if is_keyframe:
                 current_offset = frame_offset # Jump to keyframe data start

            # Decode the frame
            decoded_frame_data, next_offset = self._decode_frame(
                ani_data, current_offset, width, height, packer_code_header,
                prev_frame_data, is_keyframe
            )

            # Update offset for the next frame read
            current_offset = next_offset

            # Create Pillow Image from raw palette indices
            frame_img = Image.frombytes('P', (width, height), decoded_frame_data)
            frame_img.putpalette(pil_palette)

            # Convert to RGBA and handle transparency using the found index
            frame_img = frame_img.convert('RGBA')
            pixel_data = frame_img.load()
            for y in range(height):
                for x in range(width):
                    # Check the original palette index for transparency
                    if decoded_frame_data[y * width + x] == transp_index:
                        r, g, b, a = pixel_data[x, y]
                        pixel_data[x, y] = (r, g, b, 0) # Set alpha to 0

            frames.append(frame_img)
            prev_frame_data = decoded_frame_data # Store raw data for next delta frame

        frame_delay = 1.0 / fps if fps > 0 else 1.0 / self.DEFAULT_FPS
        return frames, frame_delay

    def _create_spritesheet(self, frames: list[Image.Image], output_path: Path) -> tuple[int, int]:
        """Create spritesheet from frames"""
        if not frames:
            raise ValueError("No frames provided for spritesheet creation")

        frame_width, frame_height = frames[0].size
        num_frames = len(frames)

        # Calculate grid size (prefer wider than tall, up to a reasonable limit like 16 cols)
        max_cols = 16
        num_cols = min(num_frames, max_cols)
        num_rows = math.ceil(num_frames / num_cols)

        sheet_width = frame_width * num_cols
        sheet_height = frame_height * num_rows
        spritesheet = Image.new('RGBA', (sheet_width, sheet_height), (0,0,0,0)) # Transparent background

        for i, frame in enumerate(frames):
            col = i % num_cols
            row = i // num_cols
            x = col * frame_width
            y = row * frame_height
            spritesheet.paste(frame, (x, y), frame) # Use frame as mask for transparency

        spritesheet.save(output_path, 'PNG')
        return num_cols, num_rows

    def convert_file(self, input_path: Path, output_path: Path) -> bool:
        """Convert ANI file to spritesheet PNG and JSON metadata"""
        try:
            self.logger.info(f"Converting {input_path}...")
            with open(input_path, 'rb') as f:
                ani_data = f.read()

            frames, frame_delay = self._extract_frames(ani_data, input_path.name)

            if not frames:
                self.logger.error(f"No frames extracted from {input_path}")
                return False

            # Output path for PNG spritesheet
            png_output_path = output_path.with_suffix(self.target_extension)
            num_cols, num_rows = self._create_spritesheet(frames, png_output_path)

            # Output path for JSON metadata
            json_output_path = output_path.with_suffix('.json')
            metadata = {
                "frames": len(frames),
                "columns": num_cols,
                "rows": num_rows,
                "frame_width": frames[0].width,
                "frame_height": frames[0].height,
                "frame_delay": frame_delay,
                "loops": True # Default assumption, EFF might override
            }

            # Check for associated EFF file for potential overrides (like FPS)
            eff_path = input_path.with_suffix('.eff')
            if eff_path.exists():
                # Placeholder: Parse EFF for FPS or other metadata
                # eff_fps = self._parse_eff_fps(eff_path)
                # if eff_fps: metadata['frame_delay'] = 1.0 / eff_fps
                self.logger.info(f"Found associated EFF file: {eff_path} (Parsing not yet implemented)")
                pass # Add EFF parsing logic here if needed

            with open(json_output_path, 'w') as f:
                json.dump(metadata, f, indent=2)

            self.logger.info(f"Successfully converted {input_path} to {png_output_path} and {json_output_path}")
            return True

        except Exception as e:
            self.logger.error(f"Failed to convert {input_path}: {e}", exc_info=True)
            return False
