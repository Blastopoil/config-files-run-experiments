#!/bin/bash

# Directory with the raw data
JOBS_DIR="1-output-jobs"
# Parser script to use
PARSER_SCRIPT=$1

if [ ! -d "$JOBS_DIR" ]; then
    echo "Error: Didn't find '$JOBS_DIR' with the current path"
    exit 1
fi

if [ ! -f "$PARSER_SCRIPT" ]; then
    echo "Error: Didn't find the script '$PARSER_SCRIPT'"
    echo "Sample usage: $0 ./data-parsing/simple_parser.sh"
    exit 1
fi

echo "========================================================"
echo "Starting batch processing of job outputs with the parser."
echo "Base directory: $JOBS_DIR"
echo "========================================================"

# 1. Iterate on level 1 (Level 1: BigO3, CVA6, MediumSonicBOOM...)
for core_dir in "$JOBS_DIR"/*; do
    if [ -d "$core_dir" ]; then
        core_name=$(basename "$core_dir")
        
        # 2. Iterate on level 2 (Level 2: LocalBP, TAGE_L, etc.)
        for bp_dir in "$core_dir"/*; do
            if [ -d "$bp_dir" ]; then
                bp_name=$(basename "$bp_dir")
                
                # All parsers assume a file structure with SPEC17/...
                if [ -d "$bp_dir/SPEC17" ]; then
                    
                    # Build arguments as required by the original script.
                    # Example: 1-output-jobs/MediumSonicBOOM/TAGE_SC_L
                    target_arg="$JOBS_DIR/$core_name/$bp_name"
                    
                    echo ">> Procesando: $core_name / $bp_name"
                    
                    # Script call with the target argument
                    $PARSER_SCRIPT "$target_arg"
                    
                else
                    echo "Skiping $core_name/$bp_name (Didn't find SPEC17 folder)"
                fi
            fi
        done
    fi
done

echo "========================================================"
echo "All data parsing finalized."
echo "========================================================"