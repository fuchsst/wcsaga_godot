#!/usr/bin/env python3
"""
Data Structures for Asset Relationship Mapping

This module defines the core data structures used throughout the asset
relationship mapping system.

Author: Dev (GDScript Developer)
Date: June 10, 2025
Epic: EPIC-003 - Data Migration & Conversion Tools
"""

from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional


@dataclass
class AssetRelationship:
    """Represents a relationship between source asset and target conversion"""
    source_path: str
    target_path: str
    asset_type: str
    parent_entity: Optional[str] = None
    relationship_type: str = "reference"  # reference, texture, model, sound, etc.
    required: bool = True
    
@dataclass 
class AssetMapping:
    """Complete asset mapping with all relationships"""
    entity_name: str
    entity_type: str  # ship, weapon, mission, etc.
    primary_asset: Optional[AssetRelationship] = None
    related_assets: List[AssetRelationship] = field(default_factory=list)
    metadata: Dict[str, Any] = field(default_factory=dict)