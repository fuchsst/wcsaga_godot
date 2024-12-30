"""Parser for FS2 mission and campaign flags"""
from typing import Dict, Iterator
from .base_parser import BaseParser

class FlagsParser(BaseParser):
    """Parser for FS2 flag values"""
    
    def parse(self, lines: Iterator[str]) -> Dict[str, bool]:
        """Parse flag values from lines
        
        Args:
            lines: Iterator over file lines
            
        Returns:
            dict: Dictionary of flag names and values
        """
        # Get first non-empty line
        for line in lines:
            if line.strip():
                try:
                    flags = int(line.strip())
                    return self.parse_flags(flags)
                except ValueError:
                    return {}
        return {}
    
    def parse_flags(self, flags: int) -> Dict[str, bool]:
        """Parse raw flags value into dictionary
        
        Args:
            flags: Raw flags integer value
            
        Returns:
            dict: Dictionary of flag names and boolean values
        """
        return self.parse_campaign_flags(flags)
    
    def parse_campaign_flags(self, flags: int) -> Dict[str, bool]:
        """Parse campaign flags into a dictionary
        
        Args:
            flags: Raw flags value
            
        Returns:
            dict: Dictionary of flag names and boolean values
        """
        return {
            "custom_tech_database": bool(flags & (1 << 0)),
            "reset_rank": bool(flags & (1 << 1)), 
            "red_alert": bool(flags & (1 << 2)),
            "scramble": bool(flags & (1 << 3)),
            "no_builtin_msgs": bool(flags & (1 << 4)),
            "no_builtin_command": bool(flags & (1 << 5)),
            "expand_wing_icons": bool(flags & (1 << 6)),
            "use_campaign_colors": bool(flags & (1 << 7)),
            "no_traitor": bool(flags & (1 << 8)),
            "allow_dock_trees": bool(flags & (1 << 9)),
            "auto_advance": bool(flags & (1 << 10)),
            "no_promotion": bool(flags & (1 << 11)),
            "2d_mission": bool(flags & (1 << 12)),
            "no_briefing": bool(flags & (1 << 13)),
            "no_debriefing": bool(flags & (1 << 14)),
            "no_goals": bool(flags & (1 << 15))
        }

    def parse_mission_flags(self, flags: int) -> Dict[str, bool]:
        """Parse mission flags into a dictionary
        
        Args:
            flags: Raw flags value
            
        Returns:
            dict: Dictionary of flag names and boolean values
        """
        return {
            "bastion": bool(flags & (1 << 0)),
            "skipped": bool(flags & (1 << 1)),
            "no_promotion": bool(flags & (1 << 2)),
            "red_alert": bool(flags & (1 << 3)),
            "scramble": bool(flags & (1 << 4)),
            "no_builtin_msgs": bool(flags & (1 << 5)),
            "no_builtin_command": bool(flags & (1 << 6)),
            "expand_wing_icons": bool(flags & (1 << 7)),
            "use_campaign_colors": bool(flags & (1 << 8)),
            "no_traitor": bool(flags & (1 << 9)),
            "toggle_ship_trails": bool(flags & (1 << 10)),
            "support_repairs_hull": bool(flags & (1 << 11)),
            "beam_free_all_by_default": bool(flags & (1 << 12)),
            "player_start_ai": bool(flags & (1 << 13)),
            "no_briefing": bool(flags & (1 << 14)),
            "no_debriefing": bool(flags & (1 << 15)),
            "no_goals": bool(flags & (1 << 16)),
            "2d_mission": bool(flags & (1 << 17)),
            "training": bool(flags & (1 << 18)),
            "no_death_fail": bool(flags & (1 << 19)),
            "allow_dock_trees": bool(flags & (1 << 20)),
            "force_fullnav": bool(flags & (1 << 21)),
            "deactivate_lan": bool(flags & (1 << 22))
        }

    def parse_game_type_flags(self, flags: int) -> Dict[str, bool]:
        """Parse game type flags into a dictionary
        
        Args:
            flags: Raw flags value
            
        Returns:
            dict: Dictionary of flag names and boolean values
        """
        return {
            "single_mission": bool(flags & (1 << 0)),
            "campaign": bool(flags & (1 << 1)),
            "multiplayer": bool(flags & (1 << 2)),
            "training": bool(flags & (1 << 3)),
            "multi_coop": bool(flags & (1 << 4)),
            "multi_teams": bool(flags & (1 << 5)),
            "multi_dogfight": bool(flags & (1 << 6)),
            "simroom": bool(flags & (1 << 7)),
            "team_vs_team": bool(flags & (1 << 8)),
            "multi_standalone": bool(flags & (1 << 9))
        }
