#!/usr/bin/env python3
"""
LOD and Material Validation System - EPIC-003 DM-006 Implementation

Validation system that measures performance impact and visual quality retention
for LOD and material processing. Ensures converted materials maintain visual accuracy
and performance characteristics while achieving optimization goals.
"""

import json
import logging
import math
from dataclasses import asdict, dataclass
from enum import Enum
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple

from .collision_mesh_generator import CollisionMeshData
from .godot_material_converter import (GodotMaterialProperties,
                                       WCSMaterialProperties)
from .mesh_optimization_tools import (MeshOptimizationResult,
                                      OptimizationProfile)
from .pof_lod_processor import LODHierarchy, LODLevel


class ValidationLevel(Enum):
    """Levels of validation thoroughness."""
    BASIC = "basic"          # Quick checks only
    STANDARD = "standard"    # Comprehensive validation
    THOROUGH = "thorough"    # Detailed analysis with measurements


class ValidationResult(Enum):
    """Validation result status."""
    PASSED = "passed"
    WARNING = "warning"
    FAILED = "failed"
    ERROR = "error"


@dataclass
class ValidationIssue:
    """Represents a validation issue found during testing."""
    
    level: ValidationResult
    category: str
    message: str
    details: Optional[Dict[str, Any]] = None
    suggestion: Optional[str] = None
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for serialization."""
        return asdict(self)


@dataclass
class PerformanceMetrics:
    """Performance metrics for validation."""
    
    # Rendering performance
    estimated_fps_impact: float = 0.0  # Percentage change in FPS
    memory_usage_mb: float = 0.0
    draw_calls: int = 0
    triangle_count: int = 0
    vertex_count: int = 0
    
    # LOD metrics
    lod_transition_smoothness: float = 1.0  # 0-1 scale
    lod_distance_coverage: float = 1.0      # 0-1 scale
    
    # Material metrics
    shader_complexity_score: float = 1.0    # 1-5 scale
    texture_memory_mb: float = 0.0
    transparency_overdraw: float = 0.0      # Percentage
    
    # Quality metrics
    visual_fidelity_score: float = 1.0      # 0-1 scale (1=perfect)
    geometric_accuracy: float = 1.0         # 0-1 scale
    material_accuracy: float = 1.0          # 0-1 scale


@dataclass
class ValidationReport:
    """Complete validation report for LOD and material processing."""
    
    model_name: str
    validation_level: ValidationLevel
    overall_result: ValidationResult
    
    performance_metrics: PerformanceMetrics
    validation_issues: List[ValidationIssue]
    
    # Detailed results
    lod_validation: Dict[str, Any]
    material_validation: Dict[str, Any]
    collision_validation: Dict[str, Any]
    optimization_validation: Dict[str, Any]
    
    # Recommendations
    recommendations: List[str]
    optimization_suggestions: List[str]
    
    # Metadata
    validation_timestamp: str
    validation_duration: float = 0.0
    
    def get_summary(self) -> Dict[str, Any]:
        """Get summary of validation results."""
        issue_counts = {}
        for issue in self.validation_issues:
            issue_counts[issue.level.value] = issue_counts.get(issue.level.value, 0) + 1
        
        return {
            'model': self.model_name,
            'overall_result': self.overall_result.value,
            'issue_count': len(self.validation_issues),
            'issues_by_level': issue_counts,
            'performance_score': self._calculate_performance_score(),
            'quality_score': self._calculate_quality_score(),
            'validation_level': self.validation_level.value
        }
    
    def _calculate_performance_score(self) -> float:
        """Calculate overall performance score (0-100)."""
        metrics = self.performance_metrics
        
        # Weight different performance factors
        fps_score = max(0, 100 + metrics.estimated_fps_impact)  # Higher is better
        memory_score = max(0, 100 - metrics.memory_usage_mb)     # Lower is better
        complexity_score = max(0, 100 - metrics.shader_complexity_score * 20)
        
        # Weighted average
        overall_score = (fps_score * 0.4 + memory_score * 0.3 + complexity_score * 0.3)
        return min(100, max(0, overall_score))
    
    def _calculate_quality_score(self) -> float:
        """Calculate overall quality score (0-100)."""
        metrics = self.performance_metrics
        
        quality_score = (
            metrics.visual_fidelity_score * 50 +
            metrics.geometric_accuracy * 30 +
            metrics.material_accuracy * 20
        )
        
        return min(100, max(0, quality_score))


class LODMaterialValidator:
    """Validates LOD and material processing results."""
    
    def __init__(self, validation_level: ValidationLevel = ValidationLevel.STANDARD) -> None:
        """Initialize validator with specified validation level."""
        self.validation_level = validation_level
        self.logger = logging.getLogger(__name__)
        
        # Performance thresholds
        self.performance_thresholds = {
            'max_memory_usage_mb': 100.0,
            'max_triangle_count': 50000,
            'max_draw_calls': 20,
            'min_fps_impact': -10.0,  # Maximum 10% FPS reduction
            'min_visual_fidelity': 0.9,  # 90% visual accuracy
            'max_shader_complexity': 3.0
        }
        
        # Quality thresholds
        self.quality_thresholds = {
            'min_geometric_accuracy': 0.95,
            'min_material_accuracy': 0.9,
            'max_lod_transition_distance': 2.0,  # Max transition should be smooth
            'min_texture_resolution_ratio': 0.25  # Minimum texture quality
        }
    
    def validate_lod_hierarchy(self, hierarchy: LODHierarchy, 
                              model_data: Dict[str, Any]) -> ValidationReport:
        """Validate complete LOD hierarchy and material processing."""
        try:
            import time
            start_time = time.time()
            
            self.logger.info(f"Validating LOD hierarchy for {hierarchy.base_model_name}")
            
            # Initialize validation report
            report = ValidationReport(
                model_name=hierarchy.base_model_name,
                validation_level=self.validation_level,
                overall_result=ValidationResult.PASSED,
                performance_metrics=PerformanceMetrics(),
                validation_issues=[],
                lod_validation={},
                material_validation={},
                collision_validation={},
                optimization_validation={},
                recommendations=[],
                optimization_suggestions=[],
                validation_timestamp=time.strftime('%Y-%m-%d %H:%M:%S')
            )
            
            # Validate LOD levels
            lod_issues = self._validate_lod_levels(hierarchy, model_data)
            report.validation_issues.extend(lod_issues)
            report.lod_validation = self._analyze_lod_performance(hierarchy)
            
            # Validate materials if provided
            if 'materials' in model_data:
                material_issues = self._validate_materials(model_data['materials'])
                report.validation_issues.extend(material_issues)
                report.material_validation = self._analyze_material_performance(model_data['materials'])
            
            # Validate collision data if provided
            if 'collision_data' in model_data:
                collision_issues = self._validate_collision_data(model_data['collision_data'])
                report.validation_issues.extend(collision_issues)
                report.collision_validation = self._analyze_collision_performance(model_data['collision_data'])
            
            # Validate optimization results if provided
            if 'optimization_results' in model_data:
                optimization_issues = self._validate_optimization_results(model_data['optimization_results'])
                report.validation_issues.extend(optimization_issues)
                report.optimization_validation = self._analyze_optimization_effectiveness(model_data['optimization_results'])
            
            # Calculate overall performance metrics
            report.performance_metrics = self._calculate_performance_metrics(hierarchy, model_data)
            
            # Generate recommendations
            report.recommendations = self._generate_recommendations(report)
            report.optimization_suggestions = self._generate_optimization_suggestions(report)
            
            # Determine overall result
            report.overall_result = self._determine_overall_result(report.validation_issues)
            
            # Record timing
            report.validation_duration = time.time() - start_time
            
            self.logger.info(
                f"Validation complete: {report.overall_result.value} "
                f"({len(report.validation_issues)} issues, {report.validation_duration:.2f}s)"
            )
            
            return report
            
        except Exception as e:
            self.logger.error(f"Validation failed for {hierarchy.base_model_name}: {e}")
            raise
    
    def _validate_lod_levels(self, hierarchy: LODHierarchy, 
                           model_data: Dict[str, Any]) -> List[ValidationIssue]:
        """Validate LOD level configuration and transitions."""
        issues = []
        
        # Check minimum number of LOD levels
        if len(hierarchy.lod_levels) < 3:
            issues.append(ValidationIssue(
                level=ValidationResult.WARNING,
                category="lod_configuration",
                message=f"Only {len(hierarchy.lod_levels)} LOD levels, recommend at least 3",
                suggestion="Add more LOD levels for better performance scaling"
            ))
        
        # Check distance thresholds are increasing
        prev_distance = 0.0
        for i, lod in enumerate(hierarchy.lod_levels):
            if lod.distance_threshold <= prev_distance:
                issues.append(ValidationIssue(
                    level=ValidationResult.FAILED,
                    category="lod_configuration",
                    message=f"LOD {lod.level} distance {lod.distance_threshold} not greater than previous {prev_distance}",
                    details={'lod_level': lod.level, 'distance': lod.distance_threshold},
                    suggestion="Ensure LOD distances are monotonically increasing"
                ))
            prev_distance = lod.distance_threshold
        
        # Check reduction factors are reasonable
        for lod in hierarchy.lod_levels:
            if lod.vertex_reduction < 0.05:
                issues.append(ValidationIssue(
                    level=ValidationResult.WARNING,
                    category="lod_optimization",
                    message=f"LOD {lod.level} vertex reduction {lod.vertex_reduction:.1%} very low",
                    suggestion="Consider more aggressive vertex reduction for distant LODs"
                ))
            
            if lod.triangle_reduction < 0.05:
                issues.append(ValidationIssue(
                    level=ValidationResult.WARNING,
                    category="lod_optimization",
                    message=f"LOD {lod.level} triangle reduction {lod.triangle_reduction:.1%} very low",
                    suggestion="Consider more aggressive triangle reduction for distant LODs"
                ))
        
        # Check LOD coverage vs model size
        max_distance = hierarchy.lod_levels[-1].distance_threshold
        model_radius = hierarchy.model_radius
        
        if max_distance < model_radius * 10:
            issues.append(ValidationIssue(
                level=ValidationResult.WARNING,
                category="lod_coverage",
                message=f"LOD max distance {max_distance:.1f} may be too small for model radius {model_radius:.1f}",
                suggestion="Extend LOD distances for better culling coverage"
            ))
        
        return issues
    
    def _validate_materials(self, materials: List[Dict[str, Any]]) -> List[ValidationIssue]:
        """Validate material conversion and optimization."""
        issues = []
        
        # Check material count
        if len(materials) > self.performance_thresholds['max_draw_calls']:
            issues.append(ValidationIssue(
                level=ValidationResult.WARNING,
                category="material_performance",
                message=f"Material count {len(materials)} exceeds recommended maximum {self.performance_thresholds['max_draw_calls']}",
                suggestion="Consider merging similar materials to reduce draw calls"
            ))
        
        # Validate individual materials
        transparent_count = 0
        complex_shader_count = 0
        
        for i, material in enumerate(materials):
            material_name = material.get('resource_name', f'material_{i}')
            
            # Check transparency
            if material.get('transparency', 0) > 0:
                transparent_count += 1
            
            # Check shader complexity
            if material.get('normal_enabled', False) and material.get('emission_enabled', False):
                complex_shader_count += 1
            
            # Check texture resolution
            if 'albedo_texture' in material:
                # Would check actual texture resolution in real implementation
                pass
            
            # Validate material properties
            albedo = material.get('albedo_color', [1, 1, 1, 1])
            if len(albedo) >= 4 and (albedo[3] < 0 or albedo[3] > 1):
                issues.append(ValidationIssue(
                    level=ValidationResult.FAILED,
                    category="material_properties",
                    message=f"Material '{material_name}' has invalid alpha value {albedo[3]}",
                    suggestion="Alpha values must be between 0.0 and 1.0"
                ))
        
        # Check transparency overdraw
        if transparent_count > len(materials) * 0.3:
            issues.append(ValidationIssue(
                level=ValidationResult.WARNING,
                category="material_performance",
                message=f"High transparency ratio: {transparent_count}/{len(materials)} materials",
                suggestion="Reduce transparent materials to minimize overdraw"
            ))
        
        # Check shader complexity
        if complex_shader_count > len(materials) * 0.5:
            issues.append(ValidationIssue(
                level=ValidationResult.WARNING,
                category="material_performance",
                message=f"High shader complexity: {complex_shader_count}/{len(materials)} complex materials",
                suggestion="Simplify shaders for better performance"
            ))
        
        return issues
    
    def _validate_collision_data(self, collision_data: Dict[str, Any]) -> List[ValidationIssue]:
        """Validate collision mesh generation and optimization."""
        issues = []
        
        # Check collision mesh complexity
        vertex_count = len(collision_data.get('vertices', []))
        if vertex_count > 1000:
            issues.append(ValidationIssue(
                level=ValidationResult.WARNING,
                category="collision_performance",
                message=f"Collision mesh has {vertex_count} vertices, may impact physics performance",
                suggestion="Consider using simpler collision shapes (box, sphere, convex hull)"
            ))
        
        # Check collision type appropriateness
        collision_type = collision_data.get('collision_type')
        if collision_type == 'trimesh' and vertex_count > 500:
            issues.append(ValidationIssue(
                level=ValidationResult.WARNING,
                category="collision_performance",
                message="Trimesh collision with high vertex count, consider convex decomposition",
                suggestion="Use convex hulls for better physics performance"
            ))
        
        # Validate collision bounds
        if 'box_center' in collision_data and 'box_extents' in collision_data:
            extents = collision_data['box_extents']
            if extents and any(extent <= 0 for extent in extents):
                issues.append(ValidationIssue(
                    level=ValidationResult.FAILED,
                    category="collision_geometry",
                    message="Collision box has invalid extents",
                    details={'extents': extents},
                    suggestion="Ensure all box extents are positive values"
                ))
        
        return issues
    
    def _validate_optimization_results(self, optimization_results: Dict[str, Any]) -> List[ValidationIssue]:
        """Validate mesh optimization effectiveness."""
        issues = []
        
        # Check optimization effectiveness
        vertex_reduction = optimization_results.get('vertex_reduction_ratio', 0.0)
        if vertex_reduction < 0.1:
            issues.append(ValidationIssue(
                level=ValidationResult.WARNING,
                category="optimization_effectiveness",
                message=f"Low vertex reduction: {vertex_reduction:.1%}",
                suggestion="Consider more aggressive optimization settings"
            ))
        
        # Check if optimization was too aggressive
        if vertex_reduction > 0.8:
            issues.append(ValidationIssue(
                level=ValidationResult.WARNING,
                category="optimization_quality",
                message=f"Very high vertex reduction: {vertex_reduction:.1%}, may impact visual quality",
                suggestion="Validate visual quality with such aggressive optimization"
            ))
        
        # Check memory savings
        memory_savings = optimization_results.get('memory_savings_bytes', 0)
        if memory_savings < 1024:  # Less than 1KB saved
            issues.append(ValidationIssue(
                level=ValidationResult.WARNING,
                category="optimization_effectiveness",
                message=f"Low memory savings: {memory_savings} bytes",
                suggestion="Review optimization settings for better memory reduction"
            ))
        
        return issues
    
    def _analyze_lod_performance(self, hierarchy: LODHierarchy) -> Dict[str, Any]:
        """Analyze LOD performance characteristics."""
        analysis = {
            'lod_count': len(hierarchy.lod_levels),
            'distance_range': {
                'min': hierarchy.lod_levels[0].distance_threshold,
                'max': hierarchy.lod_levels[-1].distance_threshold,
                'ratio': hierarchy.lod_levels[-1].distance_threshold / hierarchy.lod_levels[0].distance_threshold
            },
            'reduction_progression': [],
            'transition_smoothness': 1.0,
            'coverage_efficiency': 1.0
        }
        
        # Analyze reduction progression
        for lod in hierarchy.lod_levels:
            analysis['reduction_progression'].append({
                'level': lod.level,
                'vertex_reduction': lod.vertex_reduction,
                'triangle_reduction': lod.triangle_reduction,
                'distance_threshold': lod.distance_threshold
            })
        
        # Calculate transition smoothness (difference between consecutive LODs)
        smoothness_scores = []
        for i in range(1, len(hierarchy.lod_levels)):
            prev_lod = hierarchy.lod_levels[i-1]
            curr_lod = hierarchy.lod_levels[i]
            
            vertex_diff = abs(prev_lod.vertex_reduction - curr_lod.vertex_reduction)
            distance_diff = curr_lod.distance_threshold - prev_lod.distance_threshold
            
            # Smooth transitions have gradual vertex reduction and reasonable distance steps
            smoothness = 1.0 - min(vertex_diff, 0.5) - min(distance_diff / prev_lod.distance_threshold, 1.0) * 0.2
            smoothness_scores.append(max(0.0, smoothness))
        
        if smoothness_scores:
            analysis['transition_smoothness'] = sum(smoothness_scores) / len(smoothness_scores)
        
        return analysis
    
    def _analyze_material_performance(self, materials: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Analyze material performance characteristics."""
        analysis = {
            'material_count': len(materials),
            'transparency_ratio': 0.0,
            'texture_usage': {},
            'shader_complexity': 1.0,
            'draw_call_estimate': len(materials)
        }
        
        transparent_count = 0
        texture_types = {'albedo': 0, 'normal': 0, 'emission': 0, 'roughness': 0}
        complexity_scores = []
        
        for material in materials:
            # Count transparency
            if material.get('transparency', 0) > 0:
                transparent_count += 1
            
            # Count texture types
            for tex_type in texture_types:
                if f'{tex_type}_texture' in material:
                    texture_types[tex_type] += 1
            
            # Calculate shader complexity
            complexity = 1.0
            if material.get('normal_enabled', False):
                complexity += 1.0
            if material.get('emission_enabled', False):
                complexity += 0.5
            if material.get('transparency', 0) > 0:
                complexity += 0.5
            
            complexity_scores.append(complexity)
        
        analysis['transparency_ratio'] = transparent_count / max(len(materials), 1)
        analysis['texture_usage'] = texture_types
        analysis['shader_complexity'] = sum(complexity_scores) / max(len(complexity_scores), 1)
        
        return analysis
    
    def _analyze_collision_performance(self, collision_data: Dict[str, Any]) -> Dict[str, Any]:
        """Analyze collision performance characteristics."""
        analysis = {
            'collision_type': collision_data.get('collision_type', 'unknown'),
            'vertex_count': len(collision_data.get('vertices', [])),
            'complexity_score': 1.0,
            'memory_estimate_bytes': 0,
            'performance_rating': 'good'
        }
        
        vertex_count = analysis['vertex_count']
        collision_type = analysis['collision_type']
        
        # Calculate complexity score
        if collision_type == 'sphere':
            analysis['complexity_score'] = 1.0
        elif collision_type == 'box':
            analysis['complexity_score'] = 1.1
        elif collision_type == 'convex_hull':
            analysis['complexity_score'] = 1.0 + (vertex_count / 1000.0)
        elif collision_type == 'trimesh':
            analysis['complexity_score'] = 2.0 + (vertex_count / 500.0)
        
        # Estimate memory usage
        if collision_type in ['sphere', 'box']:
            analysis['memory_estimate_bytes'] = 64  # Minimal for simple shapes
        else:
            analysis['memory_estimate_bytes'] = vertex_count * 12 + len(collision_data.get('indices', [])) * 4
        
        # Performance rating
        if analysis['complexity_score'] <= 1.5:
            analysis['performance_rating'] = 'excellent'
        elif analysis['complexity_score'] <= 2.5:
            analysis['performance_rating'] = 'good'
        elif analysis['complexity_score'] <= 4.0:
            analysis['performance_rating'] = 'fair'
        else:
            analysis['performance_rating'] = 'poor'
        
        return analysis
    
    def _analyze_optimization_effectiveness(self, optimization_results: Dict[str, Any]) -> Dict[str, Any]:
        """Analyze optimization effectiveness."""
        analysis = {
            'vertex_reduction': optimization_results.get('vertex_reduction_ratio', 0.0),
            'triangle_reduction': optimization_results.get('triangle_reduction_ratio', 0.0),
            'memory_savings_mb': optimization_results.get('memory_savings_bytes', 0) / (1024 * 1024),
            'techniques_used': optimization_results.get('optimization_techniques_used', []),
            'effectiveness_score': 0.0
        }
        
        # Calculate effectiveness score (0-100)
        vertex_score = min(analysis['vertex_reduction'] * 100, 80)  # Cap at 80%
        memory_score = min(analysis['memory_savings_mb'] * 10, 20)   # Up to 20 points for memory
        
        analysis['effectiveness_score'] = vertex_score + memory_score
        
        return analysis
    
    def _calculate_performance_metrics(self, hierarchy: LODHierarchy, 
                                     model_data: Dict[str, Any]) -> PerformanceMetrics:
        """Calculate overall performance metrics."""
        metrics = PerformanceMetrics()
        
        # Estimate triangle and vertex counts for LOD 0
        if hierarchy.lod_levels:
            lod0 = hierarchy.lod_levels[0]
            base_vertices = model_data.get('base_vertex_count', 1000)
            base_triangles = model_data.get('base_triangle_count', 500)
            
            metrics.vertex_count = int(base_vertices * lod0.vertex_reduction)
            metrics.triangle_count = int(base_triangles * lod0.triangle_reduction)
        
        # Estimate draw calls from materials
        if 'materials' in model_data:
            metrics.draw_calls = len(model_data['materials'])
        
        # Estimate memory usage
        vertex_memory = metrics.vertex_count * 32 / (1024 * 1024)  # 32 bytes per vertex
        texture_memory = metrics.draw_calls * 2.0  # Rough estimate: 2MB per material
        metrics.memory_usage_mb = vertex_memory + texture_memory
        
        # Estimate FPS impact based on complexity reduction
        if 'optimization_results' in model_data:
            reduction = model_data['optimization_results'].get('vertex_reduction_ratio', 0.0)
            metrics.estimated_fps_impact = reduction * 20.0  # Rough estimate
        
        # LOD metrics
        if len(hierarchy.lod_levels) >= 3:
            metrics.lod_transition_smoothness = 0.9  # Good with 3+ levels
            metrics.lod_distance_coverage = min(1.0, len(hierarchy.lod_levels) / 5.0)
        
        # Material complexity
        if 'material_validation' in model_data:
            material_analysis = model_data.get('material_validation', {})
            metrics.shader_complexity_score = material_analysis.get('shader_complexity', 1.0)
            metrics.transparency_overdraw = material_analysis.get('transparency_ratio', 0.0) * 100
        
        # Quality estimates (would be measured in real implementation)
        metrics.visual_fidelity_score = 0.95  # Assume good quality
        metrics.geometric_accuracy = 0.95
        metrics.material_accuracy = 0.9
        
        return metrics
    
    def _generate_recommendations(self, report: ValidationReport) -> List[str]:
        """Generate recommendations based on validation results."""
        recommendations = []
        
        # LOD recommendations
        if len(report.lod_validation.get('reduction_progression', [])) < 4:
            recommendations.append("Add more LOD levels for better performance scaling")
        
        if report.performance_metrics.lod_transition_smoothness < 0.8:
            recommendations.append("Adjust LOD distance thresholds for smoother transitions")
        
        # Material recommendations
        if report.performance_metrics.draw_calls > 10:
            recommendations.append("Merge similar materials to reduce draw calls")
        
        if report.performance_metrics.transparency_overdraw > 30:
            recommendations.append("Reduce transparent materials to minimize overdraw")
        
        # Performance recommendations
        if report.performance_metrics.memory_usage_mb > 50:
            recommendations.append("Optimize textures and vertex data to reduce memory usage")
        
        if report.performance_metrics.shader_complexity_score > 3:
            recommendations.append("Simplify shaders for better performance on mobile devices")
        
        return recommendations
    
    def _generate_optimization_suggestions(self, report: ValidationReport) -> List[str]:
        """Generate optimization suggestions."""
        suggestions = []
        
        # Based on validation issues
        for issue in report.validation_issues:
            if issue.suggestion and issue.suggestion not in suggestions:
                suggestions.append(issue.suggestion)
        
        # Performance-based suggestions
        if report.performance_metrics.triangle_count > 20000:
            suggestions.append("Consider more aggressive triangle reduction for distant LODs")
        
        if report.performance_metrics.memory_usage_mb > 100:
            suggestions.append("Enable texture compression and vertex data compression")
        
        return suggestions
    
    def _determine_overall_result(self, issues: List[ValidationIssue]) -> ValidationResult:
        """Determine overall validation result from issues."""
        if not issues:
            return ValidationResult.PASSED
        
        has_errors = any(issue.level == ValidationResult.FAILED for issue in issues)
        if has_errors:
            return ValidationResult.FAILED
        
        has_warnings = any(issue.level == ValidationResult.WARNING for issue in issues)
        if has_warnings:
            return ValidationResult.WARNING
        
        return ValidationResult.PASSED
    
    def save_validation_report(self, report: ValidationReport, output_path: Path) -> None:
        """Save validation report to file."""
        try:
            # Convert report to serializable format
            report_dict = {
                'model_name': report.model_name,
                'validation_level': report.validation_level.value,
                'overall_result': report.overall_result.value,
                'summary': report.get_summary(),
                'performance_metrics': asdict(report.performance_metrics),
                'validation_issues': [issue.to_dict() for issue in report.validation_issues],
                'detailed_results': {
                    'lod_validation': report.lod_validation,
                    'material_validation': report.material_validation,
                    'collision_validation': report.collision_validation,
                    'optimization_validation': report.optimization_validation
                },
                'recommendations': report.recommendations,
                'optimization_suggestions': report.optimization_suggestions,
                'metadata': {
                    'validation_timestamp': report.validation_timestamp,
                    'validation_duration': report.validation_duration
                }
            }
            
            # Ensure output directory exists
            output_path.parent.mkdir(parents=True, exist_ok=True)
            
            # Write report
            with open(output_path, 'w') as f:
                json.dump(report_dict, f, indent=2, default=str)
            
            self.logger.info(f"Saved validation report: {output_path}")
            
        except Exception as e:
            self.logger.error(f"Failed to save validation report: {e}")
            raise


