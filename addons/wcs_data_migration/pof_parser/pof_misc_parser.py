#!/usr/bin/env python3
import logging
import struct
from typing import Any, BinaryIO, Dict, List, Tuple

# Import necessary helper functions and constants from pof_chunks
from .pof_chunks import (MAX_PROP_LEN, OP_BOUNDBOX, OP_DEFPOINTS, OP_EOF,
                         OP_FLATPOLY, OP_SORTNORM, OP_TMAPPOLY, read_float,
                         read_int, read_string_len, read_vector)
# Import Vector3D if needed for type hinting or direct use
from .vector3d import Vector3D

logger = logging.getLogger(__name__)


# --- BSP Parsing Helper Class ---

def read_acen_chunk(f: BinaryIO, length: int) -> List[float]:
    """Parses the Autocentering (ACEN) chunk."""
    logger.debug("Reading ACEN chunk...")
    return read_vector(f).to_list()

def read_glow_chunk(f: BinaryIO, length: int) -> List[Dict[str, Any]]:
    """Parses the Glow Points (GLOW) chunk."""
    logger.debug("Reading GLOW chunk...")
    num_banks = read_int(f)
    glow_banks = []
    for _ in range(num_banks):
        bank_data = {'points': []}
        bank_data['disp_time'] = read_int(f)
        bank_data['on_time'] = read_int(f)
        bank_data['off_time'] = read_int(f)
        bank_data['parent'] = read_int(f)
        bank_data['lod'] = read_int(f)
        bank_data['type'] = read_int(f)
        num_points = read_int(f)
        bank_data['properties'] = read_string_len(f, MAX_PROP_LEN)
        for _ in range(num_points):
            pos = read_vector(f)
            norm = read_vector(f)
            radius = read_float(f)
            bank_data['points'].append({'position': pos.to_list(), 'normal': norm.to_list(), 'radius': radius})
        glow_banks.append(bank_data)
    return glow_banks

def read_unknown_chunk(f: BinaryIO, length: int, chunk_id: int) -> None:
    """Skips an unknown chunk."""
    try:
        # Attempt to decode the chunk ID as ASCII for logging
        chunk_id_str = struct.pack('<I', chunk_id).decode('ascii', errors='replace')
    except:
        chunk_id_str = "Invalid ID"
    logger.warning(f"Skipping unknown chunk '{chunk_id_str}' (ID: {chunk_id:08X}) of length {length}")
    f.seek(length, 1)


# --- BSP Parsing ---

