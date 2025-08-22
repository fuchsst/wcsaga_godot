#!/usr/bin/env python3
import logging
import struct
from pathlib import Path
from typing import Any, Dict, List, Tuple

import numpy as np

# Assuming pygltflib is installed: pip install pygltflib
try:
    from pygltflib import GLTF2, Accessor, Attributes, Buffer, BufferView
    from pygltflib import Image as GltfImage
    from pygltflib import (Material, Mesh, Node, PbrMetallicRoughness,
                           Primitive, Sampler, Scene, Texture, TextureInfo)
    PYGLTFLIB_AVAILABLE = True
except ImportError:
    GLTF2 = None # Define dummy classes if library is missing
    Node = Mesh = Primitive = Attributes = Accessor = BufferView = Buffer = Material = None
    PbrMetallicRoughness = TextureInfo = Texture = GltfImage = Sampler = Scene = None
    PYGLTFLIB_AVAILABLE = False

from .pof_misc_parser import parse_bsp_data  # Import the BSP parser

# NOTE: POFParser is used in the main pof_converter.py, not directly here usually.
# If direct testing is needed, uncomment the POFParser import.
# from .pof_parser import POFParser

logger = logging.getLogger(__name__)

# Constants for GLTF component types and types
COMPONENT_TYPE_MAP = {
    np.uint8: 5121, np.int8: 5120, np.uint16: 5123, np.int16: 5122,
    np.uint32: 5125, np.float32: 5126
}
TYPE_MAP = {
    1: "SCALAR", 2: "VEC2", 3: "VEC3", 4: "VEC4",
    9: "MAT3", 16: "MAT4" # Although MAT3 is 9 floats, MAT4 is 16
}

def _numpy_to_gltf_type(arr: np.ndarray) -> Tuple[int, str]:
    """Maps numpy dtype and shape to GLTF componentType and type."""
    component_type = COMPONENT_TYPE_MAP.get(arr.dtype.type)
    if component_type is None:
        raise TypeError(f"Unsupported numpy dtype: {arr.dtype}")

    if len(arr.shape) == 1: # Scalar
        gltf_type = TYPE_MAP[1]
    elif len(arr.shape) == 2: # Vector
        num_components = arr.shape[1]
        gltf_type = TYPE_MAP.get(num_components)
        if gltf_type is None:
             # Handle matrices specifically if needed, though usually vectors
             if num_components == 9 and arr.shape[0] * arr.shape[1] == 9: # MAT3 check
                 gltf_type = TYPE_MAP[9]
             elif num_components == 16 and arr.shape[0] * arr.shape[1] == 16: # MAT4 check
                 gltf_type = TYPE_MAP[16]
             else:
                raise ValueError(f"Unsupported vector dimension: {num_components}")
    else:
        raise ValueError(f"Unsupported numpy array shape: {arr.shape}")

    return component_type, gltf_type

