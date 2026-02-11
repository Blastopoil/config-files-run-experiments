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
def generate_sbatch_script(gem5_binary, config_script, spec_dir, app, config, bp, 
                           output_dir, mem_size, slurm_mem_size):
    """Generate an sbatch script for running simulation with specific IQ size."""
    
    spec_number = app[:3]
    sbatch_content = f"""#!/bin/bash
#SBATCH --partition=ce_200
#SBATCH --exclude=ce210
#SBATCH --mem-per-cpu={slurm_mem_size}
#SBATCH --job-name={app}_{config}
#SBATCH --output={output_dir}/slurm-%j.out

cd {spec_dir}/{app}

{gem5_binary}  -re --outdir={output_dir} {config_script} \
    --spec_number {spec_number} \
    --config {config} \
    --bp {bp} \
    --mem_size {mem_size} \
    --num_ticks 100000000000 
"""
    
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
    config_choices = ["MediumSonicBOOM", "SmallO3", "BigO3", "CVA6"]
    parser.add_argument(
        "--config", 
        choices=config_choices,
        help=f"configuration to use of the following: {list(config_choices)}, if not specified, runs all configs",
    )
    bp_choices = ["TAGE_SC_L", "TAGE_SC", "TAGE_L", "LocalBP", "BiModeBP", "AlwaysFalseBP", "RandomBP"]
    parser.add_argument(
        "--bp",
        choices=bp_choices,
        help=f"bp to use of the following: {list(bp_choices)}, if not specified, runs all bps",
        type=str,
    )
    args = parser.parse_args()
    
    benchmarks = [args.benchmark]
    spec_apps = [int(x) for x in args.spec_number.split(',')] if args.spec_number else spec_choices
    configs = [args.config] if args.config else config_choices
    bps = [args.bp] if args.bp else bp_choices

    from dotenv import load_dotenv, find_dotenv

    # Loads the paths for the variables used here
    load_dotenv(find_dotenv())

    gem5_binary = os.getenv("gem5_path")
    #gem5_binary = "/nfs/home/ce/felixfdec/gem5/build/RISCV/gem5.opt"

    config_script = os.getenv("repo_path") + "/config-files/launch_se_from_ckpt.py"
    #config_script = "/nfs/home/ce/felixfdec/gem5/config-files-run-experiments/config-files/launch_se_from_ckpt.py"
    
    spec_dir = os.getenv("SPEC_path")

    mem_sizes = {
        "SPEC17": 4,
    }

    slurm_mem_sizes = {
        "SPEC17": "5G",
    }
    
    ckpt_base_dirs = {
        "SPEC17": os.getenv("ckpt_path") + "/",
    }
    
    # Base directory for output
    base_output_dir = os.getenv("repo_path") + "/1-output-jobs"
    create_directory(base_output_dir)
    
    submitted_jobs = []
    
    for benchmark in benchmarks:
        ckpt_base_dir = ckpt_base_dirs[benchmark]
        apps = get_applications_by_benchmark(ckpt_base_dir)
        print(apps)
        mem_size = mem_sizes[benchmark]
        slurm_mem_size = slurm_mem_sizes[benchmark]
        
        if not apps:
            print(f"Warning: No applications found for {benchmark}")
            continue
        
        print(f"\n{'='*60}")
        print(f"Found {len(apps)} applications for {benchmark}")
        print(f"Applications: {', '.join(apps)}")
        print(f"{'='*60}")
        
        for config in configs:
            for bp in bps:
                for app in apps:
                    
                    if (int(app[:3]) not in spec_apps) and benchmark == "SPEC17":
                        print(f"Skipping {app} as it's not in the specified list of SPEC17 apps.")
                        continue

                    # Create output directory: config/bp/benchmark/app/
                    output_dir = create_directory(
                        os.path.join(base_output_dir, config, bp, benchmark, app),
                        clean_if_exists=True
                    )
                    
                    # Generate sbatch script
                    sbatch_script = generate_sbatch_script(
                        gem5_binary,
                        config_script,
                        spec_dir,
                        app,
                        config,
                        bp,
                        output_dir,
                        mem_size,
                        slurm_mem_size
                    )
                    
                    # Submit the job
                    job_id = submit_job(sbatch_script)
                    
                    if job_id:
                        submitted_jobs.append((config, bp, benchmark, app, job_id))
                        print(f"Submitted job {job_id} for {config}/{bp}/{benchmark}/{app}")
                    else:
                        print(f"Failed to submit job for {config}/{bp}/{benchmark}/{app}")
                    
                    # Small delay to avoid overwhelming the scheduler
                    time.sleep(1)
    
    print(f"\n{'='*60}")
    print(f"Summary: Submitted {len(submitted_jobs)} jobs")
    print(f"{'='*60}")
    
    for config, bp, benchmark, app, job_id in submitted_jobs:
        print(f"Job {job_id}: {config}/{bp}/{benchmark}/{app}")
    
    print(f"\nMonitor jobs with: squeue -u $USER")
    print(f"Cancel all jobs with: scancel -u $USER")


if __name__ == "__main__":
    main()