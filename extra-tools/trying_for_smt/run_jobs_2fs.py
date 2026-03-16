import subprocess
import os
import time
import argparse

# ============================================================================
# FUNCTIONS
# ============================================================================

def parse_spec(spec: str) -> tuple[str, str]:
    num, rest = spec.split(".", 1)
    name = rest[:-2] if rest.endswith("_r") else rest
    return num, name

def generate_script(app1: str, app2: str) -> str:
    """Generate the shell script to execute inside the gem5 disk image."""
    
    spec_num1, spec_name1 = parse_spec(app1)
    spec_num2, spec_name2 = parse_spec(app2)
    content = f"""#!/bin/bash

echo "Running {spec_name1} and {spec_name2}"

cd /home/ubuntu/SPEC
./run_spec.sh {spec_num1} &
./run_spec.sh {spec_num2}

echo -e "\\n\\n ****** Done ******* \\n\\n"

m5 exit
"""
    return content


def create_directory(path, clean_if_exists=False):
    """Create a directory, optionally cleaning it if it already exists."""
    if clean_if_exists and os.path.exists(path):
        import shutil
        shutil.rmtree(path)
    os.makedirs(path, exist_ok=True)
    return path


def generate_sbatch_script(gem5_binary, config_script, benchmark, app1, app2, script_content, output_dir, config, bp):
    """Generate an sbatch script for taking a checkpoint."""
    
    # Escape quotes in script content for shell
    escaped_script = script_content.replace('"', '\\"').replace('$', '\\$')

    spec_number1 = app1[:3]
    spec_number2 = app2[:3]
    
    sbatch_content = f"""#!/bin/bash
#SBATCH --partition=ce_200
#SBATCH --exclude=ce210
#SBATCH --job-name={app1}_{app2}_{config}
#SBATCH --output={output_dir}/slurm.out
#SBATCH --error={output_dir}/slurm.err
#SBATCH --mem-per-cpu=6G

echo "============================================"
echo "Taking checkpoint for {benchmark} - {app1} - {app2}"
echo "============================================"

{gem5_binary} -re --outdir={output_dir} {config_script} \
    --spec_number1 {spec_number1} \
    --spec_number2 {spec_number2} \
    --config {config} \
    --bp {bp} \
    --mem_size 4 \
    --num_ticks 100000000000 \
    --script "{escaped_script}"
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
    parser = argparse.ArgumentParser(description="Run gem5 full system simulations with 2 apps at the same time.")
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
    bp_choices = ["TAGE_SC_L", "TAGE_SC", "TAGE_L", "LTAGE", "LocalBP", "BiModeBP", 
                  "AlwaysFalseBP", "AlwaysTrueBP", "RandomBP", 
                  "TAGE_SC_L_8", "TAGE_SC_8", "TAGE_L_8"]
    parser.add_argument(
        "--bp",
        help=f"bp to use of the following: {list(bp_choices)}, if not specified, runs all bps",
        type=str,
    )
    args = parser.parse_args()
    spec_apps = [int(x) for x in args.spec_number.split(',')] if args.spec_number else spec_choices
    configs = [args.config] if args.config else config_choices

    if args.bp:
        bps = [x.strip() for x in args.bp.split(",") if x.strip()]
        invalid_bps = [x for x in bps if x not in bp_choices]
        if invalid_bps:
            parser.error(f"Invalid --bp value(s): {invalid_bps}. Valid values: {bp_choices}")
        # opcional: eliminar duplicados manteniendo orden
        bps = list(dict.fromkeys(bps))
    else:
        bps = bp_choices

    benchmarks = ["SPEC17"]
    gem5_binary = "/nfs/home/ce/felixfdec/gem5/build/RISCV/gem5.opt"
    config_script = "/nfs/home/ce/felixfdec/gem5/config-files-run-experiments/config-files/launch_2fs_from_ckpt.py"

    # Base directory for output
    base_output_dir = "/nfs/home/ce/felixfdec/gem5/config-files-run-experiments" + "/1-output-jobs"
    create_directory(base_output_dir)
    
    submitted_jobs = []
    
    for benchmark in benchmarks:
        apps = [
            ["541.leela_r", "505.mcf_r"],
            ["508.namd_r", "507.cactuBSSN_r"],
            ["548.exchange2_r", "557.xz_r"],
            ["502.gcc_r", "505.mcf_r"],
            ["508.namd_r", "544.nab_r"],
            ["554.roms_r", "527.cam4_r"],
            ["541.leela_r", "507.cactuBSSN_r"],
            ["508.namd_r", "502.gcc_r"],
            ["544.nab_r", "548.exchange2_r"],
            ["502.gcc_r", "503.bwaves_r"]
        ]
        
        for config in configs:
            for bp in bps:
                for app1, app2 in apps:
                    print(f"\n{'='*60}")
                    print(f"Preparing job for: {benchmark} - {app1} - {app2}")
                    print(f"{'='*60}")
                    
                    # Create output directory for this specific job
                    both_apps = app1 + "_" + app2
                    output_dir = create_directory(
                                    os.path.join(base_output_dir, "2fs", config, bp, benchmark, both_apps),
                                    clean_if_exists=True
                                )
                    
                    # Generate the script content
                    script = generate_script(app1, app2)
                    
                    # Generate sbatch script
                    sbatch_script = generate_sbatch_script(
                        gem5_binary, 
                        config_script, 
                        benchmark, 
                        app1,
                        app2, 
                        script, 
                        output_dir,
                        config, bp
                    )
                    
                    # Submit the job
                    job_id = submit_job(sbatch_script)
                    
                    if job_id:
                        submitted_jobs.append((benchmark, app1, app2, job_id))
                        print(f"✓ Submitted job {job_id} for {benchmark}/{app1}/{app2}")
                    else:
                        print(f"✗ Failed to submit job for {benchmark}/{app1}/{app2}")
                    
                    # Small delay to avoid overwhelming the scheduler
                    time.sleep(0.1)
    
    print(f"\n{'='*60}")
    print(f"Summary: Submitted {len(submitted_jobs)} jobs")
    print(f"{'='*60}")
    
    for benchmark, app1, app2, job_id in submitted_jobs:
        print(f"Job {job_id}: {benchmark}/{app1}/{app2}")
    
    print(f"\nMonitor jobs with: squeue -u $USER")
    print(f"Cancel all jobs with: scancel -u $USER")


if __name__ == "__main__":
    main()