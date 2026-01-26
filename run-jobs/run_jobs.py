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
        if item.startswith("ckpt-"):
            app_name = item.replace("ckpt-", "")
            apps.append(app_name)
    
    return sorted(apps)


def create_directory(path, clean_if_exists=False):
    """Create a directory, optionally cleaning it if it already exists."""
    if clean_if_exists and os.path.exists(path):
        import shutil
        shutil.rmtree(path)
    os.makedirs(path, exist_ok=True)
    return path


def generate_sbatch_script(gem5_binary, config_script, benchmark, app, config, 
                           output_dir, ckpt_path, disk_image, mem_size, slurm_mem_size):
    """Generate an sbatch script for running simulation with specific IQ size."""
    
    sbatch_content = f"""#!/bin/bash
#SBATCH --partition=ce_200
#SBATCH --nodelist=ce209
#SBATCH --mem-per-cpu={slurm_mem_size}
#SBATCH --job-name={app}_{config}
#SBATCH --output={output_dir}/slurm-%j.out

{gem5_binary}  --debug-flags=LTage,TageSCL -re --outdir={output_dir} {config_script} \
    --config {config} \
    --ckpt_path {ckpt_path} \
    --disk_image {disk_image} \
    --mem_size {mem_size} \
    --num_ticks 100000000000 
"""
    
    script_path = os.path.join(output_dir, "run.sbatch")
    with open(script_path, "w") as f:
        f.write(sbatch_content)
    
    return script_path


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
        choices=["Splash-4", "NAS", "SPEC17", "ALL"], 
        help="Benchmark to run (or ALL for all benchmarks)"
    )
    parser.add_argument(
        "--config", 
        choices=["MediumSonicBOOM",
                 "MediumSonicBOOM_TAGE_SC_L",
                 "MediumSonicBOOM_TAGE_L", 
                 "MediumSonicBOOM_TAGE_SC"],
        required=True,
        help="Configuration to use (if not specified, both will be used)"
    )
    args = parser.parse_args()
    
    benchmarks = [args.benchmark] if args.benchmark != "ALL" else ["Splash-4", "NAS", "SPEC17"]
    configs = []
    configs.append(args.config) if args.config else configs.extend(["MediumSonicBOOM", "MediumSonicBOOM_TAGE_SC_L"])
    
    # For gem5 v25.0
    #gem5_binary = "/nfs/home/ce/felixfdec/gem5v25_0/build/RISCV/gem5.opt
    # For gem5 v25.1
    gem5_binary = "/nfs/home/ce/felixfdec/gem5v25_0/build/RISCV/gem5.opt"

    config_script = "/nfs/home/ce/felixfdec/gem5/config-files-run-experiments/config-files/launch_fs_from_ckpt.py"
    
    # Disk images and memory sizes per benchmark
    disk_images = {
        "Splash-4": "/nfs/home/ce/felixfdec/riscv-ubuntu-gem5-appsSmall.img",
        "NAS": "/nfs/home/ce/felixfdec/riscv-ubuntu-gem5-appsSmall.img",
        "SPEC17": "/nfs/home/ce/felixfdec/riscv-ubuntu-gem5-appsSmall.img",
    }
    
    mem_sizes = {
        "Splash-4": 2,
        "NAS": 2,
        "SPEC17": 4,
    }

    slurm_mem_sizes = {
        "Splash-4": "2G",
        "NAS": "2G",
        "SPEC17": "5G",
    }
    
    ckpt_base_dirs = {
        "Splash-4": "/nfs/shared/ce/gem5/ckpts/RISCV/1core/2GB/Splash-4",
        "NAS": "/nfs/shared/ce/gem5/ckpts/RISCV/1core/2GB/NPB3.3-SER",
        "SPEC17": "/nfs/shared/ce/gem5/ckpts/RISCV/1core/4GB/SPEC17",
    }
    
    # Base directory for output
    base_output_dir = "/nfs/home/ce/felixfdec/gem5/config-files-run-experiments/1-output-jobs"
    create_directory(base_output_dir)
    
    submitted_jobs = []
    
    for benchmark in benchmarks:
        ckpt_base_dir = ckpt_base_dirs[benchmark]
        apps = get_applications_by_benchmark(ckpt_base_dir)
        disk_image = disk_images[benchmark]
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
            for app in apps:
                
                # Create output directory: config/benchmark/app/
                output_dir = create_directory(
                    os.path.join(base_output_dir, config, benchmark, app),
                    clean_if_exists=True
                )
                
                # Construct checkpoint path
                ckpt_name = f"ckpt-{app}"
                ckpt_path = os.path.join(ckpt_base_dir, ckpt_name)
                
                # Generate sbatch script
                sbatch_script = generate_sbatch_script(
                    gem5_binary,
                    config_script,
                    benchmark,
                    app,
                    config,
                    output_dir,
                    ckpt_path,
                    disk_image,
                    mem_size,
                    slurm_mem_size
                )
                
                # Submit the job
                job_id = submit_job(sbatch_script)
                
                if job_id:
                    submitted_jobs.append((config, benchmark, app, job_id))
                    print(f"Submitted job {job_id} for {config}/{benchmark}/{app}")
                else:
                    print(f"Failed to submit job for {config}/{benchmark}/{app}")
                
                # Small delay to avoid overwhelming the scheduler
                time.sleep(1)
    
    print(f"\n{'='*60}")
    print(f"Summary: Submitted {len(submitted_jobs)} jobs")
    print(f"{'='*60}")
    
    for config, benchmark, app, job_id in submitted_jobs:
        print(f"Job {job_id}: {config}/{benchmark}/{app}")
    
    print(f"\nMonitor jobs with: squeue -u $USER")
    print(f"Cancel all jobs with: scancel -u $USER")


if __name__ == "__main__":
    main()