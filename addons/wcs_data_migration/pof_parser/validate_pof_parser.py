#!/usr/bin/env python3
"""
POF Parser Validation Script

Quick validation script to ensure POF parser components can be imported
and instantiated correctly after cleanup.
"""

import logging
import sys
from pathlib import Path

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def validate_imports():
    """Validate that all POF parser modules can be imported."""
    try:
        from . import POFDataExtractor, POFFormatAnalyzer, POFParser
        logger.info("✓ Successfully imported main classes")
        
        from .pof_chunks import PM_COMPATIBLE_VERSION, POF_HEADER_ID
        logger.info("✓ Successfully imported constants")
        
        from .cli import main as cli_main
        logger.info("✓ Successfully imported CLI")
        
        return True
        
    except ImportError as e:
        logger.error(f"✗ Import error: {e}")
        return False
    except Exception as e:
        logger.error(f"✗ Unexpected error during import: {e}")
        return False

def validate_instantiation():
    """Validate that main classes can be instantiated."""
    try:
        from . import POFDataExtractor, POFFormatAnalyzer, POFParser
        
        parser = POFParser()
        logger.info("✓ POFParser instantiated successfully")
        
        analyzer = POFFormatAnalyzer()
        logger.info("✓ POFFormatAnalyzer instantiated successfully")
        
        extractor = POFDataExtractor()
        logger.info("✓ POFDataExtractor instantiated successfully")
        
        return True
        
    except Exception as e:
        logger.error(f"✗ Instantiation error: {e}")
        return False

def validate_constants():
    """Validate that constants are properly defined."""
    try:
        from .pof_chunks import (ID_ACEN, ID_DOCK, ID_EYE, ID_FUEL, ID_GLOW,
                                 ID_GPNT, ID_INSG, ID_MPNT, ID_OHDR, ID_PATH,
                                 ID_SHLD, ID_SLDC, ID_SOBJ, ID_SPCL, ID_TXTR,
                                 PM_COMPATIBLE_VERSION,
                                 PM_OBJFILE_MAJOR_VERSION, POF_HEADER_ID)

        # Validate some key constants
        assert POF_HEADER_ID == 0x4f505350, "POF_HEADER_ID constant incorrect"
        assert PM_COMPATIBLE_VERSION == 1900, "PM_COMPATIBLE_VERSION constant incorrect"
        assert ID_OHDR == 0x32524448, "ID_OHDR constant incorrect"
        
        logger.info("✓ Constants validation passed")
        return True
        
    except AssertionError as e:
        logger.error(f"✗ Constant validation failed: {e}")
        return False
    except Exception as e:
        logger.error(f"✗ Error validating constants: {e}")
        return False

def main():
    """Run all validation checks."""
    logger.info("Starting POF parser validation...")
    
    checks = [
        ("Import validation", validate_imports),
        ("Instantiation validation", validate_instantiation),
        ("Constants validation", validate_constants),
    ]
    
    passed = 0
    total = len(checks)
    
    for check_name, check_func in checks:
        logger.info(f"\nRunning {check_name}...")
        if check_func():
            passed += 1
        else:
            logger.error(f"Failed: {check_name}")
    
    logger.info(f"\n=== Validation Summary ===")
    logger.info(f"Passed: {passed}/{total} checks")
    
    if passed == total:
        logger.info("🎉 All validation checks passed!")
        return True
    else:
        logger.error("❌ Some validation checks failed")
        return False

if __name__ == '__main__':
    success = main()
    sys.exit(0 if success else 1)