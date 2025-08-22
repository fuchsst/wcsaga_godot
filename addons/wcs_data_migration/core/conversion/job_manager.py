#!/usr/bin/env python3
"""
Job Manager

Single Responsibility: Manage conversion jobs and their execution
Handles job creation, dependency resolution, and parallel execution.
"""

import logging
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from enum import Enum
from pathlib import Path
from typing import Any, Dict, List, Optional

logger = logging.getLogger(__name__)

class JobStatus(Enum):
    PENDING = "pending"
    RUNNING = "running" 
    COMPLETED = "completed"
    FAILED = "failed"
    SKIPPED = "skipped"

@dataclass
class ConversionJob:
    """Represents a single conversion task"""
    source_path: Path
    target_path: Path
    conversion_type: str
    priority: int
    dependencies: List[str]
    status: JobStatus = JobStatus.PENDING
    progress: float = 0.0
    error_message: Optional[str] = None
    file_hash: Optional[str] = None
    duplicate_of: Optional[str] = None

class JobManager:
    """
    Manages conversion jobs with dependency resolution and parallel execution.
    
    Single Responsibility: Job lifecycle management only
    """
    
    def __init__(self, max_workers: int = 4):
        self.max_workers = max_workers
        self.jobs: List[ConversionJob] = []
        self.job_index: Dict[str, ConversionJob] = {}
        self.logger = logging.getLogger(self.__class__.__name__)
    
    def create_conversion_plan(self, assets: Dict[str, List[Path]], target_dir: Path) -> List[ConversionJob]:
        """Create prioritized conversion jobs with dependency resolution"""
        jobs = []
        
        # Phase 1: VP Archives (highest priority, no dependencies)
        for vp_file in assets.get('vp_archives', []):
            job = ConversionJob(
                source_path=vp_file,
                target_path=target_dir / "assets" / "vp_extracted" / vp_file.stem,
                conversion_type="vp_extraction",
                priority=1,
                dependencies=[]
            )
            jobs.append(job)
        
        # Phase 2: Core Assets (medium priority, may depend on VP extraction)
        for pof_file in assets.get('pof_models', []):
            job = ConversionJob(
                source_path=pof_file,
                target_path=target_dir / "assets" / "models" / (pof_file.stem + ".glb"),
                conversion_type="pof_conversion",
                priority=2,
                dependencies=self._get_pof_dependencies(pof_file, assets)
            )
            jobs.append(job)
        
        # Phase 3: Mission Files (lower priority, may depend on models)
        for mission_file in assets.get('mission_files', []):
            job = ConversionJob(
                source_path=mission_file,
                target_path=target_dir / "assets" / "missions" / (mission_file.stem + ".tscn"),
                conversion_type="mission_conversion",
                priority=3,
                dependencies=self._get_mission_dependencies(mission_file, assets)
            )
            jobs.append(job)
        
        # Phase 4: Configuration Files (lowest priority)
        for config_file in assets.get('config_files', []):
            job = ConversionJob(
                source_path=config_file,
                target_path=target_dir / "resources" / "config" / (config_file.stem + ".tres"),
                conversion_type="config_migration",
                priority=4,
                dependencies=[]
            )
            jobs.append(job)
        
        # Sort by priority
        jobs.sort(key=lambda j: j.priority)
        
        self.jobs = jobs
        self._build_job_index()
        
        return jobs
    
    def execute_jobs(self, jobs: List[ConversionJob], progress_tracker) -> bool:
        """Execute jobs with dependency resolution and parallel processing"""
        try:
            # Group jobs by priority phase
            phases = self._group_jobs_by_priority(jobs)
            
            # Execute each phase sequentially, jobs within phase in parallel
            for phase_priority, phase_jobs in phases.items():
                self.logger.info(f"Executing phase {phase_priority} ({len(phase_jobs)} jobs)")
                
                success = self._execute_phase(phase_jobs, progress_tracker)
                if not success:
                    self.logger.error(f"Phase {phase_priority} failed")
                    return False
            
            return True
            
        except Exception as e:
            self.logger.error(f"Job execution failed: {e}")
            return False
    
    def _execute_phase(self, jobs: List[ConversionJob], progress_tracker) -> bool:
        """Execute a single phase of jobs in parallel"""
        with ThreadPoolExecutor(max_workers=self.max_workers) as executor:
            # Submit all jobs in this phase
            futures = []
            for job in jobs:
                if self._are_dependencies_satisfied(job):
                    future = executor.submit(self._execute_single_job, job, progress_tracker)
                    futures.append(future)
                else:
                    job.status = JobStatus.SKIPPED
                    job.error_message = "Dependencies not satisfied"
            
            # Wait for all jobs to complete
            success = True
            for future in futures:
                try:
                    job_success = future.result()
                    if not job_success:
                        success = False
                except Exception as e:
                    self.logger.error(f"Job execution error: {e}")
                    success = False
            
            return success
    
    def _execute_single_job(self, job: ConversionJob, progress_tracker) -> bool:
        """Execute a single conversion job"""
        try:
            job.status = JobStatus.RUNNING
            self.logger.info(f"Starting {job.conversion_type}: {job.source_path.name}")
            
            # TODO: Implement actual conversion logic based on job type
            success = self._perform_conversion(job)
            
            if success:
                job.status = JobStatus.COMPLETED
                job.progress = 100.0
                self.logger.info(f"Completed {job.conversion_type}: {job.source_path.name}")
            else:
                job.status = JobStatus.FAILED
                self.logger.error(f"Failed {job.conversion_type}: {job.source_path.name}")
            
            progress_tracker.update_job_progress(job)
            return success
            
        except Exception as e:
            job.status = JobStatus.FAILED
            job.error_message = str(e)
            self.logger.error(f"Job {job.source_path.name} failed: {e}")
            return False
    
    def _perform_conversion(self, job: ConversionJob) -> bool:
        """Perform the actual conversion based on job type"""
        # TODO: Implement conversion logic for each type
        # This is a placeholder that simulates work
        import time
        time.sleep(0.1)  # Simulate work
        return True
    
    def _group_jobs_by_priority(self, jobs: List[ConversionJob]) -> Dict[int, List[ConversionJob]]:
        """Group jobs by priority for phase execution"""
        phases = {}
        for job in jobs:
            if job.priority not in phases:
                phases[job.priority] = []
            phases[job.priority].append(job)
        return phases
    
    def _are_dependencies_satisfied(self, job: ConversionJob) -> bool:
        """Check if all job dependencies are satisfied"""
        for dep in job.dependencies:
            dep_job = self.job_index.get(dep)
            if not dep_job or dep_job.status != JobStatus.COMPLETED:
                return False
        return True
    
    def _get_pof_dependencies(self, pof_file: Path, assets: Dict[str, List[Path]]) -> List[str]:
        """Get dependencies for POF file conversion"""
        # TODO: Analyze POF file to determine texture dependencies
        return []
    
    def _get_mission_dependencies(self, mission_file: Path, assets: Dict[str, List[Path]]) -> List[str]:
        """Get dependencies for mission file conversion"""
        # TODO: Analyze mission file to determine model dependencies
        return []
    
    def _build_job_index(self) -> None:
        """Build index for fast job lookup"""
        self.job_index = {str(job.source_path): job for job in self.jobs}
    
    def get_active_jobs(self) -> List[ConversionJob]:
        """Get currently running jobs"""
        return [job for job in self.jobs if job.status == JobStatus.RUNNING]
    
    def get_completed_jobs(self) -> List[ConversionJob]:
        """Get completed jobs"""
        return [job for job in self.jobs if job.status == JobStatus.COMPLETED]
    
    def get_failed_jobs(self) -> List[ConversionJob]:
        """Get failed jobs"""
        return [job for job in self.jobs if job.status == JobStatus.FAILED]