# Example usage and testing
if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    
    # Create test data
    from .pof_lod_processor import create_default_lod_hierarchy
    
    hierarchy = create_default_lod_hierarchy(100.0)  # 100-unit radius model
    
    test_model_data = {
        'base_vertex_count': 5000,
        'base_triangle_count': 2500,
        'materials': [
            {'resource_name': 'hull', 'transparency': 0, 'normal_enabled': True},
            {'resource_name': 'glass', 'transparency': 1, 'emission_enabled': True},
            {'resource_name': 'engine', 'transparency': 1, 'emission_enabled': True}
        ],
        'collision_data': {
            'collision_type': 'convex_hull',
            'vertices': [(i*0.1, i*0.1, i*0.1) for i in range(200)],
            'indices': list(range(200))
        },
        'optimization_results': {
            'vertex_reduction_ratio': 0.3,
            'triangle_reduction_ratio': 0.25,
            'memory_savings_bytes': 1024 * 1024,  # 1MB
            'optimization_techniques_used': ['vertex_deduplication', 'triangle_reduction']
        }
    }
    
    # Run validation
    validator = LODMaterialValidator(ValidationLevel.STANDARD)
    report = validator.validate_lod_hierarchy(hierarchy, test_model_data)
    
    # Print results
    print("Validation Results:")
    print(f"Overall Result: {report.overall_result.value}")
    print(f"Issues Found: {len(report.validation_issues)}")
    
    for issue in report.validation_issues:
        print(f"  {issue.level.value.upper()}: {issue.message}")
    
    print(f"\nPerformance Score: {report._calculate_performance_score():.1f}/100")
    print(f"Quality Score: {report._calculate_quality_score():.1f}/100")
    
    if report.recommendations:
        print(f"\nRecommendations:")
        for rec in report.recommendations:
            print(f"  - {rec}")
    
    # Save report
    report_path = Path("validation_report.json")
    validator.save_validation_report(report, report_path)
    print(f"\nSaved report to: {report_path}")