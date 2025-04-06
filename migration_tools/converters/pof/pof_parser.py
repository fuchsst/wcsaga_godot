#!/usr/bin/env python3
import struct
import logging
from pathlib import Path
from typing import BinaryIO, Dict, Any, List, Optional

# Import specific chunk readers from their modules
from .pof_header_parser import read_ohdr_chunk
from .pof_subobject_parser import read_sobj_chunk
from .pof_texture_parser import read_txtr_chunk
from .pof_special_points_parser import read_spcl_chunk
from .pof_path_parser import read_path_chunk
from .pof_weapon_points_parser import read_gpnt_chunk, read_mpnt_chunk
from .pof_docking_parser import read_dock_chunk
from .pof_thruster_parser import read_fuel_chunk
from .pof_shield_parser import read_shld_chunk, read_sldc_chunk
from .pof_eye_parser import read_eye_chunk
from .pof_insignia_parser import read_insg_chunk
from .pof_misc_parser import read_acen_chunk, read_glow_chunk, read_unknown_chunk

# Import constants and basic helpers from pof_chunks
from .pof_chunks import (
    read_chunk_header,
    ID_OHDR, ID_SOBJ, ID_TXTR, ID_SPCL, ID_PATH, ID_GPNT, ID_MPNT,
    ID_DOCK, ID_FUEL, ID_SHLD, ID_EYE, ID_INSG, ID_ACEN, ID_GLOW, ID_SLDC
)

logger = logging.getLogger(__name__)

# POF Header ID and Version check values
POF_HEADER_ID = 0x4f505350  # 'OPSP'
PM_COMPATIBLE_VERSION = 1900
PM_OBJFILE_MAJOR_VERSION = 30 # Corresponds to 21xx, 22xx etc.

