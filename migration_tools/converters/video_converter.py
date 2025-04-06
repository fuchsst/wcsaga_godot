#!/usr/bin/env python3
import logging
import subprocess
from pathlib import Path
from .base_converter import BaseConverter, AsyncProgress

logger = logging.getLogger(__name__)

class VideoConverter(BaseConverter):
    """
    Converter for video files (MVE, OGG) using FFmpeg.
    Converts to WebM (VP9/Opus) by default.
    """

    def __init__(self, input_dir: str = "extracted", output_dir: str = "assets/cutscenes", force: bool = False, ffmpeg_path: str = "ffmpeg"):
        # Default output to assets/cutscenes
        super().__init__(input_dir, output_dir, force)
        self.ffmpeg_path = ffmpeg_path # Path to ffmpeg executable
        self.logger = logging.getLogger(__name__)

    @property
    def source_extension(self) -> str:
        # Primarily targets .mve, but handles others via convert_all
        return ".mve"

    @property
    def target_extension(self) -> str:
        return ".webm" # WebM (VP9/Opus) is recommended for Godot 4

    def get_supported_source_extensions(self) -> list[str]:
        """Returns a list of source extensions this converter can handle."""
        # Add other potential video formats if needed
        return [".mve", ".ogg", ".ogv"]

    def convert_file(self, input_path: Path, output_path: Path) -> bool:
        """
        Convert video file to WebM using FFmpeg.

        Args:
            input_path: Path to input video file (MVE, OGG, etc.)
            output_path: Path to write WebM file

        Returns:
            bool: True if conversion successful, False otherwise
        """
        # Ensure output path has the correct target extension
        output_path = output_path.with_suffix(self.target_extension)

        # FFmpeg command:
        # -i input : Input file
        # -c:v libvpx-vp9 : Video codec VP9 (good quality/compression for webm)
        # -crf 30 : Constant Rate Factor (quality, lower is better, 30 is decent balance)
        # -b:v 0 : Variable bitrate based on CRF
        # -c:a libopus : Audio codec Opus (good quality/compression for webm)
        # -b:a 128k : Audio bitrate (adjust as needed)
        # -y : Overwrite output files without asking
        # -map_metadata -1 : Avoid copying potentially problematic metadata from source
        # -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" : Ensure dimensions are even for VP9
        # -pix_fmt yuv420p : Ensure compatible pixel format
        command = [
            self.ffmpeg_path,
            "-i", str(input_path),
            "-map_metadata", "-1", # Strip metadata
            "-c:v", "libvpx-vp9",
            "-crf", "30",
            "-b:v", "0",
            "-vf", "scale=trunc(iw/2)*2:trunc(ih/2)*2", # Ensure even dimensions
            "-pix_fmt", "yuv420p", # Ensure compatible pixel format
            "-c:a", "libopus",
            "-b:a", "128k",
            "-y",
            str(output_path)
        ]

        try:
            self.logger.debug(f"Running FFmpeg command: {' '.join(command)}")
            result = subprocess.run(command, capture_output=True, text=True, check=False, encoding='utf-8')

            if result.returncode != 0:
                self.logger.error(f"FFmpeg failed for {input_path} with return code {result.returncode}")
                # Log stderr, attempting to decode potential mixed encodings
                try:
                    stderr_output = result.stderr
                except UnicodeDecodeError:
                    stderr_output = result.stderr.decode('utf-8', errors='replace') # Fallback decoding
                self.logger.error(f"FFmpeg stderr: {stderr_output}")
                if output_path.exists():
                    try:
                        output_path.unlink()
                    except OSError:
                        pass
                return False
            else:
                self.logger.debug(f"FFmpeg successfully converted {input_path}")
                return True

        except FileNotFoundError:
            self.logger.error(f"FFmpeg not found at '{self.ffmpeg_path}'. Please ensure FFmpeg is installed and in your system's PATH or provide the correct path.")
            return False
        except Exception as e:
            self.logger.error(f"Error during FFmpeg execution for {input_path}: {e}", exc_info=True)
            if output_path.exists():
                try:
                    output_path.unlink()
                except OSError:
                    pass
            return False

    def convert_all(self) -> bool:
        """
        Convert all supported video files in the input directory.
        Overrides base implementation to handle multiple source extensions.
        """
        success = True
        processed_count = 0
        total_to_process = 0
        files_to_convert = []

        for ext in self.get_supported_source_extensions():
            found_files = list(self.input_dir.rglob(f"*{ext}"))
            files_to_convert.extend(found_files)
            total_to_process += len(found_files)

        self.logger.info(f"Found {total_to_process} video files ({', '.join(self.get_supported_source_extensions())}) in '{self.input_dir}'")

        progress = AsyncProgress()
        progress.setTarget(total_to_process)

        for i, input_path in enumerate(files_to_convert):
            try:
                rel_path = input_path.relative_to(self.input_dir)
            except ValueError:
                 self.logger.warning(f"Input path {input_path} is not relative to {self.input_dir}. Placing output directly in {self.output_dir}.")
                 rel_path = Path(input_path.name) # Use only the filename

            output_path = self.output_dir / rel_path.parent / (input_path.stem + self.target_extension)

            progress.setMessage(f"Processing {input_path.name}")
            progress.current = i + 1

            try:
                if output_path.exists() and not self.force:
                    self.logger.debug(f"Skipping {input_path} (output exists)")
                    continue

                output_path.parent.mkdir(parents=True, exist_ok=True)

                if self.convert_file(input_path, output_path):
                    self.logger.debug(f"Converted {input_path} -> {output_path}")
                    processed_count += 1
                else:
                    success = False
            except Exception as e:
                self.logger.error(f"Error processing {input_path}: {e}", exc_info=True)
                success = False

            progress.Notify()

        self.logger.info(f"Video conversion process finished. Converted {processed_count}/{total_to_process}. Overall Success: {success}")
        return success
