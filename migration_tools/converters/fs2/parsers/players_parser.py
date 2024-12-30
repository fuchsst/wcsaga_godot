"""Parser for FS2 mission players section"""
from dataclasses import dataclass, field
from typing import List, Dict, Iterator
from .base_parser import BaseParser

@dataclass
class WeaponryPool:
    """Represents available weapons"""
    weapons: Dict[str, int] = field(default_factory=dict)  # weapon name -> count

@dataclass
class Players:
    """Represents mission players section"""
    starting_shipname: str = ""
    ship_choices: List[str] = field(default_factory=list)
    weaponry_pool: WeaponryPool = field(default_factory=WeaponryPool)

class PlayersParser(BaseParser):
    """Parser for FS2 mission players section"""
    
    def _parse_multiline_list(self, first_line: str, lines: Iterator[str]) -> str:
        """Parse a multiline parenthesized list into a single string
        
        Args:
            first_line: First line of the list (with opening parenthesis)
            lines: Iterator over remaining lines
            
        Returns:
            str: Combined list content with parentheses removed
        """
        content = []
        
        # Handle first line
        if first_line.startswith('('):
            first_line = first_line[1:]  # Remove opening parenthesis
        if first_line.endswith(')'):
            return first_line[:-1].strip()  # Single line case
        content.append(first_line.strip())
        
        # Read remaining lines until closing parenthesis
        for line in lines:
            line = line.strip()
            if not line or line.startswith(';'):
                continue
            if line.startswith('#'):  # New section
                break
                
            if ')' in line:
                # Found closing parenthesis
                end_idx = line.index(')')
                content.append(line[:end_idx].strip())
                break
            else:
                content.append(line.strip())
                
        return ' '.join(content)
    
    def _parse_weapon_entry(self, entry: str) -> tuple[str, int]:
        """Parse a weapon entry into name and count
        
        Args:
            entry: Raw weapon entry string
            
        Returns:
            tuple: (weapon_name, count)
        """
        parts = entry.split('"')
        if len(parts) >= 3:  # Has quotes
            weapon = parts[1].strip()
            count = int(parts[2].strip())
        else:  # No quotes
            parts = entry.strip().rsplit(None, 1)
            weapon = parts[0].strip('" ')
            count = int(parts[1])
        return weapon, count
    
    def parse(self, lines: Iterator[str]) -> Players:
        """Parse players section content
        
        Args:
            lines: Iterator over file lines
            
        Returns:
            Players: Parsed players data
        """
        players = Players()
        
        for line in lines:
            line = line.strip()
            
            # Skip empty lines and comments
            if not line or line.startswith(';'):
                continue
                
            if line.startswith('$Starting Shipname:'):
                players.starting_shipname = self._get_value(line)
                
            elif line.startswith('$Ship Choices:'):
                # Parse ship list
                ships_str = self._get_value(line)
                if ships_str.startswith('('):
                    ships_str = self._parse_multiline_list(ships_str, lines)
                    if ships_str:
                        players.ship_choices = [s.strip(' "') for s in ships_str.split()]
                        
            elif line.startswith('+Weaponry Pool:'):
                # Parse weapon list
                weapons_str = self._get_value(line)
                if weapons_str.startswith('('):
                    weapons_str = self._parse_multiline_list(weapons_str, lines)
                    if weapons_str:
                        # Split into weapon entries and parse each one
                        entries = weapons_str.split('"')
                        # Process entries in pairs (name + count)
                        for i in range(1, len(entries)-1, 2):
                            weapon_entry = f'"{entries[i]}"{entries[i+1]}'
                            weapon, count = self._parse_weapon_entry(weapon_entry)
                            players.weaponry_pool.weapons[weapon] = count
                            
        return players
