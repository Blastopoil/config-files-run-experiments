#!/usr/bin/env python3
import subprocess
import os
import time
import argparse

def get_applications_by_benchmark(ckpt_base_dir):
    """Discover applications by reading checkpoint directories."""
    if not os.path.exists(ckpt_base_dir):
        print(f"Warning: Checkpoint path does not exist: {ckpt_base_dir}")
        return []
    
    apps = []
    for item in os.listdir(ckpt_base_dir):
        if item.startswith("ckpt_"):
            app_name = item.replace("ckpt_", "")
            apps.append(app_name)
    
    return sorted(apps)


def create_directory(path, clean_if_exists=False):
    """Create a directory, optionally cleaning it if it already exists."""
    if clean_if_exists and os.path.exists(path):
        import shutil
        shutil.rmtree(path)
    os.makedirs(path, exist_ok=True)
    return path

#SBATCH --nodelist=ce209
def generate_sbatch_script(gem5_binary, config_script, spec_dir, app, config_name, bp, 
                           output_dir, mem_size, slurm_mem_size, extra_params_dict):
    """Generate an sbatch script for running simulation with specific IQ size."""
    
    spec_number = app[:3]
    # Convert dictionary to string for command line argument
    extra_params_str = str(extra_params_dict)
    
    sbatch_content = f"""#!/bin/bash
#SBATCH --partition=ce_200
#SBATCH --exclude=ce210
#SBATCH --mem-per-cpu={slurm_mem_size}
#SBATCH --job-name={app}_{config_name}
#SBATCH --output={output_dir}/slurm-%j.out

cd {spec_dir}/{app}

{gem5_binary}  -re --outdir={output_dir} {config_script} \
    --spec_number {spec_number} \
    --config {config_name} \
    --bp {bp} \
    --mem_size {mem_size} \
    --num_ticks 100000000000 \
    --extra_params "{extra_params_str}"
"""
    # Note: We wrap extra_params_str in quotes to handle spaces/brackets in bash

    script_path = os.path.join(output_dir, "run.sbatch")
    with open(script_path, "w") as f:
        f.write(sbatch_content)
    
    return script_path

#--debug-flags=LTage,TageSCL
def submit_job(script_path):
    """Submit the job using sbatch and return job ID."""
    result = subprocess.run(["sbatch", script_path], capture_output=True, text=True)
    if result.returncode == 0:
        # Extract job ID from output like "Submitted batch job 12345"
        job_id = result.stdout.strip().split()[-1]
        return job_id
    else:
        print(f"Error submitting job: {result.stderr}")
        return None


