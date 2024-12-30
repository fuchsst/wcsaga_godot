"""Parser for FS2 mission background section"""
from dataclasses import dataclass, field
from typing import List, Dict, Iterator, Optional
from .base_parser import BaseParser

@dataclass
class BackgroundBitmap:
    """Represents a background bitmap"""
    name: str = ""
    angles: List[float] = field(default_factory=lambda: [0.0, 0.0, 0.0])
    scale: float = 1.0
    scale_x: float = 1.0
    scale_y: float = 1.0
    div_x: int = 1
    div_y: int = 1

@dataclass
class Background:
    """Represents mission background settings"""
    num_stars: int = 0
    ambient_light: int = 0
    sun_bitmap: Optional[BackgroundBitmap] = None
    skybox_model: Optional[str] = None
    skybox_flags: Optional[int] = None
    bitmaps: List[BackgroundBitmap] = field(default_factory=list)

class BackgroundParser(BaseParser):
    """Parser for FS2 mission background section"""
    
    def parse(self, lines: Iterator[str]) -> Background:
        """Parse background section content
        
        Args:
            lines: Iterator over file lines
            
        Returns:
            Background: Parsed background data
        """
        background = Background()
        current_bitmap = None
        
        for line in lines:
            line = line.strip()
            
            # Skip empty lines and comments
            if not line or line.startswith(';'):
                continue
                
            if line.startswith('$Num stars:'):
                background.num_stars = int(line.split(':', 1)[1].strip())
                
            elif line.startswith('$Ambient light level:'):
                background.ambient_light = int(line.split(':', 1)[1].strip())
                
            elif line.startswith('$Sun:'):
                # Start sun bitmap
                current_bitmap = BackgroundBitmap(
                    name=line.split(':', 1)[1].strip()
                )
                background.sun_bitmap = current_bitmap
                
            elif line.startswith('$Skybox Model:'):
                background.skybox_model = line.split(':', 1)[1].strip()
                
            elif line.startswith('+Skybox Flags:'):
                background.skybox_flags = int(line.split(':', 1)[1].strip())
                
            elif line.startswith('$Starbitmap:'):
                # Start new bitmap
                if current_bitmap and current_bitmap != background.sun_bitmap:
                    background.bitmaps.append(current_bitmap)
                current_bitmap = BackgroundBitmap(
                    name=line.split(':', 1)[1].strip()
                )
                
            elif current_bitmap:
                if line.startswith('+Angles:'):
                    angles = line.split(':', 1)[1].strip().split()
                    current_bitmap.angles = [float(x.strip()) for x in angles]
                    
                elif line.startswith('+Scale:'):
                    current_bitmap.scale = float(line.split(':', 1)[1].strip())
                    
                elif line.startswith('+ScaleX:'):
                    current_bitmap.scale_x = float(line.split(':', 1)[1].strip())
                    
                elif line.startswith('+ScaleY:'):
                    current_bitmap.scale_y = float(line.split(':', 1)[1].strip())
                    
                elif line.startswith('+DivX:'):
                    current_bitmap.div_x = int(line.split(':', 1)[1].strip())
                    
                elif line.startswith('+DivY:'):
                    current_bitmap.div_y = int(line.split(':', 1)[1].strip())
                    
        # Add final bitmap if exists
        if current_bitmap and current_bitmap != background.sun_bitmap:
            background.bitmaps.append(current_bitmap)
            
        return background

    def get_skybox_flag_names(self, flags: int) -> List[str]:
        """Get human-readable names for skybox flags
        
        Args:
            flags: Skybox flags value
            
        Returns:
            list: List of flag names that are set
        """
        flag_names = {
            0: "no-zbuffer",
            1: "no-lighting",
            2: "force-clamp",
            3: "force-texture",
            4: "separate-faces",
            5: "animated"
        }
        
        active_flags = []
        for bit, name in flag_names.items():
            if flags & (1 << bit):
                active_flags.append(name)
                
        return active_flags
