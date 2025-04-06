#!/usr/bin/env python3
import logging
import math
import re
import tempfile
import json
from pathlib import Path
from PIL import Image, UnidentifiedImageError
from .base_converter import AsyncProgress, BaseConverter
from typing import Optional, List, Tuple

logger = logging.getLogger(__name__)

# Attempt to import Wand for potentially better DDS handling
try:
    from wand.image import Image as WandImage
    from wand.exceptions import MissingDelegateError, CorruptImageError, CoderError
    WAND_AVAILABLE = True
except ImportError:
    WandImage = None
    MissingDelegateError = None
    CorruptImageError = None
    CoderError = None
    WAND_AVAILABLE = False
    logger.warning("Wand (ImageMagick) not found or import failed. Falling back to Pillow for DDS conversion, which may have limitations.")


class DDSConverter(BaseConverter):
    """Converter for DDS texture files with special handling for animation sequences"""

    def __init__(self, input_dir: str = "extracted", output_dir: str = "assets/textures", force: bool = False):
         # Default output to assets/textures, adjust if needed based on context (e.g., UI textures)
        super().__init__(input_dir, output_dir, force)
        self.logger = logging.getLogger(__name__)

    @property
    def source_extension(self) -> str:
        return ".dds"

    @property
    def target_extension(self) -> str:
        return ".png"  # Default extension for single files

    def _is_sequence_file(self, path: Path) -> bool:
        """Check if file is part of a numbered sequence (e.g., name_0000.dds)"""
        # Regex to match _ followed by 4 digits before the .dds extension
        return bool(re.search(r'_\d{4}\.dds$', str(path), re.IGNORECASE))

    def _get_sequence_base(self, path: Path) -> str:
        """Get the base name for a sequence file (e.g., 'name' from 'name_0000.dds')"""
        return re.sub(r'_\d{4}\.dds$', '', path.stem, flags=re.IGNORECASE)

    def _get_sequence_number(self, path: Path) -> int:
        """Extract sequence number from filename"""
        match = re.search(r'_(\d{4})\.dds$', str(path), re.IGNORECASE)
        return int(match.group(1)) if match else -1

    def convert_to_png(self, input_path: Path, output_path: Path) -> bool:
        """Convert DDS file to PNG using either Wand or Pillow"""
        # 1. Try Pillow first (often works for simpler DDS, faster)
        try:
            with Image.open(input_path) as img:
                # Pillow's DDS plugin might load some formats directly.
                # Ensure RGBA for consistency, especially if transparency is involved.
                if img.mode != 'RGBA':
                    img = img.convert('RGBA')
                img.save(output_path, 'PNG')
            self.logger.debug(f"Converted {input_path} using Pillow.")
            return True
        except (UnidentifiedImageError, ValueError, TypeError, OSError, Exception) as pillow_error:
            self.logger.debug(f"Pillow conversion failed for {input_path}: {pillow_error}. Trying Wand...")

            # 2. Fallback to Wand if Pillow fails and Wand is available
            if WAND_AVAILABLE:
                try:
                    # Wand might need explicit format hint for some DDS types
                    input_filename_with_hint = f"dds:{input_path}"
                    with WandImage(filename=input_filename_with_hint) as img:
                        # Ensure RGBA format for PNG output with transparency
                        if img.alpha_channel:
                            img.format = 'png'
                            # Wand handles alpha conversion implicitly when saving to PNG
                        else:
                            img.format = 'png'
                            img.alpha_channel = 'off'

                        img.save(filename=str(output_path))
                    self.logger.debug(f"Converted {input_path} using Wand.")
                    return True
                except (MissingDelegateError, CorruptImageError, CoderError, Exception) as wand_error:
                    self.logger.error(f"Wand conversion also failed for {input_path}: {wand_error}")
                    return False
            else:
                self.logger.error(f"Pillow failed and Wand is not available for {input_path}.")
                return False

        # Should not be reached unless initial try block fails unexpectedly
        return False


    def _read_eff_fps(self, base_name: str, input_dir: Path) -> int:
        """Read FPS value from associated .eff file in the same directory"""
        try:
            # Search for the .eff file in the same directory as the DDS sequence base
            eff_path = next(input_dir.glob(f"{base_name}.eff"), None)

            if not eff_path or not eff_path.exists():
                self.logger.debug(f"No .eff file found for base '{base_name}' in {input_dir}, using default 30fps")
                return 30

            with open(eff_path, 'r') as f:
                for line in f:
                    if line.strip().startswith('$FPS:'):
                        try:
                            fps = int(line.split(':')[1].strip())
                            self.logger.debug(f"Found FPS {fps} in {eff_path}")
                            return fps
                        except (ValueError, IndexError):
                            self.logger.warning(f"Could not parse FPS value in {eff_path}")
                            break # Stop searching if FPS line is found but invalid

            self.logger.debug(f"No $FPS tag found in {eff_path}, using default 30fps")
            return 30

        except Exception as e:
            self.logger.error(f"Error reading .eff file for {base_name}: {e}")
            return 30

    def _calculate_grid_dimensions(self, frame_count: int) -> tuple[int, int]:
        """Calculate optimal grid dimensions for the spritesheet"""
        if frame_count <= 0:
            return 0, 0
        # Prefer wider than tall, up to a reasonable limit like 16 cols
        max_cols = 16
        num_cols = min(frame_count, max_cols)
        num_rows = math.ceil(frame_count / num_cols)
        return num_cols, num_rows # Return cols, rows

    def convert_sequence_to_spritesheet(self, sequence_files: list[Path], output_path: Path) -> bool:
        """Convert a sequence of DDS files to a grid-based spritesheet PNG"""
        if not sequence_files:
            self.logger.error("No files provided for sequence conversion.")
            return False

        try:
            # Create temporary directory for PNG frames
            with tempfile.TemporaryDirectory() as temp_dir:
                temp_dir_path = Path(temp_dir)
                frames = []
                frame_width, frame_height = -1, -1

                # Convert each DDS to PNG first
                for i, dds_file in enumerate(sequence_files):
                    temp_png = temp_dir_path / f"frame_{i:04d}.png"
                    if not self.convert_to_png(dds_file, temp_png):
                        self.logger.error(f"Failed to convert frame {i} ({dds_file}) in sequence.")
                        return False # Abort sequence if one frame fails

                    # Load the converted PNG and store it
                    with Image.open(temp_png) as img:
                        # Ensure all frames have the same dimensions
                        if frame_width == -1:
                            frame_width, frame_height = img.size
                        elif img.size != (frame_width, frame_height):
                            self.logger.error(f"Frame {i} ({dds_file}) has different dimensions {img.size} than first frame ({frame_width}x{frame_height}). Aborting sequence.")
                            return False
                        frames.append(img.copy())

                if not frames:
                    self.logger.error("No frames were successfully converted for the sequence.")
                    return False

                # Get dimensions for the spritesheet
                num_cols, num_rows = self._calculate_grid_dimensions(len(frames))
                if num_cols == 0 or num_rows == 0:
                     self.logger.error("Calculated invalid grid dimensions for spritesheet.")
                     return False

                # Create the spritesheet
                spritesheet = Image.new('RGBA', (num_cols * frame_width, num_rows * frame_height), (0,0,0,0))

                # Paste each frame into the grid
                for idx, frame in enumerate(frames):
                    col = idx % num_cols
                    row = idx // num_cols
                    x = col * frame_width
                    y = row * frame_height
                    spritesheet.paste(frame, (x, y), frame) # Use frame as mask for transparency

                # Save the spritesheet (ensure parent dir exists)
                output_path.parent.mkdir(parents=True, exist_ok=True)
                spritesheet.save(output_path, 'PNG')
                self.logger.info(f"Saved spritesheet to {output_path}")

                # Write metadata file with frame info
                meta_path = output_path.with_suffix('.json') # Changed suffix to .json
                base_name = self._get_sequence_base(sequence_files[0])
                fps = self._read_eff_fps(base_name, sequence_files[0].parent)
                frame_delay = 1.0 / fps if fps > 0 else 0.0

                metadata = {
                    'frames': len(frames),
                    'columns': num_cols,
                    'rows': num_rows,
                    'frame_width': frame_width,
                    'frame_height': frame_height,
                    'frame_delay': frame_delay, # Store delay instead of FPS
                    'loops': True # Default assumption, EFF might override
                }
                with open(meta_path, 'w') as f:
                    json.dump(metadata, f, indent=2)
                self.logger.info(f"Saved metadata to {meta_path}")

                return True

        except Exception as e:
            self.logger.error(f"Failed to convert sequence to spritesheet: {e}", exc_info=True)
            return False

    def convert_file(self, input_path: Path, output_path: Path) -> bool:
        """Convert a single DDS file to PNG, skipping sequence files handled by convert_all."""
        # This method is now primarily for non-sequence files called by convert_all
        if self._is_sequence_file(input_path):
            # This should ideally not be called directly for sequence files by convert_all
            self.logger.debug(f"Skipping sequence file {input_path} in convert_file (handled by convert_all).")
            return True # Return True as it's not an error, just handled elsewhere
        return self.convert_to_png(input_path, output_path)

    def convert_all(self) -> bool:
        """
        Convert all DDS files, handling sequences appropriately by grouping them
        and converting each sequence to a single spritesheet and metadata file.
        """
        success = True
        processed_sequences = set() # Keep track of processed sequence base names

        all_dds_files = list(self.input_dir.rglob(f"*{self.source_extension}"))
        total_files = len(all_dds_files)
        self.logger.info(f"Found {total_files} DDS files in '{self.input_dir}'")

        # Group files by sequence base name
        sequences = {}
        single_files = []

        for input_path in all_dds_files:
            if self._is_sequence_file(input_path):
                base_name = self._get_sequence_base(input_path)
                # Use the directory containing the file as part of the key to avoid name collisions
                sequence_key = (input_path.parent, base_name)
                if sequence_key not in sequences:
                    sequences[sequence_key] = []
                sequences[sequence_key].append(input_path)
            else:
                single_files.append(input_path)

        # Process sequences first
        num_sequences = len(sequences)
        num_singles = len(single_files)
        processed_count = 0
        progress = AsyncProgress()
        progress.setTarget(num_sequences + num_singles)

        self.logger.info(f"Processing {num_sequences} potential sequences...")
        for (seq_dir, base_name), seq_files in sequences.items():
            processed_count += 1
            progress.setMessage(f"Processing sequence {base_name} ({processed_count}/{num_sequences+num_singles})")
            progress.current = processed_count

            if len(seq_files) < 2: # Treat as single file if only one frame found
                self.logger.debug(f"Sequence '{base_name}' in {seq_dir} has only one file, treating as single.")
                single_files.extend(seq_files) # Add back to single files list
                progress.Notify()
                continue

            # Sort files by sequence number
            seq_files.sort(key=self._get_sequence_number)

            # Determine output path based on the first file and base name
            try:
                first_file_rel_path = seq_files[0].relative_to(self.input_dir)
            except ValueError:
                 self.logger.warning(f"Sequence file {seq_files[0]} is not relative to {self.input_dir}. Placing output directly in {self.output_dir}.")
                 first_file_rel_path = Path(seq_files[0].name) # Use only the filename

            # Construct output path using base name and target extension
            output_path = self.output_dir / first_file_rel_path.parent / (base_name + self.target_extension)

            # Skip if output exists and not forcing
            meta_path = output_path.with_suffix('.json')
            if output_path.exists() and meta_path.exists() and not self.force:
                self.logger.debug(f"Skipping sequence {base_name} in {seq_dir} (output exists)")
                progress.Notify()
                continue

            try:
                if self.convert_sequence_to_spritesheet(seq_files, output_path):
                    self.logger.info(f"Converted sequence {base_name} in {seq_dir} to spritesheet")
                    processed_sequences.add(sequence_key) # Mark sequence as processed
                else:
                    self.logger.error(f"Failed to convert sequence {base_name} in {seq_dir}")
                    success = False
            except Exception as e:
                self.logger.error(f"Error converting sequence {base_name} in {seq_dir}: {e}", exc_info=True)
                success = False
            progress.Notify()

        # Process single files
        self.logger.info(f"Processing {num_singles} single DDS files...")
        for input_path in single_files:
            processed_count += 1
            progress.setMessage(f"Processing single file {input_path.name} ({processed_count}/{num_sequences+num_singles})")
            progress.current = processed_count

            # Check if this file was part of a sequence that was processed
            is_seq = self._is_sequence_file(input_path)
            if is_seq:
                 seq_key = (input_path.parent, self._get_sequence_base(input_path))
                 if seq_key in processed_sequences:
                     self.logger.debug(f"Skipping {input_path} as it was part of processed sequence {seq_key[1]}")
                     progress.Notify()
                     continue

            output_path = self.get_output_path(input_path)

            try:
                if output_path.exists() and not self.force:
                    self.logger.debug(f"Skipping {input_path} (output exists)")
                    progress.Notify()
                    continue

                if self.convert_to_png(input_path, output_path): # Use the dedicated PNG conversion method
                    self.logger.debug(f"Converted {input_path} -> {output_path}")
                else:
                    self.logger.error(f"Failed to convert {input_path}")
                    success = False
            except Exception as e:
                self.logger.error(f"Error converting {input_path}: {e}", exc_info=True)
                success = False
            progress.Notify()

        logger.info(f"DDS conversion process finished. Overall Success: {success}")
        return success
