#!/usr/bin/env python3
import logging
import math
import re
import tempfile
from pathlib import Path
from PIL import Image
from .base_converter import BaseConverter

try:
    from wand.image import Image as WandImage
except ImportError:
    WandImage = None

logger = logging.getLogger(__name__)

class DDSConverter(BaseConverter):
    """Converter for DDS texture files with special handling for animation sequences"""
    
    @property
    def source_extension(self) -> str:
        return ".dds"
        
    @property
    def target_extension(self) -> str:
        return ".png"  # Default extension for single files
        
    def _is_sequence_file(self, path: Path) -> bool:
        """Check if file is part of a numbered sequence"""
        return bool(re.search(r'_\d{4}\.dds$', str(path), re.IGNORECASE))
        
    def _get_sequence_base(self, path: Path) -> str:
        """Get the base name for a sequence file"""
        return re.sub(r'_\d{4}\.dds$', '', str(path), flags=re.IGNORECASE)
        
    def _get_sequence_number(self, path: Path) -> int:
        """Extract sequence number from filename"""
        match = re.search(r'_(\d{4})\.dds$', str(path), re.IGNORECASE)
        return int(match.group(1)) if match else -1
        
    def convert_to_png(self, input_path: Path, output_path: Path) -> bool:
        """Convert DDS file to PNG using either Wand or Pillow"""
        try:
            if WandImage is not None:
                with WandImage(filename=str(input_path)) as img:
                    img.format = 'png'
                    img.save(filename=str(output_path))
                return True
                
            with Image.open(input_path) as img:
                if img.mode != 'RGBA':
                    img = img.convert('RGBA')
                img.save(output_path, 'PNG')
            return True
            
        except Exception as e:
            logger.error(f"Failed to convert {input_path} to PNG: {e}")
            return False
            
    def _read_eff_fps(self, base_path: str) -> int:
        """Read FPS value from associated .eff file"""
        try:
            eff_path = Path(base_path + '.eff')
            if not eff_path.exists():
                logger.warning(f"No .eff file found at {eff_path}, using default 30fps")
                return 30
                
            with open(eff_path, 'r') as f:
                for line in f:
                    if line.startswith('$FPS:'):
                        return int(line.split(':')[1].strip())
            
            logger.warning(f"No FPS value found in {eff_path}, using default 30fps")
            return 30
            
        except Exception as e:
            logger.error(f"Error reading .eff file {eff_path}: {e}")
            return 30
    
    def _calculate_grid_dimensions(self, frame_count: int) -> tuple[int, int]:
        """Calculate optimal grid dimensions for the spritesheet"""
        # Get the number of rows/columns that would create a roughly square grid
        grid_size = math.ceil(math.sqrt(frame_count))
        rows = grid_size
        cols = grid_size
        
        # If the last row would be very empty, reduce the number of rows
        if frame_count <= (grid_size * (grid_size - 1)):
            rows = grid_size - 1
            cols = math.ceil(frame_count / rows)
            
        return rows, cols
    
    def convert_sequence_to_spritesheet(self, sequence_files: list[Path], output_path: Path) -> bool:
        """Convert a sequence of DDS files to a grid-based spritesheet PNG"""
        try:
            # Create temporary directory for PNG frames
            with tempfile.TemporaryDirectory() as temp_dir:
                temp_dir_path = Path(temp_dir)
                frames = []
                
                # Convert each DDS to PNG first
                for i, dds_file in enumerate(sequence_files):
                    temp_png = temp_dir_path / f"frame_{i:04d}.png"
                    if not self.convert_to_png(dds_file, temp_png):
                        return False
                    
                    # Load the converted PNG
                    with Image.open(temp_png) as img:
                        frames.append(img.copy())
                
                if not frames:
                    logger.error("No frames were converted")
                    return False
                
                # Get dimensions for the spritesheet
                frame_width = frames[0].width
                frame_height = frames[0].height
                rows, cols = self._calculate_grid_dimensions(len(frames))
                
                # Create the spritesheet
                spritesheet = Image.new('RGBA', (cols * frame_width, rows * frame_height))
                
                # Paste each frame into the grid
                for idx, frame in enumerate(frames):
                    row = idx // cols
                    col = idx % cols
                    x = col * frame_width
                    y = row * frame_height
                    spritesheet.paste(frame, (x, y))
                
                # Save the spritesheet
                output_path = output_path.with_suffix('.png')
                spritesheet.save(output_path, 'PNG')
                
                # Write metadata file with frame info
                meta_path = output_path.with_suffix('.meta')
                with open(meta_path, 'w') as f:
                    meta = {
                        'frame_count': len(frames),
                        'frame_width': frame_width,
                        'frame_height': frame_height,
                        'grid_rows': rows,
                        'grid_cols': cols,
                        'fps': self._read_eff_fps(self._get_sequence_base(sequence_files[0]))
                    }
                    f.write(str(meta))
                
                return True
                
        except Exception as e:
            logger.error(f"Failed to convert sequence to spritesheet: {e}")
            return False
            
    def convert_file(self, input_path: Path, output_path: Path) -> bool:
        """Convert a single DDS file to PNG"""
        # Don't convert if this is part of a sequence
        if self._is_sequence_file(input_path):
            logger.info(f"Skipping {input_path} (part of a sequence)")
            return True
        return self.convert_to_png(input_path, output_path)
        
    def convert_all(self) -> bool:
        """
        Convert all DDS files, handling sequences appropriately
        """
        success = True
        processed_files = set()
        
        # First pass: identify and group sequences
        sequences = {}
        single_files = []
        sequence_files = set()  # Track all files that are part of sequences
        
        for input_path in self.input_dir.rglob(f"*{self.source_extension}"):
            if self._is_sequence_file(input_path):
                base_name = self._get_sequence_base(input_path)
                if base_name not in sequences:
                    sequences[base_name] = []
                sequences[base_name].append(input_path)
                sequence_files.add(input_path)  # Track this file as part of a sequence
            else:
                single_files.append(input_path)
        
        # Process sequences
        for base_name, seq_files in sequences.items():
            if len(seq_files) < 2:  # If only one file in sequence, treat as single
                single_files.extend(seq_files)
                continue
                
            # Sort files by sequence number
            seq_files.sort(key=self._get_sequence_number)
            
            # Get output path using base name without sequence number
            first_file = seq_files[0]
            base_name = self._get_sequence_base(first_file)
            # Create path object with base name
            base_path = Path(base_name).with_suffix(self.target_extension)
            output_path = self.get_output_path(base_path)
            
            # Skip if output exists and not forcing
            if output_path.exists() and not self.force:
                logger.info(f"Skipping sequence {base_name} (output exists)")
                continue
            
            try:
                if self.convert_sequence_to_spritesheet(seq_files, output_path):
                    logger.info(f"Converted sequence {base_name} to spritesheet")
                    processed_files.update(seq_files)
                else:
                    logger.error(f"Failed to convert sequence {base_name}")
                    success = False
            except Exception as e:
                logger.error(f"Error converting sequence {base_name}: {e}")
                success = False
        
        # Process single files (skip if they're part of a sequence)
        for input_path in single_files:
            if input_path in processed_files or input_path in sequence_files:
                continue
                
            output_path = self.get_output_path(input_path)
            
            try:
                if output_path.exists() and not self.force:
                    logger.info(f"Skipping {input_path} (output exists)")
                    continue
                    
                if self.convert_file(input_path, output_path):
                    logger.info(f"Converted {input_path} -> {output_path}")
                else:
                    logger.error(f"Failed to convert {input_path}")
                    success = False
            except Exception as e:
                logger.error(f"Error converting {input_path}: {e}")
                success = False
                
        return success
