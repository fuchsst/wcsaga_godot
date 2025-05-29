#!/usr/bin/env python3
import os
import struct
import argparse
import logging
from pathlib import Path
from typing import Dict, List, Optional, BinaryIO
from dataclasses import dataclass
import time

# Setup logging
logger = logging.getLogger(__name__)

# VP file constants
VP_SIGNATURE = b'VPVP'
VP_VERSION = 2
VP_HEADER_SIZE = 16  # 4 bytes signature + 4 bytes version + 4 bytes diroffset + 4 bytes direntries

@dataclass
class VPDirEntry:
    offset: int
    size: int 
    name: str
    timestamp: int

class VPFile:
    def __init__(self, name: str, offset: int, size: int, timestamp: int, fileobj: BinaryIO):
        self.name = name
        self.offset = offset
        self.size = size
        self.timestamp = timestamp
        self._fileobj = fileobj

    def dump(self) -> bytes:
        """Read and return the file contents"""
        self._fileobj.seek(self.offset)
        return self._fileobj.read(self.size)

    def extract(self, dest_path: str, vp_filename: str) -> bool:
        """Extract file to destination path under VP file directory"""
        try:
            # Create path structure: <output dir>/<vp filename>/<filename in vp file>
            dest = Path(dest_path) / Path(vp_filename).stem / self.name
            dest.parent.mkdir(parents=True, exist_ok=True)

            # Write file contents
            with open(dest, 'wb') as f:
                f.write(self.dump())
            return True
        except Exception as e:
            logger.error(f"Error extracting {self.name}: {e}")
            return False