def convert_pof_to_gltf(pof_data: Dict[str, Any], pof_file_path: str, output_path: str, progress=None) -> bool:
    """
    Converts parsed POF data into a GLTF/GLB file.

    Args:
        pof_data: The dictionary containing parsed POF data from POFParser.
        pof_file_path: The Path object pointing to the original POF file (needed to read BSP data).
        output_path: The path to save the resulting .glb file.
        progress: An optional progress reporting object.

    Returns:
        True if conversion was successful, False otherwise.
    """
    if not PYGLTFLIB_AVAILABLE:
        logger.error("pygltflib library is not installed. Cannot convert to GLTF.")
        logger.error("Please install it using: pip install pygltflib numpy")
        return False

    logger.info(f"Starting GLTF conversion for {pof_data.get('filename', 'Unknown POF')}")

    # --- Basic GLTF Structure ---
    gltf = GLTF2()
    gltf.scene = 0 # Default scene index
    gltf.scenes.append(Scene(nodes=[0])) # Scene 0 contains the root node (node 0)
    gltf.nodes.append(Node(name=pof_data.get('filename', 'POF Model'))) # Root node

    # --- Coordinate System Conversion ---
    # POF: +X Right, +Y Up, +Z Forward (Right-Handed)
    # GLTF: +X Right, +Y Up, -Z Forward (Right-Handed) - Requires Z negation
    # Godot: +X Right, +Y Up, -Z Forward (Left-Handed View, Right-Handed Coords)
    # We need to negate Z for GLTF compatibility.
    coordinate_scale = 0.01 # POF uses cm, GLTF uses m

    def convert_pos(v: List[float]) -> List[float]:
        return [v[0] * coordinate_scale, v[1] * coordinate_scale, -v[2] * coordinate_scale]

    def convert_norm(v: List[float]) -> List[float]:
        return [v[0], v[1], -v[2]] # Normals are not scaled

    # --- Geometry Data Aggregation ---
    all_vertices_np = []
    all_normals_np = []
    all_uvs_np = []
    all_indices_by_material: Dict[int, List[int]] = {}
    vertex_offset = 0
    subobj_node_map: Dict[int, int] = {} # Map POF subobject number to GLTF node index

    # Create GLTF nodes first to establish hierarchy later
    # Node 0 is the root
    for subobj_index, subobj in enumerate(pof_data.get('objects', [])):
         node = Node(name=subobj.get('name', f'Subobject_{subobj_index}'))
         # Store translation temporarily, apply after conversion
         node.translation = convert_pos(subobj.get('offset', [0,0,0]))
         # Store parent index for later linking
         node._pof_parent = subobj.get('parent', -1) # Custom attribute for temp storage
         node._pof_number = subobj.get('number', -1)
         gltf.nodes.append(node)
         subobj_node_map[node._pof_number] = len(gltf.nodes) - 1 # Map POF number to GLTF node index

    # --- Process Subobjects for Geometry ---
    # No need for POFParser instance here if BSP data is read directly

    for subobj_index, subobj in enumerate(pof_data.get('objects', [])):
        subobj_num = subobj.get('number', -1)
        logger.debug(f"Processing geometry for subobject {subobj_num}: {subobj.get('name', 'N/A')}")

        # --- Read BSP Data ---
        bsp_data_offset = subobj.get('bsp_data_offset', -1)
        bsp_data_size = subobj.get('bsp_data_size', 0)
        bsp_data_bytes = None

        if bsp_data_offset >= 0 and bsp_data_size > 0:
            try:
                with open(pof_file_path, 'rb') as f:
                    f.seek(bsp_data_offset)
                    bsp_data_bytes = f.read(bsp_data_size)
                    if len(bsp_data_bytes) != bsp_data_size:
                         logger.error(f"Failed to read expected {bsp_data_size} bytes of BSP data for subobject {subobj_num}. Got {len(bsp_data_bytes)}.")
                         bsp_data_bytes = None # Mark as failed
            except Exception as e:
                logger.error(f"Error reading BSP data for subobject {subobj_num} from {pof_file_path}: {e}")
                bsp_data_bytes = None
        else:
             logger.debug(f"Subobject {subobj_num} has no BSP data (offset={bsp_data_offset}, size={bsp_data_size}).")


        if not bsp_data_bytes:
            logger.warning(f"No BSP data read for subobject {subobj_num}. Skipping geometry.")
            continue

        # --- Parse BSP Data ---
        parsed_bsp = parse_bsp_data(bsp_data_bytes, pof_data.get('version', 0))

        if not parsed_bsp or not parsed_bsp.get('vertices'):
            logger.warning(f"Failed to parse BSP data or no vertices found for subobject {subobj_num}. Skipping geometry.")
            continue

        # --- Append and Convert Geometry Data ---
        num_subobj_verts = len(parsed_bsp['vertices'])
        if num_subobj_verts == 0:
            continue

        all_vertices_np.extend([convert_pos(v) for v in parsed_bsp['vertices']])
        all_normals_np.extend([convert_norm(n) for n in parsed_bsp['normals']])
        # GLTF expects UV origin (0,0) at top-left, POF might be bottom-left.
        # Need to flip V: V_gltf = 1.0 - V_pof
        all_uvs_np.extend([[uv[0], 1.0 - uv[1]] for uv in parsed_bsp['uvs']])

        # Remap polygon indices and group by texture
        for poly in parsed_bsp['polygons']:
            tex_idx = poly['texture_index']
            if tex_idx < 0 or tex_idx >= len(pof_data.get('textures', [])):
                 logger.warning(f"Invalid texture index {tex_idx} in subobject {subobj_num}. Using material 0.")
                 tex_idx = 0 # Default to material 0

            if tex_idx not in all_indices_by_material:
                all_indices_by_material[tex_idx] = []

            # Add vertex_offset to local indices to get global indices
            # Ensure indices are within the bounds of the *current* subobject's vertices
            remapped_indices = []
            valid_poly = True
            for idx in poly['indices']:
                 if idx < 0 or idx >= num_subobj_verts:
                      logger.error(f"Invalid local vertex index {idx} in polygon for subobject {subobj_num}. Max verts: {num_subobj_verts}. Skipping polygon.")
                      valid_poly = False
                      break
                 remapped_indices.append(idx + vertex_offset)

            if valid_poly:
                all_indices_by_material[tex_idx].extend(remapped_indices)

        # --- Link Mesh to Node (will be done after buffer creation) ---
        # Store the range of vertices this subobject uses
        node_index = subobj_node_map.get(subobj_num)
        if node_index is not None:
             gltf.nodes[node_index]._vertex_start = vertex_offset
             gltf.nodes[node_index]._vertex_count = num_subobj_verts
             # Store POF texture indices used by this node's primitives
             gltf.nodes[node_index]._material_indices = list(set(p['texture_index'] for p in parsed_bsp['polygons']))
             # We'll create the actual mesh/primitives later

        vertex_offset += num_subobj_verts # Update offset for the next subobject

    # --- Convert aggregated lists to NumPy arrays ---
    vertices_np = np.array(all_vertices_np, dtype=np.float32) if all_vertices_np else np.array([], dtype=np.float32)
    normals_np = np.array(all_normals_np, dtype=np.float32) if all_normals_np else np.array([], dtype=np.float32)
    uvs_np = np.array(all_uvs_np, dtype=np.float32) if all_uvs_np else np.array([], dtype=np.float32)

    # --- Create Buffers, BufferViews, Accessors ---
    if vertices_np.size == 0:
        logger.warning("No geometry data found in POF, creating empty GLTF.")
        gltf.save_binary(output_path)
        return True

    # Combine all vertex attributes and indices into one buffer
    buffer_bytes_list = [vertices_np.tobytes()]
    buffer_views_info = [] # Store (byte_offset, byte_length, target)

    # Vertex BufferView
    buffer_views_info.append((0, len(buffer_bytes_list[0]), 34962)) # 34962 = ARRAY_BUFFER

    # Normal BufferView (if normals exist)
    normal_bv_idx = -1
    if normals_np.size > 0:
        offset = len(buffer_bytes_list[0])
        buffer_bytes_list.append(normals_np.tobytes())
        buffer_views_info.append((offset, len(buffer_bytes_list[-1]), 34962))
        normal_bv_idx = len(buffer_views_info) - 1
    else:
         buffer_views_info.append(None) # Placeholder for normals

    # UV BufferView (if UVs exist)
    uv_bv_idx = -1
    if uvs_np.size > 0:
        offset = sum(bv[1] for bv in buffer_views_info if bv is not None)
        buffer_bytes_list.append(uvs_np.tobytes())
        buffer_views_info.append((offset, len(buffer_bytes_list[-1]), 34962))
        uv_bv_idx = len(buffer_views_info) - 1
    else:
         buffer_views_info.append(None) # Placeholder for UVs

    # Index BufferViews (one per material)
    indices_accessors = {}
    indices_buffer_views_start_offset = sum(bv[1] for bv in buffer_views_info if bv is not None)
    current_indices_offset = indices_buffer_views_start_offset

    for material_index, indices in sorted(all_indices_by_material.items()):
        if not indices: continue
        # Determine component type based on max index
        max_index = max(indices) if indices else 0
        if max_index < 65535:
            indices_np = np.array(indices, dtype=np.uint16)
            indices_component_type = COMPONENT_TYPE_MAP[np.uint16]
        else:
            indices_np = np.array(indices, dtype=np.uint32)
            indices_component_type = COMPONENT_TYPE_MAP[np.uint32]

        indices_bytes = indices_np.tobytes()
        # Align index buffer data to component size boundary
        alignment = indices_np.itemsize
        padding = (alignment - (len(b"".join(buffer_bytes_list)) % alignment)) % alignment
        buffer_bytes_list.append(b'\x00' * padding)
        current_indices_offset += padding

        buffer_bytes_list.append(indices_bytes)
        bv_len = len(indices_bytes)
        buffer_views_info.append((current_indices_offset, bv_len, 34963)) # 34963 = ELEMENT_ARRAY_BUFFER
        current_indices_offset += bv_len

        # Create Accessor for these indices
        accessor = Accessor(
            bufferView=len(buffer_views_info) - 1, # Index of the BufferView just added
            componentType=indices_component_type,
            count=len(indices),
            type="SCALAR",
            min=[int(np.min(indices_np))], # GLTF requires lists for min/max
            max=[int(np.max(indices_np))]
        )
        gltf.accessors.append(accessor)
        indices_accessors[material_index] = len(gltf.accessors) - 1

    # --- Create the main Buffer ---
    buffer_blob = b"".join(buffer_bytes_list)
    gltf.buffers.append(Buffer(byteLength=len(buffer_blob)))
    gltf.set_binary_blob(buffer_blob)

    # --- Create BufferViews ---
    current_bv_index = 0
    for bv_info in buffer_views_info:
        if bv_info is not None: # Skip placeholders
            offset, length, target = bv_info
            gltf.bufferViews.append(BufferView(buffer=0, byteOffset=offset, byteLength=length, target=target))
            # Update indices for accessors based on actual created BufferViews
            if target == 34962: # ARRAY_BUFFER
                if current_bv_index == 0: vertex_bv_idx = len(gltf.bufferViews) - 1
                elif current_bv_index == 1: normal_bv_idx = len(gltf.bufferViews) - 1
                elif current_bv_index == 2: uv_bv_idx = len(gltf.bufferViews) - 1
            current_bv_index += 1
        else:
             # If a placeholder was added, increment index counter anyway
             current_bv_index += 1


    # --- Create Attribute Accessors ---
    # Vertex Accessor
    vertex_accessor_idx = -1
    if vertices_np.size > 0:
        comp_type, type_str = _numpy_to_gltf_type(vertices_np)
        accessor = Accessor(
            bufferView=vertex_bv_idx, # Use correct BufferView index
            componentType=comp_type,
            count=len(vertices_np),
            type=type_str,
            min=vertices_np.min(axis=0).tolist(),
            max=vertices_np.max(axis=0).tolist()
        )
        gltf.accessors.append(accessor)
        vertex_accessor_idx = len(gltf.accessors) - 1

    # Normal Accessor
    normal_accessor_idx = -1
    if normals_np.size > 0:
        comp_type, type_str = _numpy_to_gltf_type(normals_np)
        accessor = Accessor(
            bufferView=normal_bv_idx, # Use correct BufferView index
            componentType=comp_type,
            count=len(normals_np),
            type=type_str,
            min=normals_np.min(axis=0).tolist(),
            max=normals_np.max(axis=0).tolist()
        )
        gltf.accessors.append(accessor)
        normal_accessor_idx = len(gltf.accessors) - 1

    # UV Accessor
    uv_accessor_idx = -1
    if uvs_np.size > 0:
        comp_type, type_str = _numpy_to_gltf_type(uvs_np)
        accessor = Accessor(
            bufferView=uv_bv_idx, # Use correct BufferView index
            componentType=comp_type,
            count=len(uvs_np),
            type=type_str,
            min=uvs_np.min(axis=0).tolist(),
            max=uvs_np.max(axis=0).tolist()
        )
        gltf.accessors.append(accessor)
        uv_accessor_idx = len(gltf.accessors) - 1

    # --- Create Materials ---
    logger.info("Creating materials...")
    material_map = {} # pof_texture_index -> gltf_material_index
    gltf.images = []
    gltf.textures = []
    gltf.materials = []
    gltf.samplers = []

    # Create a default sampler if none exists (common practice)
    if not gltf.samplers:
        # MagFilter=LINEAR, MinFilter=LINEAR_MIPMAP_LINEAR, WrapS=REPEAT, WrapT=REPEAT
        gltf.samplers.append(Sampler(magFilter=9729, minFilter=9987, wrapS=10497, wrapT=10497))
    sampler_index = 0

    for idx, tex_name in enumerate(pof_data.get('textures', [])):
        if not tex_name or tex_name.lower() == "none":
            # Create a default material for "none" texture index or invalid indices
            if -1 not in material_map:
                 material = Material(
                     pbrMetallicRoughness=PbrMetallicRoughness(
                         baseColorFactor=[0.8, 0.8, 0.8, 1.0],
                         metallicFactor=0.0,
                         roughnessFactor=0.8
                     ),
                     name="DefaultMaterial_NoneTexture"
                 )
                 gltf.materials.append(material)
                 material_map[-1] = len(gltf.materials) - 1
            material_map[idx] = material_map[-1] # Map this POF index to the default
            continue

        # Assume texture files are converted to PNG and relative to the output GLB
        # Use Path for robust path handling
        image_path = Path(tex_name)
        image_uri = image_path.with_suffix('.png').name # Use relative path name

        # Check if image already exists
        image_index = next((i for i, img in enumerate(gltf.images) if img.uri == image_uri), -1)
        if image_index == -1:
            gltf.images.append(GltfImage(uri=image_uri))
            image_index = len(gltf.images) - 1

        # Create texture reference
        gltf.textures.append(Texture(sampler=sampler_index, source=image_index))
        texture_index = len(gltf.textures) - 1

        # Create material using the texture
        material = Material(
            pbrMetallicRoughness=PbrMetallicRoughness(
                baseColorTexture=TextureInfo(index=texture_index),
                metallicFactor=0.0, # Default non-metallic
                roughnessFactor=0.8 # Default somewhat rough
            ),
            name=image_path.stem, # Use filename without extension as material name
            alphaMode="OPAQUE" # Assume opaque unless properties indicate otherwise
            # TODO: Check POF properties for transparency/alpha needs (e.g., $transparent)
        )
        gltf.materials.append(material)
        material_map[idx] = len(gltf.materials) - 1

    # Ensure a default material exists if no textures were defined at all
    if not gltf.materials:
         material = Material(pbrMetallicRoughness=PbrMetallicRoughness(baseColorFactor=[0.8, 0.8, 0.8, 1.0], metallicFactor=0.0, roughnessFactor=0.8), name="DefaultMaterial")
         gltf.materials.append(material)
         material_map[-1] = 0 # Map index -1 (or any invalid POF index) to material 0

    # --- Create Meshes and Primitives ---
    logger.info("Creating meshes and primitives...")
    mesh_map = {} # gltf_node_index -> gltf_mesh_index
    primitives_by_node: Dict[int, List[Primitive]] = {} # node_index -> [Primitive]

    # Create primitives grouped by material index first
    primitives_by_material: Dict[int, Primitive] = {}
    for material_pof_idx, index_accessor_idx in indices_accessors.items():
        attributes = Attributes(POSITION=vertex_accessor_idx)
        if normal_accessor_idx != -1:
            attributes.NORMAL = normal_accessor_idx
        if uv_accessor_idx != -1:
            attributes.TEXCOORD_0 = uv_accessor_idx

        gltf_material_idx = material_map.get(material_pof_idx, material_map.get(-1, 0))

        primitive = Primitive(
            attributes=attributes,
            indices=index_accessor_idx,
            material=gltf_material_idx
        )
        primitives_by_material[material_pof_idx] = primitive

    # Assign primitives to nodes and create meshes
    for node_idx, node in enumerate(gltf.nodes):
        if node_idx == 0: continue # Skip root node

        node_primitives = []
        # Check which materials this node uses (stored temporarily)
        if hasattr(node, '_material_indices'):
            processed_materials = set() # Track materials already added to this node's mesh
            for pof_mat_idx in node._material_indices:
                if pof_mat_idx in primitives_by_material:
                    # Ensure we don't add the same primitive multiple times if a node
                    # somehow references the same material multiple ways (unlikely but safe)
                    if pof_mat_idx not in processed_materials:
                        node_primitives.append(primitives_by_material[pof_mat_idx])
                        processed_materials.add(pof_mat_idx)
                else:
                    # Handle cases where the material index might be invalid or default (-1)
                    if -1 in primitives_by_material and -1 not in processed_materials:
                        node_primitives.append(primitives_by_material[-1])
                        processed_materials.add(-1)
                    elif pof_mat_idx != -1: # Don't warn for expected -1 indices if default exists
                         logger.warning(f"Node {node_idx} ('{node.name}') uses POF material index {pof_mat_idx}, but no corresponding primitive found.")

        if node_primitives:
            # Create a mesh for this node
            mesh = Mesh(primitives=node_primitives)
            gltf.meshes.append(mesh)
            mesh_idx = len(gltf.meshes) - 1
            node.mesh = mesh_idx
            mesh_map[node_idx] = mesh_idx # Store mapping if needed elsewhere
        elif hasattr(node, '_material_indices'):
             # Node was expected to have geometry but didn't get any primitives
             logger.warning(f"Node {node_idx} ('{node.name}') had material indices but no primitives were generated.")


    # --- Finalize Hierarchy ---
    logger.info("Finalizing node hierarchy...")
    root_children = []
    for i, node in enumerate(gltf.nodes):
        if i == 0: continue # Skip root node itself

        parent_pof_num = getattr(node, '_pof_parent', -1)
        if parent_pof_num != -1:
            # Find the GLTF node index corresponding to the POF parent number
            parent_node_index = subobj_node_map.get(parent_pof_num)
            if parent_node_index is not None and parent_node_index < len(gltf.nodes):
                 # Add current node index to parent's children list
                 if gltf.nodes[parent_node_index].children is None:
                      gltf.nodes[parent_node_index].children = []
                 # Avoid duplicates if somehow processed twice
                 if i not in gltf.nodes[parent_node_index].children:
                      gltf.nodes[parent_node_index].children.append(i)
            else:
                 logger.warning(f"Parent node for POF subobject {parent_pof_num} not found for child node {i} ('{node.name}'). Attaching to root.")
                 if i not in root_children: # Avoid duplicates
                      root_children.append(i)
        else:
            # No parent specified, attach to root (node 0)
            if i not in root_children: # Avoid duplicates
                 root_children.append(i)

        # Clean up temporary attributes used for hierarchy building
        if hasattr(node, '_pof_parent'): del node._pof_parent
        if hasattr(node, '_pof_number'): del node._pof_number
        if hasattr(node, '_vertex_start'): del node._vertex_start
        if hasattr(node, '_vertex_count'): del node._vertex_count
        if hasattr(node, '_material_indices'): del node._material_indices

    # Add all nodes identified as root children to the actual root node
    if root_children:
        if gltf.nodes[0].children is None:
            gltf.nodes[0].children = []
        # Add only those not already present (though should be unnecessary with checks above)
        for child_idx in root_children:
             if child_idx not in gltf.nodes[0].children:
                  gltf.nodes[0].children.append(child_idx)

    # Ensure the root node (index 0) is the only node listed in the scene's nodes array
    if gltf.scenes[0].nodes != [0]:
         logger.warning(f"Scene nodes were not [0], correcting. Original: {gltf.scenes[0].nodes}")
         gltf.scenes[0].nodes = [0]

    root_children = []
    for i, node in enumerate(gltf.nodes):
        if i == 0: continue # Skip root node itself

        parent_pof_num = getattr(node, '_pof_parent', -1)
        if parent_pof_num != -1:
            parent_node_index = subobj_node_map.get(parent_pof_num)
            if parent_node_index is not None and parent_node_index < len(gltf.nodes):
                 if gltf.nodes[parent_node_index].children is None:
                      gltf.nodes[parent_node_index].children = []
                 gltf.nodes[parent_node_index].children.append(i)
            else:
                 logger.warning(f"Parent node for POF subobject {parent_pof_num} not found. Attaching node {i} to root.")
                 root_children.append(i)
        else:
            # No parent specified, attach to root (node 0)
            root_children.append(i)

        # Clean up temporary attributes
        if hasattr(node, '_pof_parent'): del node._pof_parent
        if hasattr(node, '_pof_number'): del node._pof_number
        if hasattr(node, '_vertex_start'): del node._vertex_start
        if hasattr(node, '_vertex_count'): del node._vertex_count
        if hasattr(node, '_material_indices'): del node._material_indices


    if root_children:
        if gltf.nodes[0].children is None:
            gltf.nodes[0].children = []
        gltf.nodes[0].children.extend(root_children)

    # Ensure root node is in the scene
    if not gltf.scenes[0].nodes:
         gltf.scenes[0].nodes = [0]


    # --- Save GLTF file ---
    try:
        logger.info(f"Saving GLB file to: {output_path}")
        gltf.save_binary(output_path) # Save as binary GLB
        logger.info("GLTF conversion successful.")
        return True
    except Exception as e:
        logger.error(f"Failed to save GLTF file {output_path}: {e}", exc_info=True)
        return False