class POFParser:
    """Parses a POF file into a structured dictionary."""

    def __init__(self):
        self.pof_data: Dict[str, Any] = {
            "filename": "",
            "version": 0,
            "header": {},
            "textures": [],
            "objects": [],
            "special_points": [],
            "paths": [],
            "gun_points": [],
            "missile_points": [],
            "docking_points": [],
            "thrusters": [],
            "shield_mesh": {},
            "eye_points": [],
            "insignia": [],
            "autocenter": None,
            "glow_banks": [],
            "shield_collision_tree": None,
            # Add other top-level sections as needed
        }
        self.bsp_data_cache: Dict[int, bytes] = {} # Cache for BSP data if read separately
        self._current_file_handle: Optional[BinaryIO] = None

    def _read_bsp_data(self, subobj_num: int, offset: int, size: int) -> Optional[bytes]:
        """Reads BSP data for a specific subobject on demand."""
        if subobj_num in self.bsp_data_cache:
            return self.bsp_data_cache[subobj_num]

        if self._current_file_handle and offset >= 0 and size > 0:
            try:
                current_pos = self._current_file_handle.tell()
                self._current_file_handle.seek(offset)
                bsp_data = self._current_file_handle.read(size)
                self._current_file_handle.seek(current_pos) # Restore position
                self.bsp_data_cache[subobj_num] = bsp_data
                logger.debug(f"Read {size} bytes of BSP data for subobject {subobj_num}")
                return bsp_data
            except Exception as e:
                logger.error(f"Failed to read BSP data for subobject {subobj_num}: {e}")
                return None
        return None

    def get_subobject_bsp_data(self, subobj_num: int) -> Optional[bytes]:
         """Public method to get BSP data, reading it if necessary."""
         if subobj_num in self.bsp_data_cache:
             return self.bsp_data_cache[subobj_num]

         # Find the subobject data in the parsed structure
         sobj_data = next((obj for obj in self.pof_data.get('objects', []) if obj.get('number') == subobj_num), None)

         if sobj_data:
             offset = sobj_data.get('bsp_data_offset', -1)
             size = sobj_data.get('bsp_data_size', 0)
             return self._read_bsp_data(subobj_num, offset, size)

         logger.warning(f"Subobject {subobj_num} not found in parsed data.")
         return None


    def parse(self, file_path: Path) -> Optional[Dict[str, Any]]:
        """Parses the POF file at the given path."""
        # Reset data for new parse
        self.pof_data = { "filename": file_path.name, "version": 0, "header": {}, "textures": [], "objects": [], "special_points": [], "paths": [], "gun_points": [], "missile_points": [], "docking_points": [], "thrusters": [], "shield_mesh": {}, "eye_points": [], "insignia": [], "autocenter": None, "glow_banks": [], "shield_collision_tree": None }
        self.bsp_data_cache = {}
        self._current_file_handle = None

        logger.info(f"Parsing POF file: {file_path}")

        try:
            with open(file_path, 'rb') as f:
                self._current_file_handle = f # Store handle for potential BSP reads

                # Read POF header
                pof_id = struct.unpack('<I', f.read(4))[0]
                pof_version = struct.unpack('<i', f.read(4))[0]

                if pof_id != POF_HEADER_ID:
                    logger.error(f"Invalid POF header ID in {file_path}. Expected {POF_HEADER_ID:08X}, got {pof_id:08X}")
                    self._current_file_handle = None
                    return None

                # Version Check (Adjust as needed based on required features)
                # if pof_version < PM_COMPATIBLE_VERSION or (pof_version // 100) > PM_OBJFILE_MAJOR_VERSION:
                #     logger.warning(f"Potentially unsupported POF version {pof_version} in {file_path}. Minimum tested: {PM_COMPATIBLE_VERSION}")

                self.pof_data["version"] = pof_version
                logger.debug(f"POF Version: {pof_version}")

                # Read chunks until EOF
                while True:
                    chunk_start_pos = f.tell()
                    try:
                        # Check if there's enough data for a header
                        header_bytes = f.peek(8)
                        if not header_bytes or len(header_bytes) < 8:
                             logger.debug("Reached end of file (or insufficient data for header).")
                             break
                        chunk_id, chunk_len = read_chunk_header(f)
                        logger.debug(f"Found chunk ID: {chunk_id:08X} ('{struct.pack('<I', chunk_id).decode('ascii', errors='replace')}'), Length: {chunk_len}")
                    except (struct.error, EOFError):
                        logger.debug("Reached end of file or failed to read chunk header.")
                        break
                    except Exception as e:
                         logger.error(f"Unexpected error reading chunk header at pos {chunk_start_pos}: {e}")
                         break

                    if chunk_len < 0:
                        logger.error(f"Invalid negative chunk length {chunk_len} for ID {chunk_id:08X} at pos {chunk_start_pos}. Aborting parse.")
                        break

                    next_chunk_pos = chunk_start_pos + 8 + chunk_len

                    # Process known chunks using a dictionary lookup for cleaner code
                    chunk_readers = {
                        ID_OHDR: read_ohdr_chunk,
                        ID_SOBJ: read_sobj_chunk,
                        ID_TXTR: read_txtr_chunk,
                        ID_SPCL: read_spcl_chunk,
                        ID_PATH: read_path_chunk,
                        ID_GPNT: read_gpnt_chunk,
                        ID_MPNT: read_mpnt_chunk,
                        ID_DOCK: read_dock_chunk,
                        ID_FUEL: read_fuel_chunk,
                        ID_SHLD: read_shld_chunk,
                        ID_EYE: read_eye_chunk,
                        ID_INSG: read_insg_chunk,
                        ID_ACEN: read_acen_chunk,
                        ID_GLOW: read_glow_chunk,
                        ID_SLDC: read_sldc_chunk,
                    }

                    reader_func = chunk_readers.get(chunk_id)

                    if reader_func:
                        # Map chunk ID to dictionary key
                        key_map = {
                            ID_OHDR: 'header', ID_SOBJ: 'objects', ID_TXTR: 'textures',
                            ID_SPCL: 'special_points', ID_PATH: 'paths', ID_GPNT: 'gun_points',
                            ID_MPNT: 'missile_points', ID_DOCK: 'docking_points', ID_FUEL: 'thrusters',
                            ID_SHLD: 'shield_mesh', ID_EYE: 'eye_points', ID_INSG: 'insignia',
                            ID_ACEN: 'autocenter', ID_GLOW: 'glow_banks', ID_SLDC: 'shield_collision_tree'
                        }
                        data_key = key_map.get(chunk_id)
                        if data_key:
                            parsed_data = reader_func(f, chunk_len)
                            # Append to list for chunks that can appear multiple times (like SOBJ)
                            if isinstance(self.pof_data[data_key], list):
                                 # SOBJ reader returns a dict, so append it
                                 if chunk_id == ID_SOBJ:
                                     self.pof_data[data_key].append(parsed_data)
                                 # Most others return a list of items, extend the list
                                 elif isinstance(parsed_data, list):
                                      self.pof_data[data_key].extend(parsed_data)
                                 else: # Should not happen if readers are consistent
                                      logger.error(f"Reader for {chunk_id:08X} returned unexpected type {type(parsed_data)}")
                            else:
                                # Assign directly for single-instance chunks
                                self.pof_data[data_key] = parsed_data
                        else:
                             # This case should ideally not be hit if key_map is complete
                             logger.error(f"Internal error: No dictionary key mapped for chunk ID {chunk_id:08X}")
                             read_unknown_chunk(f, chunk_len, chunk_id)
                    else:
                        # Handle unknown or skipped chunks
                        read_unknown_chunk(f, chunk_len, chunk_id)


                    # --- Verification and Seeking ---
                    current_pos = f.tell()
                    # Check for reading past the expected end
                    if current_pos > next_chunk_pos:
                        logger.error(f"Read past end of chunk {chunk_id:08X}! Expected {next_chunk_pos}, got {current_pos}. Attempting to recover.")
                        f.seek(next_chunk_pos)
                    # Check for reading less than expected (and seek forward)
                    elif current_pos < next_chunk_pos:
                        bytes_skipped = next_chunk_pos - current_pos
                        logger.warning(f"Chunk read mismatch for ID {chunk_id:08X}. Read {current_pos - (chunk_start_pos + 8)} bytes, expected {chunk_len}. Skipping {bytes_skipped} bytes.")
                        f.seek(next_chunk_pos)
                    # Else: current_pos == next_chunk_pos (perfect read)

                    # Basic EOF check before next iteration
                    peek = f.peek(1)
                    if not peek:
                        logger.debug("Reached end of file after chunk.")
                        break

            logger.info(f"Successfully parsed {file_path}")
            self._current_file_handle = None # Release file handle
            return self.pof_data

        except FileNotFoundError:
            logger.error(f"POF file not found: {file_path}")
            self._current_file_handle = None
            return None
        except Exception as e:
            logger.error(f"Error parsing POF file {file_path}: {e}", exc_info=True)
            self._current_file_handle = None
            return None
            logger.error(f"POF file not found: {file_path}")
            return None
        except Exception as e:
            logger.error(f"Error parsing POF file {file_path}: {e}", exc_info=True)
            return None
