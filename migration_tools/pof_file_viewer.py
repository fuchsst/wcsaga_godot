"""
POF (Parallax Object Format) file viewer.
Displays detailed information about POF files used in Wing Commander Saga,
using the POF file format implementation.

The viewer provides:
- Basic model information (version, header data)
- Geometry details (subobjects, shield mesh)
- Weapon systems (guns, missiles, turrets)
- Special features (thrusters, docking points, paths)
- Visual effects (glow points, insignias)
"""

import argparse
import logging
import logging.handlers
import sys
from pathlib import Path
from typing import Optional

from .converters.pof.pof_file import POFFile
from .converters.pof.vector3d import Vector3D

logger = logging.getLogger(__name__)

class POFViewer:
    """POF file viewer that displays detailed model information.
    
    Provides formatted output of POF file contents including:
    - Model header information
    - Geometry and subobjects
    - Weapons and turrets
    - Special features and effects
    """
    
    def __init__(self, filename: str):
        """Initialize POF viewer.
        
        Args:
            filename: Path to POF file to view
        """
        self.filename = Path(filename)
        self.pof_file = POFFile()
        
    def load_file(self) -> bool:
        """Load and parse POF file.
        
        Returns:
            True if file loaded successfully, False otherwise
            
        Raises:
            FileNotFoundError: If file does not exist
            ValueError: If file is not a valid POF file
            Exception: For other errors during loading
        """
        try:
            logger.info(f"Loading POF file: {self.filename.absolute()}")
            logger.debug(f"File size: {self.filename.stat().st_size:,} bytes")
            
            with self.filename.open('rb') as f:
                self.pof_file.read(f)
                
            logger.info(f"Successfully loaded POF file version {self.pof_file.version}")
            self._log_model_stats()
            return True
            
        except FileNotFoundError:
            logger.error(f"File not found: {self.filename}")
            return False
            
        except ValueError as e:
            logger.error(f"Invalid POF file format: {e}")
            return False
            
        except Exception as e:
            logger.error(f"Unexpected error loading POF file: {e}", exc_info=True)
            return False
            
    def _log_model_stats(self):
        """Log basic model statistics."""
        logger.debug("Model contains:")
        logger.debug(f"- {len(self.pof_file.objects):,} subobjects")
        logger.debug(f"- {len(self.pof_file.textures):,} textures")
        logger.debug(f"- {len(self.pof_file.shield_mesh):,} shield triangles")
        logger.debug(f"- {len(self.pof_file.gun_banks):,} gun banks")
        logger.debug(f"- {len(self.pof_file.missile_banks):,} missile banks")
        logger.debug(f"- {len(self.pof_file.thrusters):,} thrusters")
        logger.debug(f"- {len(self.pof_file.paths):,} AI paths")
        logger.debug(f"- {len(self.pof_file.glow_banks):,} glow banks")
            
    def print_model_info(self):
        """Print formatted model information."""
        self._print_header("POF Model Information")
        print(f"Version: {self.pof_file.version}")
        
        self._print_header_info()
        self._print_textures()
        self._print_subobjects()
        self._print_shield_data()
        self._print_eye_points()
        self._print_weapons()
        self._print_turrets()
        self._print_thrusters()
        self._print_docking()
        self._print_paths()
        self._print_glow_banks()

    def _print_header(self, title: str, char: str = "="):
        """Print a formatted section header.
        
        Args:
            title: Header title text
            char: Character to use for header line
        """
        print(f"\n{char * 3} {title} {char * 3}")

    def _print_header_info(self):
        """Print model header information."""
        if not self.pof_file.header:
            return
            
        self._print_header("Model Header")
        print(f"Max Radius: {self.pof_file.header.max_radius:.2f}")
        print(f"Bounding Box:")
        print(f"  Min: {self.pof_file.header.min_bounding}")
        print(f"  Max: {self.pof_file.header.max_bounding}")
        print(f"Mass: {self.pof_file.header.mass:.2f}")
        print(f"Mass Center: {self.pof_file.header.mass_center}")
        print(f"Detail Levels: {self.pof_file.header.detail_levels}")
        print(f"Debris Pieces: {self.pof_file.header.debris_pieces}")
        
        if self.pof_file.header.cross_sections:
            print("\nCross Sections:")
            for i, cs in enumerate(self.pof_file.header.cross_sections):
                print(f"  [{i:2d}] Depth: {cs[0]:8.2f}, Radius: {cs[1]:8.2f}")

    def _print_textures(self):
        """Print texture information."""
        self._print_header(f"Textures ({len(self.pof_file.textures)})")
        for i, texture in enumerate(self.pof_file.textures):
            print(f"  [{i:2d}] {texture}")

    def _print_subobjects(self):
        """Print subobject information."""
        self._print_header(f"Subobjects ({len(self.pof_file.objects)})")
        for i, obj in enumerate(self.pof_file.objects):
            print(f"\nSubobject {i:2d}: {obj.name}")
            print(f"  Parent: {obj.parent}")
            print(f"  Properties: {obj.properties}")
            print(f"  Offset: {obj.offset}")
            print(f"  Radius: {obj.radius:.2f}")
            print(f"  Geometric Center: {obj.geometric_center}")
            print(f"  Bounding Box:")
            print(f"    Min: {obj.bounding_min}")
            print(f"    Max: {obj.bounding_max}")
            print(f"  Movement:")
            print(f"    Type: {obj.movement_type}")
            print(f"    Axis: {obj.movement_axis}")
            print(f"  BSP Data Size: {len(obj.bsp_data):,} bytes")

    def _print_shield_data(self):
        """Print shield mesh information."""
        self._print_header(f"Shield Data ({len(self.pof_file.shield_mesh)})")
        for i, shield in enumerate(self.pof_file.shield_mesh):
            if i < 5:  # Only show first 5 faces to avoid spam
                print(f"\nShield Face {i:2d}:")
                print(f"  Normal: {shield[0]}")
                print(f"  Vertices: {len(shield[1])}")
                print(f"  Neighbors: {shield[2]}")
            elif i == 5:
                print("\n  ... remaining faces omitted ...")

    def _print_eye_points(self):
        """Print eye point information."""
        self._print_header(f"Eye Points ({len(self.pof_file.eyes)})")
        for i, eye in enumerate(self.pof_file.eyes):
            print(f"\nEye Point {i:2d}:")
            print(f"  SubObject: {eye[0]}")
            print(f"  Offset: {eye[1]}")
            print(f"  Normal: {eye[2]}")

    def _print_weapons(self):
        """Print weapon information."""
        self._print_header("Weapon Banks")
        print(f"Gun Banks: {len(self.pof_file.gun_banks)}")
        print(f"Missile Banks: {len(self.pof_file.missile_banks)}")
        
        for i, bank in enumerate(self.pof_file.gun_banks):
            print(f"\nGun Bank {i:2d}:")
            for j, point in enumerate(bank.points):
                print(f"  Point {j:2d}:")
                print(f"    Position: {point.position}")
                print(f"    Normal: {point.normal}")
                
        for i, bank in enumerate(self.pof_file.missile_banks):
            print(f"\nMissile Bank {i:2d}:")
            for j, point in enumerate(bank.points):
                print(f"  Point {j:2d}:")
                print(f"    Position: {point.position}")
                print(f"    Normal: {point.normal}")

    def _print_turrets(self):
        """Print turret information."""
        self._print_header("Turrets")
        print(f"Gun Turrets: {len(self.pof_file.gun_turrets)}")
        print(f"Missile Turrets: {len(self.pof_file.missile_turrets)}")
        
        for i, turret in enumerate(self.pof_file.gun_turrets):
            print(f"\nGun Turret {i:2d}:")
            print(f"  Parent: {turret.sobj_parent}")
            print(f"  Physics Parent: {turret.sobj_par_phys}")
            print(f"  Normal: {turret.normal}")
            print(f"  Fire Points: {len(turret.fire_points)}")
            
        for i, turret in enumerate(self.pof_file.missile_turrets):
            print(f"\nMissile Turret {i:2d}:")
            print(f"  Parent: {turret.sobj_parent}")
            print(f"  Physics Parent: {turret.sobj_par_phys}")
            print(f"  Normal: {turret.normal}")
            print(f"  Fire Points: {len(turret.fire_points)}")

    def _print_thrusters(self):
        """Print thruster information."""
        self._print_header(f"Thrusters ({len(self.pof_file.thrusters)})")
        for i, thruster in enumerate(self.pof_file.thrusters):
            print(f"\nThruster {i:2d}:")
            print(f"  Properties: {thruster.properties}")
            print(f"  Glow Points: {len(thruster.points)}")
            for j, glow in enumerate(thruster.points):
                print(f"    Point {j:2d}:")
                print(f"      Position: {glow.position}")
                print(f"      Normal: {glow.normal}")
                print(f"      Radius: {glow.radius:.2f}")

    def _print_docking(self):
        """Print docking point information."""
        self._print_header(f"Docking Points ({len(self.pof_file.docking_points)})")
        for i, dock in enumerate(self.pof_file.docking_points):
            print(f"\nDocking Point {i:2d}:")
            print(f"  Properties: {dock[0]}")
            print(f"  Paths: {dock[1]}")
            print(f"  Points: {len(dock[2])}")

    def _print_paths(self):
        """Print AI path information."""
        self._print_header(f"AI Paths ({len(self.pof_file.paths)})")
        for i, path in enumerate(self.pof_file.paths):
            print(f"\nPath {i:2d}:")
            print(f"  Name: {path[0]}")
            print(f"  Parent: {path[1]}")
            print(f"  Vertices: {len(path[2])}")

    def _print_glow_banks(self):
        """Print glow bank information."""
        self._print_header(f"Glow Banks ({len(self.pof_file.glow_banks)})")
        for i, bank in enumerate(self.pof_file.glow_banks):
            print(f"\nGlow Bank {i:2d}:")
            print(f"  Display Time: {bank.disp_time}")
            print(f"  On Time: {bank.on_time}")
            print(f"  Off Time: {bank.off_time}")
            print(f"  Parent Object: {bank.obj_parent}")
            print(f"  LOD: {bank.LOD}")
            print(f"  Type: {bank.type}")
            print(f"  Properties: {bank.properties}")
            print(f"  Points: {len(bank.points)}")

