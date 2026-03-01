import subprocess
import os
import time

SPEC_APPS = [
##  Aplicaciones con dos almoadillas no alcanzan ROI en tiempo razonable con qemu
### perlbench no esta anotado
###    "500.perlbench_r",  
    "502.gcc_r",
    "503.bwaves_r",
    "505.mcf_r",
    "507.cactuBSSN_r",
    "508.namd_r",
    "510.parest_r",
    "511.povray_r",
    "519.lbm_r", 
    "520.omnetpp_r",
    "521.wrf_r",
    "523.xalancbmk_r",
##    "525.x264_r",
    "526.blender_r", 
    "527.cam4_r",
    "531.deepsjeng_r",
##    "538.imagick_r",
    "541.leela_r",
    "544.nab_r",
    "548.exchange2_r",
    "549.fotonik3d_r",
    "554.roms_r",
    "557.xz_r",
]

# ============================================================================
# FUNCTIONS
# ============================================================================

def parse_spec(spec: str) -> tuple[str, str]:
    num, rest = spec.split(".", 1)
    name = rest[:-2] if rest.endswith("_r") else rest
    return num, name

def generate_script(app: str) -> str:
    """Generate the shell script to execute inside the gem5 disk image."""
    
    spec_num, spec_name = parse_spec(app)
    content = f"""#!/bin/bash

echo "Running {spec_name}"

cd /home/ubuntu/SPEC
./run_spec.sh {spec_num}

echo -e "\\n\\n ****** Done ******* \\n\\n"

m5 exit
"""
    return content


def create_directory(path):
    """Create a directory if it doesn't exist."""
    os.makedirs(path, exist_ok=True)
    return path


def generate_sbatch_script(gem5_binary, config_script, benchmark, app, script_content, output_dir):
    """Generate an sbatch script for taking a checkpoint."""
    
    # Escape quotes in script content for shell
    escaped_script = script_content.replace('"', '\\"').replace('$', '\\$')
    
    sbatch_content = f"""#!/bin/bash
#SBATCH --partition=ce_200
#SBATCH --exclude=ce210
#SBATCH --job-name=ckpt_{benchmark}_{app}
#SBATCH --output={output_dir}/slurm.out
#SBATCH --error={output_dir}/slurm.err
#SBATCH --mem-per-cpu=6G

echo "============================================"
echo "Taking checkpoint for {benchmark} - {app}"
echo "============================================"

{gem5_binary} -re --outdir={output_dir} {config_script} \\
    --app {app} \\
    --script "{escaped_script}"

exit_code=$?
if [ $exit_code -eq 0 ]; then
    echo "✓ Successfully completed checkpoint for {benchmark}/{app}"
else
    echo "✗ Failed to complete checkpoint for {benchmark}/{app} (exit code: $exit_code)"
fi

exit $exit_code
"""
    
    script_path = os.path.join(output_dir, f"take_ckpt_{benchmark}_{app}.sbatch")
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
    benchmarks = ["SPEC17"]
    gem5_binary = "/nfs/home/ce/felixfdec/gem5/build/RISCV/gem5.opt"
    config_script = "/nfs/home/ce/felixfdec/gem5/config-files-run-experiments/extra-tools/take-SPEC-checkopoints/take_1_app_ckpt.py"
    
    # Directory for sbatch scripts and logs
    sbatch_dir = "/nfs/home/ce/felixfdec/ckpts_fs_v25_1_logs"
    create_directory(sbatch_dir)
    
    submitted_jobs = []
    
    for benchmark in benchmarks:
        apps = SPEC_APPS
        
        for app in apps:
            print(f"\n{'='*60}")
            print(f"Preparing job for: {benchmark} - {app}")
            print(f"{'='*60}")
            
            # Create output directory for this specific job
            output_dir = create_directory(os.path.join(sbatch_dir, benchmark, app))
            
            # Generate the script content
            script = generate_script(app)
            
            # Generate sbatch script
            sbatch_script = generate_sbatch_script(
                gem5_binary, 
                config_script, 
                benchmark, 
                app, 
                script, 
                output_dir
            )
            
            # Submit the job
            job_id = submit_job(sbatch_script)
            
            if job_id:
                submitted_jobs.append((benchmark, app, job_id))
                print(f"✓ Submitted job {job_id} for {benchmark}/{app}")
            else:
                print(f"✗ Failed to submit job for {benchmark}/{app}")
            
            # Small delay to avoid overwhelming the scheduler
            time.sleep(0.1)
    
    print(f"\n{'='*60}")
    print(f"Summary: Submitted {len(submitted_jobs)} jobs")
    print(f"{'='*60}")
    
    for benchmark, app, job_id in submitted_jobs:
        print(f"Job {job_id}: {benchmark}/{app}")
    
    print(f"\nMonitor jobs with: squeue -u $USER")
    print(f"Cancel all jobs with: scancel -u $USER")


if __name__ == "__main__":
    main()