def main():
    parser = argparse.ArgumentParser(description="Run gem5 simulations with divided IQ for different benchmarks.")
    parser.add_argument(
        "--benchmark", 
        choices=["SPEC17"],
        required=True,
        help="Benchmark to run (or ALL for all benchmarks)"
    )
    spec_choices = [ 502, 503, 505, 507, 508, 510, 511, 519, 520, 521, 523, 
                     526, 527, 531, 541, 544, 548, 549, 554, 557 ]
    parser.add_argument(
        "--spec_number",
        nargs='?', 
        help=f"SPEC17 app identification's tag: {list(spec_choices)}, if not specified, runs all SPES17 apps"
    )
    bp_choices = ["TAGE_SC_L", "TAGE_SC", "TAGE_L", "LocalBP", "BiModeBP", "AlwaysFalseBP", "AlwaysTrueBP", "RandomBP"]
    parser.add_argument(
        "--bp",
        choices=bp_choices,
        help=f"bp to use of the following: {list(bp_choices)}, if not specified, runs all bps",
        type=str,
    )
    args = parser.parse_args()
    
    benchmarks = [args.benchmark]
    spec_apps = [int(x) for x in args.spec_number.split(',')] if args.spec_number else spec_choices
    # configs list is used if we weren't doing permutations, or to filter the permutations
    target_configs = [args.config] if args.config else config_choices
    bps = [args.bp] if args.bp else bp_choices

    def load_env_file(env_path):
        """Load environment variables from a .env file."""
        env_vars = {}
        if not os.path.exists(env_path):
            return env_vars
        
        with open(env_path, 'r') as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith('#'):
                    continue
                if '=' in line:
                    key, value = line.split('=', 1)
                    value = value.strip('"').strip("'")
                    env_vars[key] = value
        return env_vars

    script_dir = os.path.dirname(os.path.abspath(__file__))
    env_path = os.path.join(os.path.dirname(script_dir), ".env")
    env_vars = load_env_file(env_path)
    
    for key, value in env_vars.items():
        os.environ.setdefault(key, value)

    gem5_binary = os.getenv("gem5_path")
    config_script = os.getenv("repo_path") + "/config-files/launch_se_from_ckpt.py"
    spec_dir = os.getenv("SPEC_path")

    mem_sizes = { "SPEC17": 4 }
    slurm_mem_sizes = { "SPEC17": "5G" }
    ckpt_base_dirs = { "SPEC17": os.getenv("ckpt_path") + "/" }
    
    base_output_dir = os.getenv("repo_path") + "/1-output-jobs"
    create_directory(base_output_dir)
    
    submitted_jobs = []
    
    # =================================================================
    # Permutations Definition
    # =================================================================
    permutations_widths = (
        {"fetchWidth" : 3, "decodeWidth" : 3, "renameWidth" : 3, "dispatchWidth" : 6, "issueWidth" : 6, "wbWidth" : 6}, # [0] SmallO3
        {"fetchWidth" : 6, "decodeWidth" : 6, "renameWidth" : 6, "dispatchWidth" : 11, "issueWidth" : 11, "wbWidth" : 11} # [1] BigO3
    )
    
    permutations_commit_width = (
        {"commitWidth" : 4}, # [0] SmallO3
        {"commitWidth" : 5}, # [1]
        {"commitWidth" : 8}, # [2] BigO3
        {"commitWidth" : 9}  # [3]
    )

    permutations_ROB_entries = (
        {"numROBEntries" : 64},  # [0] MediumSonicBOOM
        {"numROBEntries" : 192}, # [1] SmallO3
        {"numROBEntries" : 720}  # [2] BigO3
    )

    permutations_Queue_entries = (
        {"LQEntries" : 16, "SQEntries" : 16, "numIQEntries": "MediumSonicBOOM"}, # [0] Medium
        {"LQEntries" : 20, "SQEntries" : 15, "numIQEntries": "SmallO3"}, # [1] Small
        {"LQEntries" : 48, "SQEntries" : 48, "numIQEntries": "BigO3"} # [2] Big
    )

    permutations_registers = (
        {"numPhysIntRegs" : 80, "numPhysFloatRegs" : 64},   # [0] Medium
        {"numPhysIntRegs" : 128, "numPhysFloatRegs" : 119}, # [1] Small
        {"numPhysIntRegs" : 228, "numPhysFloatRegs" : 240}  # [2] Big
    )

    # Restriction Maps
    map_width_to_commit = {
        0: [0, 1], # Width[0] (Small) goes with Commit[0,1]
        1: [2, 3]  # Width[1] (Big) goes with Commit[2,3]
    }

    map_rob_to_others = {
        0: [0], # ROB[0] strictly with Queue/Regs [0]
        1: [0, 1],    # ROB[1] mixes with Queue/Regs [0,1]
        2: [2]     # ROB[2] strictly with Queue/Regs [2]
    }

    for benchmark in benchmarks:
        ckpt_base_dir = ckpt_base_dirs[benchmark]
        apps = get_applications_by_benchmark(ckpt_base_dir)
        mem_size = mem_sizes[benchmark]
        slurm_mem_size = slurm_mem_sizes[benchmark]
        
        if not apps:
            print(f"Warning: No applications found for {benchmark}")
            continue
        
        print(f"\n{'='*60}")
        print(f"Generating Permutations for {benchmark}")
        print(f"{'='*60}")

        # ITERATE PERMUTATIONS INSTEAD OF STANDARD CONFIGS
        
        # 1. Width + Commit
        for w_idx, width_dict in enumerate(permutations_widths):
            # Determine Base Config Class based on Width Index
            # Index 0 is derived from SmallO3, Index 1 from BigO3
            base_config_name = "SmallO3" if w_idx == 0 else "BigO3"
            
            # If user filtered --config on command line, respect it
            if args.config and args.config != base_config_name:
                continue

            allowed_commits = map_width_to_commit.get(w_idx, [])
            
            for c_idx in allowed_commits:
                commit_dict = permutations_commit_width[c_idx]
                
                # 2. ROB + Queue + Registers
                for r_idx, rob_dict in enumerate(permutations_ROB_entries):
                    allowed_others = map_rob_to_others.get(r_idx, [])
                    
                    for q_idx in allowed_others:
                        queue_dict = permutations_Queue_entries[q_idx]
                        
                        for reg_idx in allowed_others:
                            regs_dict = permutations_registers[reg_idx]
                            
                            # MERGE DICTIONARIES
                            full_config_dict = {
                                **width_dict,
                                **commit_dict,
                                **rob_dict,
                                **queue_dict,
                                **regs_dict
                            }

                            # CREATE UNIQUE FOLDER NAME
                            # Naming scheme: BaseConfig_ROBxxx_IQxxx_CWx
                            # We pick key params to distinguish the simulation
                            rob_val = full_config_dict.get("numROBEntries")
                            iq_val = full_config_dict.get("numIQEntries")
                            cw_val = full_config_dict.get("commitWidth")
                            
                            # You can add more identifiers here if needed
                            dir_suffix = f"_ROB{rob_val}_IQ{iq_val}_CW{cw_val}_W{w_idx}"
                            unique_config_dir_name = f"{base_config_name}{dir_suffix}"

                            # RUN LOOP
                            for bp in bps:
                                for app in apps:
                                    if (int(app[:3]) not in spec_apps) and benchmark == "SPEC17":
                                        continue

                                    # Create output directory: config_unique/bp/benchmark/app/
                                    # Example: 1-output-jobs/SmallO3_ROB64_IQ64_CW4_W0/TAGE_SC_L/SPEC17/500.perlbench
                                    output_dir = create_directory(
                                        os.path.join(base_output_dir, unique_config_dir_name, bp, benchmark, app),
                                        clean_if_exists=True
                                    )
                                    
                                    # Generate sbatch script passing the FULL DICT
                                    sbatch_script = generate_sbatch_script(
                                        gem5_binary,
                                        config_script,
                                        spec_dir,
                                        app,
                                        base_config_name, # Passes "SmallO3" or "BigO3"
                                        bp,
                                        output_dir,
                                        mem_size,
                                        slurm_mem_size,
                                        full_config_dict # Passes the permutation dict
                                    )
                                    
                                    # Submit
                                    job_id = submit_job(sbatch_script)
                                    
                                    if job_id:
                                        submitted_jobs.append((unique_config_dir_name, bp, benchmark, app, job_id))
                                        print(f"Submitted {job_id}: {unique_config_dir_name}/{bp}/{app}")
                                    else:
                                        print(f"Failed: {unique_config_dir_name}/{bp}/{app}")
                                    
                                    # Slight delay
                                    time.sleep(0.5)

    print(f"\n{'='*60}")
    print(f"Summary: Submitted {len(submitted_jobs)} jobs")
    print(f"{'='*60}")
    
    print(f"\nMonitor jobs with: squeue -u $USER")
    print(f"Cancel all jobs with: scancel -u $USER")

if __name__ == "__main__":
    main()