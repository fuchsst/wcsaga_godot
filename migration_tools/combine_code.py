import argparse
from pathlib import Path
import fnmatch
import os

def should_ignore_file(file_path: str, ignore_patterns: list) -> bool:
    """Check if file should be ignored based on patterns."""
    return any(fnmatch.fnmatch(file_path, pattern) for pattern in ignore_patterns)

def process_directory(root_dir: Path, output_dir: Path, ignore_patterns: list):
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
        # Create markdown content
        content = []
        for file_path in sorted(files):
            content.append(f"## {file_path}\n")
            content.append("```cpp")
            
            # Read and append file content
            with open(root_dir / file_path, 'r', encoding='utf-8') as f:
                content.append(f.read())
            
            content.append("```\n")
        
        # Create output filename
        output_filename = dir_path.replace('/', '_').replace('\\', '_') + '.md'
        output_path = output_dir / output_filename
        
        # Write markdown file
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write('\n'.join(content))

def main():
    parser = argparse.ArgumentParser(description='Combine C++ source files into markdown files by directory')
    parser.add_argument('input_dir', help='Input directory to process')
    parser.add_argument('output_dir', help='Output directory for markdown files')
    parser.add_argument('--ignore', nargs='+', default=[], 
                      help='Patterns to ignore (e.g. "test/*" "vendor/*")')
    
    args = parser.parse_args()
    
    try:
        process_directory(args.input_dir, args.output_dir, args.ignore)
        print(f"Processing complete. Output files written to {args.output_dir}")
    except Exception as e:
        print(f"Error: {e}")
        return 1
    
    return 0

if __name__ == '__main__':
    exit(main())
