#!/usr/bin/env python3
"""
Main entry point for Indian EHV Substation Digital Twin
"""

import sys
import os
from pathlib import Path

# Add src directory to Python path
src_path = Path(__file__).parent / "src"
sys.path.insert(0, str(src_path))

# Import and run the digital twin
if __name__ == "__main__":
    # Import the digital twin server module
    import api.digital_twin_server
    # The server will start automatically when the module is imported