#!/usr/bin/env python3
import logging
from typing import BinaryIO, List

# Import necessary helper functions and constants from pof_chunks
from .pof_chunks import read_int, read_string_len

logger = logging.getLogger(__name__)

def read_txtr_chunk(f: BinaryIO, length: int) -> List[str]:
    """Parses the Texture Filenames (TXTR) chunk."""
    num_textures = read_int(f)
    textures = []
    # Use a reasonable max length for texture filenames, adjust if needed
    max_texture_name_len = 64
    for _ in range(num_textures):
        textures.append(read_string_len(f, max_texture_name_len))
    return textures