# Example usage (if run directly)
if __name__ == '__main__':
    logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

    # --- Dummy POF Data for Testing ---
    # In a real scenario, this would come from POFParser.parse()
    # and the BSP cache would be populated by reading the file.
    dummy_pof_data = {
        "filename": "dummy_model.pof",
        "version": 2117,
        "header": {
            'max_radius': 1000.0, 'obj_flags': 0, 'num_subobjects': 1,
            'min_bounding': [-5.0, -5.0, -10.0], 'max_bounding': [5.0, 5.0, 10.0],
            'detail_levels': [0, -1, -1, -1, -1, -1, -1, -1], 'debris_pieces': [-1]*32,
            'mass': 10.0, 'mass_center': [0.0, 0.0, 0.0],
            'moment_inertia': [[1,0,0],[0,1,0],[0,0,1]],
            'cross_sections': [], 'lights': []
        },
        "textures": ["texture1", "texture2"],
        "objects": [
            {
                'number': 0, 'radius': 10.0, 'parent': -1, 'offset': [0.0, 0.0, 0.0],
                'geometric_center': [0.0, 0.0, 0.0],
                'bounding_min': [-5.0, -5.0, -10.0], 'bounding_max': [5.0, 5.0, 10.0],
                'name': 'subobject0', 'properties': '', 'movement_type': -1, 'movement_axis': -1,
                'bsp_data_size': 50, 'bsp_data_offset': 1000 # Placeholder offset
            }
        ],
        "special_points": [], "paths": [], "gun_points": [], "missile_points": [],
        "docking_points": [], "thrusters": [], "shield_mesh": {}, "eye_points": [],
        "insignia": [], "autocenter": None, "glow_banks": [], "shield_collision_tree": None,
        # --- Manually add dummy BSP cache ---
         "_bsp_cache": {
              0: b'dummy_placeholder_bsp_data_longer_than_20_bytes' # Placeholder BSP data
         }
    }
    # --- End Dummy Data ---

    output_glb_path = Path("./dummy_model.glb")

    # Simulate BSP parsing result (replace with actual call in real use)
    # In the real converter script, parse_bsp_data would be called inside convert_pof_to_gltf
    dummy_bsp_result = {
        'vertices': [[-1,-1,0], [1,-1,0], [1,1,0], [-1,1,0]],
        'normals': [[0,0,1], [0,0,1], [0,0,1], [0,0,1]],
        'uvs': [[0,1], [1,1], [1,0], [0,0]],
        'polygons': [
            {'texture_index': 0, 'indices': [0, 1, 2]}, # Triangle 1
            {'texture_index': 0, 'indices': [0, 2, 3]}  # Triangle 2
        ]
    }
    # --- End Dummy Data ---

    # Define paths for testing
    dummy_pof_file_path = Path("./dummy_model.pof") # Need a dummy file to read from
    output_glb_path = Path("./dummy_model.glb")

    # Create a dummy POF file for reading BSP data offset
    try:
        with open(dummy_pof_file_path, "wb") as f:
            # Write enough dummy bytes so the BSP offset read doesn't fail
            f.seek(dummy_pof_data["objects"][0]["bsp_data_offset"])
            f.write(dummy_pof_data["_bsp_cache"][0])
    except Exception as e:
        print(f"Could not create dummy POF file: {e}")
        # Decide how to proceed if dummy file creation fails

    # Run the conversion
    if convert_pof_to_gltf(dummy_pof_data, dummy_pof_file_path, output_glb_path):
        print(f"Conversion successful! Output: {output_glb_path}")
    else:
        print("Conversion failed.")

    # Clean up dummy file
    # try:
    #     dummy_pof_file_path.unlink()
    # except OSError:
    #     pass # Ignore cleanup errors
