#!/bin/bash

# --- Check for Arguments ---
# We ensure the user provided both Config and Benchmark names
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 Folder inside 1-output-jobs/ with all the results "
    echo "Example: $0 1-output-jobs/SmallO3"
    exit 1
fi

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
DATA_SRC_DIR="${BASE_DIR}/${1}"
OUTPUT_DEST_DIR="${BASE_DIR}/2-parser-output"

# Define the output filename based on the inputs
# This creates a file like: parsed_results_MediumSonicBOOM_SPEC17.csv
results_file_name=$(echo $1 | sed -r 's#^1-output-jobs/##' | sed s#/#_#g)
OUTPUT_FILE="${OUTPUT_DEST_DIR}/${results_file_name}_gshare_data.csv"

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
echo "cond_bp,App,IPC,Sim_Is,total_cond_predicts,wrong_cond_predicts,lookup_used_ghr1,lookup_used_ghr2,update_used_ghr1,update_used_ghr2,lookup_used_ghr_exclusive,lookup_used_ghr_inclusive,update_used_ghr_exclusive,update_used_ghr_inclusive" > "$OUTPUT_FILE"

echo "------------------------------------------------"
echo "Reading from:     $DATA_SRC_DIR"
echo "Writing to:       $OUTPUT_FILE"
echo "------------------------------------------------"

# Populate branch predictor history counters depending on predictor type.
# Returns 0 for supported predictor types and 1 for unsupported ones.
extract_ghr_usage_metrics() {
    local bp_type="$1"
    local stats_path="$2"

    sim_lookup_used_ghr1=0
    sim_lookup_used_ghr2=0
    sim_update_used_ghr1=0
    sim_update_used_ghr2=0
    sim_lookup_used_ghr_exclusive=0
    sim_lookup_used_ghr_inclusive=0
    sim_update_used_ghr_exclusive=0
    sim_update_used_ghr_inclusive=0

    case "$bp_type" in
        GshareBP)
            ;;
        GshareReplicatedBP)
            sim_lookup_used_ghr1=$(grep "conditionalBranchPred.lookupUsedGhr1" "$stats_path" | tail -n 1 | awk '{print $2}')
            sim_lookup_used_ghr2=$(grep "conditionalBranchPred.lookupUsedGhr2" "$stats_path" | tail -n 1 | awk '{print $2}')
            sim_update_used_ghr1=$(grep "conditionalBranchPred.updateUsedGhr1" "$stats_path" | tail -n 1 | awk '{print $2}')
            sim_update_used_ghr2=$(grep "conditionalBranchPred.updateUsedGhr2" "$stats_path" | tail -n 1 | awk '{print $2}')
            ;;
        GshareReplicatedInclusiveBP)
            sim_lookup_used_ghr_exclusive=$(grep "conditionalBranchPred.lookupUsedGhrExclusive" "$stats_path" | tail -n 1 | awk '{print $2}')
            sim_lookup_used_ghr_inclusive=$(grep "conditionalBranchPred.lookupUsedGhrInclusive" "$stats_path" | tail -n 1 | awk '{print $2}')
            sim_update_used_ghr_exclusive=$(grep "conditionalBranchPred.updateUsedGhrExclusive" "$stats_path" | tail -n 1 | awk '{print $2}')
            sim_update_used_ghr_inclusive=$(grep "conditionalBranchPred.updateUsedGhrInclusive" "$stats_path" | tail -n 1 | awk '{print $2}')
            ;;
        *)
            return 1
            ;;
    esac

    sim_lookup_used_ghr1=${sim_lookup_used_ghr1:-0}
    sim_lookup_used_ghr2=${sim_lookup_used_ghr2:-0}
    sim_update_used_ghr1=${sim_update_used_ghr1:-0}
    sim_update_used_ghr2=${sim_update_used_ghr2:-0}
    sim_lookup_used_ghr_exclusive=${sim_lookup_used_ghr_exclusive:-0}
    sim_lookup_used_ghr_inclusive=${sim_lookup_used_ghr_inclusive:-0}
    sim_update_used_ghr_exclusive=${sim_update_used_ghr_exclusive:-0}
    sim_update_used_ghr_inclusive=${sim_update_used_ghr_inclusive:-0}

    return 0
}

