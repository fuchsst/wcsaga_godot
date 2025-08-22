#!/usr/bin/env python3
"""
Progress Tracker

Single Responsibility: Track and report conversion progress
Provides real-time progress updates and statistics.
"""

import logging
import time
from dataclasses import dataclass
from threading import Lock
from typing import Any, Callable, Dict, List, Optional

from .job_manager import ConversionJob, JobStatus

logger = logging.getLogger(__name__)

@dataclass
class ProgressStats:
    """Progress statistics"""
    total_jobs: int = 0
    completed_jobs: int = 0
    failed_jobs: int = 0
    running_jobs: int = 0
    overall_progress: float = 0.0
    start_time: Optional[float] = None
    end_time: Optional[float] = None
    
    @property
    def elapsed_time(self) -> float:
        if self.start_time is None:
            return 0.0
        end = self.end_time or time.time()
        return end - self.start_time
    
    @property
    def estimated_time_remaining(self) -> Optional[float]:
        if self.overall_progress <= 0 or self.start_time is None:
            return None
        
        elapsed = self.elapsed_time
        total_estimated = elapsed / (self.overall_progress / 100.0)
        return total_estimated - elapsed

class ProgressTracker:
    """
    Tracks conversion progress with thread-safe updates.
    
    Single Responsibility: Progress tracking and reporting only
    """
    
    def __init__(self):
        self.stats = ProgressStats()
        self.job_progress: Dict[str, float] = {}
        self.callbacks: List[Callable[[ProgressStats], None]] = []
        self._lock = Lock()
        self.logger = logging.getLogger(self.__class__.__name__)
    
    def start_conversion(self, total_jobs: int) -> None:
        """Start tracking conversion progress"""
        with self._lock:
            self.stats = ProgressStats(
                total_jobs=total_jobs,
                start_time=time.time()
            )
            self.job_progress.clear()
        
        self.logger.info(f"Started tracking {total_jobs} conversion jobs")
        self._notify_callbacks()
    
    def update_job_progress(self, job: ConversionJob) -> None:
        """Update progress for a specific job"""
        with self._lock:
            job_key = str(job.source_path)
            self.job_progress[job_key] = job.progress
            
            # Update overall statistics
            self._recalculate_stats()
        
        self._notify_callbacks()
    
    def complete_conversion(self, success: bool) -> None:
        """Mark conversion as complete"""
        with self._lock:
            self.stats.end_time = time.time()
            
            if success:
                self.stats.overall_progress = 100.0
                self.logger.info(f"Conversion completed successfully in {self.stats.elapsed_time:.2f}s")
            else:
                self.logger.error(f"Conversion failed after {self.stats.elapsed_time:.2f}s")
        
        self._notify_callbacks()
    
    def add_progress_callback(self, callback: Callable[[ProgressStats], None]) -> None:
        """Add a callback for progress updates"""
        self.callbacks.append(callback)
    
    def remove_progress_callback(self, callback: Callable[[ProgressStats], None]) -> None:
        """Remove a progress callback"""
        if callback in self.callbacks:
            self.callbacks.remove(callback)
    
    def get_progress(self) -> ProgressStats:
        """Get current progress statistics"""
        with self._lock:
            return ProgressStats(
                total_jobs=self.stats.total_jobs,
                completed_jobs=self.stats.completed_jobs,
                failed_jobs=self.stats.failed_jobs,
                running_jobs=self.stats.running_jobs,
                overall_progress=self.stats.overall_progress,
                start_time=self.stats.start_time,
                end_time=self.stats.end_time
            )
    
    def get_detailed_progress(self) -> Dict[str, Any]:
        """Get detailed progress information"""
        with self._lock:
            return {
                'stats': self.get_progress(),
                'job_progress': dict(self.job_progress),
                'time_info': {
                    'elapsed': self.stats.elapsed_time,
                    'estimated_remaining': self.stats.estimated_time_remaining
                }
            }
    
    def _recalculate_stats(self) -> None:
        """Recalculate overall statistics (called with lock held)"""
        total_progress = sum(self.job_progress.values())
        
        if self.stats.total_jobs > 0:
            self.stats.overall_progress = total_progress / self.stats.total_jobs
        else:
            self.stats.overall_progress = 0.0
        
        # Count job statuses (this would need job status info passed in)
        self.stats.completed_jobs = sum(1 for progress in self.job_progress.values() if progress >= 100.0)
        self.stats.running_jobs = sum(1 for progress in self.job_progress.values() if 0 < progress < 100.0)
        
        # Failed jobs would need to be tracked separately with job status updates
    
    def _notify_callbacks(self) -> None:
        """Notify all registered callbacks of progress update"""
        current_stats = self.get_progress()
        
        for callback in self.callbacks:
            try:
                callback(current_stats)
            except Exception as e:
                self.logger.warning(f"Progress callback failed: {e}")
    
    def log_progress_summary(self) -> None:
        """Log a summary of current progress"""
        stats = self.get_progress()
        
        self.logger.info("Progress Summary:")
        self.logger.info(f"  Overall: {stats.overall_progress:.1f}%")
        self.logger.info(f"  Completed: {stats.completed_jobs}/{stats.total_jobs}")
        self.logger.info(f"  Failed: {stats.failed_jobs}")
        self.logger.info(f"  Running: {stats.running_jobs}")
        self.logger.info(f"  Elapsed: {stats.elapsed_time:.1f}s")
        
        if stats.estimated_time_remaining:
            self.logger.info(f"  Estimated remaining: {stats.estimated_time_remaining:.1f}s")