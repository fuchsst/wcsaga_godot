#!/usr/bin/env python3
import logging
import subprocess
from pathlib import Path
from .base_converter import AsyncProgress, BaseConverter

logger = logging.getLogger(__name__)

class AudioConverter(BaseConverter):
    """
    Converter for audio files (WAV, OGG) using FFmpeg.
    Converts to OGG Vorbis by default.
    """

    def __init__(self, input_dir: str = "extracted", output_dir: str = "assets/sounds", force: bool = False, ffmpeg_path: str = "ffmpeg"):
        # Default output to assets/sounds
        super().__init__(input_dir, output_dir, force)
        self.ffmpeg_path = ffmpeg_path # Path to ffmpeg executable
        self.logger = logging.getLogger(__name__)

    @property
    def source_extension(self) -> str:
        # Primarily targets .wav, but handles others via convert_all
        return ".wav"

    @property
    def target_extension(self) -> str:
        return ".ogg" # OGG Vorbis is generally preferred for Godot

    def get_supported_source_extensions(self) -> list[str]:
        """Returns a list of source extensions this converter can handle."""
        return [".wav", ".ogg"] # Add others if FFmpeg supports them easily

    def convert_file(self, input_path: Path, output_path: Path) -> bool:
        """
        Convert audio file to OGG Vorbis using FFmpeg.

        Args:
            input_path: Path to input audio file (WAV or OGG)
            output_path: Path to write OGG file

        Returns:
            bool: True if conversion successful, False otherwise
        """
        # Ensure output path has the correct target extension
        output_path = output_path.with_suffix(self.target_extension)

        # FFmpeg command: -i input -vn (no video) -acodec libvorbis (codec) -q:a 5 (quality) -y (overwrite) output
        # Quality q:a ranges from -1 (lowest) to 10 (highest). 5 is a good balance.
        command = [
            self.ffmpeg_path,
            "-i", str(input_path),
            "-vn",           # Disable video recording
            "-acodec", "libvorbis",
            "-q:a", "5",     # Audio quality (adjust as needed)
            "-y",            # Overwrite output files without asking
            str(output_path)
        ]

        try:
            self.logger.debug(f"Running FFmpeg command: {' '.join(command)}")
            # Use subprocess.run for simpler execution and error handling
            result = subprocess.run(command, capture_output=True, text=True, check=False, encoding='utf-8') # check=False to handle errors manually

            if result.returncode != 0:
                self.logger.error(f"FFmpeg failed for {input_path} with return code {result.returncode}")
                # Log stderr, attempting to decode potential mixed encodings
                try:
                    stderr_output = result.stderr
                except UnicodeDecodeError:
                    stderr_output = result.stderr.decode('utf-8', errors='replace') # Fallback decoding
                self.logger.error(f"FFmpeg stderr: {stderr_output}")
                # Attempt to remove potentially corrupted output file
                if output_path.exists():
                    try:
                        output_path.unlink()
                    except OSError:
                        pass # Ignore if removal fails
                return False
            else:
                 self.logger.debug(f"FFmpeg successfully converted {input_path}")
                 return True

        except FileNotFoundError:
            self.logger.error(f"FFmpeg not found at '{self.ffmpeg_path}'. Please ensure FFmpeg is installed and in your system's PATH or provide the correct path.")
            return False
        except Exception as e:
            self.logger.error(f"Error during FFmpeg execution for {input_path}: {e}", exc_info=True)
            # Attempt to remove potentially corrupted output file
            if output_path.exists():
                 try:
                     output_path.unlink()
                 except OSError:
                     pass # Ignore if removal fails
            return False

    def convert_all(self) -> bool:
        """
        Convert all supported audio files in the input directory.
        Overrides base implementation to handle multiple source extensions.
        """
        success = True
        processed_count = 0
        total_to_process = 0
        files_to_convert = []

        # Collect all files matching any supported source extension
        for ext in self.get_supported_source_extensions():
            found_files = list(self.input_dir.rglob(f"*{ext}"))
            files_to_convert.extend(found_files)
            total_to_process += len(found_files)

        self.logger.info(f"Found {total_to_process} audio files ({', '.join(self.get_supported_source_extensions())}) in '{self.input_dir}'")

        progress = AsyncProgress()
        progress.setTarget(total_to_process)

        for i, input_path in enumerate(files_to_convert):
            # Determine output path based on the *target* extension
            try:
                rel_path = input_path.relative_to(self.input_dir)
            except ValueError:
                 self.logger.warning(f"Input path {input_path} is not relative to {self.input_dir}. Placing output directly in {self.output_dir}.")
                 rel_path = Path(input_path.name) # Use only the filename

            output_path = self.output_dir / rel_path.parent / (input_path.stem + self.target_extension)

            progress.setMessage(f"Processing {input_path.name}")
            progress.current = i + 1

            try:
                # Skip if output exists and not forcing
                if output_path.exists() and not self.force:
                    self.logger.debug(f"Skipping {input_path} (output exists)")
                    continue

                # Ensure output directory exists before conversion attempt
                output_path.parent.mkdir(parents=True, exist_ok=True)

                if self.convert_file(input_path, output_path):
                    self.logger.debug(f"Converted {input_path} -> {output_path}")
                    processed_count += 1
                else:
                    # Error logged within convert_file
                    success = False
            except Exception as e:
                self.logger.error(f"Error processing {input_path}: {e}", exc_info=True)
                success = False

            progress.Notify() # Log progress

        self.logger.info(f"Audio conversion process finished. Converted {processed_count}/{total_to_process}. Overall Success: {success}")
        return success
