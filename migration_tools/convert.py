#!/usr/bin/env python3
import argparse
import logging
from converters import DDSConverter, PCXConverter, ANIConverter, POFConverter, FS2Converter, FC2Converter

def main():
    parser = argparse.ArgumentParser(description='Convert game assets to Godot-friendly formats')
    parser.add_argument('-i', '--input', default='extracted',
                      help='Input directory containing extracted files')
    parser.add_argument('-o', '--output', default='converted',
                      help='Output directory for converted files')
    parser.add_argument('-v', '--verbose', action='store_true',
                      help='Enable verbose output')
    parser.add_argument('--format', choices=['dds', 'eff', 'ani', 'pof', 'pcx', 'tbl', 'fs2', 'fc2', 'frc', 'vf'],
                      help='Only convert files of specified format')
    parser.add_argument('-f', '--force', action='store_true',
                      help='Force conversion even if output files exist')
    
    args = parser.parse_args()
    
    # Setup logging
    log_level = logging.DEBUG if args.verbose else logging.INFO
    logging.basicConfig(level=log_level, format='%(asctime)s %(levelname)-8s [%(filename)s:%(lineno)d] %(message)s')
    
    # Initialize converters
    converters = []
    
    # Initialize appropriate converters based on format argument
    if args.format == 'dds' or args.format is None:
        converters.append(DDSConverter(args.input, args.output, args.force))
    if args.format == 'pcx' or args.format is None:
        converters.append(PCXConverter(args.input, args.output, args.force))
    if args.format == 'ani' or args.format is None:
        converters.append(ANIConverter(args.input, args.output, args.force))
    if args.format == 'pof' or args.format is None:
        converters.append(POFConverter(args.input, args.output, args.force))
    if args.format == 'fs2' or args.format is None:
        converters.append(FS2Converter(args.input, args.output, args.force))
    if args.format == 'fc2' or args.format is None:
        converters.append(FC2Converter(args.input, args.output, args.force))
    
    # Convert files
    success = True
    for converter in converters:
        if not converter.convert_all():
            success = False
            
    return 0 if success else 1

if __name__ == '__main__':
    exit(main())