class VPIndex:
    def __init__(self):
        self.filename: str = ""
        self.entries: Dict[str, VPDirEntry] = {}
        self._fileobj: Optional[BinaryIO] = None

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        if self._fileobj:
            self._fileobj.close()

    def get_filename(self) -> str:
        """Get the VP file path"""
        return self.filename

    def parse(self, path: str) -> bool:
        """Parse VP file and build index"""
        try:
            self._fileobj = open(path, 'rb')  # Open for reading only
            self.filename = path

            # Get file size
            self._fileobj.seek(0, 2)  # Seek to end
            file_size = self._fileobj.tell()
            self._fileobj.seek(0)  # Back to start
            
            logger.debug(f"Processing VP file: {path}, size: {file_size} bytes")

            if file_size < VP_HEADER_SIZE:
                logger.error(f"File too small: {file_size} bytes (minimum {VP_HEADER_SIZE} bytes required)")
                return False

            # Read and verify header
            header_data = self._fileobj.read(VP_HEADER_SIZE)
            if len(header_data) < VP_HEADER_SIZE:
                logger.error(f"Incomplete header: got {len(header_data)} bytes, expected {VP_HEADER_SIZE}")
                return False

            signature = header_data[0:4]
            if signature != VP_SIGNATURE:
                logger.error(f"Invalid VP signature: {signature!r}")
                return False

            version = struct.unpack('<I', header_data[4:8])[0]
            if version != VP_VERSION:
                logger.error(f"Unsupported VP version: {version}")
                return False

            dir_offset = struct.unpack('<I', header_data[8:12])[0]
            dir_entries = struct.unpack('<I', header_data[12:16])[0]

            logger.debug(f"VP header: version={version}, dir_offset={dir_offset}, dir_entries={dir_entries}")

            if dir_offset > file_size:
                logger.error(f"Invalid directory offset: {dir_offset} (file size: {file_size})")
                return False

            # Calculate how many entries we can safely read
            available_space = file_size - dir_offset
            max_entries = available_space // 44  # Each entry is 44 bytes
            
            if dir_entries > max_entries:
                logger.warning(f"Directory entry count exceeds available space. "
                             f"Claimed: {dir_entries}, Maximum possible: {max_entries} "
                             f"(available space: {available_space} bytes at offset {dir_offset})")
                dir_entries = max_entries
            
            if dir_entries == 0:
                logger.error("No directory entries found")
                return False
            
            logger.debug(f"Reading {dir_entries} directory entries from offset {dir_offset}")
            
            # Seek to directory
            self._fileobj.seek(dir_offset)

            # Read directory entries
            curr_dir = ""
            entries_read = 0
            for _ in range(dir_entries):
                try:
                    entry = self._read_dir_entry()
                    entries_read += 1
                    
                    if entry.size == 0:
                        # Directory entry
                        if entry.name == "..":
                            curr_dir = str(Path(curr_dir).parent)
                        else:
                            curr_dir = str(Path(curr_dir) / entry.name)
                    else:
                        # File entry
                        full_path = str(Path(curr_dir) / entry.name)
                        self.entries[full_path] = entry
                except EOFError as e:
                    logger.warning(f"Reached end of file after reading {entries_read} entries: {e}")
                    break
                except Exception as e:
                    logger.warning(f"Error reading entry {entries_read}: {e}")
                    continue

            if entries_read > 0:
                logger.info(f"Successfully read {entries_read} entries")
                return True
            else:
                logger.error("No valid entries could be read")
                return False

        except Exception as e:
            logger.error(f"Error parsing VP file: {e}")
            if self._fileobj:
                self._fileobj.close()
                self._fileobj = None
            return False

    def _read_dir_entry(self) -> VPDirEntry:
        """Read a single directory entry"""
        try:
            current_pos = self._fileobj.tell()
            logger.debug(f"Reading directory entry at position {current_pos}")
            
            # Read and verify we have enough data for the entry
            entry_data = self._fileobj.read(44)  # 4 + 4 + 32 + 4 bytes
            if len(entry_data) < 44:
                raise EOFError(f"Incomplete directory entry data at position {current_pos}: got {len(entry_data)} bytes, expected 44")
            
            # Unpack the fixed-size fields
            offset = struct.unpack('<i', entry_data[0:4])[0]
            size = struct.unpack('<i', entry_data[4:8])[0]
            name_bytes = entry_data[8:40]  # 32 bytes for name
            timestamp = struct.unpack('<i', entry_data[40:44])[0]
            
            # Process name field
            null_pos = name_bytes.find(b'\0')
            if null_pos != -1:
                name_bytes = name_bytes[:null_pos]
            
            name = name_bytes.decode('latin1').rstrip('\0')  # Remove any trailing nulls
            
            logger.debug(f"Directory entry: pos={current_pos}, offset={offset}, size={size}, "
                        f"name={name!r}, timestamp={timestamp}")
            
            return VPDirEntry(offset, size, name, timestamp)
            
        except EOFError as e:
            logger.error(str(e))
            raise
        except struct.error as e:
            logger.error(f"Error unpacking directory entry data at position {current_pos}: {e}")
            raise
        except Exception as e:
            logger.error(f"Error reading directory entry at position {current_pos}: {e}")
            if 'entry_data' in locals():
                logger.error(f"Raw entry data: {entry_data!r}")
            raise

    def get_file(self, name: str) -> Optional[VPFile]:
        """Get a VPFile object for the given filename"""
        if name not in self.entries:
            return None
        entry = self.entries[name]
        return VPFile(entry.name, entry.offset, entry.size, entry.timestamp, self._fileobj)

    def list_files(self) -> List[str]:
        """Return sorted list of file paths"""
        return sorted(self.entries.keys())

    def extract_all(self, dest_path: str) -> bool:
        """Extract all files to destination path under VP file directory"""
        success = True
        vp_filename = Path(self.filename).name
        for name in self.entries:
            file = self.get_file(name)
            if file:
                if not file.extract(dest_path, vp_filename):
                    success = False
        return success

def get_file_timestamp(path: Path) -> int:
    """Get file modification time as Unix timestamp"""
    return int(path.stat().st_mtime)

