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
DATA_SRC_DIR="${BASE_DIR}/1-output-jobs/BaseCPU_delay_experiments"
OUTPUT_DEST_DIR="${BASE_DIR}/2-parser-output"

OUTPUT_FILE="${OUTPUT_DEST_DIR}/delay_experiments_data.csv"

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
echo "general_delay,cond_bp,App,IPC,Sim_Is,total_cond_predicts,wrong_cond_predicts,total_bp_mispredicts" > "$OUTPUT_FILE"

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
    # Extract general delay from the fetch to rename delay
    sim_general_delay=$(jq -r '.board.processor.cores[0].core.fetchToDecodeDelay' "$config_file")
    # Extract cond_bp
    sim_cond_bp=$(jq -r '.board.processor.cores[0].core.branchPred.conditionalBranchPred.type' "$config_file")
    if [ "$sim_cond_bp" == "AlwaysBooleanBP" ]; then
        always_true=$(jq -r '.board.processor.cores[0].core.branchPred.conditionalBranchPred.alwaysTruePreds' "$config_file")
        if [ "$always_true" == "true" ]; then
            sim_cond_bp="AlwaysTrueBP"
        else
            sim_cond_bp="AlwaysFalseBP"
        fi
    elif [ "$sim_cond_bp" == "TAGE_SC_L_64KB" ]; then
        disable_loop_pred=$(jq -r '.board.processor.cores[0].core.branchPred.conditionalBranchPred.loop_predictor.disable' "$config_file")
        disable_sc=$(jq -r '.board.processor.cores[0].core.branchPred.conditionalBranchPred.statistical_corrector.disable' "$config_file")
        if [ "$disable_loop_pred" == "false" ] && [ "$disable_sc" == "false" ]; then
            sim_cond_bp="TAGE_SC_L"
        elif [ "$disable_loop_pred" == "false" ]; then
            sim_cond_bp="TAGE_SC"
        elif [ "$disable_sc" == "false" ]; then
            sim_cond_bp="TAGE_L"
        fi
    fi

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
    sim_general_delay=${sim_general_delay:-N/A}
    sim_cond_bp=${sim_cond_bp:-N/A}

    # 4. Append to Output CSV
    echo "${sim_general_delay},${sim_cond_bp},${app_name},${sim_ipc},${sim_Is},${sim_total_cond_preds},${sim_incorrect_cond_preds},${sim_total_bp_mispredicts}" >> "$OUTPUT_FILE"
    echo "Processed App: $app_name"
done
echo "------------------------------------------------"
echo "Data parsing completed. Output written to: $OUTPUT_FILE"
echo "------------------------------------------------"
