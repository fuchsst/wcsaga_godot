"""Parser for FS2 mission briefing and debriefing sections"""
from dataclasses import dataclass, field
from typing import List, Dict, Iterator, Optional, Any
from .base_parser import BaseParser
from .parser_factory import ParserFactory

@dataclass
class BriefingIcon:
    """Represents an icon in a briefing stage"""
    type: int = 0
    team: int = 0
    class_type: int = 0
    pos: List[float] = field(default_factory=lambda: [0.0, 0.0, 0.0])
    label: str = ""

@dataclass
class BriefingLine:
    """Represents a line in a briefing stage"""
    start: int = 0
    end: int = 0

@dataclass
class BriefingStage:
    """Represents a stage in a briefing/debriefing"""
    text: List[dict] = field(default_factory=list)  # XSTR entries
    position: List[float] = field(default_factory=lambda: [0.0, 0.0, 0.0])
    camera_pos: List[float] = field(default_factory=lambda: [0.0, 0.0, 0.0])
    camera_orient: List[List[float]] = field(default_factory=lambda: [[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]])
    camera_time: int = 0
    formula: Dict[str, Any] = field(default_factory=dict)  # Parsed SEXP formula
    voice: str = ""
    icons: List[BriefingIcon] = field(default_factory=list)
    lines: List[BriefingLine] = field(default_factory=list)
    recommendation_text: List[dict] = field(default_factory=list)  # For debriefing stages

@dataclass
class Briefing:
    """Represents a mission briefing or debriefing"""
    num_stages: int = 0
    stages: List[BriefingStage] = field(default_factory=list)

class BriefingParser(BaseParser):
    """Parser for FS2 briefing and debriefing sections"""
    
    def __init__(self):
        self.sexp_parser = ParserFactory.create_parser('sexp')
        
    def parse(self, lines: Iterator[str]) -> Briefing:
        """Parse briefing/debriefing content
        
        Args:
            lines: Iterator over file lines
            
        Returns:
            Briefing: Parsed briefing data
        """
        briefing = Briefing()
        current_stage = None
        
        # Track what section we're in
        in_icons = False
        in_lines = False
        icon_lines = []
        line_lines = []
        
        for line in lines:
            line = line.strip()
            
            # Skip empty lines and comments
            if not line or line.startswith(';'):
                continue
                
            if line.startswith('$start_briefing'):
                continue
                
            elif line.startswith('$num_stages:'):
                briefing.num_stages = int(line.split(':', 1)[1].strip())
                
            elif line.startswith('$start_stage'):
                # Start new stage
                if current_stage:
                    briefing.stages.append(current_stage)
                current_stage = BriefingStage()
                
            elif current_stage:
                if line.startswith('$Position:'):
                    pos = self._get_value(line).split(',')
                    current_stage.position = [float(x.strip()) for x in pos]
                    
                elif line.startswith('$Camera pos:'):
                    pos = self._get_value(line).split(',')
                    current_stage.camera_pos = [float(x.strip()) for x in pos]
                    
                elif line.startswith('$Camera orient:'):
                    orient = []
                    for _ in range(3):  # Read 3x3 matrix
                        line = next(lines).strip().strip(',')
                        orient.append([float(x.strip()) for x in line.split(',')])
                    current_stage.camera_orient = orient
                    
                elif line.startswith('$Camera time:'):
                    current_stage.camera_time = int(self._get_value(line))
                    
                elif line.startswith('$Text:') or line.startswith('$Multi text'):
                    # Parse multi-line text
                    text_lines = []
                    line = next(lines).strip()  # Skip first line
                    while not line.startswith('$end_multi_text'):
                        text_lines.append(line)
                        line = next(lines).strip()
                    current_stage.text = '\n'.join(text_lines)
                    
                elif line.startswith('$Voice:'):
                    current_stage.voice = self._get_value(line)
                    
                elif line.startswith('$Formula:'):
                    # Parse multiline SEXP formula
                    formula_str = self._get_value(line)
                    if formula_str:
                        sexp_lines = self._get_sexp_lines(formula_str, lines)
                        current_stage.formula = self.sexp_parser.parse(sexp_lines)
                    
                elif line.startswith('$start_icons'):
                    in_icons = True
                    continue
                    
                elif line.startswith('$end_icons'):
                    in_icons = False
                    current_stage.icons = self._parse_icons(icon_lines)
                    icon_lines = []
                    continue
                    
                elif line.startswith('$start_lines'):
                    in_lines = True
                    continue
                    
                elif line.startswith('$end_lines'):
                    in_lines = False
                    current_stage.lines = self._parse_lines(line_lines)
                    line_lines = []
                    continue
                    
                elif line.startswith('$Recommendation text:'):
                    # Parse multi-line recommendation text (debriefing only)
                    rec_lines = []
                    line = next(lines).strip()  # Skip first line
                    while not line.startswith('$end_multi_text'):
                        rec_lines.append(line)
                        line = next(lines).strip()
                    current_stage.recommendation_text = '\n'.join(rec_lines)
                    
                elif line.startswith('$end_stage'):
                    briefing.stages.append(current_stage)
                    current_stage = None
                    
                # Collect lines for icons/lines sections
                elif in_icons:
                    icon_lines.append(line)
                elif in_lines:
                    line_lines.append(line)
                    
            elif line.startswith('$end_briefing'):
                break
                
        # Add final stage if exists
        if current_stage:
            briefing.stages.append(current_stage)
            
        return briefing
    
    def _parse_icons(self, lines: List[str]) -> List[BriefingIcon]:
        """Parse briefing stage icons
        
        Args:
            lines: Icon definition lines
            
        Returns:
            list: List of parsed BriefingIcon objects
        """
        icons = []
        
        for line in lines:
            if line.startswith('$icon:'):
                parts = self._get_value(line).split(',')
                icon = BriefingIcon(
                    type=int(parts[0].strip()),
                    team=int(parts[1].strip()),
                    class_type=int(parts[2].strip()),
                    pos=[float(x.strip()) for x in parts[3:6]]
                )
                if len(parts) > 6:
                    icon.label = parts[6].strip(' "')
                icons.append(icon)
                
        return icons
    
    def _parse_lines(self, lines: List[str]) -> List[BriefingLine]:
        """Parse briefing stage lines
        
        Args:
            lines: Line definition lines
            
        Returns:
            list: List of parsed BriefingLine objects
        """
        stage_lines = []
        
        for line in lines:
            if line.startswith('$line:'):
                parts = self._get_value(line).split(',')
                stage_lines.append(BriefingLine(
                    start=int(parts[0].strip()),
                    end=int(parts[1].strip())
                ))
                
        return stage_lines