def setup_logging(debug: bool = False, log_dir: Path = Path('logs')):
    """Setup logging configuration.
    
    Args:
        debug: Enable debug logging if True
        log_dir: Directory to store log files
    """
    level = logging.DEBUG if debug else logging.INFO
    
    # Create logs directory if needed
    log_dir.mkdir(exist_ok=True)
    
    # Configure logging format
    log_format = '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    
    # Configure handlers
    handlers = [
        # File handler with rotation
        logging.handlers.RotatingFileHandler(
            log_dir / 'pof_viewer.log',
            maxBytes=1024*1024,  # 1MB
            backupCount=5
        ),
        # Console handler
        logging.StreamHandler(sys.stdout)
    ]
    
    # Configure root logger
    logging.basicConfig(
        level=level,
        format=log_format,
        handlers=handlers
    )
    
    # Set specific module log levels
    if debug:
        logging.getLogger('converters.pof').setLevel(logging.DEBUG)
    else:
        logging.getLogger('converters.pof').setLevel(logging.INFO)

def main():
    """Main entry point for POF viewer."""
    parser = argparse.ArgumentParser(
        description='Wing Commander POF File Viewer',
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )
    parser.add_argument('filename', 
                      help='Path to POF file to view')
    parser.add_argument('--debug', 
                      action='store_true',
                      help='Enable debug output')
    parser.add_argument('--log-dir',
                      default='logs',
                      help='Directory to store log files')
    args = parser.parse_args()
    
    # Setup logging
    log_dir = Path(args.log_dir)
    setup_logging(args.debug, log_dir)
    
    try:
        logger.info(f"Starting POF viewer")
        logger.debug(f"Arguments: {args}")
        
        # Create and run viewer
        viewer = POFViewer(args.filename)
        if viewer.load_file():
            viewer.print_model_info()
        else:
            sys.exit(1)
            
    except KeyboardInterrupt:
        logger.info("Viewer terminated by user")
        sys.exit(0)
    except Exception as e:
        logger.error(f"Unexpected error: {e}", exc_info=True)
        sys.exit(1)

if __name__ == '__main__':
    main()
