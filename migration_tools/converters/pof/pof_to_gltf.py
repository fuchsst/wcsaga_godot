"""
POF to GLTF conversion.
Converts POF files to GLTF 2.0 format using pygltflib.
"""

from __future__ import annotations
from dataclasses import dataclass, field
from typing import List, Dict, Optional, Tuple, BinaryIO
import numpy as np
from pygltflib import (
    GLTF2, Scene, Node, Mesh, Primitive, Buffer, BufferView, 
    Accessor, Material, Asset, TextureInfo, NormalTextureInfo,
    ARRAY_BUFFER, ELEMENT_ARRAY_BUFFER, SCALAR, VEC2, VEC3, VEC4,
    FLOAT, UNSIGNED_INT, UNSIGNED_SHORT
)

from .pof_file import POFFile, POFObject
from .vector3d import Vector3D
from .matrix3d import Matrix3D
from .bsp_traversal import (
    extract_bsp_geometry, triangulate_polygon,
    convert_coordinate_system, BSPVertex, BSPPolygon, BSPGeometry
)
from ..base_converter import AsyncProgress

@dataclass
class GltfConverter:
    """Converts POF data to GLTF format."""
    
    def __init__(self):
        """Initialize converter."""
        self.gltf = GLTF2()
        self.buffer = Buffer()
        self.vertex_data: List[float] = []
        self.normal_data: List[float] = []
        self.uv_data: List[float] = []
        self.index_data: List[int] = []
        self.material_map: Dict[str, int] = {}
        
        # Initialize asset info
        self.gltf.asset = Asset(version="2.0", generator="POF-GLTF-Converter")
        
        # Add default scene
        self.gltf.scenes.append(Scene(nodes=[]))
        self.gltf.scene = 0

    def convert_pof(self, pof: POFFile, progress: Optional[AsyncProgress] = None) -> GLTF2:
        """
        Convert POF file to GLTF.
        
        Args:
            pof: POF file to convert
            progress: Optional progress reporter
            
        Returns:
            Converted GLTF data
        """
        # Convert materials/textures
        if progress:
            progress.incrementWithMessage("Converting materials and textures")
        self._convert_materials(pof)
        
        # Convert objects/submodels
        if progress:
            progress.incrementWithMessage("Converting objects and submodels")
        root_node = self._convert_objects(pof, progress)
        
        # Add root node to scene
        if progress:
            progress.incrementWithMessage("Building scene hierarchy")
        self.gltf.scenes[0].nodes.append(len(self.gltf.nodes))
        self.gltf.nodes.append(root_node)
        
        # Create buffer views and accessors
        if progress:
            progress.incrementWithMessage("Creating buffer views and accessors")
        self._create_buffer_views()
        
        if progress:
            progress.incrementWithMessage("GLTF conversion complete")
            
        return self.gltf

    def _convert_materials(self, pof: POFFile) -> None:
        """Convert POF textures to GLTF materials."""
        for i, texture in enumerate(pof.textures):
            material = Material(
                name=texture,
                pbrMetallicRoughness={
                    "baseColorTexture": {
                        "index": i
                    },
                    "metallicFactor": 0.0,
                    "roughnessFactor": 1.0
                }
            )
            self.gltf.materials.append(material)
            self.material_map[texture] = i
            
        # Add default material for untextured polys
        default_material = Material(
            name="default",
            pbrMetallicRoughness={
                "baseColorFactor": [0.8, 0.8, 0.8, 1.0],
                "metallicFactor": 0.0,
                "roughnessFactor": 1.0
            }
        )
        self.gltf.materials.append(default_material)
        self.material_map["default"] = len(self.gltf.materials) - 1

    def _convert_objects(self, pof: POFFile, progress: Optional[AsyncProgress] = None) -> Node:
        """Convert POF objects/submodels to GLTF nodes."""
        # Create root node
        root_node = Node(
            name="root",
            children=[],
            translation=[0, 0, 0],
            rotation=[0, 0, 0, 1],
            scale=[1, 1, 1]
        )
        
        # Process each submodel
        total_objects = len(pof.objects)
        for i, obj in enumerate(pof.objects):
            if progress:
                progress.setMessage(f"Converting object {i+1}/{total_objects}: {obj.name}")
                
            # Create node for this object
            node = Node(
                name=obj.name,
                translation=[obj.offset.x, obj.offset.y, obj.offset.z],
                mesh=len(self.gltf.meshes)  # Index of mesh we'll create
            )
            
            # Convert geometry to mesh
            if obj.bsp_data:
                mesh = self._convert_mesh(obj)
                self.gltf.meshes.append(mesh)
            
            # Add node
            node_index = len(self.gltf.nodes)
            self.gltf.nodes.append(node)
            
            # Add to parent's children
            if obj.parent == -1:
                root_node.children.append(node_index)
            else:
                self.gltf.nodes[obj.parent].children.append(node_index)
                
        return root_node

    def _convert_mesh(self, obj: POFObject) -> Mesh:
        """Convert POF object geometry to GLTF mesh."""
        # Extract geometry from BSP data
        geometry = extract_bsp_geometry(obj.bsp_data)
        
        # Convert coordinate system
        for i, vertex in enumerate(geometry.vertices):
            geometry.vertices[i] = convert_coordinate_system(vertex)
            
        # Deduplicate vertices and get polygon indices
        unique_vertices: List[BSPVertex] = []
        vertex_map: Dict[Tuple[float, float, float, float, float, float, float, float], int] = {}
        polygon_indices: List[List[int]] = []
        
        for polygon in geometry.polygons:
            poly_indices = []
            for vertex in polygon.vertices:
                # Create tuple key from vertex data
                key = (vertex.position.x, vertex.position.y, vertex.position.z,
                      vertex.normal.x, vertex.normal.y, vertex.normal.z,
                      vertex.u, vertex.v)
                
                # Get or create vertex index
                if key not in vertex_map:
                    vertex_map[key] = len(unique_vertices)
                    unique_vertices.append(vertex)
                poly_indices.append(vertex_map[key])
            polygon_indices.append(poly_indices)
            
        # Group polygons by material
        material_groups: Dict[int, List[List[int]]] = {}
        for poly, indices in zip(geometry.polygons, polygon_indices):
            material_id = poly.texture_id if poly.texture_id >= 0 else len(self.gltf.materials) - 1
            if material_id not in material_groups:
                material_groups[material_id] = []
            material_groups[material_id].extend(triangulate_polygon(indices))
            
        # Create primitives for each material group
        primitives = []
        base_accessor = len(self.gltf.accessors)
        
        for material_id, triangle_indices in material_groups.items():
            # Add vertex data
            vertex_start = len(self.vertex_data) // 3
            for vertex in unique_vertices:
                self.vertex_data.extend([vertex.position.x, vertex.position.y, vertex.position.z])
                self.normal_data.extend([vertex.normal.x, vertex.normal.y, vertex.normal.z])
                self.uv_data.extend([vertex.u, vertex.v])
                
            # Add index data
            index_start = len(self.index_data)
            self.index_data.extend(triangle_indices)
            
            # Create primitive
            primitive = Primitive(
                attributes={
                    "POSITION": base_accessor,
                    "NORMAL": base_accessor + 1,
                    "TEXCOORD_0": base_accessor + 2
                },
                indices=base_accessor + 3,
                material=material_id
            )
            primitives.append(primitive)
            
            # Update accessor indices for next primitive
            base_accessor += 4
            
        return Mesh(primitives=primitives)

    def _create_buffer_views(self) -> None:
        """Create buffer views and accessors for mesh data."""
        # Convert lists to numpy arrays for binary conversion
        vertices = np.array(self.vertex_data, dtype=np.float32)
        normals = np.array(self.normal_data, dtype=np.float32)
        uvs = np.array(self.uv_data, dtype=np.float32)
        indices = np.array(self.index_data, dtype=np.uint32)
        
        # Create buffer views
        vertex_view = BufferView(
            buffer=0,
            byteOffset=0,
            byteLength=vertices.nbytes,
            target=ARRAY_BUFFER
        )
        self.gltf.bufferViews.append(vertex_view)
        
        normal_view = BufferView(
            buffer=0,
            byteOffset=vertex_view.byteLength,
            byteLength=normals.nbytes,
            target=ARRAY_BUFFER
        )
        self.gltf.bufferViews.append(normal_view)
        
        uv_view = BufferView(
            buffer=0,
            byteOffset=vertex_view.byteLength + normal_view.byteLength,
            byteLength=uvs.nbytes,
            target=ARRAY_BUFFER
        )
        self.gltf.bufferViews.append(uv_view)
        
        index_view = BufferView(
            buffer=0,
            byteOffset=vertex_view.byteLength + normal_view.byteLength + uv_view.byteLength,
            byteLength=indices.nbytes,
            target=ELEMENT_ARRAY_BUFFER
        )
        self.gltf.bufferViews.append(index_view)
        
        # Create accessors
        vertex_accessor = Accessor(
            bufferView=0,
            componentType=FLOAT,
            count=len(vertices) // 3,
            type=VEC3,
            min=[float(x) for x in vertices.reshape(-1,3).min(axis=0)],
            max=[float(x) for x in vertices.reshape(-1,3).max(axis=0)]
        )
        self.gltf.accessors.append(vertex_accessor)
        
        normal_accessor = Accessor(
            bufferView=1,
            componentType=FLOAT,
            count=len(normals) // 3,
            type=VEC3
        )
        self.gltf.accessors.append(normal_accessor)
        
        uv_accessor = Accessor(
            bufferView=2,
            componentType=FLOAT,
            count=len(uvs) // 2,
            type=VEC2
        )
        self.gltf.accessors.append(uv_accessor)
        
        index_accessor = Accessor(
            bufferView=3,
            componentType=UNSIGNED_INT,
            count=len(indices),
            type=SCALAR
        )
        self.gltf.accessors.append(index_accessor)
        
        # Create buffer with all data
        buffer_data = np.concatenate([
            vertices.tobytes(),
            normals.tobytes(),
            uvs.tobytes(),
            indices.tobytes()
        ])
        
        self.buffer.byteLength = len(buffer_data)
        self.gltf.buffers.append(self.buffer)

def convert_pof_to_gltf(pof_file: POFFile, output_path: str, progress: Optional[AsyncProgress] = None) -> None:
    """
    Convert POF file to GLTF format and save to file.
    
    Args:
        pof_file: POF file to convert
        output_path: Path to save GLTF file
        progress: Optional progress reporter
    """
    if progress:
        progress.setTarget(5)  # 5 main steps
        progress.incrementWithMessage("Starting GLTF conversion")
        
    converter = GltfConverter()
    gltf = converter.convert_pof(pof_file, progress)
    
    if progress:
        progress.incrementWithMessage("Saving GLTF file")
        
    # Save as GLB if output path ends with .glb
    if output_path.lower().endswith('.glb'):
        gltf.save_binary(output_path)
    else:
        gltf.save(output_path)
