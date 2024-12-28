#!/usr/bin/env python3
import logging
import json
import struct
import math
from pathlib import Path
from PIL import Image
from .base_converter import BaseConverter

logger = logging.getLogger(__name__)

class ANIConverter(BaseConverter):
    """
    Converter for Volition's ANI animation files.
    
    Format (from FreeSpace source):
    - Header:
        Version 0 (original):
            - width (2 bytes)
            - height (2 bytes)
            - total_frames (2 bytes)
            - packer_code (1 byte)
            - palette (768 bytes)
            - num_keys (2 bytes)
            Default: 30fps, green transparency (0,255,0)
            
        Version 2+ (extended):
            - width (2 bytes): if 0, indicates extended header
            - version (2 bytes)
            - fps (2 bytes)
            - transparency color (3 bytes: RGB)
            - width (2 bytes)
            - height (2 bytes)
            - total_frames (2 bytes)
            - packer_code (1 byte)
            - palette (768 bytes)
            - num_keys (2 bytes)
    """
    
    @property
    def source_extension(self) -> str:
        """Extension of source files this converter handles"""
        return ".ani"
        
    @property
    def target_extension(self) -> str:
        """Extension of converted files this converter produces"""
        return ".png"
    
    # Constants
    DEFAULT_FPS = 30
    DEFAULT_TRANSPARENT = (0, 255, 0)  # Green
    TRANSPARENT_PIXEL = 254
    
    def _check_dimensions(self, width: int, height: int):
        """Debug check for power-of-2 dimensions"""
        if width <= 16:
            return
            
        # Find nearest power of 2
        floor_pow = math.floor(math.log2(height))
        floor_size = 2 ** floor_pow
        diff = height - floor_size
        
        if diff != 0:
            waste = (diff / height) * 100
            logger.debug(f"Non-optimal ANI dimensions: {width}x{height} ({waste:.1f}% wasted)")
    
    def _read_header(self, data: bytes) -> tuple:
        """Parse ANI header data"""
        # Check for extended header by reading initial width
        width = struct.unpack("<H", data[:2])[0]
        
        if width == 0:
            # Extended header (version 2+)
            version = struct.unpack("<H", data[2:4])[0]
            fps = struct.unpack("<H", data[4:6])[0]
            
            # Custom transparency color
            transp_r, transp_g, transp_b = struct.unpack("BBB", data[6:9])
            
            # Rest of header
            width, height, total_frames = struct.unpack("<HHH", data[9:15])
            packer_code = data[15]
            offset = 16
            
        else:
            # Original header (version 0)
            version = 0
            fps = self.DEFAULT_FPS
            transp_r, transp_g, transp_b = self.DEFAULT_TRANSPARENT
            
            # Continue reading header (width already read)
            height = struct.unpack("<H", data[2:4])[0]
            total_frames = struct.unpack("<H", data[4:6])[0]
            packer_code = data[6]
            offset = 7
            
        # Read palette (256 RGB colors = 768 bytes)
        palette_data = data[offset:offset+768]
        offset += 768
        
        # Number of keyframes
        num_keys = struct.unpack("<H", data[offset:offset+2])[0]
        offset += 2
        
        # Debug output
        logger.debug(
            f"ANI header: version={version}, fps={fps}, size={width}x{height}, "
            f"frames={total_frames}, keys={num_keys}, "
            f"transparency=({transp_r},{transp_g},{transp_b})"
        )
        
        # Debug check dimensions
        self._check_dimensions(width, height)
        
        return (version, fps, (transp_r, transp_g, transp_b), width, height, 
                total_frames, packer_code, palette_data, num_keys, offset)
    
    def _read_keyframes(self, data: bytes, offset: int, num_keys: int) -> tuple[list, int, int]:
        """
        Read keyframe definitions and endcount
        
        Returns:
            tuple[list, int, int]: List of keyframes, endcount value, and new offset
        """
        keyframes = []
        cur_offset = offset
        
        # Read keyframe definitions
        for i in range(num_keys):
            frame_num = struct.unpack("<H", data[cur_offset:cur_offset+2])[0]
            frame_offset = struct.unpack("<I", data[cur_offset+2:cur_offset+6])[0]
            keyframes.append((frame_num, frame_offset))
            cur_offset += 6
            
        # Read endcount (total compressed data size)
        endcount = struct.unpack("<I", data[cur_offset:cur_offset+4])[0]
        cur_offset += 4
        
        return keyframes, endcount, cur_offset
    
    def _decode_frame(self, data: bytes, offset: int, width: int, height: int, 
                     packer_code: int, frame_offset: int, prev_frame: bytes = None, 
                     is_keyframe: bool = False) -> tuple[bytes, int]:
        """
        Decode a single frame using RLE compression
        
        Args:
            data: ANI file data
            offset: Current offset in data
            width: Frame width
            height: Frame height
            packer_code: RLE marker byte
            prev_frame: Previous frame data for transparency
            is_keyframe: Whether this is a keyframe
            
        Returns:
            tuple[bytes, int]: Decoded frame data and new offset
        """
        # Use frame offset if provided
        cur_offset = frame_offset if frame_offset >= 0 else offset
        
        # Read frame flag byte
        flag_byte = data[cur_offset]
        cur_offset += 1
        
        # Calculate padded width (4-byte aligned)
        padded_width = (width + 3) & ~3
        frame = bytearray(padded_width * height)
        
        if prev_frame is None or is_keyframe:
            prev_frame = bytes([0] * (padded_width * height))
            
        pos = 0
        runcount = 0
        last_value = 0
        
        # Process each row
        for y in range(height):
            x = 0
            while x < width:
                if runcount > 0:
                    runcount -= 1
                    value = last_value
                else:
                    value = data[cur_offset]
                    cur_offset += 1
                    if value == packer_code:
                        runcount = data[cur_offset]
                        cur_offset += 1
                        if runcount < 2:
                            value = packer_code
                            runcount = 0
                        else:
                            value = data[cur_offset]
                            cur_offset += 1
                            last_value = value
                
                # Handle transparent pixels
                if value == self.TRANSPARENT_PIXEL and not is_keyframe:
                    frame[pos] = prev_frame[pos]
                else:
                    frame[pos] = value
                pos += 1
                x += 1
            
            # Move to next row with padding
            pos += padded_width - width
            
        return bytes(frame), cur_offset
    
    def _extract_frames(self, ani_data: bytes) -> tuple[list[Image.Image], float]:
        """Extract all frames from ANI data"""
        # Parse header
        (version, fps, transp_color, width, height, total_frames, packer_code,
         palette_data, num_keys, offset) = self._read_header(ani_data)
        
        # Read keyframe definitions and endcount
        keyframes, endcount, frame_data_start = self._read_keyframes(ani_data, offset, num_keys)
        
        # Map frame numbers to their data offsets
        keyframe_indices = {
            frame_num: frame_data_start + frame_offset 
            for frame_num, frame_offset in keyframes
        }
        
        # Start of frame data
        offset = frame_data_start
        
        # Check if all frames are keyframes
        all_keyframes = (total_frames == num_keys)
        
        # Create palette image
        palette_img = Image.new('P', (1, 1))
        palette_img.putpalette(palette_data)
        
        # Process frames
        frames = []
        prev_frame = None
        
        for i in range(total_frames):
            # Get frame offset if it's a keyframe
            frame_offset = keyframe_indices.get(i, None)
            if frame_offset is not None:
                # Keyframe - seek directly to frame data
                is_keyframe = True
                frame_data, next_offset = self._decode_frame(
                    ani_data, frame_offset, width, height, packer_code, 
                    -1, None, True  # Force new frame for keyframes
                )
            else:
                # Regular frame - use previous frame data
                is_keyframe = False
                frame_data, next_offset = self._decode_frame(
                    ani_data, offset, width, height, packer_code, 
                    -1, prev_frame, False
                )
            
            # Update offset for next frame
            offset = next_offset
            
            # Create frame image
            padded_width = (width + 3) & ~3
            frame = Image.frombytes('P', (padded_width, height), frame_data)
            
            # Set up palette with transparency color as index 0
            palette = bytearray(palette_data)
            palette[0:3] = [transp_color[0], transp_color[1], transp_color[2]]
            frame.putpalette(palette)
            
            # Crop to actual width
            if padded_width != width:
                frame = frame.crop((0, 0, width, height))
            
            # Convert to RGBA, making transparent pixels fully transparent
            frame = frame.convert('RGBA')
            pixel_data = frame.load()
            for y in range(height):
                for x in range(width):
                    r, g, b, a = pixel_data[x, y]
                    if (r, g, b) == transp_color:
                        pixel_data[x, y] = (r, g, b, 0)  # Make fully transparent
            
            frames.append(frame)
            prev_frame = frame_data
            
        return frames, 1.0 / fps if fps > 0 else 1.0 / self.DEFAULT_FPS
    
    def _create_spritesheet(self, frames: list[Image.Image], output_path: Path) -> tuple[int, int]:
        """Create spritesheet from frames"""
        if not frames:
            raise ValueError("No frames found")
            
        frame_width, frame_height = frames[0].size
        num_frames = len(frames)
        num_cols = min(num_frames, 8)  # Max 8 frames per row
        num_rows = (num_frames + num_cols - 1) // num_cols
        
        # Create spritesheet
        sheet_width = frame_width * num_cols
        sheet_height = frame_height * num_rows
        spritesheet = Image.new('RGBA', (sheet_width, sheet_height))
        
        # Add frames
        for i, frame in enumerate(frames):
            x = (i % num_cols) * frame_width
            y = (i // num_cols) * frame_height
            spritesheet.paste(frame, (x, y))
                
        spritesheet.save(output_path, 'PNG')
        return num_cols, num_rows
    
    def convert_file(self, input_path: Path, output_path: Path) -> bool:
        """Convert ANI file to spritesheet and animation data"""
        try:
            # Read ANI file
            with open(input_path, 'rb') as f:
                ani_data = f.read()
                
            # Extract frames
            frames, frame_delay = self._extract_frames(ani_data)
            
            if not frames:
                logger.error(f"No frames extracted from {input_path}")
                return False
                
            # Create spritesheet
            num_cols, num_rows = self._create_spritesheet(frames, output_path)
            
            # Save animation data
            animation_data = {
                "frames": len(frames),
                "columns": num_cols,
                "rows": num_rows,
                "frame_delay": frame_delay
            }
            
            json_path = output_path.with_suffix('.json')
            with open(json_path, 'w') as f:
                json.dump(animation_data, f, indent=2)
                
            return True
            
        except Exception as e:
            logger.error(f"Failed to convert {input_path}: {e}")
            return False
