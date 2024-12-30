import argparse
from pathlib import Path
import fnmatch
import os
import re

MAX_LINES_PER_FILE = 10000

def remove_cpp_comments(source: str) -> str:
    """Remove C and C++ style comments from source code."""
    # First, remove single line comments
    source = re.sub(r'//.*$', '', source, flags=re.MULTILINE)
    
    # Then remove multi-line comments
    source = re.sub(r'/\*.*?\*/', '', source, flags=re.DOTALL)
    
    # Remove empty lines and normalize whitespace
    lines = [line.strip() for line in source.splitlines()]
    lines = [line for line in lines if line]
    return '\n'.join(lines)

def should_ignore_file(file_path: str, ignore_patterns: list) -> bool:
    """Check if file should be ignored based on patterns."""
    return any(fnmatch.fnmatch(file_path, pattern) for pattern in ignore_patterns)

def count_lines(content_list: list) -> int:
    """Count total number of lines in a list of content strings."""
    return sum(len(str(content).splitlines()) for content in content_list)

def write_content_part(content: list, dir_path: str, part: int, output_dir: Path):
    """Write a part of the content to a markdown file."""
    file_name_base = dir_path.replace('/', '_').replace('\\', '_')
    if part == 0:
        output_filename = f"{file_name_base}.md"
    else:
        output_filename = f"{file_name_base}_part{part}.md"
    
    output_path = output_dir / output_filename
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(content))
    print(f"Created {output_filename}")

def process_directory(root_dir: Path, output_dir: Path, ignore_patterns: list, strip_comments: bool = True):
    """Process directory recursively and create markdown files."""
    root_dir = Path(root_dir).resolve()
    
    # Group files by directory
    dir_files = {}
    
    # Walk through directory
    for path in root_dir.rglob('*'):
        if path.is_file() and (path.suffix.lower() in ['.h', '.cpp']):
            rel_path = path.relative_to(root_dir)
            
            # Check if file should be ignored
            if should_ignore_file(str(rel_path), ignore_patterns):
                continue
                
            parent_dir = str(rel_path.parent)
            if parent_dir == '.':
                parent_dir = 'root'
                
            if parent_dir not in dir_files:
                dir_files[parent_dir] = []
            dir_files[parent_dir].append(rel_path)
    
    # Create output directory if it doesn't exist
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Process each directory
    for dir_path, files in dir_files.items():
        current_content = []
        current_lines = 0
        part = 0
        
        for file_path in sorted(files):
            # Create content for this file
            file_content = []
            file_content.append(f"## {file_path}\n")
            file_content.append("```cpp")
            
            # Try different encodings in order
            encodings = ['utf-8', 'windows-1252', 'iso-8859-1', 'latin1']
            source_content = None
            
            for encoding in encodings:
                try:
                    with open(root_dir / file_path, 'r', encoding=encoding) as f:
                        source_content = f.read()
                        break
                except UnicodeDecodeError:
                    continue
            
            if source_content is None:
                print(f"Warning: Could not decode {file_path} with any supported encoding")
                continue
            
            # Strip comments if requested
            if strip_comments:
                source_content = remove_cpp_comments(source_content)
                
            file_content.append(source_content)
            file_content.append("```\n")
            
            # Calculate lines that would be added
            file_lines = count_lines(file_content)
            
            # Check if adding this file would exceed the limit
            if current_lines + file_lines > MAX_LINES_PER_FILE and current_content:
                # Write current content as a part
                write_content_part(current_content, dir_path, part, output_dir)
                # Start new part
                current_content = []
                current_lines = 0
                part += 1
            
            # Add file content
            current_content.extend(file_content)
            current_lines += file_lines
        
        # Write remaining content
        if current_content:
            write_content_part(current_content, dir_path, part, output_dir)

def main():
    parser = argparse.ArgumentParser(description='Combine C++ source files into markdown files by directory')
    parser.add_argument('input_dir', help='Input directory to process')
    parser.add_argument('output_dir', help='Output directory for markdown files')
    parser.add_argument('--ignore', nargs='+', default=[], 
                      help='Patterns to ignore (e.g. "test/*" "vendor/*")')
    parser.add_argument('--keep-comments', action='store_true',
                      help='Keep comments in the output (default: remove comments)')
    parser.add_argument('--max-lines', type=int, default=MAX_LINES_PER_FILE,
                      help=f'Maximum lines per output file (default: {MAX_LINES_PER_FILE})')
    
    args = parser.parse_args()
    
    try:
        process_directory(args.input_dir, args.output_dir, args.ignore, strip_comments=not args.keep_comments)
        print(f"Processing complete. Output files written to {args.output_dir}")
    except Exception as e:
        print(f"Error: {e}")
        return 1
    
    return 0

if __name__ == '__main__':
    exit(main())
