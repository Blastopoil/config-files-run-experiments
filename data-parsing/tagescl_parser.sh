#!/bin/bash

# --- Check for Arguments ---
# We ensure the user provided both Config and Benchmark names
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 Folder inside 1-output-jobs/ with all the results "
    echo "Example: $0 1-output-jobs/MediumSonicBOOM/TAGE_SC_L"
    exit 1
fi

# --- Configuration ---
# Base directories
ENV_FILE="./../.env"
if [ -f "$ENV_FILE" ]; then
    set -a
    source "$ENV_FILE"
    set +a
else
    echo "Warning: .env file not found at $ENV_FILE. Please create it with the necessary variables."
fi
BASE_DIR=$repo_path
DATA_SRC_DIR="${BASE_DIR}/${1}/SPEC17"
OUTPUT_DEST_DIR="${BASE_DIR}/2-parser-output"

# Define the output filename based on the inputs
# This creates a file like: parsed_results_MediumSonicBOOM_SPEC17.csv
results_file_name=$(echo $1 | sed -r 's/^1-output-jobs//' | sed s#/#_#g)
OUTPUT_FILE="${OUTPUT_DEST_DIR}/tagescl_data${results_file_name}.csv"

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
echo "App,IPC,Sim_Is,Exec_Is,total_cond_predicts,wrong_cond_predicts,loop_pred_used,loop_pred_correct,loop_pred_wrong,sc_correct,sc_wrong" > "$OUTPUT_FILE"

echo "------------------------------------------------"
echo "Reading from:     $DATA_SRC_DIR"
echo "Writing to:       $OUTPUT_FILE"
echo "------------------------------------------------"

# --- Main Loop ---
# Iterate through each APP folder inside the specific Config/Benchmark directory
# We use 'find' with -maxdepth 1 to look only at the immediate app folders (e.g., xz, mcf)
find "$DATA_SRC_DIR" -maxdepth 1 -mindepth 1 -type d | sort | while read app_dir; do
    
    # 1. Identify the App Name
    app_name=$(basename "$app_dir")
    stats_file="${app_dir}/stats.txt"

    # 2. Check if stats.txt exists
    if [ -f "$stats_file" ]; then
        
        # 3. Extract Metrics
        # Extract IPC
        sim_ipc=$(grep "board.processor.cores.core.ipc" "$stats_file" | tail -n 1 | awk '{print $2}')
        
        # Extract total conditional branch predictions
        sim_total_cond_preds=$(grep "board.processor.cores.core.branchPred.condPredicted" "$stats_file" | tail -n 1 | awk '{print $2}')

        # Extract conditional branch mispredictions
        sim_incorrect_cond_preds=$(grep "board.processor.cores.core.branchPred.condIncorrect" "$stats_file" | tail -n 1 | awk '{print $2}')

        #Extract component specific data
        sim_loop_pred_used=$(grep "board.processor.cores.core.branchPred.conditionalBranchPred.loop_predictor.used" "$stats_file" | tail -n 1 | awk '{print $2}')
        sim_loop_pred_correct=$(grep "board.processor.cores.core.branchPred.conditionalBranchPred.loop_predictor.correct" "$stats_file" | tail -n 1 | awk '{print $2}')
        sim_loop_pred_wrong=$(grep "board.processor.cores.core.branchPred.conditionalBranchPred.loop_predictor.wrong" "$stats_file" | tail -n 1 | awk '{print $2}')

        sim_sc_correct=$(grep "board.processor.cores.core.branchPred.conditionalBranchPred.statistical_corrector.correct" "$stats_file" | tail -n 1 | awk '{print $2}')
        sim_sc_wrong=$(grep "board.processor.cores.core.branchPred.conditionalBranchPred.statistical_corrector.wrong" "$stats_file" | tail -n 1 | awk '{print $2}')

        # Extract number of instructions
        sim_Is=$(grep "simInsts" "$stats_file" | tail -n 1 | awk '{print $2}')
        exec_Is=$(grep "board.processor.cores.core.executeStats0.numInsts" "$stats_file" | tail -n 1 | awk '{print $2}')

        # Handle missing values
        sim_ipc=${sim_ipc:-N/A}
        sim_total_cond_preds=${sim_total_cond_preds:-N/A}
        sim_incorrect_cond_preds=${sim_incorrect_cond_preds:-N/A}
        sim_loop_pred_used=${sim_loop_pred_used:-N/A}
        sim_loop_pred_correct=${sim_loop_pred_correct:-N/A}
        sim_loop_pred_wrong=${sim_loop_pred_wrong:-N/A}
        sim_sc_correct=${sim_sc_correct:-N/A}
        sim_sc_wrong=${sim_sc_wrong:-N/A}
        sim_Is=${sim_Is:-N/A}
        exec_Is=${exec_Is:-N/A}


        # 4. Save to CSV
        echo "$app_name,$sim_ipc,$sim_Is,$exec_Is,$sim_total_cond_preds,$sim_incorrect_cond_preds,$sim_loop_pred_used,$sim_loop_pred_correct,$sim_loop_pred_wrong,$sim_sc_correct,$sim_sc_wrong" >> "$OUTPUT_FILE"
        echo "Processed App: $app_name"
        
    else
        echo "WARNING: No stats.txt found in app: $app_name"
    fi

done

echo "------------------------------------------------"
echo "Done! Results saved to: $OUTPUT_FILE"