def create_vp(src_path: str, vp_filename: str, verbose: bool = False) -> bool:
    """Create a VP file from directory contents"""
    try:
        src_path = Path(src_path)
        if not src_path.is_dir():
            logger.error(f"Error: {src_path} is not a directory")
            return False

        # If data directory exists or src_path ends with 'data', use that as root
        if (src_path / "data").is_dir():
            if verbose:
                logger.info(f"Found data directory, using {src_path}/data as root")
            src_path = src_path / "data"
        elif src_path.name != "data":
            if verbose:
                logger.warning(f"Source directory is not named 'data' and contains no data subdirectory")

        # Collect all files and directories
        entries: List[VPDirEntry] = []
        file_data: List[tuple[Path, bytes]] = []
        curr_offset = VP_HEADER_SIZE

        def process_dir(path: Path, rel_path: Path):
            nonlocal curr_offset
            # Add directory entry
            if rel_path != Path("."):
                entries.append(VPDirEntry(0, 0, rel_path.name, int(path.stat().st_mtime)))

            # Process all files and subdirectories (sorted for consistency)
            paths = sorted(path.iterdir())
            for item in paths:
                item_rel_path = rel_path / item.name
                if item.is_dir():
                    process_dir(item, item_rel_path)
                    # Add updir entry after processing directory
                    entries.append(VPDirEntry(0, 0, "..", 0))
                else:
                    # Read file content
                    with open(item, 'rb') as f:
                        data = f.read()
                    # Add file entry
                    entries.append(VPDirEntry(
                        curr_offset,
                        len(data),
                        item.name,
                        int(item.stat().st_mtime)
                    ))
                    file_data.append((item_rel_path, data))
                    curr_offset += len(data)

        # Process the root directory
        process_dir(src_path, Path("."))

        # Write VP file
        with open(vp_filename, 'wb') as f:
            # Write header
            f.write(VP_SIGNATURE)  # 4 bytes
            f.write(struct.pack('<I', VP_VERSION))  # 4 bytes
            f.write(struct.pack('<I', curr_offset))  # 4 bytes - Directory offset
            f.write(struct.pack('<I', len(entries)))  # 4 bytes - Number of entries

            # Write file data
            for _, data in file_data:
                f.write(data)

            # Write directory entries
            for entry in entries:
                f.write(struct.pack('<i', entry.offset))
                f.write(struct.pack('<i', entry.size))
                name_bytes = entry.name.encode('latin1')  # Use Latin-1 encoding to match reading
                f.write(name_bytes)
                f.write(b'\0' * (32 - len(name_bytes)))  # Pad to 32 bytes
                f.write(struct.pack('<i', entry.timestamp))

        return True

    except Exception as e:
        logger.error(f"Error creating VP file: {e}")
        return False

def main():
    parser = argparse.ArgumentParser(description='VP file extractor/creator')
    parser.add_argument('vp_file', help='VP file to process/create')
    parser.add_argument('-l', '--list', action='store_true', help='List files')
    parser.add_argument('-x', '--extract', action='store_true', help='Extract all files')
    parser.add_argument('-f', '--file', help='Extract specific file')
    parser.add_argument('-o', '--output', default='extracted', help='Output directory')
    parser.add_argument('-c', '--create', help='Create VP file from directory')
    parser.add_argument('-v', '--verbose', action='store_true', help='Enable verbose output')

    args = parser.parse_args()

    # Setup logging based on verbosity
    log_level = logging.DEBUG if args.verbose else logging.INFO
    logging.basicConfig(
        level=log_level,
        format='%(levelname)s: %(message)s'
    )

    try:
        if args.create:
            if create_vp(args.create, args.vp_file, args.verbose):
                print(f"Created VP file {args.vp_file}")
                return 0
            return 1

        with VPIndex() as vp:
            if not vp.parse(args.vp_file):
                return 1

            if args.list:
                print("\nFiles in package:")
                for f in vp.list_files():
                    print(f"  {f}")
                return 0

            if args.file:
                file = vp.get_file(args.file)
                if not file:
                    print(f"File not found: {args.file}")
                    return 1
                if not file.extract(args.output, Path(args.vp_file).name):
                    return 1
                print(f"Extracted {args.file}")
                return 0

            if args.extract:
                if not vp.extract_all(args.output):
                    return 1
                print(f"Extracted files to {args.output}/")
                return 0

            parser.print_help()
            return 1

    except Exception as e:
        logger.error(f"Error: {e}")
        return 1

if __name__ == '__main__':
    exit(main())