class _BSPGeometryParser:
    """Helper class to parse BSP data and store geometry state."""
    def __init__(self, pof_version: int):
        self.pof_version = pof_version
        # Temporary storage during recursive parse
        self.bsp_vertices: List[Vector3D] = [] # Stores Vector3D objects from DEFPOINTS
        self.bsp_normals: List[Vector3D] = []  # Stores Vector3D objects from DEFPOINTS

        # Final geometry data to be returned, ready for GLTF
        self.geometry: Dict[str, Any] = {
            'vertices': [], # List of final vertex coordinate lists [x, y, z]
            'normals': [],  # List of final normal vector lists [x, y, z]
            'uvs': [],      # List of final UV coordinate lists [u, v]
            'polygons': []  # List of dicts: {'texture_index': int, 'indices': List[int]}
                            # Indices point into the final vertices/normals/uvs lists
        }
        # Map to deduplicate vertices based on POF indices and UVs
        # Key: (pof_vert_idx, pof_norm_idx, uv_tuple)
        # Value: index in the final geometry lists
        self.vertex_map: Dict[tuple, int] = {}

    def _parse_bsp_defpoints(self, data: bytes, offset: int) -> int:
        """Parses OP_DEFPOINTS chunk and populates temporary vertex/normal lists."""
        self.bsp_vertices.clear()
        self.bsp_normals.clear()
        logger.debug(f"Parsing DEFPOINTS at offset {offset}")

        try:
            nverts = struct.unpack_from('<i', data, offset + 8)[0]
            data_offset = struct.unpack_from('<i', data, offset + 16)[0]
            # n_norms = struct.unpack_from('<i', data, offset + 12)[0] # Total normals

            current_pos = offset + data_offset
            # Check if data is long enough for norm_counts
            if offset + 20 + nverts > len(data):
                logger.error(f"DEFPOINTS: Data too short for norm_counts. Offset: {offset}, NVerts: {nverts}, Data Len: {len(data)}")
                raise EOFError("Insufficient data for DEFPOINTS norm counts")

            norm_counts = struct.unpack_from(f'<{nverts}B', data, offset + 20)

            for i in range(nverts):
                # Check bounds before reading vertex
                if current_pos + 12 > len(data):
                    logger.error(f"DEFPOINTS: Data too short for vertex {i+1}/{nverts}. Offset: {current_pos}, Data Len: {len(data)}")
                    raise EOFError("Insufficient data for DEFPOINTS vertex")
                # Read vertex position
                vx, vy, vz = struct.unpack_from('<fff', data, current_pos); current_pos += 12
                self.bsp_vertices.append(Vector3D(vx, vy, vz))

                num_norms_for_vert = norm_counts[i]
                # Check bounds before reading normals
                if current_pos + num_norms_for_vert * 12 > len(data):
                    logger.error(f"DEFPOINTS: Data too short for normals of vertex {i+1}/{nverts}. Offset: {current_pos}, Norms: {num_norms_for_vert}, Data Len: {len(data)}")
                    raise EOFError("Insufficient data for DEFPOINTS normals")

                if num_norms_for_vert > 0:
                    # Read only the first normal, as per C++ code interpretation
                    nx, ny, nz = struct.unpack_from('<fff', data, current_pos); current_pos += 12
                    self.bsp_normals.append(Vector3D(nx, ny, nz))
                    # Skip remaining normals for this vertex
                    current_pos += (num_norms_for_vert - 1) * 12
                else:
                    # If no normals defined, add a default (should not happen often)
                    logger.warning(f"DEFPOINTS: Vertex {i} has 0 normals. Using default [0,0,1].")
                    self.bsp_normals.append(Vector3D(0, 0, 1))

            logger.debug(f"DEFPOINTS: Parsed {len(self.bsp_vertices)} vertices and {len(self.bsp_normals)} primary normals.")
            # Return the expected end offset based on chunk size
            return offset + struct.unpack_from('<i', data, offset + 4)[0]

        except struct.error as e:
            logger.error(f"Struct error parsing DEFPOINTS at offset {offset}: {e}")
            raise EOFError("Struct error during DEFPOINTS parsing")
        except IndexError as e:
             logger.error(f"Index error parsing DEFPOINTS at offset {offset} (likely accessing norm_counts): {e}")
             raise EOFError("Index error during DEFPOINTS parsing")


    def _parse_bsp_tmappoly(self, data: bytes, offset: int):
        """Parses OP_TMAPPOLY chunk and adds triangles to final geometry lists."""
        try:
            # Read polygon header info
            # normal = read_vector(data, offset + 8) # Face normal, useful for flat shading or validation
            nv = struct.unpack_from('<i', data, offset + 36)[0]
            texture_index = struct.unpack_from('<i', data, offset + 40)[0]

            if nv <= 2: # Need at least 3 vertices for a triangle
                if nv > 0: logger.warning(f"TMAPPOLY with {nv} vertices found (needs >= 3). Skipping.")
                return

            indices = []
            uvs = []
            vert_offset = offset + 44
            # Check bounds before reading vertex data
            expected_vert_data_size = nv * (2 + 2 + 4 + 4) # short vert_idx, short norm_idx, float u, float v
            if vert_offset + expected_vert_data_size > len(data):
                logger.error(f"TMAPPOLY: Data too short for vertex data. Offset: {vert_offset}, NV: {nv}, Expected Size: {expected_vert_data_size}, Data Len: {len(data)}")
                raise EOFError("Insufficient data for TMAPPOLY vertex data")

            # Read all vertex references for this polygon
            for _ in range(nv):
                vert_idx = struct.unpack_from('<h', data, vert_offset)[0]; vert_offset += 2
                norm_idx = struct.unpack_from('<h', data, vert_offset)[0]; vert_offset += 2
                u, v = struct.unpack_from('<ff', data, vert_offset); vert_offset += 8
                indices.append(vert_idx)
                uvs.append((u, v))

            # Triangulate the polygon (simple fan triangulation) and add to final geometry lists
            for i in range(1, nv - 1):
                tri_final_indices = [] # Indices for the current triangle pointing to final geometry lists
                valid_tri = True
                for k in [0, i, i + 1]: # Indices for the fan triangle
                    pof_vert_idx = indices[k]
                    # POF uses the vertex index also as the index into the normal list
                    # (since only the first normal per vertex is stored in our lists)
                    pof_norm_idx = pof_vert_idx
                    uv_tuple = uvs[k]

                    # Validate indices against the temporary lists populated by DEFPOINTS
                    if not (0 <= pof_vert_idx < len(self.bsp_vertices)):
                        logger.error(f"TMAPPOLY: Invalid POF vertex index {pof_vert_idx} encountered in polygon. Max verts: {len(self.bsp_vertices)}. Skipping triangle.")
                        valid_tri = False; break
                    if not (0 <= pof_norm_idx < len(self.bsp_normals)):
                        logger.error(f"TMAPPOLY: Invalid POF normal index {pof_norm_idx} encountered in polygon. Max norms: {len(self.bsp_normals)}. Skipping triangle.")
                        valid_tri = False; break

                    # Create a unique key for this combination of vertex attributes
                    # Round UVs slightly to handle potential float inaccuracies if needed
                    # uv_tuple_rounded = (round(uv_tuple[0], 5), round(uv_tuple[1], 5))
                    vertex_key = (pof_vert_idx, pof_norm_idx, uv_tuple)

                    # Deduplicate vertex data
                    if vertex_key not in self.vertex_map:
                        # This vertex combination is new, add it to the final geometry lists
                        new_final_idx = len(self.geometry['vertices'])
                        self.vertex_map[vertex_key] = new_final_idx
                        self.geometry['vertices'].append(self.bsp_vertices[pof_vert_idx].to_list())
                        self.geometry['normals'].append(self.bsp_normals[pof_norm_idx].to_list())
                        self.geometry['uvs'].append(list(uv_tuple))
                        tri_final_indices.append(new_final_idx)
                    else:
                        # Vertex combination already exists, reuse its index
                        tri_final_indices.append(self.vertex_map[vertex_key])

                # If all indices for the triangle were valid, add the triangle to the polygon list
                if valid_tri:
                    self.geometry['polygons'].append({
                        'texture_index': texture_index,
                        'indices': tri_final_indices, # These indices point to the final geometry lists
                    })

        except struct.error as e:
            logger.error(f"Struct error parsing TMAPPOLY at offset {offset}: {e}")
            raise EOFError("Struct error during TMAPPOLY parsing")
        except IndexError as e:
             logger.error(f"Index error parsing TMAPPOLY at offset {offset} (likely accessing bsp_vertices/normals): {e}")
             raise EOFError("Index error during TMAPPOLY parsing")

    def _parse_bsp_flatpoly(self, data: bytes, offset: int):
        """Parses OP_FLATPOLY chunk (Currently skips)."""
        # Flat polys are rare and don't have UVs. Need to decide how to handle them.
        # Option 1: Skip them (simplest).
        # Option 2: Assign default UVs (e.g., [0,0]) and add them.
        # Option 3: Create separate primitives without UVs (more complex GLTF).
        # For now, skipping seems safest unless they are found to be important.
        logger.debug("Skipping FLATPOLY chunk.")
        pass

    def _parse_bsp_sortnorm(self, data: bytes, offset: int):
        """Recursively parses OP_SORTNORM chunk."""
        try:
            # Read offsets for child nodes
            frontlist_offset = struct.unpack_from('<i', data, offset + 36)[0]
            backlist_offset = struct.unpack_from('<i', data, offset + 40)[0]
            prelist_offset = struct.unpack_from('<i', data, offset + 44)[0]
            postlist_offset = struct.unpack_from('<i', data, offset + 48)[0]
            onlist_offset = struct.unpack_from('<i', data, offset + 52)[0]

            # Recursively parse child nodes in the correct order (back-to-front rendering)
            if prelist_offset > 0: self._parse_bsp_recursive(data, offset + prelist_offset)
            if backlist_offset > 0: self._parse_bsp_recursive(data, offset + backlist_offset)
            if onlist_offset > 0: self._parse_bsp_recursive(data, offset + onlist_offset)
            if frontlist_offset > 0: self._parse_bsp_recursive(data, offset + frontlist_offset)
            if postlist_offset > 0: self._parse_bsp_recursive(data, offset + postlist_offset)
        except struct.error as e:
            logger.error(f"Struct error parsing SORTNORM at offset {offset}: {e}")
            raise EOFError("Struct error during SORTNORM parsing")

    def _parse_bsp_boundbox(self, data: bytes, offset: int):
        """Parses OP_BOUNDBOX chunk (Currently skips)."""
        # Bounding box info within BSP is mainly for rendering optimization, not needed for geometry extraction.
        pass

    def _parse_bsp_recursive(self, data: bytes, offset: int):
        """Recursive helper to parse BSP data chunks."""
        while offset < len(data):
            # Check if enough data for header
            if offset + 8 > len(data):
                 logger.warning(f"Reached end of BSP data unexpectedly at offset {offset}")
                 break
            try:
                # Read chunk header safely
                chunk_id = struct.unpack_from('<i', data, offset)[0]
                chunk_size = struct.unpack_from('<i', data, offset + 4)[0]
            except struct.error:
                logger.error(f"Failed to read BSP chunk header at offset {offset}")
                break

            if chunk_id == OP_EOF: break # End of BSP data for this branch
            if chunk_size <= 0:
                 logger.error(f"Invalid BSP chunk size {chunk_size} for ID {chunk_id:08X} at offset {offset}")
                 break # Stop parsing this branch

            current_chunk_offset = offset
            next_offset = offset + chunk_size

            # Check if chunk size is valid before proceeding
            if next_offset > len(data):
                 logger.error(f"BSP Chunk size {chunk_size} for ID {chunk_id:08X} at offset {offset} exceeds data length {len(data)}")
                 break # Stop parsing this branch

            # Process known chunk types
            if chunk_id == OP_DEFPOINTS: self._parse_bsp_defpoints(data, current_chunk_offset)
            elif chunk_id == OP_FLATPOLY: self._parse_bsp_flatpoly(data, current_chunk_offset)
            elif chunk_id == OP_TMAPPOLY: self._parse_bsp_tmappoly(data, current_chunk_offset)
            elif chunk_id == OP_SORTNORM: self._parse_bsp_sortnorm(data, current_chunk_offset)
            elif chunk_id == OP_BOUNDBOX: self._parse_bsp_boundbox(data, current_chunk_offset)
            else: logger.warning(f"Unknown BSP chunk ID {chunk_id:08X}")

            offset = next_offset # Move to the next chunk based on chunk_size

    def parse(self, bsp_bytes: bytes) -> Dict[str, Any]:
        """Main entry point to parse BSP data."""
        # Reset geometry data for this parse run
        self.geometry = {'vertices': [], 'normals': [], 'uvs': [], 'polygons': []}
        self.vertex_map = {}
        self.bsp_vertices = []
        self.bsp_normals = []

        try:
            self._parse_bsp_recursive(bsp_bytes, 0)
            logger.debug(f"BSP Parsing finished. Final Vertices: {len(self.geometry['vertices'])}, Polygons: {len(self.geometry['polygons'])}")
            return self.geometry
        except EOFError as e:
             logger.error(f"EOFError during BSP parsing: {e}. Returning partial/empty geometry.")
             # Return potentially partial geometry - might be better than nothing?
             return self.geometry
        except Exception as e:
            logger.error(f"Unexpected error during BSP parsing: {e}", exc_info=True)
            # Return empty geometry on other errors
            return {'vertices': [], 'normals': [], 'uvs': [], 'polygons': []}


def parse_bsp_data(bsp_bytes: bytes, pof_version: int) -> Dict[str, Any]:
    """
    Parses the raw BSP data for a subobject using the helper class.
    """
    parser = _BSPGeometryParser(pof_version)
    return parser.parse(bsp_bytes)
