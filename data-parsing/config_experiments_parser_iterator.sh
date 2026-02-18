#!/bin/bash

# --- Check for Arguments ---
echo "This script is hardcoded to look inside 1-output-jobs/BaseCPU, because of that no argument is taken"

# --- Configuration ---
# Base directories
ENV_FILE="./.env"
if [ -f "$ENV_FILE" ]; then
    set -a
    source "$ENV_FILE"
    set +a
else
    echo "Warning: .env file not found at $ENV_FILE. Please create it with the necessary variables."
fi
BASE_DIR=$repo_path
DATA_SRC_DIR="${BASE_DIR}/1-output-jobs/BaseCPU"
OUTPUT_DEST_DIR="${BASE_DIR}/2-parser-output"

OUTPUT_FILE="${OUTPUT_DEST_DIR}/config_experiments_data.csv"

# --- Validation ---
# Check if the source directory actually exists
if [ ! -d "$DATA_SRC_DIR" ]; then
    echo "Error: Directory not found: $DATA_SRC_DIR"
    echo "Please check your spelling of '$' and '$'."
    exit 1
fi

# Create the output directory if it doesn't exist
if [ ! -d "$OUTPUT_DEST_DIR" ]; then
    mkdir -p "$OUTPUT_DEST_DIR"
fi

# --- Initialize Output File ---
echo "frontend_width,backend_width,commit_width,rob_entries,lq_entries,sq_entries,iq_entries,int_regs,float_regs,cond_bp,App,IPC,Sim_Is,total_cond_predicts,wrong_cond_predicts,total_bp_mispredicts" > "$OUTPUT_FILE"

echo "------------------------------------------------"
echo "Reading from:     $DATA_SRC_DIR"
echo "Writing to:       $OUTPUT_FILE"
echo "------------------------------------------------"

# --- Main Loop ---
# Iterate through each APP folder inside the specific Config/Benchmark directory
# We use 'find' with -maxdepth 1 to look only at the immediate app folders (e.g., xz, mcf)
find "$DATA_SRC_DIR" -maxdepth 4 -mindepth 4 -type d | sort | while read app_dir; do

    # 1. Identify the App Name
    app_name=$(basename "$app_dir")
    stats_file="${app_dir}/stats.txt"
    config_file="${app_dir}/config.json"

    # 2. Check if stats.txt and config.ini exist
    if [ ! -f "$stats_file" ]; then
        echo "Warning: stats.txt not found for $app_name at $stats_file. Skipping."
        continue
    fi
    if [ ! -f "$config_file" ]; then
        echo "Warning: config.ini not found for $app_name at $config_file. Skipping."
        continue
    fi

    # 3. Extract Metrics
    # (from config.json)
    # Extract frontend_width
    sim_frontend_width=$(jq -r '.board.processor.cores[0].core.decodeWidth' "$config_file")
    # Extract backend_width
    sim_backend_width=$(jq -r '.board.processor.cores[0].core.dispatchWidth' "$config_file")
    # Extract commit_width
    sim_commit_width=$(jq -r '.board.processor.cores[0].core.commitWidth' "$config_file")
    # Extract rob_entries
    sim_rob_entries=$(jq -r '.board.processor.cores[0].core.numROBEntries' "$config_file")
    # Extract lq_entries
    sim_lq_entries=$(jq -r '.board.processor.cores[0].core.LQEntries' "$config_file")
    # Extract sq_entries
    sim_sq_entries=$(jq -r '.board.processor.cores[0].core.SQEntries' "$config_file")
    # Extract iq_entries
    sim_iq_entries=$(jq -r '.board.processor.cores[0].core.instQueues[0].numEntries' "$config_file")
    # Extract int_regs
    sim_int_regs=$(jq -r '.board.processor.cores[0].core.numPhysIntRegs' "$config_file")
    # Extract float_regs
    sim_float_regs=$(jq -r '.board.processor.cores[0].core.numPhysFloatRegs' "$config_file")
    # Extract cond_bp
    sim_cond_bp=$(jq -r '.board.processor.cores[0].core.branchPred.conditionalBranchPred.type' "$config_file")

    # (from stats.txt)
    # Extract IPC
    sim_ipc=$(grep "board.processor.cores.core.ipc" "$stats_file" | tail -n 1 | awk '{print $2}')
    # Extract number of instructions
    sim_Is=$(grep "simInsts" "$stats_file" | tail -n 1 | awk '{print $2}')    
    # Extract total conditional branch predictions
    sim_total_cond_preds=$(grep "board.processor.cores.core.branchPred.condPredicted" "$stats_file" | tail -n 1 | awk '{print $2}')
    # Extract conditional branch mispredictions
    sim_incorrect_cond_preds=$(grep "board.processor.cores.core.branchPred.condIncorrect" "$stats_file" | tail -n 1 | awk '{print $2}')
    # Extract total branch commited mispredicts
    sim_total_bp_mispredicts=$(grep "mispredictDueToPredictor_0::total" "$stats_file" | tail -n 1 | awk '{print $2}')

    # Handle missing values
    sim_ipc=${sim_ipc:-N/A}
    sim_Is=${sim_Is:-N/A}
    sim_total_cond_preds=${sim_total_cond_preds:-N/A}
    sim_incorrect_cond_preds=${sim_incorrect_cond_preds:-N/A}
    sim_total_bp_mispredicts=${sim_total_bp_mispredicts:-N/A}
    sim_frontend_width=${sim_frontend_width:-N/A}
    sim_backend_width=${sim_backend_width:-N/A}
    sim_commit_width=${sim_commit_width:-N/A}
    sim_rob_entries=${sim_rob_entries:-N/A}
    sim_lq_entries=${sim_lq_entries:-N/A}
    sim_sq_entries=${sim_sq_entries:-N/A}
    sim_iq_entries=${sim_iq_entries:-N/A}
    sim_int_regs=${sim_int_regs:-N/A}
    sim_float_regs=${sim_float_regs:-N/A}
    sim_cond_bp=${sim_cond_bp:-N/A}

    # 4. Append to Output CSV
    echo "${sim_frontend_width},${sim_backend_width},${sim_commit_width},${sim_rob_entries},${sim_lq_entries},${sim_sq_entries},${sim_iq_entries},${sim_int_regs},${sim_float_regs},${sim_cond_bp},${app_name},${sim_ipc},${sim_Is},${sim_total_cond_preds},${sim_incorrect_cond_preds},${sim_total_bp_mispredicts}" >> "$OUTPUT_FILE"
    echo "Processed App: $app_name"
done
echo "------------------------------------------------"
echo "Data parsing completed. Output written to: $OUTPUT_FILE"
echo "------------------------------------------------"