# --- Main Loop ---
# Iterate through each APP folder inside the specific Config/Benchmark directory
# We use 'find' with -maxdepth 1 to look only at the immediate app folders (e.g., xz, mcf)
find "$DATA_SRC_DIR" -maxdepth 3 -mindepth 3 -type d | sort | while read app_dir; do
    
    # 1. Identify the App Name
    app_name=$(basename "$app_dir")
    stats_file="${app_dir}/stats.txt"
    config_file="${app_dir}/config.json"

    # 2. Check if stats.txt and config.json exist
    if [ ! -f "$stats_file" ]; then
        echo "Warning: stats.txt not found for $app_name at $stats_file. Skipping."
        continue
    fi
    if [ ! -f "$config_file" ]; then
        echo "Warning: config.json not found for $app_name at $config_file. Skipping."
        continue
    fi
        
    # 3. Extract Metrics
    # (from config.json)
    # Extract cond_bp
    sim_cond_bp=$(jq -r '.board.processor.cores[0].core.branchPred.conditionalBranchPred.type' "$config_file")
    raw_cond_bp="$sim_cond_bp"

    if [ "$raw_cond_bp" == "GshareBP" ]; then
        length=$(jq -r '.board.processor.cores[0].core.branchPred.conditionalBranchPred.global_predictor_size' "$config_file")
        if [ "$length" == 512 ]; then
            sim_cond_bp="GshareBP"
        elif [ "$length" == 4096 ]; then
            sim_cond_bp="LongGshareBP"
        fi

        extract_ghr_usage_metrics "$raw_cond_bp" "$stats_file"
    elif [ "$raw_cond_bp" == "GshareReplicatedBP" ]; then
        length=$(jq -r '.board.processor.cores[0].core.branchPred.conditionalBranchPred.global_predictor_size' "$config_file")
        if [ "$length" == 512 ]; then
            sim_cond_bp="GshareReplicatedBP"
        elif [ "$length" == 4096 ]; then
            sim_cond_bp="LongGshareReplicatedBP"
        elif [ "$length" == 256 ]; then
            sim_cond_bp="PartitionedGshareReplicatedBP"
        elif [ "$length" == 2048 ]; then
            sim_cond_bp="LongPartitionedGshareReplicatedBP"
        fi

        extract_ghr_usage_metrics "$raw_cond_bp" "$stats_file"
    elif [ "$raw_cond_bp" == "GshareReplicatedInclusiveBP" ]; then
        length=$(jq -r '.board.processor.cores[0].core.branchPred.conditionalBranchPred.global_predictor_size' "$config_file")
        if [ "$length" == 512 ]; then
            sim_cond_bp="GshareInclusiveBP"
        elif [ "$length" == 4096 ]; then
            sim_cond_bp="LongGshareInclusiveBP"
        elif [ "$length" == 256 ]; then
            sim_cond_bp="PartitionedGshareInclusiveBP"
        elif [ "$length" == 2048 ]; then
            sim_cond_bp="LongPartitionedGshareInclusiveBP"
        fi

        extract_ghr_usage_metrics "$raw_cond_bp" "$stats_file"
    fi

    # Skip this app if the predictor is not one of the supported mapped names.
    case "$sim_cond_bp" in
        GshareBP|LongGshareBP|GshareReplicatedBP|LongGshareReplicatedBP|PartitionedGshareReplicatedBP|LongPartitionedGshareReplicatedBP|GshareInclusiveBP|LongGshareInclusiveBP|PartitionedGshareInclusiveBP|LongPartitionedGshareInclusiveBP)
            ;;
        *)
            echo "Skipping App: $app_name (unsupported sim_cond_bp: $sim_cond_bp)"
            continue
            ;;
    esac
    

    # (from stats.txt)
    # Extract IPC
    sim_ipc=$(grep "board.processor.cores.core.ipc" "$stats_file" | tail -n 1 | awk '{print $2}')

    # Extract number of instructions
    sim_Is=$(grep "simInsts" "$stats_file" | tail -n 1 | awk '{print $2}')
    
    # Extract total conditional branch predictions
    sim_total_cond_preds=$(grep "branchPred.committed_0::DirectCond" "$stats_file" | tail -n 1 | awk '{print $2}')

    # Extract conditional branch mispredictions due to the conditional predictor
    sim_incorrect_cond_preds=$(grep "mispredictDueToPredictor_0::DirectCond" "$stats_file" | tail -n 1 | awk '{print $2}')

    # Handle missing values
    sim_ipc=${sim_ipc:-N/A}
    sim_Is=${sim_Is:-N/A}
    sim_total_cond_preds=${sim_total_cond_preds:-N/A}
    sim_incorrect_cond_preds=${sim_incorrect_cond_preds:-N/A}
    sim_cond_bp=${sim_cond_bp:-N/A}
    sim_lookup_used_ghr1=${sim_lookup_used_ghr1:-0}
    sim_lookup_used_ghr2=${sim_lookup_used_ghr2:-0}
    sim_update_used_ghr1=${sim_update_used_ghr1:-0}
    sim_update_used_ghr2=${sim_update_used_ghr2:-0}
    sim_lookup_used_ghr_exclusive=${sim_lookup_used_ghr_exclusive:-0}
    sim_lookup_used_ghr_inclusive=${sim_lookup_used_ghr_inclusive:-0}
    sim_update_used_ghr_exclusive=${sim_update_used_ghr_exclusive:-0}
    sim_update_used_ghr_inclusive=${sim_update_used_ghr_inclusive:-0}

    # 4. Save to CSV
    echo "$sim_cond_bp,$app_name,$sim_ipc,$sim_Is,$sim_total_cond_preds,$sim_incorrect_cond_preds,$sim_lookup_used_ghr1,$sim_lookup_used_ghr2,$sim_update_used_ghr1,$sim_update_used_ghr2,$sim_lookup_used_ghr_exclusive,$sim_lookup_used_ghr_inclusive,$sim_update_used_ghr_exclusive,$sim_update_used_ghr_inclusive" >> "$OUTPUT_FILE"
    echo "Processed App: $app_name"

done

echo "------------------------------------------------"
echo "Done! Results saved to: $OUTPUT_FILE"