"""Parser for FS2 mission asteroid field sections"""
from dataclasses import dataclass, field
from typing import Dict, List, Iterator, Optional
from .base_parser import BaseParser

@dataclass
class AsteroidField:
    """Represents an asteroid field in a mission"""
    name: str = ""
    radius: float = 0.0
    density: float = 0.0
    location: List[float] = field(default_factory=lambda: [0.0, 0.0, 0.0])
    field_type: int = 0
    debris_type: int = 0
    debris_genre: int = 0
    speed: float = 0.0
    heading: float = 0.0
    pitch: float = 0.0
    bank: float = 0.0
    flags: int = 0
    fog_near_mult: float = 1.0
    fog_far_mult: float = 1.0
    lightning_storm: bool = False
    lightning_count: int = 0
    lightning_delay: float = 0.0

class AsteroidParser(BaseParser):
    """Parser for FS2 asteroid field sections"""
    
    def parse(self, lines: Iterator[str]) -> List[AsteroidField]:
        """Parse asteroid fields from lines
        
        Args:
            lines: Iterator over file lines
            
        Returns:
            list: List of parsed AsteroidField objects
        """
        fields = []
        current_field = None
        
        for line in lines:
            line = line.strip()
            
            # Skip empty lines and comments
            if not line or line.startswith(';'):
                continue
                
            if line.startswith('$Name:'):
                # Start new field
                if current_field:
                    fields.append(current_field)
                current_field = AsteroidField(
                    name=line.split(':', 1)[1].strip()
                )
                
            elif current_field:
                # Parse field properties
                if line.startswith('$Radius:'):
                    current_field.radius = float(line.split(':', 1)[1].strip())
                    
                elif line.startswith('$Density:') or line.startswith('+Density:'):
                    current_field.density = float(line.split(':', 1)[1].strip())
                    
                elif line.startswith('$Location:'):
                    pos = line.split(':', 1)[1].strip().split(',')
                    current_field.location = [float(x.strip()) for x in pos]
                    
                elif line.startswith('$Field Type:'):
                    current_field.field_type = int(line.split(':', 1)[1].strip())
                    
                elif line.startswith('$Debris Type:'):
                    current_field.debris_type = int(line.split(':', 1)[1].strip())
                    
                elif line.startswith('$Debris Genre:'):
                    current_field.debris_genre = int(line.split(':', 1)[1].strip())
                    
                elif line.startswith('$Speed:'):
                    current_field.speed = float(line.split(':', 1)[1].strip())
                    
                elif line.startswith('$Heading:'):
                    current_field.heading = float(line.split(':', 1)[1].strip())
                    
                elif line.startswith('$Pitch:'):
                    current_field.pitch = float(line.split(':', 1)[1].strip())
                    
                elif line.startswith('$Bank:'):
                    current_field.bank = float(line.split(':', 1)[1].strip())
                    
                elif line.startswith('$Flags:'):
                    current_field.flags = int(line.split(':', 1)[1].strip())
                    
                elif line.startswith('$Fog Near Mult:'):
                    current_field.fog_near_mult = float(line.split(':', 1)[1].strip())
                    
                elif line.startswith('$Fog Far Mult:'):
                    current_field.fog_far_mult = float(line.split(':', 1)[1].strip())
                    
                elif line.startswith('$Lightning Storm:'):
                    current_field.lightning_storm = bool(int(line.split(':', 1)[1].strip()))
                    
                elif line.startswith('$Lightning Count:'):
                    current_field.lightning_count = int(line.split(':', 1)[1].strip())
                    
                elif line.startswith('$Lightning Delay:'):
                    current_field.lightning_delay = float(line.split(':', 1)[1].strip())
                    
                elif line.startswith('$End'):
                    fields.append(current_field)
                    current_field = None
                    
        # Add final field if exists
        if current_field:
            fields.append(current_field)
            
        return fields

    def get_field_type_name(self, field_type: int) -> str:
        """Get human-readable name for field type
        
        Args:
            field_type: Field type ID
            
        Returns:
            str: Field type name
        """
        types = {
            0: "None",
            1: "Small Asteroid",
            2: "Medium Asteroid", 
            3: "Large Asteroid",
            4: "Small Debris",
            5: "Medium Debris",
            6: "Large Debris"
        }
        return types.get(field_type, "Unknown")

    def get_debris_type_name(self, debris_type: int) -> str:
        """Get human-readable name for debris type
        
        Args:
            debris_type: Debris type ID
            
        Returns:
            str: Debris type name
        """
        types = {
            0: "None",
            1: "Hull Debris",
            2: "Small Ship Debris",
            3: "Capital Ship Debris",
            4: "Transport Debris",
            5: "Fighter Debris"
        }
        return types.get(debris_type, "Unknown")

    def get_debris_genre_name(self, debris_genre: int) -> str:
        """Get human-readable name for debris genre
        
        Args:
            debris_genre: Debris genre ID
            
        Returns:
            str: Debris genre name
        """
        genres = {
            0: "None",
            1: "Terran",
            2: "Vasudan",
            3: "Shivan",
            4: "Debris"
        }
        return genres.get(debris_genre, "Unknown")
